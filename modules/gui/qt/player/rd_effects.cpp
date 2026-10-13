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

#include "rd_effects.hpp"

#include <QLocale>

#include <cfloat>
#include <cstdint>
#include <cstring>

#include <vlc_common.h>
#include <vlc_aout.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_player.h>
#include <vlc_plugin.h>
#include <vlc_vout.h>

#include "player/player_controller.hpp"
#include "../../../audio_filter/equalizer_presets.h"

namespace {

QStringList splitChain(const QString& chain)
{
    return chain.split(':', Qt::SkipEmptyParts);
}

QString configString(const char* name)
{
    char* value = config_GetPsz(name);
    const QString result = qfu(value ? value : "");
    free(value);
    return result;
}

QVariant readVar(vlc_object_t* obj, const char* name, int type)
{
    switch (type & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
        return QVariant(var_GetBool(obj, name));
    case VLC_VAR_INTEGER:
        return QVariant(static_cast<qlonglong>(var_GetInteger(obj, name)));
    case VLC_VAR_FLOAT:
        return QVariant(static_cast<double>(var_GetFloat(obj, name)));
    case VLC_VAR_STRING:
    {
        char* value = var_GetString(obj, name);
        const QString result = qfu(value ? value : "");
        free(value);
        return QVariant(result);
    }
    default:
        return QVariant();
    }
}

QVariant readConfig(const char* name)
{
    switch (config_GetType(name) & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
        return QVariant(config_GetInt(name) != 0);
    case VLC_VAR_INTEGER:
        return QVariant(static_cast<qlonglong>(config_GetInt(name)));
    case VLC_VAR_FLOAT:
        return QVariant(static_cast<double>(config_GetFloat(name)));
    case VLC_VAR_STRING:
        return QVariant(configString(name));
    default:
        return QVariant();
    }
}

void writeConfig(const char* name, const QVariant& value)
{
    switch (config_GetType(name) & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
    case VLC_VAR_INTEGER:
        config_PutInt(name, value.toLongLong());
        break;
    case VLC_VAR_FLOAT:
        config_PutFloat(name, value.toFloat());
        break;
    case VLC_VAR_STRING:
        config_PutPsz(name, qtu(value.toString()));
        break;
    default:
        break;
    }
}

void writeVar(vlc_object_t* obj, const char* name, const QVariant& value)
{
    int type = var_Type(obj, name);
    if (type == 0)
        type = config_GetType(name);

    vlc_value_t val;
    QByteArray text;
    switch (type & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:
        val.b_bool = value.toBool();
        break;
    case VLC_VAR_INTEGER:
        val.i_int = value.toLongLong();
        break;
    case VLC_VAR_FLOAT:
        val.f_float = value.toFloat();
        break;
    case VLC_VAR_STRING:
        text = value.toString().toUtf8();
        val.psz_string = text.data();
        break;
    default:
        return;
    }
    var_SetChecked(obj, name, type & VLC_VAR_CLASS, val);
}

QString floatList(const QVariantList& values)
{
    QStringList parts;
    for (const QVariant& v : values)
        parts << QLocale(QLocale::C).toString(v.toFloat());
    return parts.join(' ');
}

} // namespace

