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
#ifndef RD_MEDIA_INFO_HPP
#define RD_MEDIA_INFO_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QPointer>
#include <QVariant>

#include <vlc_common.h>

Q_MOC_INCLUDE("player/player_controller.hpp")

class PlayerController;

/**
 * redesign: the input statistics of the current media for the "Show Statistics" overlay of
 * the player (settings sidebar, Playback tab; Figma "playback" 5187:24492, Decision 13). The
 * values are the ones of VLC's Media Information > Statistics panel
 * (dialogs/mediainfo/info_panels.cpp), sent by the player with every statistics update, as
 * display text in `values`:
 *   readBytes, inputBitrate, demuxBytes, demuxBitrate, corrupted, discontinuity,
 *   decodedVideo, displayedPictures, latePictures, lostPictures,
 *   decodedAudio, playedBuffers, lostBuffers
 * The object follows the player only while it exists: the overlay creates it when it shows.
 * `collecting` is false when VLC does not collect statistics (option "stats").
 */
class RdInputStats : public QObject
{
    Q_OBJECT

    Q_PROPERTY(PlayerController* player READ player WRITE setPlayer NOTIFY playerChanged FINAL)
    Q_PROPERTY(QVariantMap values READ values NOTIFY valuesChanged FINAL)
    Q_PROPERTY(bool collecting READ collecting NOTIFY collectingChanged FINAL)

public:
    explicit RdInputStats(QObject* parent = nullptr);

    PlayerController* player() const;
    void setPlayer(PlayerController* player);

    QVariantMap values() const;
    bool collecting() const;

signals:
    void playerChanged();
    void valuesChanged();
    void collectingChanged();

private:
    void updateStats(const input_stats_t& stats);
    void onInputChanged(bool hasInput);
    void updateCollecting();

    QPointer<PlayerController> m_player;
    QVariantMap m_values;
    bool m_collecting = false;
};

/**
 * redesign: the file information of the current media for the "Show Metadata" panel of the
 * player (settings sidebar, Playback tab; video 9:17-9:19, Decision 24). The rows are the
 * ones of VLC's Media Information dialog: the media's meta data (title, artist, album, ...,
 * the non-empty ones, with VLC's localized names), its duration and location, then the
 * codec details of each stream (dialogs/mediainfo/info_panels.cpp, InfoPanel).
 *   sections: [ { title: string, rows: [ { label: string, value: string } ] } ]
 * Updated when the current media, its meta data or its information change.
 */
class RdMediaMeta : public QObject
{
    Q_OBJECT

    Q_PROPERTY(PlayerController* player READ player WRITE setPlayer NOTIFY playerChanged FINAL)
    Q_PROPERTY(QVariantList sections READ sections NOTIFY sectionsChanged FINAL)

public:
    explicit RdMediaMeta(QObject* parent = nullptr);

    PlayerController* player() const;
    void setPlayer(PlayerController* player);

    QVariantList sections() const;

signals:
    void playerChanged();
    void sectionsChanged();

private:
    void scheduleRefresh();
    void refresh();

    QPointer<PlayerController> m_player;
    QVariantList m_sections;
    bool m_refreshPending = false;
};

#endif // RD_MEDIA_INFO_HPP
