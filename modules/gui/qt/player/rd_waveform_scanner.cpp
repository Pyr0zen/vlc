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

#include "rd_waveform_scanner.hpp"

#include <vlc_aout.h>
#include <vlc_block.h>
#include <vlc_codec.h>
#include <vlc_demux.h>
#include <vlc_es_out.h>
#include <vlc_stream.h>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <new>
#include <vector>

namespace {

// sampled scan: the audio measured after each seek, and a bound on the packets demuxed to
// reach it (a video packet comes between audio packets; a broken file must not read forever)
constexpr double kSampleSeconds = 0.25;
constexpr int kSampleMaxPackets = 4000;
// a file that has shown no audio track after this many packets has none (a video-only file
// is not read to its end for nothing)
constexpr int kNoAudioPackets = 2000;
// the AVI demuxer's "avi-index" choice "Never fix" (0 asks the user)
constexpr int64_t kAviIndexNeverFix = 2;

struct Track
{
    es_format_t fmt;
    decoder_t* packetizer = nullptr;
    decoder_t* decoder = nullptr;
};

} // namespace

struct RdWaveformScanner::Scan
{
    explicit Scan(const RdWaveformScanner& scanner);

    QByteArray execute();

    // es_out
    es_out_id_t* addTrack(const es_format_t* fmt);
    void sendBlock(Track* track, block_t* block);
    void deleteTrack(Track* track);
    int control(int query, va_list args);

    // decoders of the audio track
    bool openDecoders(Track* track);
    void closeDecoders(Track* track);
    decoder_t* loadDecoder(bool packetizer, const es_format_t* fmt);
    void process(Track* track, block_t* block);
    void flush(Track* track);

    // decoded audio
    void consume(const audio_format_t& fmt, const block_t* frame);
    void accumulate(int bin, const audio_format_t& fmt, const uint8_t* data, size_t frames);
    QByteArray result() const;

    // the scan ends: a failure, a cancel, or the time budget spent
    bool stopped()
    {
        if (!failed && !overBudget && vlc_tick_now() >= deadline)
            overBudget = true;
        return failed || overBudget || scanner.cancelled();
    }

    const RdWaveformScanner& scanner;
    vlc_object_t* obj = nullptr;
    // the end of the time budget (RdWaveformScanner::kTimeBudgetSeconds), and whether it came
    vlc_tick_t deadline = VLC_TICK_MAX;
    bool overBudget = false;

    std::vector<Track*> tracks;
    // the measured track: the first audio track whose decoder could be loaded
    Track* audio = nullptr;
    // a decoder could not be (re)loaded or gave an unusable format: the scan gives up
    bool failed = false;
    // the levels are made: the demuxer's closing deletes its tracks without a drain
    bool finished = false;

    double lengthSeconds = 0;
    std::vector<double> sumSquares;
    std::vector<double> counts;

    // full scan: the time of the next decoded sample (seconds)
    bool positionKnown = false;
    double position = 0;

    // how the file was read, for the log
    const char* mode = "not opened";

    // sampled scan: the slice being sampled (-1: none) and the audio still wanted for it
    bool sampled = false;
    int targetBin = -1;
    double sampleLeft = 0;
};

