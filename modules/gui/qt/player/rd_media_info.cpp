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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "rd_media_info.hpp"

#include <QLocale>
#include <QUrl>

#include <vlc_configuration.h>
#include <vlc_input_item.h>
#include <vlc_meta.h>
#include <vlc_player.h>

#include "qt.hpp"
#include "player/player_controller.hpp"
#include "util/shared_input_item.hpp"
#include "util/vlctick.hpp"

namespace {

QString formatCount(uint64_t count)
{
    return QLocale().toString(static_cast<qulonglong>(count));
}

// a count with VLC's unit for it ("blocks", "frames", "buffers")
QString formatCount(uint64_t count, const QString& unit)
{
    return QStringLiteral("%1 %2").arg(formatCount(count), unit);
}

QString formatSize(uint64_t bytes)
{
    return QLocale().formattedDataSize(static_cast<qint64>(bytes));
}

// the statistics bitrates are in bytes per microsecond (info_panels.cpp shows them x 8000)
QString formatBitrate(float bitrate)
{
    return qtr("%1 kb/s").arg(QLocale().toString(bitrate * 8000.f, 'f', 0));
}

QVariantMap row(const QString& label, const QString& value)
{
    return QVariantMap{ { QStringLiteral("label"), label }, { QStringLiteral("value"), value } };
}

} // namespace

/* RdInputStats */

RdInputStats::RdInputStats(QObject* parent)
    : QObject(parent)
{
}

PlayerController* RdInputStats::player() const
{
    return m_player;
}

void RdInputStats::setPlayer(PlayerController* player)
{
    if (m_player == player)
        return;

    if (m_player)
        disconnect(m_player.data(), nullptr, this, nullptr);

    m_player = player;

    if (m_player)
    {
        connect(player, &PlayerController::statisticsUpdated, this, &RdInputStats::updateStats);
        connect(player, &PlayerController::inputChanged, this, &RdInputStats::onInputChanged);
    }

    updateCollecting();
    emit playerChanged();
}

QVariantMap RdInputStats::values() const
{
    return m_values;
}

bool RdInputStats::collecting() const
{
    return m_collecting;
}

void RdInputStats::updateStats(const input_stats_t& stats)
{
    m_values = QVariantMap{
        { QStringLiteral("readBytes"), formatSize(stats.i_read_bytes) },
        { QStringLiteral("inputBitrate"), formatBitrate(stats.f_input_bitrate) },
        { QStringLiteral("demuxBytes"), formatSize(stats.i_demux_read_bytes) },
        { QStringLiteral("demuxBitrate"), formatBitrate(stats.f_demux_bitrate) },
        { QStringLiteral("corrupted"), formatCount(stats.i_demux_corrupted) },
        { QStringLiteral("discontinuity"), formatCount(stats.i_demux_discontinuity) },
        { QStringLiteral("decodedVideo"), formatCount(stats.i_decoded_video, qtr("blocks")) },
        { QStringLiteral("displayedPictures"), formatCount(stats.i_displayed_pictures, qtr("frames")) },
        { QStringLiteral("latePictures"), formatCount(stats.i_late_pictures, qtr("frames")) },
        { QStringLiteral("lostPictures"), formatCount(stats.i_lost_pictures, qtr("frames")) },
        { QStringLiteral("decodedAudio"), formatCount(stats.i_decoded_audio, qtr("blocks")) },
        { QStringLiteral("playedBuffers"), formatCount(stats.i_played_abuffers, qtr("buffers")) },
        { QStringLiteral("lostBuffers"), formatCount(stats.i_lost_abuffers, qtr("buffers")) },
    };
    emit valuesChanged();

    if (!m_collecting)
    {
        m_collecting = true;
        emit collectingChanged();
    }
}

void RdInputStats::onInputChanged(bool hasInput)
{
    // the statistics belong to the media that played: start empty for the next one, which
    // reads the "stats" option again when it opens
    if (!m_values.isEmpty())
    {
        m_values.clear();
        emit valuesChanged();
    }
    if (hasInput)
        updateCollecting();
}

void RdInputStats::updateCollecting()
{
    const bool collecting = config_GetInt("stats") != 0;
    if (collecting == m_collecting)
        return;
    m_collecting = collecting;
    emit collectingChanged();
}

