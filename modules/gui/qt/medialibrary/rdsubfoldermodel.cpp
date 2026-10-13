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

RdSubfolderModel::RdSubfolderModel(QObject* parent)
    : MLBaseModel(parent)
{
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
    case VLC_ML_EVENT_FOLDER_ADDED:
    case VLC_ML_EVENT_FOLDER_DELETED:
    case VLC_ML_EVENT_ENTRY_POINT_ADDED:
    case VLC_ML_EVENT_ENTRY_POINT_REMOVED:
    case VLC_ML_EVENT_ENTRY_POINT_BANNED:
    case VLC_ML_EVENT_ENTRY_POINT_UNBANNED:
        emit resetRequested();
        return;
    case VLC_ML_EVENT_FOLDER_UPDATED:
        updateItemInCache(MLItemId(event.modification.i_entity_id, VLC_ML_PARENT_FOLDER));
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

std::vector<const vlc_ml_folder_t*>
RdSubfolderModel::Loader::folders(vlc_medialibrary_t* ml, ml_unique_ptr<vlc_ml_folder_list_t>& holder) const
{
    std::vector<const vlc_ml_folder_t*> result;
    const bool roots = !m_parent.isValid();

    if (roots)
    {
        holder.reset(vlc_ml_list_entry_points(ml, nullptr));
    }
    else
    {
        vlc_ml_folder_list_t* list = nullptr;
        if (vlc_ml_list(ml, VLC_ML_LIST_SUBFOLDERS, nullptr, m_parent.id, &list) == VLC_SUCCESS)
            holder.reset(list);
    }
    if (!holder)
        return result;

    const QString pattern = QString::fromUtf8(m_searchPattern);
    for (const vlc_ml_folder_t& folder : ml_range_iterate<vlc_ml_folder_t>(holder))
    {
        if (folder.b_banned || !folder.psz_mrl)
            continue;
        if (roots)
        {
            const QString key = RdLibraryItems::mrlKey(qfu(folder.psz_mrl));
            if (!m_mine.contains(key) && m_others.contains(key))
                continue;
        }
        if (!pattern.isEmpty() && !qfu(folder.psz_name).contains(pattern, Qt::CaseInsensitive))
            continue;
        result.push_back(&folder);
    }

    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    const bool desc = m_sortDesc;
    std::stable_sort(result.begin(), result.end(), [&](const vlc_ml_folder_t* a, const vlc_ml_folder_t* b) {
        const int cmp = collator.compare(qfu(a->psz_name), qfu(b->psz_name));
        return desc ? cmp > 0 : cmp < 0;
    });
    return result;
}

size_t RdSubfolderModel::Loader::count(vlc_medialibrary_t* ml, const vlc_ml_query_params_t*) const
{
    ml_unique_ptr<vlc_ml_folder_list_t> holder;
    return folders(ml, holder).size();
}

std::vector<std::unique_ptr<MLItem>>
RdSubfolderModel::Loader::load(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const
{
    ml_unique_ptr<vlc_ml_folder_list_t> holder;
    const std::vector<const vlc_ml_folder_t*> all = folders(ml, holder);

    const size_t offset = queryParams ? queryParams->i_offset : 0;
    const size_t count = (queryParams && queryParams->i_nbResults > 0) ? queryParams->i_nbResults : all.size();

    std::vector<std::unique_ptr<MLItem>> result;
    for (size_t i = offset; i < all.size() && i < offset + count; ++i)
        result.emplace_back(std::make_unique<MLFolder>(all[i]));
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