namespace {

// the es_out the demuxer writes to; C layout, so the demuxer's es_out_t* leads back to the scan
struct ScanEsOut
{
    es_out_t out;
    RdWaveformScanner::Scan* scan;
};

RdWaveformScanner::Scan* scanOf(es_out_t* out)
{
    return reinterpret_cast<ScanEsOut*>(out)->scan;
}

Track* trackOf(es_out_id_t* id)
{
    return reinterpret_cast<Track*>(id);
}

es_out_id_t* EsOutAdd(es_out_t* out, input_source_t*, const es_format_t* fmt)
{
    return scanOf(out)->addTrack(fmt);
}

int EsOutSend(es_out_t* out, es_out_id_t* id, block_t* block)
{
    scanOf(out)->sendBlock(trackOf(id), block);
    return VLC_SUCCESS;
}

void EsOutDel(es_out_t* out, es_out_id_t* id)
{
    scanOf(out)->deleteTrack(trackOf(id));
}

int EsOutControl(es_out_t* out, input_source_t*, int query, va_list args)
{
    return scanOf(out)->control(query, args);
}

void EsOutDestroy(es_out_t*)
{
    // owned by the scan
}

es_out_callbacks makeEsOutCallbacks()
{
    es_out_callbacks cbs {};
    cbs.add = EsOutAdd;
    cbs.send = EsOutSend;
    cbs.del = EsOutDel;
    cbs.control = EsOutControl;
    cbs.destroy = EsOutDestroy;
    return cbs;
}

const es_out_callbacks kEsOutCallbacks = makeEsOutCallbacks();

// a decoder or packetizer of the scan; C layout, decoder_t first (vlc_object_create)
struct DecoderOwner
{
    decoder_t dec;
    es_format_t fmtIn;
    RdWaveformScanner::Scan* scan;
};

DecoderOwner* ownerOf(decoder_t* dec)
{
    return reinterpret_cast<DecoderOwner*>(dec);
}

// the formats the loudness is read from (what VLC's audio decoders output)
bool supportedFormat(vlc_fourcc_t format)
{
    switch (format)
    {
    case VLC_CODEC_FL32:
    case VLC_CODEC_FL64:
    case VLC_CODEC_S16N:
    case VLC_CODEC_S32N:
    case VLC_CODEC_U8:
        return true;
    default:
        return false;
    }
}

// what the core does for an audio output, without one: a passthrough decoder (S/PDIF) is
// refused, so VLC loads the next decoder, one that outputs samples
int DecoderFormatUpdate(decoder_t* dec)
{
    audio_format_t& audio = dec->fmt_out.audio;
    audio.i_format = dec->fmt_out.i_codec;
    if (!supportedFormat(audio.i_format) || audio.i_rate == 0)
        return -1;
    if (audio.i_physical_channels == 0 && audio.i_channels > 0
        && audio.i_channels < ARRAY_SIZE(vlc_chan_maps))
        audio.i_physical_channels = vlc_chan_maps[audio.i_channels];
    aout_FormatPrepare(&audio);
    if (audio.i_channels == 0 || audio.i_bytes_per_frame == 0 || audio.i_frame_length == 0)
        return -1;
    return 0;
}

void DecoderQueueAudio(decoder_t* dec, vlc_frame_t* frame)
{
    ownerOf(dec)->scan->consume(dec->fmt_out.audio, frame);
    block_Release(frame);
}

decoder_owner_callbacks makeDecoderCallbacks()
{
    decoder_owner_callbacks cbs {};
    cbs.audio.format_update = DecoderFormatUpdate;
    cbs.audio.queue = DecoderQueueAudio;
    cbs.get_attachments = nullptr;
    return cbs;
}

const decoder_owner_callbacks kDecoderCallbacks = makeDecoderCallbacks();

void destroyDecoder(decoder_t* dec)
{
    if (!dec)
        return;
    decoder_Clean(dec);
    es_format_Clean(&ownerOf(dec)->fmtIn);
    vlc_object_delete(dec);
}

// the sum of the squared samples of `frames` interleaved frames
template<typename T>
double sumOfSquares(const uint8_t* data, size_t samples, double scale, double offset)
{
    T value;
    double sum = 0;
    for (size_t i = 0; i < samples; ++i)
    {
        memcpy(&value, data + i * sizeof(T), sizeof(T));
        const double v = (static_cast<double>(value) - offset) * scale;
        sum += v * v;
    }
    return sum;
}

} // namespace

RdWaveformScanner::Scan::Scan(const RdWaveformScanner& scanner)
    : scanner(scanner)
{
}

es_out_id_t* RdWaveformScanner::Scan::addTrack(const es_format_t* fmt)
{
    auto* track = new (std::nothrow) Track;
    if (!track)
        return nullptr;
    es_format_Copy(&track->fmt, fmt);
    tracks.push_back(track);

    if (!audio && fmt->i_cat == AUDIO_ES && openDecoders(track))
        audio = track;
    return reinterpret_cast<es_out_id_t*>(track);
}