RdEffects::RdEffects(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
{
    // the configuration file is written once a burst of changes (a slider drag) is over
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(500);
    connect(&m_saveTimer, &QTimer::timeout, this, [this]() {
        config_SaveConfigFile(m_intf);
    });
}

void RdEffects::bump()
{
    ++m_revision;
    emit changed();
    m_saveTimer.start();
}

void RdEffects::refresh()
{
    ++m_revision;
    emit changed();
}

QVariant RdEffects::option(const QString& name) const
{
    return readConfig(qtu(name));
}

void RdEffects::setOption(const QString& name, const QVariant& value)
{
    writeConfig(qtu(name), value);
    bump();
}

QVariantList RdEffects::optionChoices(const QString& name) const
{
    QVariantList choices;
    const QByteArray key = name.toUtf8();

    if ((config_GetType(key.constData()) & VLC_VAR_CLASS) == VLC_VAR_STRING)
    {
        char** values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetPszChoices(key.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            choices << QVariantMap{ { QStringLiteral("value"), qfu(values[i]) },
                                    { QStringLiteral("text"), qfu(texts[i]) } };
            free(values[i]);
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    else
    {
        int64_t* values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetIntChoices(key.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            choices << QVariantMap{ { QStringLiteral("value"), static_cast<qlonglong>(values[i]) },
                                    { QStringLiteral("text"), qfu(texts[i]) } };
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    return choices;
}

QVariantMap RdEffects::optionRange(const QString& name) const
{
    const module_config_t* config = config_FindConfig(qtu(name));
    if (!config)
        return {};

    // options declared without a range report the type's limits: no usable range
    if (IsConfigIntegerType(config->i_type))
    {
        if (config->min.i == INT64_MIN || config->max.i == INT64_MAX)
            return {};
        return { { QStringLiteral("min"), static_cast<qlonglong>(config->min.i) },
                 { QStringLiteral("max"), static_cast<qlonglong>(config->max.i) },
                 { QStringLiteral("default"), static_cast<qlonglong>(config->orig.i) } };
    }
    if (IsConfigFloatType(config->i_type))
    {
        if (config->min.f <= -FLT_MAX || config->max.f >= FLT_MAX)
            return {};
        return { { QStringLiteral("min"), static_cast<double>(config->min.f) },
                 { QStringLiteral("max"), static_cast<double>(config->max.f) },
                 { QStringLiteral("default"), static_cast<double>(config->orig.f) } };
    }
    return {};
}

QString RdEffects::optionDescription(const QString& name) const
{
    const module_config_t* config = config_FindConfig(qtu(name));
    if (!config)
        return {};
    if (config->psz_longtext && *config->psz_longtext)
        return qfut(config->psz_longtext);
    if (config->psz_text && *config->psz_text)
        return qfut(config->psz_text);
    return {};
}

/* audio */

bool RdEffects::audioFilterEnabled(const QString& module) const
{
    QString chain;
    if (SharedAOut aout = m_player->getAout())
    {
        char* value = var_GetNonEmptyString(aout.get(), "audio-filter");
        chain = qfu(value ? value : "");
        free(value);
    }
    else
        chain = configString("audio-filter");
    return splitChain(chain).contains(module);
}

void RdEffects::setAudioFilterEnabled(const QString& module, bool enabled)
{
    if (!module_exists(qtu(module)))
    {
        msg_Err(m_intf, "Unable to find filter module \"%s\".", qtu(module));
        return;
    }

    QStringList chain = splitChain(configString("audio-filter"));
    chain.removeAll(module);
    if (enabled)
        chain << module;
    writeConfig("audio-filter", chain.join(':'));

    vlc_player_aout_EnableFilter(m_intf->p_player, qtu(module), enabled);
    bump();
}

double RdEffects::audioValue(const QString& name) const
{
    if (SharedAOut aout = m_player->getAout())
    {
        if (var_Type(aout.get(), qtu(name)) != 0)
            return var_GetFloat(aout.get(), qtu(name));
    }
    if (!config_FindConfig(qtu(name)))
        return 0.;
    return config_GetFloat(qtu(name));
}

void RdEffects::setAudioValue(const QString& name, double value)
{
    if (SharedAOut aout = m_player->getAout())
        var_SetFloat(aout.get(), qtu(name), value);
    writeConfig(qtu(name), value);
    bump();
}

bool RdEffects::audioFlag(const QString& name) const
{
    if (SharedAOut aout = m_player->getAout())
    {
        if (var_Type(aout.get(), qtu(name)) != 0)
            return var_GetBool(aout.get(), qtu(name));
    }
    return config_FindConfig(qtu(name)) && config_GetInt(qtu(name)) != 0;
}

void RdEffects::setAudioFlag(const QString& name, bool value)
{
    if (SharedAOut aout = m_player->getAout())
        var_SetBool(aout.get(), qtu(name), value);
    writeConfig(qtu(name), value);
    bump();
}

/* equalizer */

QStringList RdEffects::equalizerPresetNames() const
{
    QStringList names;
    for (int i = 0; i < NB_PRESETS; ++i)
        names << qfut(preset_list_text[i]);
    return names;
}

QVariantList RdEffects::equalizerPresetBands(int preset) const
{
    QVariantList bands;
    if (preset < 0 || preset >= NB_PRESETS)
        return bands;
    for (int i = 0; i < eqz_preset_10b[preset].i_band; ++i)
        bands << static_cast<double>(eqz_preset_10b[preset].f_amp[i]);
    return bands;
}

QStringList RdEffects::equalizerBandNames() const
{
    if (var_InheritBool(m_intf, "equalizer-vlcfreqs"))
        return { qtr("60 Hz"), qtr("170 Hz"), qtr("310 Hz"), qtr("600 Hz"), qtr("1 KHz"),
                 qtr("3 KHz"), qtr("6 KHz"), qtr("12 KHz"), qtr("14 KHz"), qtr("16 KHz") };
    return { qtr("31 Hz"), qtr("63 Hz"), qtr("125 Hz"), qtr("250 Hz"), qtr("500 Hz"),
             qtr("1 KHz"), qtr("2 KHz"), qtr("4 KHz"), qtr("8 KHz"), qtr("16 KHz") };
}

int RdEffects::equalizerPreset() const
{
    if (!audioFilterEnabled(QStringLiteral("equalizer")))
        return -1;

    QString preset;
    if (SharedAOut aout = m_player->getAout())
    {
        char* value = var_GetNonEmptyString(aout.get(), "equalizer-preset");
        preset = qfu(value ? value : "");
        free(value);
    }
    if (preset.isEmpty())
        preset = configString("equalizer-preset");

    for (int i = 0; i < NB_PRESETS; ++i)
        if (preset == QLatin1String(preset_list[i]))
            return i;
    return 0;
}

void RdEffects::setEqualizerPreset(int preset)
{
    if (preset < 0 || preset >= NB_PRESETS)
    {
        setAudioFilterEnabled(QStringLiteral("equalizer"), false);
        return;
    }

    const QString bands = floatList(equalizerPresetBands(preset));
    const eqz_preset_t& p = eqz_preset_10b[preset];
    if (SharedAOut aout = m_player->getAout())
    {
        var_SetString(aout.get(), "equalizer-preset", preset_list[preset]);
        var_SetFloat(aout.get(), "equalizer-preamp", p.f_preamp);
        var_SetString(aout.get(), "equalizer-bands", qtu(bands));
    }
    writeConfig("equalizer-preset", QString::fromLatin1(preset_list[preset]));
    writeConfig("equalizer-preamp", static_cast<double>(p.f_preamp));
    writeConfig("equalizer-bands", bands);

    if (!audioFilterEnabled(QStringLiteral("equalizer")))
        setAudioFilterEnabled(QStringLiteral("equalizer"), true);
    else
        bump();
}

QVariantList RdEffects::equalizerBands() const
{
    QString bands;
    if (SharedAOut aout = m_player->getAout())
    {
        if ((var_Type(aout.get(), "equalizer-bands") & VLC_VAR_CLASS) == VLC_VAR_STRING)
        {
            char* value = var_GetString(aout.get(), "equalizer-bands");
            bands = qfu(value ? value : "");
            free(value);
        }
    }
    if (bands.isEmpty())
        bands = configString("equalizer-bands");

    QVariantList gains;
    for (const QString& part : bands.split(' ', Qt::SkipEmptyParts))
        gains << static_cast<double>(QLocale(QLocale::C).toFloat(part));
    while (gains.size() < EQZ_BANDS_MAX)
        gains << 0.;
    return gains.mid(0, EQZ_BANDS_MAX);
}

void RdEffects::setEqualizerBand(int band, double gain)
{
    if (band < 0 || band >= EQZ_BANDS_MAX)
        return;

    QVariantList gains = equalizerBands();
    gains[band] = gain;
    const QString bands = floatList(gains);
    if (SharedAOut aout = m_player->getAout())
        var_SetString(aout.get(), "equalizer-bands", qtu(bands));
    writeConfig("equalizer-bands", bands);
    bump();
}

/* video */

QString RdEffects::videoFilterType(const QString& module) const
{
    // the answer never changes for a module: look it up once (bindings ask often)
    const auto cached = m_filterTypes.constFind(module);
    if (cached != m_filterTypes.constEnd())
        return *cached;

    QString type;
    if (module_t* obj = module_find(qtu(module)))
    {
        if (module_provides(obj, "video splitter"))
            type = QStringLiteral("video-splitter");
        else if (module_provides(obj, "video filter"))
            type = QStringLiteral("video-filter");
        else if (module_provides(obj, "sub source"))
            type = QStringLiteral("sub-source");
        else if (module_provides(obj, "sub filter"))
            type = QStringLiteral("sub-filter");
    }
    else
        msg_Err(m_intf, "Unable to find filter module \"%s\".", qtu(module));

    m_filterTypes.insert(module, type);
    return type;
}

QString RdEffects::filterChain(const char* type) const
{
    // the video output has no "video-splitter" variable: a splitter is chosen when the output
    // is created, from the configuration
    if (strcmp(type, "video-splitter") != 0)
    {
        if (SharedVOutThread vout = m_player->getVout())
        {
            char* value = var_GetString(vout.get(), type);
            const QString chain = qfu(value ? value : "");
            free(value);
            return chain;
        }
    }
    return configString(type);
}

bool RdEffects::videoFilterEnabled(const QString& module) const
{
    const QString type = videoFilterType(module);
    if (type.isEmpty())
        return false;
    return splitChain(filterChain(qtu(type))).contains(module);
}

void RdEffects::setVideoFilterEnabled(const QString& module, bool enabled)
{
    const QString type = videoFilterType(module);
    if (type.isEmpty())
        return;

    if (type == QLatin1String("video-splitter"))
    {
        // one splitter at a time; it applies to the next video output
        writeConfig("video-splitter", enabled ? module : QString());
        bump();
        return;
    }

    QStringList chain = splitChain(filterChain(qtu(type)));
    chain.removeAll(module);
    if (enabled)
        chain << module;
    const QString result = chain.join(':');

    writeConfig(qtu(type), result);
    for (const SharedVOutThread& vout : m_player->getVouts())
        var_SetString(vout.get(), qtu(type), qtu(result));
    bump();
}

void RdEffects::restartVideoFilter(const QString& module)
{
    // filter options that are read when the filter starts: rebuild the chain without and with
    // the filter (the video output ignores an unchanged chain)
    if (!videoFilterEnabled(module))
        return;
    const QString type = videoFilterType(module);
    if (type == QLatin1String("video-splitter"))
        return;

    QStringList without = splitChain(filterChain(qtu(type)));
    const QString with = without.join(':');
    without.removeAll(module);
    for (const SharedVOutThread& vout : m_player->getVouts())
    {
        var_SetString(vout.get(), qtu(type), qtu(without.join(':')));
        var_SetString(vout.get(), qtu(type), qtu(with));
    }
    bump();
}

QVariant RdEffects::videoValue(const QString& name) const
{
    if (SharedVOutThread vout = m_player->getVout())
    {
        const int type = var_Type(vout.get(), qtu(name));
        if (type != 0)
            return readVar(VLC_OBJECT(vout.get()), qtu(name), type);
    }
    return readConfig(qtu(name));
}

void RdEffects::setVideoValue(const QString& name, const QVariant& value)
{
    for (const SharedVOutThread& vout : m_player->getVouts())
        writeVar(VLC_OBJECT(vout.get()), qtu(name), value);
    writeConfig(qtu(name), value);
    bump();
}

/* subtitles */

int RdEffects::subtitleTextScale() const
{
    vlc_player_locker lock{ m_intf->p_player };
    return vlc_player_GetSubtitleTextScale(m_intf->p_player);
}

void RdEffects::setSubtitleTextScale(int percent)
{
    {
        vlc_player_locker lock{ m_intf->p_player };
        // the core accepts 10 % to 500 %
        vlc_player_SetSubtitleTextScale(m_intf->p_player, static_cast<unsigned>(qBound(10, percent, 500)));
    }
    writeConfig("sub-text-scale", qBound(10, percent, 500));
    bump();
}

double RdEffects::subtitleDurationFactor() const
{
    if (!videoFilterEnabled(QStringLiteral("subsdelay")))
        return 0.;
    return videoValue(QStringLiteral("subsdelay-factor")).toDouble();
}

void RdEffects::setSubtitleDurationFactor(double factor)
{
    for (const SharedVOutThread& vout : m_player->getVouts())
        var_SetFloat(vout.get(), "subsdelay-factor", factor);
    writeConfig("subsdelay-factor", factor);
    setVideoFilterEnabled(QStringLiteral("subsdelay"), factor > 0);
}
