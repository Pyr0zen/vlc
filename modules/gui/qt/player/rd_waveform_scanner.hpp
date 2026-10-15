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
#ifndef RD_WAVEFORM_SCANNER_HPP
#define RD_WAVEFORM_SCANNER_HPP

#include <QByteArray>

#include <atomic>

#include <vlc_common.h>
#include <vlc_interrupt.h>

/**
 * redesign: the loudness profile of a file's audio, for the waveform seek bar (P6-06, IB-24).
 *
 * Opens the file a second time with VLC's own access, demuxer, packetizer and audio decoder
 * (the same modules playback uses, no audio output, no clock) and measures the loudness of
 * the first audio track over `kBins` equal slices of the file's duration.
 *
 * - Files up to `kFullScanMaxBytes` are decoded from start to end, as fast as the decoder goes.
 * - Larger files (films, long recordings) are sampled: one short stretch of audio is decoded
 *   after a seek to each slice, so a 50 GB file costs about `kBins` seeks, not a full read.
 *
 * run() blocks and is meant for a low priority worker thread. cancel() may be called from any
 * thread: run() then returns an empty array within one demuxed packet (the VLC interrupt
 * context of the run also aborts blocking reads).
 *
 * Result: `kBins` bytes, the RMS loudness of each slice scaled so the loudest slice is 255;
 * empty when the file has no decodable audio, no known duration, or the run was cancelled.
 */
class RdWaveformScanner
{
public:
    static constexpr int kBins = 1000;
    static constexpr quint64 kFullScanMaxBytes = 256ull * 1024 * 1024;

    // `parent`: the VLC object the scan's objects hang from (the interface); `url`: a file://
    // URL; `lengthHint`: the duration the player knows, used when the demuxer gives none
    RdWaveformScanner(vlc_object_t* parent, const QByteArray& url, vlc_tick_t lengthHint);
    ~RdWaveformScanner();

    RdWaveformScanner(const RdWaveformScanner&) = delete;
    RdWaveformScanner& operator=(const RdWaveformScanner&) = delete;

    QByteArray run();
    void cancel();
    bool cancelled() const { return m_cancelled.load(std::memory_order_relaxed); }

    struct Scan;

private:
    vlc_object_t* m_parent;
    QByteArray m_url;
    vlc_tick_t m_lengthHint;
    vlc_interrupt_t* m_interrupt;
    std::atomic<bool> m_cancelled { false };
};

#endif // RD_WAVEFORM_SCANNER_HPP