void RdWaveformScanner::Scan::sendBlock(Track* track, block_t* block)
{
    if (track == audio && !stopped())
        process(track, block);
    else
        block_Release(block);
}

void RdWaveformScanner::Scan::deleteTrack(Track* track)
{
    const auto it = std::find(tracks.begin(), tracks.end(), track);
    if (it == tracks.end())
        return;
    tracks.erase(it);
    if (track == audio)
    {
        // the rest of its audio was demuxed: let the decoder give out what it holds
        if (!finished && !stopped())
            process(track, nullptr);
        audio = nullptr;
    }
    closeDecoders(track);
    es_format_Clean(&track->fmt);
    delete track;
}

int RdWaveformScanner::Scan::control(int query, va_list args)
{
    switch (query)
    {
    case ES_OUT_GET_ES_STATE:
    {
        // only the measured track is selected: demuxers skip reading the others where they can
        es_out_id_t* id = va_arg(args, es_out_id_t*);
        bool* selected = va_arg(args, bool*);
        *selected = audio && trackOf(id) == audio;
        return VLC_SUCCESS;
    }
    case ES_OUT_IS_EMPTY:
        *va_arg(args, bool*) = true;
        return VLC_SUCCESS;
    case ES_OUT_RESTART_ES:
    {
        Track* track = trackOf(va_arg(args, es_out_id_t*));
        if (track == audio)
        {
            closeDecoders(track);
            if (!openDecoders(track))
                failed = true;
        }
        return VLC_SUCCESS;
    }
    case ES_OUT_SET_ES_FMT:
    {
        Track* track = trackOf(va_arg(args, es_out_id_t*));
        const es_format_t* fmt = va_arg(args, es_format_t*);
        es_format_Clean(&track->fmt);
        es_format_Copy(&track->fmt, fmt);
        if (track == audio)
        {
            closeDecoders(track);
            if (!openDecoders(track))
                failed = true;
        }
        return VLC_SUCCESS;
    }
    case ES_OUT_SET_ES:
    case ES_OUT_SET_ES_DEFAULT:
    case ES_OUT_SET_ES_STATE:
    case ES_OUT_SET_ES_CAT_POLICY:
    case ES_OUT_SET_GROUP:
    case ES_OUT_SET_PCR:
    case ES_OUT_SET_GROUP_PCR:
    case ES_OUT_RESET_PCR:
    case ES_OUT_SET_NEXT_DISPLAY_TIME:
    case ES_OUT_SET_GROUP_META:
    case ES_OUT_SET_GROUP_EPG:
    case ES_OUT_SET_GROUP_EPG_EVENT:
    case ES_OUT_SET_EPG_TIME:
    case ES_OUT_DEL_GROUP:
    case ES_OUT_SET_ES_SCRAMBLED_STATE:
    case ES_OUT_DRAIN:
    case ES_OUT_SET_META:
        return VLC_SUCCESS;
    default:
        return VLC_EGENERIC;
    }
}

decoder_t* RdWaveformScanner::Scan::loadDecoder(bool packetizer, const es_format_t* fmt)
{
    auto* owner = static_cast<DecoderOwner*>(vlc_object_create(obj, sizeof(DecoderOwner)));
    if (!owner)
        return nullptr;
    owner->scan = this;

    decoder_t* dec = &owner->dec;
    decoder_Init(dec, &owner->fmtIn, fmt);
    dec->cbs = &kDecoderCallbacks;
    dec->b_frame_drop_allowed = false;

    decoder_LoadModule(dec, packetizer, false);
    if (!dec->p_module)
    {
        destroyDecoder(dec);
        return nullptr;
    }
    return dec;
}

bool RdWaveformScanner::Scan::openDecoders(Track* track)
{
    track->packetizer = loadDecoder(true, &track->fmt);
    if (!track->packetizer)
        return false;
    track->decoder = loadDecoder(false, &track->packetizer->fmt_out);
    if (!track->decoder)
    {
        destroyDecoder(track->packetizer);
        track->packetizer = nullptr;
        return false;
    }
    return true;
}

