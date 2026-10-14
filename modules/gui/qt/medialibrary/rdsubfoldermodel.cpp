/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#if HAVE_CONFIG_H
# include "config.h"
#endif

#include "rdsubfoldermodel.hpp"

#include <QCollator>

#include <algorithm>

#include <vlc_media_library.h>

#include "mlfolder.hpp"
#include "rdlibrarymodel.hpp"
#include "qt.hpp"

// folder events of a scan reload a level at most this often
static constexpr int SCAN_RESET_DELAY_MS = 300;

RdSubfolderModel::RdSubfolderModel(QObject* parent)
    : MLBaseModel(parent)
{
    m_scanResetTimer.setSingleShot(true);
    m_scanResetTimer.setInterval(SCAN_RESET_DELAY_MS);
    connect(&m_scanResetTimer, &QTimer::timeout, this, &RdSubfolderModel::resetRequested);
}

QHash<int, QByteArray> RdSubfolderModel::roleNames() const
{
    return {
        { FOLDER_ID, QByteArrayLiteral("id") },
        { FOLDER_TITLE, QByteArrayLiteral("title") },
        { FOLDER_MRL, QByteArrayLiteral("mrl") },
        { FOLDER_COUNT, QByteArrayLiteral("count") },
        { FOLDER_NB_VIDEOS, QByteArrayLiteral("nb_videos") },
        { FOLDER_NB_AUDIOS, QByteArrayLiteral("nb_audios") },
    };
}

void RdSubfolderModel::setCategoryMrls(const QStringList& mrls)
{
    if (m_categoryMrls == mrls)
        return;
    m_categoryMrls = mrls;
    emit categoryMrlsChanged();
    if (!m_parent.isValid())
        emit resetRequested();
}

void RdSubfolderModel::setOtherMrls(const QStringList& mrls)
{
    if (m_otherMrls == mrls)
        return;
    m_otherMrls = mrls;
    emit otherMrlsChanged();
    if (!m_parent.isValid())
        emit resetRequested();
}

QVariant RdSubfolderModel::itemRoleData(const MLItem* item, int role) const
{
    const auto folder = static_cast<const MLFolder*>(item);
    if (!folder)
        return {};

    switch (role)
    {
    case Qt::DisplayRole:
    case FOLDER_TITLE:
        return folder->getTitle();
    case FOLDER_ID:
        return QVariant::fromValue(folder->getId());
    case FOLDER_MRL:
        return folder->getMRL();
    case FOLDER_COUNT:
        return folder->getCount();
    case FOLDER_NB_VIDEOS:
        return folder->getVideoCount();
    case FOLDER_NB_AUDIOS:
        return folder->getAudioCount();
    default:
        return {};
    }
}

vlc_ml_sorting_criteria_t RdSubfolderModel::nameToCriteria(QByteArray name) const
{
    return name == QByteArrayLiteral("title") ? VLC_ML_SORTING_ALPHA : VLC_ML_SORTING_DEFAULT;
}

std::unique_ptr<MLListCacheLoader> RdSubfolderModel::createMLLoader() const
{
    return std::make_unique<MLListCacheLoader>(m_mediaLib, std::make_shared<RdSubfolderModel::Loader>(*this));
}

void RdSubfolderModel::onVlcMlEvent(const MLEvent& event)
{
    switch (event.i_type)
    {
    case VLC_ML_EVENT_FOLDER_DELETED:
    case VLC_ML_EVENT_ENTRY_POINT_ADDED:
    case VLC_ML_EVENT_ENTRY_POINT_REMOVED:
    case VLC_ML_EVENT_ENTRY_POINT_BANNED:
    case VLC_ML_EVENT_ENTRY_POINT_UNBANNED:
        m_scanResetTimer.stop();
        emit resetRequested();
        return;
    // folders found or updated during a scan: reload the level at most every
    // SCAN_RESET_DELAY_MS (the first event starts the delay, the next ones join it).
    // MLEvent does not copy the id of an updated folder (mlevent.hpp), so the level reloads.
    case VLC_ML_EVENT_FOLDER_ADDED:
    case VLC_ML_EVENT_FOLDER_UPDATED:
        if (!m_scanResetTimer.isActive())
            m_scanResetTimer.start();
        return;
    default:
        break;
    }
    MLBaseModel::onVlcMlEvent(event);
}

// Loader

RdSubfolderModel::Loader::Loader(const RdSubfolderModel& model)
    : MLOp(model)
{
    for (const QString& mrl : model.m_categoryMrls)
        m_mine.insert(RdLibraryItems::mrlKey(mrl));
    for (const QString& mrl : model.m_otherMrls)
        m_others.insert(RdLibraryItems::mrlKey(mrl));
}

namespace {

bool keyInside(const QString& rootKey, const QString& key)
{
    return key == rootKey || (key.startsWith(rootKey) && key.at(rootKey.size()) == QLatin1Char('/'));
}

// the folder `key` below the library folder `rootId`, walking down one level at a time
ml_unique_ptr<vlc_ml_folder_t> findFolder(vlc_medialibrary_t* ml, int64_t rootId, const QString& key)
{
    int64_t current = rootId;
    while (current != 0)
    {
        ml_unique_ptr<vlc_ml_folder_t> folder(vlc_ml_get_folder(ml, current));
        if (!folder || !folder->psz_mrl)
            return {};
        if (RdLibraryItems::mrlKey(qfu(folder->psz_mrl)) == key)
            return folder;

        vlc_ml_folder_list_t* list = nullptr;
        if (vlc_ml_list(ml, VLC_ML_LIST_SUBFOLDERS, nullptr, current, &list) != VLC_SUCCESS || !list)
            return {};
        ml_unique_ptr<vlc_ml_folder_list_t> subfolders(list);
        int64_t next = 0;
        for (const vlc_ml_folder_t& sub : ml_range_iterate<vlc_ml_folder_t>(subfolders))
        {
            if (sub.psz_mrl && keyInside(RdLibraryItems::mrlKey(qfu(sub.psz_mrl)), key))
            {
                next = sub.i_id;
                break;
            }
        }
        current = next;
    }
    return {};
}

} // namespace

