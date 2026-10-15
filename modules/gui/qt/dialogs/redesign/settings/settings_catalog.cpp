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

#include "settings_catalog.hpp"

#include <QCollator>
#include <QDesktopServices>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QPointer>

#include <algorithm>
#include <cfloat>

#include <vlc_configuration.h>
#include <vlc_config_cat.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#ifdef _WIN32
#include <windows.h>
#include "util/registry.hpp"
#endif

#include "maininterface/mainctx.hpp"
#include "medialibrary/medialib.hpp"
#include "util/color_scheme_model.hpp"

namespace {

// options the category pages show by name (dialogs/redesign/settings/pages/*): they are left
// out of the generated "More ... options" lists. Keep in sync with the pages.
const QSet<QString>& curatedOptions()
{
    static const QSet<QString> names {
        // General
        "interact", "qt-updates-notif", "file-logging", "logfile", "log-verbose",
        "qt-error-dialogs", "logmode", "stats", "syslog", "syslog-debug", "syslog-ident",
        "syslog-facility", "qt-verbose", "qt-accent-color",
        // Interface
        "intf", "skins2-last", "embedded-video", "qt-video-autoresize", "video-on-top", "qt-titlebar",
        "qt-name-in-title", "qt-fullscreen-screennumber", "qt-minimal-view", "qt-pin-controls",
        "mouse-hide-timeout", "qt-fs-controller", "qt-system-tray", "qt-start-minimized",
        "qt-notification", "playlist-tree", "qt-opacity", "qt-pause-minimized", "qt-auto-raise",
        "qt-bgcone", "qt-embedded-open", "qt-icon-change", "qt-fs-opacity", "qt-fs-sensitivity",
        // Privacy
        "save-recentplay", "restore-playback-pos", "metadata-network-access", "lastfm-username",
        "lastfm-password", "scrobbler-url", "qt-privacy-ask",
        // Controls
        "extrashort-jump-size", "short-jump-size", "medium-jump-size", "long-jump-size",
        "mouse-pause-policy", "hotkeys-y-wheel-mode", "hotkeys-x-wheel-mode", "http-port",
        "http-password", "qt-disable-volume-keys", "mouse-events", "keyboard-events",
        // Playback
        "playlist-autostart", "rate", "playlist-cork", "preferred-resolution", "menu-language",
        "audio-track", "sub-track", "loop", "repeat", "random", "play-and-stop", "play-and-exit",
        "play-and-pause", "input-fast-seek", "dvd", "avi-index", "mkv-preload-local-dir",
        "input-timeshift-path", "input-timeshift-granularity",
        // Video
        "video", "fullscreen", "disable-screensaver", "video-wallpaper", "deinterlace",
        "deinterlace-mode", "aspect-ratio", "crop", "autoscale", "fit", "align", "snapshot-path",
        "snapshot-prefix", "snapshot-format", "snapshot-width", "snapshot-height",
        "snapshot-sequential", "snapshot-preview", "custom-aspect-ratios", "custom-crop-ratios",
        "monitor-par",
        // Audio
        "audio", "mmdevice-audio-device", "waveout-audio-device",
        "mix-mode", "qt-max-volume", "volume-save", "mmdevice-volume", "waveout-volume",
        "volume-step", "norm-max-level", "audio-replay-gain-mode", "audio-replay-gain-preamp",
        "equalizer-2pass", "pitch-shift", "audio-language", "audio-desync", "audio-visual",
        "mmdevice-passthrough", "force-dolby-surround", "soxr-resampler-quality", "role",
        // Subtitles
        "spu", "sub-language", "subsdec-encoding", "sub-autodetect-file", "sub-autodetect-fuzzy",
        "freetype-font", "freetype-bold",
        "freetype-color", "freetype-opacity", "freetype-outline-thickness",
        "freetype-outline-color", "freetype-shadow-opacity", "freetype-shadow-color",
        "freetype-shadow-distance", "freetype-background-opacity", "freetype-background-color",
        "sub-margin", "sub-delay", "osd", "video-title-show", "video-title-timeout",
        "sub-autodetect-path", "freetype-shadow-angle", "freetype-text-direction",
        "freetype-monofont", "sub-text-scale",
        // Library
        "one-instance", "one-instance-when-started-from-file", "playlist-enqueue", "recursive",
        "show-hiddenfiles", "media-library", "auto-preparse", "ignore-filetypes",
        // Network
        "file-caching", "disc-caching", "network-caching", "live-caching", "http-proxy",
        "http-proxy-pwd", "gnutls-system-trust", "gnutls-priorities", "ipv4-timeout", "mtu",
        // Performance
        "hw-dec", "dec-dev", "postproc-q", "avcodec-skiploopfilter", "avcodec-threads", "drop-late-frames",
        "high-priority", "codec", "clock-synchro", "clock-jitter", "cr-average",
        // Recording
        "input-record-path", "input-record-native", "sout-chromecast-conversion-quality",
        "sout-display", "sout-audio", "sout-video", "sout-spu", "sout-x264-preset", "sout-x264-tune",
        "sout-keep", "sout-all", "sout-x264-profile", "sout-x264-level",
        // Extensions
        "qt-autoload-extensions",
    };
    return names;
}

// the dialog's category for an option VLC files under `subcat`
QString categoryOfSubcat(int subcat)
{
    switch (subcat)
    {
    case SUBCAT_INTERFACE_GENERAL:
    case SUBCAT_INTERFACE_MAIN:
        return QStringLiteral("interface");
    case SUBCAT_INTERFACE_CONTROL:
    case SUBCAT_INTERFACE_HOTKEYS:
        return QStringLiteral("controls");
    case SUBCAT_AUDIO_GENERAL:
    case SUBCAT_AUDIO_AOUT:
    case SUBCAT_AUDIO_AFILTER:
    case SUBCAT_AUDIO_VISUAL:
    case SUBCAT_AUDIO_RESAMPLER:
    case SUBCAT_INPUT_ACODEC:
        return QStringLiteral("audio");
    case SUBCAT_VIDEO_GENERAL:
    case SUBCAT_VIDEO_VOUT:
    case SUBCAT_VIDEO_VFILTER:
    case SUBCAT_VIDEO_SPLITTER:
        return QStringLiteral("video");
    case SUBCAT_VIDEO_SUBPIC:
    case SUBCAT_INPUT_SCODEC:
        return QStringLiteral("subtitles");
    case SUBCAT_INPUT_GENERAL:
    case SUBCAT_INPUT_DEMUX:
    case SUBCAT_PLAYLIST_GENERAL:
        return QStringLiteral("playback");
    case SUBCAT_INPUT_ACCESS:
    case SUBCAT_INPUT_STREAM_FILTER:
    case SUBCAT_ADVANCED_NETWORK:
        return QStringLiteral("network");
    case SUBCAT_INPUT_VCODEC:
    case SUBCAT_ADVANCED_MISC:
        return QStringLiteral("performance");
    case SUBCAT_SOUT_GENERAL:
    case SUBCAT_SOUT_STREAM:
    case SUBCAT_SOUT_MUX:
    case SUBCAT_SOUT_ACO:
    case SUBCAT_SOUT_PACKETIZER:
    case SUBCAT_SOUT_VOD:
    case SUBCAT_SOUT_RENDERER:
        return QStringLiteral("recording");
    case SUBCAT_PLAYLIST_SD:
    case SUBCAT_PLAYLIST_EXPORT:
        return QStringLiteral("library");
    default:
        return {};
    }
}

// plugins whose options belong to another page than their VLC category says
QString categoryOfPlugin(const QString& name, const QString& capability)
{
    if (capability == QLatin1String("logger"))
        return QStringLiteral("general");
    if (name.startsWith(QLatin1String("lua")) || capability == QLatin1String("extension"))
        return QStringLiteral("extensions");
    if (name == QLatin1String("audioscrobbler"))
        return QStringLiteral("privacy");
    if (name == QLatin1String("medialibrary"))
        return QStringLiteral("library");
    if (name == QLatin1String("gnutls"))
        return QStringLiteral("network");
    return {};
}

QString typeName(int type)
{
    switch (type)
    {
    case CONFIG_ITEM_BOOL: return QStringLiteral("bool");
    case CONFIG_ITEM_INTEGER: return QStringLiteral("integer");
    case CONFIG_ITEM_RGB: return QStringLiteral("color");
    case CONFIG_ITEM_FLOAT: return QStringLiteral("float");
    case CONFIG_ITEM_PASSWORD: return QStringLiteral("password");
    case CONFIG_ITEM_MODULE:
    case CONFIG_ITEM_MODULE_CAT: return QStringLiteral("module");
    case CONFIG_ITEM_MODULE_LIST:
    case CONFIG_ITEM_MODULE_LIST_CAT: return QStringLiteral("modules");
    case CONFIG_ITEM_LOADFILE: return QStringLiteral("file");
    case CONFIG_ITEM_SAVEFILE: return QStringLiteral("savefile");
    case CONFIG_ITEM_DIRECTORY: return QStringLiteral("directory");
    case CONFIG_ITEM_FONT: return QStringLiteral("font");
    default: return QStringLiteral("string");
    }
}

// reads every option of VLC and its plugins (worker thread: the plugin bank does not change
// while VLC runs, and only reads it)
SettingsCatalog::Catalog readCatalog()
{
    SettingsCatalog::Catalog catalog;
    const QSet<QString>& curated = curatedOptions();

    size_t count = 0;
    module_t** modules = module_list_get(&count);

    for (size_t m = 0; m < count; ++m)
    {
        const module_t* module = modules[m];
        const QString object = qfu(module_get_object(module));
        const QString capability = qfu(module_get_capability(module));
        const bool core = module_is_main(module);

        catalog.plugins.append({ object, qfut(module_get_name(module, true)), capability,
                                 module_get_score(module) });

        unsigned size = 0;
        module_config_t* config = module_config_get(module, &size);
        if (!config)
            continue;

        const QString forcedCategory = core ? QString() : categoryOfPlugin(object, capability);
        // a plugin's options declared before its first set_subcategory belong to that one
        int subcat = SUBCAT_UNKNOWN;
        if (!core)
        {
            for (unsigned i = 0; i < size; ++i)
            {
                if (config[i].i_type == CONFIG_SUBCATEGORY)
                {
                    subcat = config[i].value.i;
                    break;
                }
            }
        }
        // a plugin is one group, filed by its first subcategory (as VLC's preferences tree);
        // VLC's own options are grouped by their subcategory
        QString pluginCategory;
        QHash<QString, int> groupIndex;

        for (unsigned i = 0; i < size; ++i)
        {
            const module_config_t& item = config[i];
            if (item.i_type == CONFIG_SUBCATEGORY)
            {
                subcat = item.value.i;
                continue;
            }
            if (!CONFIG_ITEM(item.i_type) || item.i_type == CONFIG_ITEM_KEY || !item.psz_name)
                continue;
            if (subcat == SUBCAT_HIDDEN)
                continue;

            QString category = forcedCategory;
            if (category.isEmpty())
            {
                if (!core && !pluginCategory.isEmpty())
                    category = pluginCategory;
                else
                    category = categoryOfSubcat(subcat);
            }
            if (category.isEmpty())
                continue;
            if (!core && pluginCategory.isEmpty())
                pluginCategory = category;

            const QString name = qfu(item.psz_name);
            if (catalog.options.contains(name))
                continue;

            QString groupId;
            QString groupTitle;
            if (core)
            {
                groupId = QStringLiteral("core/%1").arg(subcat);
                // already translated
                const char* subcatName = vlc_config_subcat_GetName(static_cast<vlc_config_subcat>(subcat));
                groupTitle = subcatName ? qfu(subcatName) : qtr("VLC");
            }
            else
            {
                groupId = object;
                groupTitle = qfut(module_get_name(module, true));
            }

            SettingsCatalog::Option option;
            option.name = name;
            option.text = qfut(item.psz_text);
            option.longtext = item.psz_longtext ? qfut(item.psz_longtext) : QString();
            option.group = groupId;
            option.category = category;
            option.type = item.i_type;
            catalog.options.insert(name, option);

            if (curated.contains(name))
                continue;

            auto it = groupIndex.constFind(groupId);
            if (it == groupIndex.constEnd())
            {
                groupIndex.insert(groupId, catalog.groups.size());
                catalog.groups.append({ groupId, groupTitle, category, { name } });
            }
            else
            {
                catalog.groups[*it].options.append(name);
            }
        }
        module_config_free(config);
    }
    module_list_free(modules);

    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(catalog.groups.begin(), catalog.groups.end(), [&collator](const auto& a, const auto& b) {
        return collator.compare(a.title, b.title) < 0;
    });
    std::sort(catalog.plugins.begin(), catalog.plugins.end(), [&collator](const auto& a, const auto& b) {
        return collator.compare(a.title, b.title) < 0;
    });
    return catalog;
}

QStringList filterWords(const QString& filter)
{
    return filter.toLower().split(QLatin1Char(' '), Qt::SkipEmptyParts);
}

} // namespace

