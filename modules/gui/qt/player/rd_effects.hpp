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
#ifndef RD_EFFECTS_HPP
#define RD_EFFECTS_HPP

#include <QHash>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariant>

#include "qt.hpp"

class PlayerController;

/**
 * redesign: the settings sidebar's access to VLC's audio and video effects and to the
 * options it shows (video 7:12-9:19). The logic mirrors VLC's "Adjustments and Effects"
 * dialog (dialogs/extended/extended_panels.cpp): audio filters are enabled on the player's
 * audio output, video filters are set on the video output's filter chains, and every
 * change is also written to the configuration (saved shortly after), so it is kept for
 * the next files and the next start.
 *
 * QML reads values through the getters; `revision` changes after every write so bindings
 * that read `revision` re-evaluate.
 */
class RdEffects : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)

public:
    RdEffects(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);

    int revision() const { return m_revision; }

    // makes the bindings re-read every value (after another window, e.g. VLC's preferences,
    // changed the configuration); nothing is written
    Q_INVOKABLE void refresh();

    // options of the configuration (most apply to the next file)
    Q_INVOKABLE QVariant option(const QString& name) const;
    Q_INVOKABLE void setOption(const QString& name, const QVariant& value);
    // the choices VLC declares for an option: [{ value, text }]
    Q_INVOKABLE QVariantList optionChoices(const QString& name) const;
    // the range VLC declares for a numeric option: { min, max, default }
    Q_INVOKABLE QVariantMap optionRange(const QString& name) const;
    // VLC's explanation of an option (its long text, else its label), translated; empty if unknown
    Q_INVOKABLE QString optionDescription(const QString& name) const;

    // audio filters: live on the audio output, kept in "audio-filter"
    Q_INVOKABLE bool audioFilterEnabled(const QString& module) const;
    Q_INVOKABLE void setAudioFilterEnabled(const QString& module, bool enabled);
    Q_INVOKABLE double audioValue(const QString& name) const;
    Q_INVOKABLE void setAudioValue(const QString& name, double value);
    Q_INVOKABLE bool audioFlag(const QString& name) const;
    Q_INVOKABLE void setAudioFlag(const QString& name, bool value);

    // 10 band equalizer ("equalizer" audio filter)
    Q_INVOKABLE QStringList equalizerPresetNames() const;
    Q_INVOKABLE QVariantList equalizerPresetBands(int preset) const;
    Q_INVOKABLE QStringList equalizerBandNames() const;
    Q_INVOKABLE int equalizerPreset() const;           // -1: off ("None")
    Q_INVOKABLE void setEqualizerPreset(int preset);   // -1 disables the equalizer
    Q_INVOKABLE QVariantList equalizerBands() const;
    Q_INVOKABLE void setEqualizerBand(int band, double gain);

    // video filters: live on the video output, kept in "video-filter" / "sub-source" / ...
    Q_INVOKABLE bool videoFilterEnabled(const QString& module) const;
    Q_INVOKABLE void setVideoFilterEnabled(const QString& module, bool enabled);
    Q_INVOKABLE QVariant videoValue(const QString& name) const;
    Q_INVOKABLE void setVideoValue(const QString& name, const QVariant& value);
    // re-applies a filter whose options are read when it starts (e.g. transform-type)
    Q_INVOKABLE void restartVideoFilter(const QString& module);

    // subtitle text size in percent (live, "sub-text-scale")
    Q_INVOKABLE int subtitleTextScale() const;
    Q_INVOKABLE void setSubtitleTextScale(int percent);

    // subtitle duration factor ("subsdelay" sub filter, 0 disables it)
    Q_INVOKABLE double subtitleDurationFactor() const;
    Q_INVOKABLE void setSubtitleDurationFactor(double factor);

signals:
    void changed();

private:
    QString videoFilterType(const QString& module) const;
    QString filterChain(const char* type) const;
    void bump();

    qt_intf_t* m_intf = nullptr;
    PlayerController* m_player = nullptr;
    int m_revision = 0;
    mutable QHash<QString, QString> m_filterTypes;
    QTimer m_saveTimer;
};

#endif // RD_EFFECTS_HPP
