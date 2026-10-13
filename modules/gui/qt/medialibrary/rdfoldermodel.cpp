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

#include "rdfoldermodel.hpp"

#include <QSet>

#include <vlc_media_library.h>

#include "mlhelper.hpp"
#include "qt.hpp"

RdFolderModel::RdFolderModel(QObject* parent)
    : RdLibraryModel(parent)
{
}

void RdFolderModel::setFolderId(const MLItemId& id)
{
    if (m_folderId == id)
        return;
    m_folderId = id;
    emit folderIdChanged();
    scheduleReload();
}

void RdFolderModel::setCategory(const QString& category)
{
    if (m_category == category)
        return;
    m_category = category;
    emit categoryChanged();
    scheduleReload();
}

void RdFolderModel::setCategoryMrls(const QStringList& mrls)
{
    if (m_categoryMrls == mrls)
        return;
    m_categoryMrls = mrls;
    emit categoryMrlsChanged();
    if (!m_folderId.isValid())
        scheduleReload();
}

void RdFolderModel::setOtherMrls(const QStringList& mrls)
{
    if (m_otherMrls == mrls)
        return;
    m_otherMrls = mrls;
    emit otherMrlsChanged();
    if (!m_folderId.isValid())
        scheduleReload();
}

RdLibraryModel::Loader RdFolderModel::createLoader() const
{
    const int64_t folderId = m_folderId.isValid() ? m_folderId.id : 0;
    const bool music = m_category == QLatin1String("music");

    QSet<QString> mine;
    QSet<QString> others;
    for (const QString& mrl : m_categoryMrls)
        mine.insert(RdLibraryItems::normalizedMrl(mrl));
    for (const QString& mrl : m_otherMrls)
        others.insert(RdLibraryItems::normalizedMrl(mrl));

    return [folderId, music, mine, others](vlc_medialibrary_t* ml) {
        RdLibraryItemList items;

        if (folderId == 0)
        {
            // the library folders of the category
            ml_unique_ptr<vlc_ml_folder_list_t> roots(vlc_ml_list_entry_points(ml, nullptr));
            if (!roots)
                return items;
            for (const vlc_ml_folder_t& folder : ml_range_iterate<vlc_ml_folder_t>(roots))
            {
                if (folder.b_banned || !folder.psz_mrl)
                    continue;
                const QString mrl = RdLibraryItems::normalizedMrl(qfu(folder.psz_mrl));
                if (mine.contains(mrl) || !others.contains(mrl))
                    items.push_back(RdLibraryItems::fromFolder(folder));
            }
            return items;
        }

        vlc_ml_folder_list_t* subfolders = nullptr;
        if (vlc_ml_list(ml, VLC_ML_LIST_SUBFOLDERS, nullptr, folderId, &subfolders) == VLC_SUCCESS && subfolders)
        {
            ml_unique_ptr<vlc_ml_folder_list_t> list(subfolders);
            for (const vlc_ml_folder_t& folder : ml_range_iterate<vlc_ml_folder_t>(list))
            {
                if (!folder.b_banned)
                    items.push_back(RdLibraryItems::fromFolder(folder));
            }
        }

        ml_unique_ptr<vlc_ml_media_list_t> media(vlc_ml_list_folder_media(ml, nullptr, folderId));
        if (media)
        {
            for (const vlc_ml_media_t& m : ml_range_iterate<vlc_ml_media_t>(media))
            {
                if ((m.i_type == VLC_ML_MEDIA_TYPE_AUDIO) == music)
                    items.push_back(RdLibraryItems::fromMedia(ml, m));
            }
        }
        return items;
    };
}