/* RdMediaMeta */

RdMediaMeta::RdMediaMeta(QObject* parent)
    : QObject(parent)
{
}

PlayerController* RdMediaMeta::player() const
{
    return m_player;
}

void RdMediaMeta::setPlayer(PlayerController* player)
{
    if (m_player == player)
        return;

    if (m_player)
        disconnect(m_player.data(), nullptr, this, nullptr);

    m_player = player;

    if (m_player)
    {
        connect(player, &PlayerController::inputChanged, this, &RdMediaMeta::scheduleRefresh);
        connect(player, &PlayerController::currentMetaChanged, this, &RdMediaMeta::scheduleRefresh);
        connect(player, &PlayerController::infoChanged, this, &RdMediaMeta::scheduleRefresh);
    }

    refresh();
    emit playerChanged();
}

QVariantList RdMediaMeta::sections() const
{
    return m_sections;
}

// a new media sends its meta data and information in several steps: read them once after
// the burst
void RdMediaMeta::scheduleRefresh()
{
    if (m_refreshPending)
        return;
    m_refreshPending = true;
    QMetaObject::invokeMethod(this, [this]() {
        m_refreshPending = false;
        refresh();
    }, Qt::QueuedConnection);
}

void RdMediaMeta::refresh()
{
    QVariantList sections;

    SharedInputItem item;
    if (m_player)
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker lock{ player };
        input_item_t* media = vlc_player_GetCurrentMedia(player);
        if (media)
            item = SharedInputItem(media, true);
    }

    if (item)
    {
        // the meta data of VLC's Media Information dialog (General and Metadata tabs)
        static const vlc_meta_type_t metaTypes[] = {
            vlc_meta_Title, vlc_meta_Artist, vlc_meta_AlbumArtist, vlc_meta_Album,
            vlc_meta_ShowName, vlc_meta_Season, vlc_meta_Episode, vlc_meta_TrackNumber,
            vlc_meta_TrackTotal, vlc_meta_DiscNumber, vlc_meta_Genre, vlc_meta_Date,
            vlc_meta_Director, vlc_meta_Actors, vlc_meta_Description, vlc_meta_Copyright,
            vlc_meta_Publisher, vlc_meta_EncodedBy, vlc_meta_Language, vlc_meta_Rating,
            vlc_meta_NowPlaying, vlc_meta_URL,
        };

        QVariantList general;
        const auto add = [&general](const QString& label, const QString& value) {
            if (!value.trimmed().isEmpty())
                general.append(row(label, value));
        };

        for (const vlc_meta_type_t type : metaTypes)
        {
            char* value = input_item_GetMeta(item.get(), type);
            add(qfu(vlc_meta_TypeToLocalizedString(type)), qfu(value));
            free(value);
        }

        const vlc_tick_t duration = input_item_GetDuration(item.get());
        if (duration > 0)
            add(qtr("Duration"), VLCDuration(duration).formatHMS());

        char* uri = input_item_GetURI(item.get());
        if (uri)
        {
            add(qtr("Location"), QUrl(qfu(uri)).toDisplayString(QUrl::PreferLocalFile));
            free(uri);
        }

        if (!general.isEmpty())
            sections.append(QVariantMap{ { QStringLiteral("title"), qtr("General") },
                                         { QStringLiteral("rows"), general } });

        // codec details per stream (Codec tab)
        vlc_mutex_locker locker(&item->lock);
        // the C list macros: vlc_list.hpp defines non-inline operators, so a second
        // translation unit including it breaks the link (info_panels.cpp includes it)
        info_category_t* category;
        vlc_list_foreach(category, &item->categories, node)
        {
            if (info_category_IsHidden(category))
                continue;

            QVariantList rows;
            info_t* info;
            vlc_list_foreach(info, &category->infos, node)
                rows.append(row(qfu(info->psz_name), qfu(info->psz_value)));

            if (!rows.isEmpty())
                sections.append(QVariantMap{ { QStringLiteral("title"), qfu(category->psz_name) },
                                             { QStringLiteral("rows"), rows } });
        }
    }

    // the panel rebuilds its rows on a change: skip the updates that change nothing
    if (sections == m_sections)
        return;
    m_sections = std::move(sections);
    emit sectionsChanged();
}