void RdWaveformScanner::Scan::closeDecoders(Track* track)
{
    destroyDecoder(track->decoder);
    destroyDecoder(track->packetizer);
    track->decoder = nullptr;
    track->packetizer = nullptr;
}

// the input core's decoder loop without the clock: packetize, reload the decoder on a format
// change, decode (`block` null: drain)
void RdWaveformScanner::Scan::process(Track* track, block_t* block)
{
    decoder_t* packetizer = track->packetizer;
    if (!packetizer || !track->decoder)
    {
        if (block)
            block_Release(block);
        return;
    }

    // the packetizer owns `block` from here, whatever it returns: a bytestream packetizer
    // (MPEG audio, AAC, FLAC ...) keeps it in its queue and leaves `*blockRef` pointing at it,
    // so it is never released here (as in the input core). The loop always runs until the
    // packetizer has nothing more for this block; once the scan stops, its packets are dropped
    // instead of decoded.
    const bool draining = !block;
    block_t** blockRef = draining ? nullptr : &block;
    block_t* packets;
    while ((packets = packetizer->pf_packetize(packetizer, blockRef)) != nullptr)
    {
        if (stopped())
        {
            block_ChainRelease(packets);
            continue;
        }

        if (!es_format_IsSimilar(track->decoder->fmt_in, &packetizer->fmt_out))
        {
            track->decoder->pf_decode(track->decoder, nullptr);
            destroyDecoder(track->decoder);
            track->decoder = loadDecoder(false, &packetizer->fmt_out);
            if (!track->decoder)
            {
                failed = true;
                block_ChainRelease(packets);
                continue;
            }
        }

        while (packets)
        {
            block_t* next = packets->p_next;
            packets->p_next = nullptr;
            if (track->decoder->pf_decode(track->decoder, packets) == VLCDEC_ECRITICAL)
            {
                failed = true;
                block_ChainRelease(next);
                break;
            }
            packets = next;
        }
    }
    if (draining && track->decoder && !stopped())
        track->decoder->pf_decode(track->decoder, nullptr);
}

void RdWaveformScanner::Scan::flush(Track* track)
{
    if (track->packetizer && track->packetizer->pf_flush)
        track->packetizer->pf_flush(track->packetizer);
    if (track->decoder && track->decoder->pf_flush)
        track->decoder->pf_flush(track->decoder);
}

void RdWaveformScanner::Scan::consume(const audio_format_t& fmt, const block_t* frame)
{
    if (stopped() || fmt.i_rate == 0 || fmt.i_bytes_per_frame == 0 || fmt.i_frame_length == 0)
        return;

    const size_t bytesPerFrame = fmt.i_bytes_per_frame / fmt.i_frame_length;
    if (bytesPerFrame == 0)
        return;
    const size_t frames = std::min<size_t>(frame->i_nb_samples, frame->i_buffer / bytesPerFrame);
    const double rate = fmt.i_rate;

    if (sampled)
    {
        if (targetBin < 0 || sampleLeft <= 0)
            return;
        const size_t used = std::min(frames, static_cast<size_t>(std::ceil(sampleLeft * rate)));
        accumulate(targetBin, fmt, frame->p_buffer, used);
        sampleLeft -= static_cast<double>(used) / rate;
        return;
    }

    // the first decoded audio starts where its timestamp says (audio that begins after the
    // video); from there the samples are counted, so timestamp gaps do not move the slices
    if (!positionKnown)
    {
        positionKnown = true;
        if (frame->i_pts != VLC_TICK_INVALID && frame->i_pts > VLC_TICK_0)
            position = std::min(secf_from_vlc_tick(frame->i_pts - VLC_TICK_0), lengthSeconds);
    }

    const double binsPerSecond = kBins / lengthSeconds;
    size_t done = 0;
    while (done < frames)
    {
        const int bin = static_cast<int>(std::min<double>(kBins - 1, position * binsPerSecond));
        size_t run = frames - done;
        if (bin < kBins - 1)
        {
            const double untilNext = (bin + 1) / binsPerSecond - position;
            run = std::min(run, std::max<size_t>(1, static_cast<size_t>(std::ceil(untilNext * rate))));
        }
        accumulate(bin, fmt, frame->p_buffer + done * bytesPerFrame, run);
        position += static_cast<double>(run) / rate;
        done += run;
    }
}