SettingsCatalog::SettingsCatalog(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , p_intf(intf)
{
    m_pool.setMaxThreadCount(1);

#ifdef _WIN32
    // VLC raises its priority in vlc_threads_setup() (src/win32/thread.c), before it reads its
    // configuration file, so only "--high-priority" on the command line had an effect: the saved
    // option applies here, when the interface starts (created once, from MainUI)
    m_startPriority = GetPriorityClass(GetCurrentProcess());
    if (var_InheritBool(p_intf, "high-priority"))
        setHighPriority(true);
#endif
}

SettingsCatalog::~SettingsCatalog()
{
    m_pool.waitForDone();
}

void SettingsCatalog::load()
{
    if (m_ready || m_loading)
        return;
    m_loading = true;

    QPointer<SettingsCatalog> self(this);
    m_pool.start([self]() {
        Catalog catalog = readCatalog();
        if (!self)
            return;
        QMetaObject::invokeMethod(self, [self, catalog = std::move(catalog)]() mutable {
            if (!self)
                return;
            self->m_catalog = std::move(catalog);
            self->m_loading = false;
            self->m_ready = true;
            emit self->readyChanged();
        }, Qt::QueuedConnection);
    });
}

bool SettingsCatalog::moduleExists(const QString& name) const
{
    return !name.isEmpty() && module_exists(qtu(name));
}

bool SettingsCatalog::exists(const QString& name) const
{
    if (name.isEmpty())
        return false;
    // obsolete options are still found, without a text
    const module_config_t* config = config_FindConfig(qtu(name));
    return config && config->psz_text;
}

QVariantMap SettingsCatalog::describe(const QString& name) const
{
    const module_config_t* config = config_FindConfig(qtu(name));
    if (!config || !config->psz_text)
        return {};

    QVariantMap result {
        { QStringLiteral("name"), name },
        { QStringLiteral("type"), typeName(config->i_type) },
        { QStringLiteral("text"), config->psz_text ? qfut(config->psz_text) : name },
        { QStringLiteral("description"), config->psz_longtext ? qfut(config->psz_longtext)
                                                                : (config->psz_text ? qfut(config->psz_text) : QString()) },
    };
    if (IsConfigIntegerType(config->i_type) && config->i_type != CONFIG_ITEM_RGB)
    {
        result.insert(QStringLiteral("default"), static_cast<qlonglong>(config->orig.i));
        if (config->min.i != INT64_MIN && config->max.i != INT64_MAX)
        {
            result.insert(QStringLiteral("min"), static_cast<qlonglong>(config->min.i));
            result.insert(QStringLiteral("max"), static_cast<qlonglong>(config->max.i));
        }
    }
    else if (IsConfigFloatType(config->i_type))
    {
        result.insert(QStringLiteral("default"), static_cast<double>(config->orig.f));
        if (config->min.f > -FLT_MAX && config->max.f < FLT_MAX)
        {
            result.insert(QStringLiteral("min"), static_cast<double>(config->min.f));
            result.insert(QStringLiteral("max"), static_cast<double>(config->max.f));
        }
    }
    return result;
}

bool SettingsCatalog::matches(const Option& option, const Group& group, const QStringList& words) const
{
    const QString haystack = (option.text + QLatin1Char(' ') + option.longtext + QLatin1Char(' ')
                              + option.name + QLatin1Char(' ') + group.title).toLower();
    return std::all_of(words.cbegin(), words.cend(), [&haystack](const QString& word) {
        return haystack.contains(word);
    });
}

QVariantList SettingsCatalog::groups(const QString& category, const QString& filter) const
{
    QVariantList result;
    if (!m_ready)
        return result;

    const QStringList words = filterWords(filter);
    for (const Group& group : m_catalog.groups)
    {
        if (group.category != category)
            continue;
        QStringList names;
        QString keywords;
        for (const QString& name : group.options)
        {
            // constFind: no copy of the option per lookup (const operator[] returns one)
            const auto it = m_catalog.options.constFind(name);
            if (it == m_catalog.options.constEnd())
                continue;
            const Option& option = *it;
            if (!words.isEmpty() && !matches(option, group, words))
                continue;
            names.append(name);
            keywords += option.text + QLatin1Char(' ') + option.longtext + QLatin1Char(' ') + name + QLatin1Char(' ');
        }
        if (names.isEmpty())
            continue;
        result.append(QVariantMap {
            { QStringLiteral("id"), group.id },
            { QStringLiteral("title"), group.title },
            { QStringLiteral("options"), names },
            // what the dialog's search finds the group by: its options' texts and names
            { QStringLiteral("keywords"), keywords },
        });
    }
    return result;
}

int SettingsCatalog::matchCount(const QString& category, const QString& filter) const
{
    const QStringList words = filterWords(filter);
    if (!m_ready || words.isEmpty())
        return 0;
    int count = 0;
    for (const Group& group : m_catalog.groups)
    {
        if (group.category != category)
            continue;
        for (const QString& name : group.options)
        {
            const auto it = m_catalog.options.constFind(name);
            if (it != m_catalog.options.constEnd() && matches(*it, group, words))
                ++count;
        }
    }
    return count;
}

QVariantList SettingsCatalog::plugins(const QString& filter) const
{
    QVariantList result;
    if (!m_ready)
        return result;

    const QStringList words = filterWords(filter);
    for (const Plugin& plugin : m_catalog.plugins)
    {
        if (!words.isEmpty())
        {
            const QString haystack = (plugin.title + QLatin1Char(' ') + plugin.name + QLatin1Char(' ')
                                      + plugin.capability).toLower();
            if (!std::all_of(words.cbegin(), words.cend(), [&haystack](const QString& w) { return haystack.contains(w); }))
                continue;
        }
        result.append(QVariantMap {
            { QStringLiteral("name"), plugin.name },
            { QStringLiteral("title"), plugin.title },
            { QStringLiteral("capability"), plugin.capability },
            { QStringLiteral("score"), plugin.score },
        });
    }
    return result;
}

QString SettingsCatalog::pickFile(const QString& title, const QString& current, bool save,
                                  const QString& filter) const
{
    // no parent, as VLC's own file dialogs (dialogs_provider.cpp): the main window is a QML
    // window, not a widget
    const QString dir = current.isEmpty() ? QDir::homePath() : QFileInfo(current).absolutePath();
    const QString file = save ? QFileDialog::getSaveFileName(nullptr, title, current.isEmpty() ? dir : current, filter)
                              : QFileDialog::getOpenFileName(nullptr, title, dir, filter);
    return QDir::toNativeSeparators(file);
}

QString SettingsCatalog::pickDirectory(const QString& title, const QString& current) const
{
    const QString dir = QFileDialog::getExistingDirectory(nullptr, title,
                                                          current.isEmpty() ? QDir::homePath() : current);
    return QDir::toNativeSeparators(dir);
}

QVariantList SettingsCatalog::opticalDrives() const
{
    QVariantList drives;
    const auto add = [&drives](const QString& device) {
        drives.append(QVariantMap {
            { QStringLiteral("value"), device },
            { QStringLiteral("text"), device },
        });
    };
#ifdef _WIN32
    // the drive letters of the CD / DVD / Blu-ray drives (no disc access: an empty drive does
    // not slow the list down)
    const DWORD letters = GetLogicalDrives();
    for (int i = 0; i < 26; ++i)
    {
        if (!(letters & (1u << i)))
            continue;
        const wchar_t root[] = { static_cast<wchar_t>(L'A' + i), L':', L'\\', L'\0' };
        if (GetDriveTypeW(root) == DRIVE_CDROM)
            add(QString(QChar(static_cast<char16_t>(u'A' + i))) + QLatin1Char(':'));
    }
#else
    static const char* const devices[] = { "/dev/sr0", "/dev/sr1", "/dev/sr2", "/dev/sr3",
                                            "/dev/cdrom", "/dev/dvd", "/dev/cd0", "/dev/cd0c" };
    for (const char* device : devices)
    {
        if (QFileInfo::exists(QString::fromLatin1(device)))
            add(QString::fromLatin1(device));
    }
#endif
    return drives;
}

void SettingsCatalog::openConfigFolder() const
{
    char* dir = config_GetUserDir(VLC_CONFIG_DIR);
    if (!dir)
        return;
    const QString path = qfu(dir);
    free(dir);
    QDir().mkpath(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void SettingsCatalog::resetAll()
{
    // VLC's "Reset Preferences" (dialogs/preferences/preferences.cpp): every option back to its
    // default and saved; the interface's own state (window, library) stays. The caller drops
    // the settings bridge's pending writes first (RdEffects.discardPending()), so none of them
    // lands after the reset
    config_ResetAll();
    MainCtx* mainCtx = p_intf->p_mi;
    if (mainCtx)
    {
        // the accent goes back to the theme's own (written before the save); the theme and the
        // interface size of the General and Interface pages are reset too (kept outside VLC's
        // options, in the interface's settings)
        mainCtx->setAccentColor(QColor());
        // dark, the redesign's default (MainCtx::loadPrefs); the list is System, Day, Night,
        // so a scheme is its row
        mainCtx->getColorScheme()->setCurrentIndex(ColorSchemeModel::Night);
        mainCtx->setIntfUserScaleFactor(1.0);
    }
    config_SaveConfigFile(p_intf);
    // the interface reads its options again (as VLC's preferences)
    if (mainCtx)
        mainCtx->reloadPrefs();
#ifdef _WIN32
    setLanguage(QStringLiteral("auto"));
    setHighPriority(false);
#endif
    emit resetDone();
}

bool SettingsCatalog::clearHistory()
{
    MediaLib* mediaLib = p_intf->p_mi ? p_intf->p_mi->getMediaLibrary() : nullptr;
    if (!mediaLib)
        return false;
    // as the Recent page (medialibrary/mlrecentmediamodel.cpp)
    mediaLib->runOnMLThread(this, [](vlc_medialibrary_t* ml) {
        vlc_ml_clear_history(ml, VLC_ML_HISTORY_TYPE_GLOBAL);
    });
    return true;
}

bool SettingsCatalog::languageSupported() const
{
#ifdef _WIN32
    return true;
#else
    return false;
#endif
}

QVariantList SettingsCatalog::languages() const
{
    // VLC's list (dialogs/preferences/simple_preferences.cpp), each language in its own words
    static const struct { const char* iso; const char* name; } list[] = {
        { "auto", "" }, { "en", "American English" }, { "ar", "عربي" },
        { "bn", "বাংলা" }, { "pt_BR", "Português Brasileiro" }, { "en_GB", "British English" },
        { "el", "Νέα Ελληνικά" }, { "bg", "български език" }, { "ca", "Català" },
        { "zh_TW", "正體中文" }, { "cs", "Čeština" }, { "cy", "Cymraeg" }, { "da", "Dansk" },
        { "nl", "Nederlands" }, { "fi", "Suomi" }, { "et", "eesti keel" }, { "eu", "Euskara" },
        { "fr", "Français" }, { "ga", "Gaeilge" }, { "gd", "Gàidhlig" }, { "gl", "Galego" },
        { "ka", "ქართული" }, { "de", "Deutsch" }, { "he", "עברית" }, { "hr", "hrvatski" },
        { "hu", "Magyar" }, { "hy", "հայերեն" }, { "is", "íslenska" }, { "id", "Bahasa Indonesia" },
        { "it", "Italiano" }, { "ja", "日本語" }, { "ko", "한국어" }, { "lt", "lietuvių" },
        { "mn", "Монгол хэл" }, { "ms", "Melayu" }, { "nb", "Bokmål" }, { "nn", "Nynorsk" },
        { "kk", "Қазақ тілі" }, { "km", "ភាសាខ្មែរ" }, { "ne", "नेपाली" }, { "oc", "Occitan" },
        { "fa", "فارسی" }, { "pl", "Polski" }, { "pt_PT", "Português" }, { "pa", "ਪੰਜਾਬੀ" },
        { "ro", "Română" }, { "ru", "Русский" }, { "zh_CN", "简体中文" }, { "si", "සිංහල" },
        { "sr", "српски" }, { "sk", "Slovensky" }, { "sl", "slovenščina" },
        { "ckb", "کوردیی سۆرانی" }, { "es", "Español" }, { "sv", "Svenska" }, { "te", "తెలుగు" },
        { "tr", "Türkçe" }, { "uk", "украї́нська мо́ва" }, { "vi", "tiếng Việt" }, { "wa", "Walon" },
    };

    QVariantList result;
    for (const auto& entry : list)
    {
        const bool automatic = !strcmp(entry.iso, "auto");
        result.append(QVariantMap {
            { QStringLiteral("value"), QString::fromLatin1(entry.iso) },
            { QStringLiteral("text"), automatic ? qtr("System language") : QString::fromUtf8(entry.name) },
        });
    }
    return result;
}

QString SettingsCatalog::language() const
{
#ifdef _WIN32
    QVLCRegistry registry(HKEY_CURRENT_USER);
    char* lang = registry.ReadRegistry("Software\\VideoLAN\\VLC\\", "Lang", "auto");
    const QString result = lang ? qfu(lang) : QString();
    free(lang);
    return result.isEmpty() ? QStringLiteral("auto") : result;
#else
    return QStringLiteral("auto");
#endif
}

void SettingsCatalog::setHighPriority(bool high) const
{
#ifdef _WIN32
    // as vlc_threads_setup(): above normal, else high; when turned off, the class VLC started
    // with (normal if it started raised, by --high-priority)
    const HANDLE process = GetCurrentProcess();
    if (!high)
    {
        const bool raised = m_startPriority == ABOVE_NORMAL_PRIORITY_CLASS
                            || m_startPriority == HIGH_PRIORITY_CLASS;
        SetPriorityClass(process, (m_startPriority == 0 || raised) ? NORMAL_PRIORITY_CLASS
                                                                   : m_startPriority);
    }
    else if (SetPriorityClass(process, ABOVE_NORMAL_PRIORITY_CLASS)
             || SetPriorityClass(process, HIGH_PRIORITY_CLASS))
        msg_Dbg(p_intf, "raised process priority");
    else
        msg_Dbg(p_intf, "could not raise process priority");
#else
    Q_UNUSED(high);
#endif
}

void SettingsCatalog::setLanguage(const QString& iso)
{
#ifdef _WIN32
    // as VLC's preferences: the language is read from the registry when VLC starts
    QVLCRegistry registry(HKEY_CURRENT_USER);
    if (iso.isEmpty() || iso == QLatin1String("auto"))
    {
        registry.DeleteValue("Software\\VideoLAN\\VLC\\", "Lang");
        registry.DeleteKey("Software\\VideoLAN\\", "VLC");
        registry.DeleteKey("Software\\", "VideoLAN");
    }
    else
    {
        registry.WriteRegistry("Software\\VideoLAN\\VLC\\", "Lang", qtu(iso));
    }
#else
    Q_UNUSED(iso);
#endif
}
