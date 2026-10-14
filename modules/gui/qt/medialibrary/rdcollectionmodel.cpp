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

#include "rdcollectionmodel.hpp"

#include <QHash>

#include <algorithm>

#include <vlc_media_library.h>

#include "mlhelper.hpp"
#include "qt.hpp"

namespace {

// how many songs of the history count for "Frequently Listened Artists"
constexpr uint32_t ARTIST_HISTORY_DEPTH = 200;

vlc_ml_query_params_t limitParams(int limit)
{
    vlc_ml_query_params_t params = vlc_ml_query_params_create();
    params.i_nbResults = static_cast<uint32_t>(limit);
    return params;
}

void appendMedia(vlc_medialibrary_t* ml, vlc_ml_media_list_t* list, RdLibraryItemList& items,
                 const std::function<bool(const vlc_ml_media_t&)>& keep = {})
{
    ml_unique_ptr<vlc_ml_media_list_t> media(list);
    if (!media)
        return;
    for (const vlc_ml_media_t& m : ml_range_iterate<vlc_ml_media_t>(media))
    {
        if (!keep || keep(m))
            items.push_back(RdLibraryItems::fromMedia(ml, m));
    }
}

} // namespace

RdCollectionModel::RdCollectionModel(QObject* parent)
    : RdLibraryModel(parent)
{
}

void RdCollectionModel::setSection(const QString& section)
{
    if (m_section == section)
        return;
    m_section = section;
    emit sectionChanged();
    requestReload();
}

void RdCollectionModel::setLimit(int limit)
{
    if (m_limit == limit)
        return;
    m_limit = limit;
    emit limitChanged();
    // follows the window width: wait until a resize settles (the first load is requested by the
    // other parameters)
    scheduleReload();
}

void RdCollectionModel::setIds(const QVariantList& ids)
{
    if (m_ids == ids)
        return;
    m_ids = ids;
    emit idsChanged();
    requestReload();
}

RdLibraryModel::Loader RdCollectionModel::createLoader() const
{
    const QString section = m_section;
    const int limit = (m_limit > 0 && m_limit < MAX_ROWS) ? m_limit : MAX_ROWS;
    std::vector<int64_t> ids;
    for (const QVariant& id : m_ids)
        ids.push_back(id.toLongLong());

    return [section, limit, ids](vlc_medialibrary_t* ml) {
        RdLibraryItemList items;
        const vlc_ml_query_params_t params = limitParams(limit);

        if (section == QLatin1String("continueWatching"))
        {
            // the history holds finished videos too: read more than needed, keep the started ones
            const vlc_ml_query_params_t wide = limitParams(limit * 4);
            appendMedia(ml, vlc_ml_list_video_history(ml, &wide), items, [](const vlc_ml_media_t& m) {
                return m.f_progress > 0. && m.f_progress < 1.;
            });
            if (items.size() > static_cast<size_t>(limit))
                items.resize(static_cast<size_t>(limit));
        }
        else if (section == QLatin1String("listenAgain"))
        {
            appendMedia(ml, vlc_ml_list_audio_history(ml, &params), items);
        }
        else if (section == QLatin1String("latestStreams"))
        {
            appendMedia(ml, vlc_ml_list_history(ml, &params, VLC_ML_HISTORY_TYPE_NETWORK), items);
        }
        else if (section == QLatin1String("frequentFolders"))
        {
            for (size_t i = 0; i < ids.size() && i < static_cast<size_t>(limit); ++i)
            {
                const int64_t id = ids[i];
                ml_unique_ptr<vlc_ml_folder_t> folder(vlc_ml_get_folder(ml, id));
                if (folder && folder->b_present && !folder->b_banned)
                    items.push_back(RdLibraryItems::fromFolder(*folder));
            }
        }
        else if (section == QLatin1String("frequentPlaylists"))
        {
            for (size_t i = 0; i < ids.size() && i < static_cast<size_t>(limit); ++i)
            {
                const int64_t id = ids[i];
                ml_unique_ptr<vlc_ml_playlist_t> playlist(vlc_ml_get_playlist(ml, id));
                if (playlist)
                    items.push_back(RdLibraryItems::fromPlaylist(*playlist));
            }
        }
        else if (section == QLatin1String("frequentArtists"))
        {
            const vlc_ml_query_params_t history = limitParams(ARTIST_HISTORY_DEPTH);
            ml_unique_ptr<vlc_ml_media_list_t> songs(vlc_ml_list_audio_history(ml, &history));
            QHash<int64_t, unsigned> plays;
            if (songs)
            {
                for (const vlc_ml_media_t& m : ml_range_iterate<vlc_ml_media_t>(songs))
                {
                    if (m.album_track.i_artist_id > 0)
                        plays[m.album_track.i_artist_id] += std::max(m.i_playcount, 1u);
                }
            }
            std::vector<std::pair<int64_t, unsigned>> ranked;
            for (auto it = plays.cbegin(); it != plays.cend(); ++it)
                ranked.emplace_back(it.key(), it.value());
            std::stable_sort(ranked.begin(), ranked.end(), [](const auto& a, const auto& b) {
                return a.second > b.second;
            });
            for (const auto& entry : ranked)
            {
                if (items.size() >= static_cast<size_t>(limit))
                    break;
                ml_unique_ptr<vlc_ml_artist_t> artist(vlc_ml_get_artist(ml, entry.first));
                if (artist)
                    items.push_back(RdLibraryItems::fromArtist(*artist));
            }
        }
        return items;
    };
}