void RdWaveformScanner::Scan::accumulate(int bin, const audio_format_t& fmt, const uint8_t* data,
                                         size_t frames)
{
    const size_t samples = frames * fmt.i_channels;
    double sum = 0;
    switch (fmt.i_format)
    {
    case VLC_CODEC_FL32:
        sum = sumOfSquares<float>(data, samples, 1.0, 0);
        break;
    case VLC_CODEC_FL64:
        sum = sumOfSquares<double>(data, samples, 1.0, 0);
        break;
    case VLC_CODEC_S16N:
        sum = sumOfSquares<int16_t>(data, samples, 1.0 / 32768.0, 0);
        break;
    case VLC_CODEC_S32N:
        sum = sumOfSquares<int32_t>(data, samples, 1.0 / 2147483648.0, 0);
        break;
    case VLC_CODEC_U8:
        sum = sumOfSquares<uint8_t>(data, samples, 1.0 / 128.0, 128.0);
        break;
    default:
        return;
    }
    sumSquares[bin] += sum;
    counts[bin] += static_cast<double>(samples);
}

QByteArray RdWaveformScanner::Scan::result() const
{
    std::vector<double> rms(kBins, -1.0);
    double loudest = 0;
    bool any = false;
    for (int i = 0; i < kBins; ++i)
    {
        if (counts[i] <= 0)
            continue;
        rms[i] = std::sqrt(sumSquares[i] / counts[i]);
        loudest = std::max(loudest, rms[i]);
        any = true;
    }
    if (!any)
        return {};

    // slices no audio reached (a sample that failed, a duration longer than the audio) take
    // the nearest measured slice before them, or after them at the start
    double last = -1.0;
    for (int i = 0; i < kBins; ++i)
    {
        if (rms[i] >= 0)
            last = rms[i];
        else if (last >= 0)
            rms[i] = last;
    }
    for (int i = kBins - 1; i >= 0; --i)
    {
        if (rms[i] >= 0)
            last = rms[i];
        else
            rms[i] = last;
    }

    QByteArray levels(kBins, '\0');
    for (int i = 0; i < kBins; ++i)
    {
        const long value = loudest > 0 ? std::lround(rms[i] / loudest * 255.0) : 0;
        levels[i] = static_cast<char>(std::clamp(value, 0L, 255L));
    }
    return levels;
}

