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
    params.i_nbResults = limit > 0 ? static_cast<uint32_t>(limit) : 0;
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

RdLibraryItem fromAlbum(const vlc_ml_album_t& album)
{
    RdLibraryItem item;
    item.kind = RdLibraryItem::Album;
    item.id = MLItemId(album.i_id, VLC_ML_PARENT_ALBUM);
    item.title = qfu(album.psz_title);
    item.artist = qfu(album.psz_artist);
    item.subtitle = item.artist;
    item.album = item.title;
    item.count = static_cast<int>(album.i_nb_tracks);
    item.duration = album.i_duration;
    item.isFavorite = album.b_is_favorite;
    const vlc_ml_thumbnail_t& small = album.thumbnails[VLC_ML_THUMBNAIL_SMALL];
    if (small.i_status == VLC_ML_THUMBNAIL_STATUS_AVAILABLE && small.psz_mrl)
        item.thumbnail = qfu(small.psz_mrl);
    return item;
}

RdLibraryItem fromGenre(const vlc_ml_genre_t& genre)
{
    RdLibraryItem item;
    item.kind = RdLibraryItem::Genre;
    item.id = MLItemId(genre.i_id, VLC_ML_PARENT_GENRE);
    item.title = qfu(genre.psz_name);
    item.count = static_cast<int>(genre.i_nb_tracks);
    item.isFavorite = genre.b_is_favorite;
    return item;
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
    scheduleReload();
}

void RdCollectionModel::setParentId(const MLItemId& id)
{
    if (m_parentId == id)
        return;
    m_parentId = id;
    emit parentIdChanged();
    scheduleReload();
}

void RdCollectionModel::setLimit(int limit)
{
    if (m_limit == limit)
        return;
    m_limit = limit;
    emit limitChanged();
    scheduleReload();
}

void RdCollectionModel::setIds(const QVariantList& ids)
{
    if (m_ids == ids)
        return;
    m_ids = ids;
    emit idsChanged();
    scheduleReload();
}

bool RdCollectionModel::canLoad() const
{
    if (m_section.isEmpty())
        return false;
    if (m_section == QLatin1String("media"))
        return m_parentId.isValid();
    return true;
}

RdLibraryModel::Loader RdCollectionModel::createLoader() const
{
    const QString section = m_section;
    const MLItemId parentId = m_parentId;
    const int limit = m_limit;
    std::vector<int64_t> ids;
    for (const QVariant& id : m_ids)
        ids.push_back(id.toLongLong());

    return [section, parentId, limit, ids](vlc_medialibrary_t* ml) {
        RdLibraryItemList items;
        const vlc_ml_query_params_t params = limitParams(limit);

        if (section == QLatin1String("continueWatching"))
        {
            // the history holds finished videos too: read more than needed, keep the started ones
            const vlc_ml_query_params_t wide = limitParams(limit > 0 ? limit * 4 : 0);
            appendMedia(ml, vlc_ml_list_video_history(ml, &wide), items, [](const vlc_ml_media_t& m) {
                return m.f_progress > 0. && m.f_progress < 1.;
            });
            if (limit > 0 && items.size() > static_cast<size_t>(limit))
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
        else if (section == QLatin1String("recent"))
        {
            appendMedia(ml, vlc_ml_list_history(ml, &params, VLC_ML_HISTORY_TYPE_GLOBAL), items);
        }
        else if (section == QLatin1String("frequentFolders"))
        {
            for (int64_t id : ids)
            {
                ml_unique_ptr<vlc_ml_folder_t> folder(vlc_ml_get_folder(ml, id));
                if (folder && folder->b_present && !folder->b_banned)
                    items.push_back(RdLibraryItems::fromFolder(*folder));
            }
        }
        else if (section == QLatin1String("frequentPlaylists"))
        {
            for (int64_t id : ids)
            {
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
                if (limit > 0 && items.size() >= static_cast<size_t>(limit))
                    break;
                ml_unique_ptr<vlc_ml_artist_t> artist(vlc_ml_get_artist(ml, entry.first));
                if (artist)
                    items.push_back(RdLibraryItems::fromArtist(*artist));
            }
        }
        else if (section == QLatin1String("albums"))
        {
            ml_unique_ptr<vlc_ml_album_list_t> list(vlc_ml_list_albums(ml, &params));
            if (list)
                for (const vlc_ml_album_t& album : ml_range_iterate<vlc_ml_album_t>(list))
                    items.push_back(fromAlbum(album));
        }
        else if (section == QLatin1String("artists"))
        {
            ml_unique_ptr<vlc_ml_artist_list_t> list(vlc_ml_list_artists(ml, &params, false));
            if (list)
                for (const vlc_ml_artist_t& artist : ml_range_iterate<vlc_ml_artist_t>(list))
                    items.push_back(RdLibraryItems::fromArtist(artist));
        }
        else if (section == QLatin1String("genres"))
        {
            ml_unique_ptr<vlc_ml_genre_list_t> list(vlc_ml_list_genres(ml, &params));
            if (list)
                for (const vlc_ml_genre_t& genre : ml_range_iterate<vlc_ml_genre_t>(list))
                    items.push_back(fromGenre(genre));
        }
        else if (section == QLatin1String("playlists"))
        {
            ml_unique_ptr<vlc_ml_playlist_list_t> list(vlc_ml_list_playlists(ml, &params, VLC_ML_PLAYLIST_TYPE_ALL));
            if (list)
                for (const vlc_ml_playlist_t& playlist : ml_range_iterate<vlc_ml_playlist_t>(list))
                    items.push_back(RdLibraryItems::fromPlaylist(playlist));
        }
        else if (section == QLatin1String("media") && parentId.isValid())
        {
            appendMedia(ml, vlc_ml_list_media_of(ml, &params, parentId.type, parentId.id), items);
        }
        return items;
    };
}