void RdSubfolderModel::Loader::addInnerFolders(vlc_medialibrary_t* ml, Folders& result) const
{
    for (const QString& key : m_mine)
    {
        bool isRoot = false;
        int64_t containingRoot = 0;
        bool containingRootShown = false;
        for (const vlc_ml_folder_t& root : ml_range_iterate<vlc_ml_folder_t>(result.list))
        {
            if (root.b_banned || !root.psz_mrl)
                continue;
            const QString rootKey = RdLibraryItems::mrlKey(qfu(root.psz_mrl));
            if (rootKey == key)
            {
                isRoot = true;
                break;
            }
            if (keyInside(rootKey, key))
            {
                containingRoot = root.i_id;
                // the library folder is in this category, or in none (shown in both)
                containingRootShown = m_mine.contains(rootKey) || !m_others.contains(rootKey);
            }
        }
        if (isRoot || containingRoot == 0)
            continue;
        // already shown in this category inside its library folder or a folder above it
        const bool shownAbove = std::any_of(m_mine.cbegin(), m_mine.cend(), [&key](const QString& other) {
            return other != key && keyInside(other, key);
        });
        if (shownAbove || containingRootShown)
            continue;
        ml_unique_ptr<vlc_ml_folder_t> folder = findFolder(ml, containingRoot, key);
        if (folder)
            result.extra.push_back(std::move(folder));
    }
}

void RdSubfolderModel::Loader::folders(vlc_medialibrary_t* ml, Folders& result) const
{
    const bool roots = !m_parent.isValid();

    if (roots)
    {
        result.list.reset(vlc_ml_list_entry_points(ml, nullptr));
    }
    else
    {
        vlc_ml_folder_list_t* list = nullptr;
        if (vlc_ml_list(ml, VLC_ML_LIST_SUBFOLDERS, nullptr, m_parent.id, &list) == VLC_SUCCESS)
            result.list.reset(list);
    }
    if (!result.list)
        return;

    const QString pattern = QString::fromUtf8(m_searchPattern);
    const auto matches = [&pattern](const vlc_ml_folder_t& folder) {
        return pattern.isEmpty() || qfu(folder.psz_name).contains(pattern, Qt::CaseInsensitive);
    };

    for (const vlc_ml_folder_t& folder : ml_range_iterate<vlc_ml_folder_t>(result.list))
    {
        // below the library folders every row counts (VLC_ML_COUNT_SUBFOLDERS counts them all,
        // a folder on an unplugged drive has no MRL)
        if (roots)
        {
            if (folder.b_banned || !folder.psz_mrl)
                continue;
            const QString key = RdLibraryItems::mrlKey(qfu(folder.psz_mrl));
            if (!m_mine.contains(key) && m_others.contains(key))
                continue;
        }
        if (matches(folder))
            result.sorted.push_back(&folder);
    }

    if (roots)
    {
        addInnerFolders(ml, result);
        for (const ml_unique_ptr<vlc_ml_folder_t>& folder : result.extra)
        {
            if (matches(*folder))
                result.sorted.push_back(folder.get());
        }
    }

    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    const bool desc = m_sortDesc;
    std::stable_sort(result.sorted.begin(), result.sorted.end(), [&](const vlc_ml_folder_t* a, const vlc_ml_folder_t* b) {
        const int cmp = collator.compare(qfu(a->psz_name), qfu(b->psz_name));
        return desc ? cmp > 0 : cmp < 0;
    });
}

size_t RdSubfolderModel::Loader::count(vlc_medialibrary_t* ml, const vlc_ml_query_params_t*) const
{
    // below the library folders without a search: the media library counts
    if (m_parent.isValid() && m_searchPattern.isEmpty())
    {
        size_t count = 0;
        if (vlc_ml_list(ml, VLC_ML_COUNT_SUBFOLDERS, nullptr, m_parent.id, &count) == VLC_SUCCESS)
            return count;
    }
    Folders all;
    folders(ml, all);
    return all.sorted.size();
}

std::vector<std::unique_ptr<MLItem>>
RdSubfolderModel::Loader::load(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const
{
    Folders all;
    folders(ml, all);

    const size_t offset = queryParams ? queryParams->i_offset : 0;
    const size_t count = (queryParams && queryParams->i_nbResults > 0) ? queryParams->i_nbResults : all.sorted.size();

    // only the rows of the page
    std::vector<std::unique_ptr<MLItem>> result;
    for (size_t i = offset; i < all.sorted.size() && i < offset + count; ++i)
        result.emplace_back(std::make_unique<MLFolder>(all.sorted[i]));
    return result;
}

std::unique_ptr<MLItem> RdSubfolderModel::Loader::loadItemById(vlc_medialibrary_t* ml, MLItemId itemId) const
{
    assert(itemId.type == VLC_ML_PARENT_FOLDER);
    ml_unique_ptr<vlc_ml_folder_t> folder(vlc_ml_get_folder(ml, itemId.id));
    if (!folder)
        return nullptr;
    return std::make_unique<MLFolder>(folder.get());
}