QByteArray RdWaveformScanner::Scan::execute()
{
    stream_t* stream = vlc_stream_NewURL(obj, scanner.m_url.constData());
    if (!stream)
        return {};

    uint64_t size = 0;
    const bool sizeKnown = vlc_stream_GetSize(stream, &size) == VLC_SUCCESS;

    ScanEsOut esOut { { &kEsOutCallbacks }, this };
    demux_t* demux = demux_New(obj, "any", scanner.m_url.constData(), stream, &esOut.out);
    if (!demux)
    {
        vlc_stream_Delete(stream);
        return {};
    }

    vlc_tick_t length = 0;
    if (demux_Control(demux, DEMUX_GET_LENGTH, &length) != VLC_SUCCESS || length <= 0)
        length = scanner.m_lengthHint;
    bool canSeek = false;
    if (demux_Control(demux, DEMUX_CAN_SEEK, &canSeek) != VLC_SUCCESS)
        canSeek = false;

    QByteArray levels;
    mode = "no duration";
    if (length > 0)
    {
        lengthSeconds = secf_from_vlc_tick(length);
        sumSquares.assign(kBins, 0.0);
        counts.assign(kBins, 0.0);
        // a large file the demuxer cannot seek in is never read from start to end: no waveform
        const bool large = sizeKnown && size > kFullScanMaxBytes;
        sampled = large && canSeek;
        mode = !large ? "full" : sampled ? "sampled" : "large, not seekable";

        if (!large)
        {
            for (int packet = 0; !stopped() && demux_Demux(demux) == VLC_DEMUXER_SUCCESS; ++packet)
            {
                if (!audio && packet >= kNoAudioPackets)
                    break;
            }
            if (audio && !stopped())
                process(audio, nullptr);
        }
        else if (sampled)
        {
            // never more audio per slice than the slice holds: a short file of a high bitrate
            // (a 30 s 4K clip) decodes at most its own audio, not 0.25 s per 1/1000 of it
            const double slice = lengthSeconds / kBins;
            const double sampleSeconds = std::min(kSampleSeconds, slice);
            for (int bin = 0; bin < kBins && !stopped(); ++bin)
            {
                // a stretch centered in the slice; by time, else by position (demuxers without
                // an index, such as an MPEG-TS recording, seek better by position)
                const double start = std::max(0.0, (bin + 0.5) * slice - sampleSeconds / 2);
                if (demux_SetTime(demux, vlc_tick_from_sec(start), false) != VLC_SUCCESS
                    && demux_SetPosition(demux, start / lengthSeconds, false) != VLC_SUCCESS)
                    continue;
                if (audio)
                    flush(audio);
                targetBin = bin;
                sampleLeft = sampleSeconds;
                for (int packet = 0; packet < kSampleMaxPackets && sampleLeft > 0 && !stopped(); ++packet)
                {
                    if (demux_Demux(demux) != VLC_DEMUXER_SUCCESS)
                        break;
                    if (!audio && packet >= kNoAudioPackets)
                        break;
                }
                targetBin = -1;
                if (!audio)
                    break;
            }
        }

        if (!stopped())
            levels = result();
    }
    finished = true;

    // the demuxer deletes its tracks (es_out del) and the stream
    demux_Delete(demux);
    for (Track* track : tracks)
    {
        closeDecoders(track);
        es_format_Clean(&track->fmt);
        delete track;
    }
    tracks.clear();
    audio = nullptr;
    return levels;
}

RdWaveformScanner::RdWaveformScanner(vlc_object_t* parent, const QByteArray& url,
                                     vlc_tick_t lengthHint)
    : m_parent(parent)
    , m_url(url)
    , m_lengthHint(lengthHint)
    , m_interrupt(vlc_interrupt_create())
{
}

RdWaveformScanner::~RdWaveformScanner()
{
    if (m_interrupt)
        vlc_interrupt_destroy(m_interrupt);
}

void RdWaveformScanner::cancel()
{
    m_cancelled.store(true, std::memory_order_relaxed);
    if (m_interrupt)
        vlc_interrupt_kill(m_interrupt);
}

QByteArray RdWaveformScanner::run()
{
    if (cancelled())
        return {};

    vlc_interrupt_t* previous = m_interrupt ? vlc_interrupt_set(m_interrupt) : nullptr;

    // the scan's own object: the demuxer and decoders hang from it, apart from the interface
    QByteArray levels;
    if (vlc_object_t* obj = static_cast<vlc_object_t*>(vlc_object_create(m_parent, sizeof(vlc_object_t))))
    {
        // a background scan never asks the user anything: an AVI file with a broken index is
        // read as is (VLC would ask whether to build the index, which reads the whole file)
        if (var_Create(obj, "avi-index", VLC_VAR_INTEGER) == VLC_SUCCESS)
            var_SetInteger(obj, "avi-index", kAviIndexNeverFix);

        const vlc_tick_t start = vlc_tick_now();
        Scan scan(*this);
        scan.obj = obj;
        scan.deadline = start + VLC_TICK_FROM_SEC(kTimeBudgetSeconds);
        levels = scan.execute();
        vlc_object_delete(obj);

        // the measurements of the PC tests read this line (WAVEFORM_NOTES section 8)
        msg_Dbg(m_parent, "waveform scan (%s): %s in %lld ms", scan.mode,
                cancelled() ? "cancelled"
                : scan.overBudget ? "no waveform, over the time budget"
                : levels.isEmpty() ? "no waveform" : "levels",
                static_cast<long long>(MS_FROM_VLC_TICK(vlc_tick_now() - start)));
    }

    if (m_interrupt)
        vlc_interrupt_set(previous);
    return cancelled() ? QByteArray() : levels;
}
