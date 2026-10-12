/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
#include "systempalette.hpp"

#include <algorithm>
#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QFile>
#include <maininterface/mainctx.hpp>
#include <vlc_modules.h>
#include <vlc_picture.h>

namespace {

QColor setColorAlpha(const QColor& c1, float alpha)
{
    QColor c(c1);
    c.setAlphaF(alpha);
    return c;
}

#ifndef _WIN32
/**
 * function taken from QtBase gui/platform/unix/qgenericunixservices.cpp
 */
static inline QByteArray detectLinuxDesktopEnvironment()
{
    const QByteArray xdgCurrentDesktop = qgetenv("XDG_CURRENT_DESKTOP");
    if (!xdgCurrentDesktop.isEmpty())
        return xdgCurrentDesktop.toUpper(); // KDE, GNOME, UNITY, LXDE, MATE, XFCE...

    // Classic fallbacks
    if (!qEnvironmentVariableIsEmpty("KDE_FULL_SESSION"))
        return QByteArrayLiteral("KDE");
    if (!qEnvironmentVariableIsEmpty("GNOME_DESKTOP_SESSION_ID"))
        return QByteArrayLiteral("GNOME");

    // Fallback to checking $DESKTOP_SESSION (unreliable)
    QByteArray desktopSession = qgetenv("DESKTOP_SESSION");

    // This can be a path in /usr/share/xsessions
    int slash = desktopSession.lastIndexOf('/');
    if (slash != -1) {
        QSettings desktopFile(QFile::decodeName(desktopSession + ".desktop"), QSettings::IniFormat);
        desktopFile.beginGroup(QStringLiteral("Desktop Entry"));
        QByteArray desktopName = desktopFile.value(QStringLiteral("DesktopNames")).toByteArray();
        if (!desktopName.isEmpty())
            return desktopName;

        // try decoding just the basename
        desktopSession = desktopSession.mid(slash + 1);
    }

    if (desktopSession == "gnome")
        return QByteArrayLiteral("GNOME");
    else if (desktopSession == "xfce")
        return QByteArrayLiteral("XFCE");
    else if (desktopSession == "kde")
        return QByteArrayLiteral("KDE");

    return QByteArrayLiteral("UNKNOWN");
}

bool isGTKBasedEnvironment()
{
    QList<QByteArray> gtkBasedEnvironments{
        "GNOME",
        "X-CINNAMON",
        "UNITY",
        "MATE",
        "XFCE",
        "LXDE"
    };
    const QList<QByteArray> desktopNames = detectLinuxDesktopEnvironment().split(':');
    for (const QByteArray& desktopName: desktopNames)
    {
        if (gtkBasedEnvironments.contains(desktopName))
            return true;
    }
    return false;
}
#endif


static void PaletteChangedCallback(vlc_qt_theme_provider_t*, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    emit priv->paletteChanged();
}

static void MetricsChangedCallback(vlc_qt_theme_provider_t*, vlc_qt_theme_image_type type, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    assert(priv);
    priv->updateMetrics(type);
}


static void ReleaseVLCPictureCb(void* data)
{
    auto pic = static_cast<picture_t*>(data);
    if (pic)
        picture_Release(pic);
}


static void setColorRBGAInt(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    int r, int g, int b, int a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

static void setColorRBGAFloat(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    double r, double g, double b, double a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color;
    color.setRgbF(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

}

//ExternalPaletteImpl

ExternalPaletteImpl::ExternalPaletteImpl(MainCtx* ctx, SystemPalette& palette, QObject* parent)
    : QObject(parent)
    , m_palette(palette)
    , m_ctx(ctx)
{
}

ExternalPaletteImpl::~ExternalPaletteImpl()
{
    if (m_provider)
    {
        if (m_provider->close)
            m_provider->close(m_provider);
        if (m_module)
            module_unneed(m_provider, m_module);
        vlc_object_delete(m_provider);
    }
}

bool ExternalPaletteImpl::init()
{
    QString preferedProvider;
#ifndef _WIN32
    if (isGTKBasedEnvironment())
        preferedProvider = "qt-themeprovider-gtk";
#endif

    m_provider = vlc_object_create<vlc_qt_theme_provider_t>(m_ctx->getIntf());
    if (!m_provider)
        return false;


    m_provider->paletteUpdated = PaletteChangedCallback;
    m_provider->paletteUpdatedData = this;

    m_provider->metricsUpdated = MetricsChangedCallback;
    m_provider->metricsUpdatedData = this;

    m_provider->setColorF = setColorRBGAFloat;
    m_provider->setColorInt = setColorRBGAInt;
    m_provider->setColorData = &m_palette;

    m_module = module_need(m_provider, "qt theme provider",
                           preferedProvider.isNull() ? nullptr : qtu(preferedProvider),
                           true);
    if (!m_module)
        return false;
    return true;
}

bool ExternalPaletteImpl::isThemeDark() const
{
    if (!m_provider->isThemeDark)
        return false;
    return m_provider->isThemeDark(m_provider);
}

bool ExternalPaletteImpl::hasCSDImages() const
{
    if (!m_provider->supportThemeImage)
        return false;
    return m_provider->supportThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON);
}


QImage ExternalPaletteImpl::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!m_provider->getThemeImage)
        return {};
    vlc_qt_theme_image_setting imageSettings;
    imageSettings.windowScaleFactor = m_ctx->intfMainWindow()->devicePixelRatio();
    imageSettings.userScaleFacor = m_ctx->getIntfUserScaleFactor();
    imageSettings.u.csdButton.buttonType = type;
    imageSettings.u.csdButton.state = state;
    imageSettings.u.csdButton.maximized = maximized;
    imageSettings.u.csdButton.active = active;
    imageSettings.u.csdButton.bannerHeight = bannerHeight;
    picture_t* pic = m_provider->getThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &imageSettings);
    if (!pic)
        return {};

    QImage::Format format = QImage::Format_Invalid;
    switch (pic->format.i_chroma)
    {
    case VLC_CODEC_ARGB:
        format = QImage::Format_ARGB32_Premultiplied;
        break;
    case VLC_CODEC_RGBA:
        format = QImage::Format_RGBA8888_Premultiplied;
        break;
    case VLC_CODEC_RGB24:
        format = QImage::Format_RGB888;
        break;
    default:
        msg_Err(m_ctx->getIntf(), "unexpected image format from theme provider");
        break;
    }

    return QImage(pic->p[0].p_pixels,
            pic->format.i_visible_width, pic->format.i_visible_height, pic->p[0].i_pitch,
            format,
            ReleaseVLCPictureCb, pic
            );
}

CSDMetrics* ExternalPaletteImpl::getCSDMetrics() const
{
    return m_csdMetrics.get();
}

int ExternalPaletteImpl::update()
{
    if (m_provider->updatePalette)
        return m_provider->updatePalette(m_provider);
    return VLC_EGENERIC;
}

void ExternalPaletteImpl::updateMetrics(vlc_qt_theme_image_type type)
{
    if (m_provider->getThemeMetrics)
    {
        if (type == VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON)
        {
            m_csdMetrics.reset();
            [&](){
                if (!m_provider->getThemeMetrics)
                    return;
                vlc_qt_theme_metrics metrics;
                memset(&metrics, 0, sizeof(metrics));
                bool ret = m_provider->getThemeMetrics(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &metrics);
                if (!ret)
                    return;
                m_csdMetrics = std::make_unique<CSDMetrics>();
                m_csdMetrics->interNavButtonSpacing = metrics.u.csd.interNavButtonSpacing;

                m_csdMetrics->csdFrameMarginLeft = metrics.u.csd.csdFrameMarginLeft;
                m_csdMetrics->csdFrameMarginRight = metrics.u.csd.csdFrameMarginRight;
                m_csdMetrics->csdFrameMarginTop = metrics.u.csd.csdFrameMarginTop;
                m_csdMetrics->csdFrameMarginBottom = metrics.u.csd.csdFrameMarginBottom;
            }();
            emit CSDMetricsChanged();
        }
    }
}

SystemPalette::SystemPalette(QObject* parent)
    : QObject(parent)
{

}

// redesign: derive the Figma accent shades (Bright, DIm, BG/Accent Bright, BG/Accent Dark)
// from a main accent color, keeping the hue and scaling saturation/value with the same
// ratios as the original orange set (#D37918 -> #FC9729, #AB6314, #371F06, #1A1611).
static QColor deriveAccentShade(const QColor& main, float satRatio, float valRatio)
{
    float h, s, v, a;
    main.getHsvF(&h, &s, &v, &a);
    if (h < 0)
        h = 0;
    return QColor::fromHsvF(h, std::min(1.f, s * satRatio), std::min(1.f, v * valRatio));
}

void SystemPalette::applyAccent()
{
    QColor main;
    if (m_ctx && m_ctx->accentColor().isValid())
        main = m_ctx->accentColor();
    else if (m_ctx)
    {
        char* accentColor = var_InheritString(m_ctx->getIntf(), "qt-accent-color");
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
        if (accentColor && !strcmp(accentColor, "system"))
        {
            assert(qApp);
            main = qApp->palette().color(QPalette::Normal, QPalette::Accent);
        }
#endif
        free(accentColor);
    }
    if (!main.isValid())
        main = QColor("#D37918"); // Dark/Accent/Main

    orange500 = main;
    rdAccentMain = main;
    if (main == QColor("#D37918"))
    {
        // exact Figma values for the default accent
        orange800 = rdAccentBright = QColor("#FC9729");
        rdAccentDim = QColor("#AB6314");
        rdBgAccentBright = QColor("#371F06");
        rdBgAccentDark = QColor("#1A1611");
    }
    else
    {
        orange800 = rdAccentBright = deriveAccentShade(main, 0.945f, 1.195f);
        rdAccentDim = deriveAccentShade(main, 0.997f, 0.811f);
        rdBgAccentBright = deriveAccentShade(main, 1.006f, 0.261f);
        rdBgAccentDark = deriveAccentShade(main, 0.390f, 0.123f);
    }
}

void SystemPalette::componentComplete()
{
    assert(m_ctx);
    applyAccent();
    updatePalette();
}

ColorSchemeModel::ColorScheme SystemPalette::source() const
{
    return m_source;
}

QImage SystemPalette::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!hasCSDImage())
        return QImage();
    assert(m_palettePriv);
    return m_palettePriv->getCSDImage(type, state, maximized, active, bannerHeight);

}

CSDMetrics* SystemPalette::getCSDMetrics() const
{
    if (!m_palettePriv)
        return nullptr;
    return m_palettePriv->getCSDMetrics();
}

bool SystemPalette::hasCSDImage() const
{
    if (!m_palettePriv)
        return false;
    return m_palettePriv->hasCSDImages();
}

void SystemPalette::setSource(ColorSchemeModel::ColorScheme source)
{
    if (m_source == source)
        return;
    m_source = source;

    updatePalette();
    emit sourceChanged();
}

void SystemPalette::setCtx(MainCtx* ctx)
{
    if (ctx == m_ctx)
        return;
    if (m_ctx)
        disconnect(m_ctx, &MainCtx::accentColorChanged, this, nullptr);
    m_ctx = ctx;
    if (m_ctx)
    {
        // redesign: live accent recolor (Decision 9 / 15)
        connect(m_ctx, &MainCtx::accentColorChanged, this, [this]() {
            applyAccent();
            updatePalette();
        });
        applyAccent();
    }
    emit ctxChanged();
    updatePalette();
}

void SystemPalette::updatePalette()
{
    m_palettePriv.reset();
    switch(m_source)
    {
    case ColorSchemeModel::System:
        makeSystemPalette();
        break;
    case ColorSchemeModel::Day:
        makeLightPalette();
        break;
    case ColorSchemeModel::Night:
        makeDarkPalette();
        break;
    default:
        break;
    }

    if (m_palettePriv)
    {
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::paletteChanged,
            this, &SystemPalette::updatePalette);
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::CSDMetricsChanged,
            this, &SystemPalette::CSDMetricsChanged);
    }
    emit paletteChanged();

    bool hasCSDImage = m_palettePriv && m_palettePriv->hasCSDImages();
    if (m_hasCSDImage != hasCSDImage)
    {
        m_hasCSDImage = hasCSDImage;
        emit hasCSDImageChanged();
    }
}

static quint64 makeKey(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                       ColorContext::ColorName name, ColorContext::ColorState state)
{
    static_assert(VQTC_STATE_COUNT < (1<<4), "");
    static_assert(VQTC_SECTION_COUNT < (1<<4), "");
    static_assert(VQTC_NAME_COUNT < (1<<8), "");
    static_assert(VQTC_SET_COUNT < (1<<16), "");
    return  (colorSet << 16)
        + (name << 8)
        + (section << 4)
        + state;
}

void SystemPalette::setColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                             ColorContext::ColorName name, ColorContext::ColorState state, QColor color)
{

    quint64 key = makeKey(colorSet, section, name, state);
    m_colorMap[key] = color;
}


QColor SystemPalette::getColor(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                               ColorContext::ColorName name, ColorContext::ColorState state) const
{
    typedef ColorContext C;

    quint64 key = makeKey(colorSet, section, name, state);
    auto it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the normal state
    key = makeKey(colorSet, section, name, C::Normal);
    it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the colorSet View
    //TODO do we want finer hierarchy?
    if (colorSet != C::View)
    {
        return getColor(C::View, section, name, state);
    }
    else
    {
        //nothing matches, that's probably an issue, return an ugly color
        return Qt::magenta;
    }
}


void SystemPalette::makeLightPalette()
{
    m_isDark = false;

    typedef ColorContext C;

    m_colorMap.clear();

    //base set
    {
        C::ColorSet CS = C::View;
        setColor(CS, C::Bg, C::Primary, C::Normal, lightGrey100 );
        setColor(CS, C::Bg, C::Secondary, C::Normal, Qt::white );

        setColor(CS, C::Fg, C::Primary, C::Normal, darkGrey300);
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(Qt::black, 0.3));

        setColor(CS, C::Fg, C::Secondary, C::Normal, setColorAlpha(Qt::black, 0.7));

        setColor(CS, C::Bg, C::Negative, C::Normal, QColor("#fde7e9")); //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, Qt::red);

        setColor(CS, C::Bg, C::Neutral, C::Normal, QColor("#e4dab8")); //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, orange800);

        setColor(CS, C::Bg, C::Positive, C::Normal, QColor("#dff6dd")); //FIXME
        setColor(CS, C::Fg, C::Positive, C::Normal, Qt::green);

        setColor(CS, C::Decoration, C::VisualFocus, C::Normal, setColorAlpha(Qt::black, 0.0) );
        setColor(CS, C::Decoration, C::VisualFocus, C::Focused, Qt::black );

        setColor(CS, C::Decoration, C::Border, C::Normal, setColorAlpha(Qt::black, 0.4) );
        setColor(CS, C::Decoration, C::Border, C::Focused, setColorAlpha(Qt::black, 0.7) );
        setColor(CS, C::Decoration, C::Border, C::Hovered, setColorAlpha(Qt::black, 0.7) );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::black, 0.0) );

        setColor(CS, C::Decoration, C::Separator, C::Normal, QColor("#E0E0E0")); //FIXME not a predef

        setColor(CS, C::Decoration, C::Shadow, C::Normal, setColorAlpha(Qt::black, 0.22));

        setColor(CS, C::Decoration, C::Accent, C::Normal, orange800);
        setColor(CS, C::Fg, C::Link, C::Normal, orange800 /* accent */);
    }

    //window banner & miniplayer
    {
        C::ColorSet CS = C::Window;
        setColor(CS, C::Bg, C::Primary, C::Normal, lightGrey400); //looks not white in figma more like #FDFDFD
        setColor(CS, C::Bg, C::Secondary, C::Normal, lightGrey400);
        setColor(CS, C::Decoration, C::Border, C::Normal, QColor{"#E0E0E0"}); //FIXME not a predef
    }

    //badges
    {
        C::ColorSet CS = C::Badge;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(Qt::black, 0.6));
        setColor(CS, C::Fg, C::Primary, C::Normal, Qt::white);
    }

    //tab button
    {
        C::ColorSet CS = C::TabButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(lightGrey300, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, lightGrey300);
        setColor(CS, C::Bg, C::Primary, C::Hovered, lightGrey300);

        setColor(CS, C::Fg, C::Primary, C::Normal, setColorAlpha(Qt::black, 0.6));
        setColor(CS, C::Fg, C::Primary, C::Focused, Qt::black);
        setColor(CS, C::Fg, C::Primary, C::Hovered, Qt::black);
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(Qt::black, 0.2));
        setColor(CS, C::Fg, C::Secondary, C::Normal, Qt::black);
    }

    //tool button
    {
        C::ColorSet CS = C::ToolButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Secondary, C::Normal, lightGrey400);

        setColor(CS, C::Fg, C::Primary, C::Normal, setColorAlpha(Qt::black, 0.6));
        setColor(CS, C::Fg, C::Primary, C::Focused, Qt::black);
        setColor(CS, C::Fg, C::Primary, C::Hovered, Qt::black);
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(Qt::black, 0.2));
        setColor(CS, C::Fg, C::Secondary, C::Normal, Qt::black);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //menubar
    {
        C::ColorSet CS = C::MenuBar;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(lightGrey700, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, lightGrey700);
        setColor(CS, C::Bg, C::Primary, C::Hovered, lightGrey700);
        setColor(CS, C::Fg, C::Primary, C::Normal, Qt::black);
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(Qt::black, 0.2));
    }

    //Item
    {
        C::ColorSet CS = C::Item;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(lightGrey600, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, setColorAlpha(lightGrey600, 0.5));
        setColor(CS, C::Bg, C::Primary, C::Hovered, setColorAlpha(lightGrey600, 0.5));

        setColor(CS, C::Bg, C::Highlight, C::Normal, lightGrey600);
        setColor(CS, C::Bg, C::Highlight, C::Focused, setColorAlpha(lightGrey600, 0.8));
        setColor(CS, C::Bg, C::Highlight, C::Hovered, setColorAlpha(lightGrey600, 0.8));
        setColor(CS, C::Fg, C::Highlight, C::Normal, Qt::black);

        setColor(CS, C::Fg, C::Primary, C::Normal, Qt::black);
        setColor(CS, C::Fg, C::Secondary, C::Normal, setColorAlpha(Qt::black, 0.6));

        setColor(CS, C::Decoration, C::Indicator, C::Normal, QColor("#9e9e9e")); //FIXME not a predef

    }

    //Accent Buttons
    {
        C::ColorSet CS = C::ButtonAccent;
        setColor(CS, C::Bg, C::Primary, C::Normal, orange800);
        setColor(CS, C::Bg, C::Primary, C::Pressed, QColor("#e65609"));  //FIXME not a predef
        setColor(CS, C::Bg, C::Primary, C::Disabled, setColorAlpha(Qt::black, 0.2));

        setColor(CS, C::Fg, C::Primary, C::Normal, Qt::white);
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(Qt::black, 0.3));

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Standard Buttons
    {
        C::ColorSet CS = C::ButtonStandard;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);

        setColor(CS, C::Fg, C::Primary, C::Normal, setColorAlpha(Qt::black, 0.6));
        setColor(CS, C::Fg, C::Primary, C::Focused, Qt::black);
        setColor(CS, C::Fg, C::Primary, C::Hovered, Qt::black);
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(Qt::black, 0.3));

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //tooltip
    {
        C::ColorSet CS = C::Tooltip;
        setColor(CS, C::Bg, C::Primary, C::Normal, lightGrey200);
        setColor(CS, C::Fg, C::Primary, C::Normal, Qt::black);
    }

    //slider
    {
        C::ColorSet CS = C::Slider;
        setColor(CS, C::Bg, C::Primary, C::Normal, lightGrey400); //#EEEEEE on the designs
        setColor(CS, C::Bg, C::Secondary, C::Normal, setColorAlpha("#lightGrey400", 0.2));
        setColor(CS, C::Fg, C::Primary, C::Normal, orange800);
        setColor(CS, C::Fg, C::Positive, C::Normal, "#0F7B0F");  //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, "#9D5D00");  //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, "#C42B1C");  //FIXME
    }

    //Combo box
    {
        C::ColorSet CS = C::ComboBox;
        setColor(CS, C::Fg, C::Primary, C::Normal, Qt::black);
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(Qt::white, 0.8));
        setColor(CS, C::Bg, C::Secondary, C::Normal, lightGrey500);
    }

    //TextField
    {
        C::ColorSet CS = C::TextField;
        setColor(CS, C::Decoration, C::Border, C::Normal, setColorAlpha(Qt::black, 0.4) );
        setColor(CS, C::Decoration, C::Border, C::Focused, orange800);
        setColor(CS, C::Decoration, C::Border, C::Hovered, setColorAlpha(Qt::black, 0.7) );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::black, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, darkGrey800); //FIXME
        setColor(CS, C::Fg, C::Highlight, C::Normal, Qt::white); //FIXME
    }

    //Switch
    {
        C::ColorSet CS = C::Switch;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(Qt::black, 0.05));
        setColor(CS, C::Fg, C::Primary, C::Normal, setColorAlpha(Qt::black, 0.55));
        setColor(CS, C::Decoration, C::Border, C::Normal, setColorAlpha(Qt::black, 0.55));

        setColor(CS, C::Bg, C::Secondary, C::Normal, orange800);
        setColor(CS, C::Fg, C::Secondary, C::Normal, Qt::white);
    }

    //SpinBox
    {
        C::ColorSet CS = C::SpinBox;
        setColor(CS, C::Decoration, C::Border, C::Normal, setColorAlpha(Qt::black, 0.4) );
        setColor(CS, C::Decoration, C::Border, C::Focused, orange800);
        setColor(CS, C::Decoration, C::Border, C::Hovered, setColorAlpha(Qt::black, 0.7) );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::black, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, darkGrey800); //FIXME
        setColor(CS, C::Fg, C::Highlight, C::Normal, Qt::white); //FIXME
    }
}

void SystemPalette::makeDarkPalette()
{
    // redesign: values are the Figma "Dark" color styles (redesign/reference/figma/styles.txt).
    // The accent follows orange500 / orange800 so qt-accent-color keeps working.
    m_isDark = true;

    m_colorMap.clear();

    typedef ColorContext C;

    const QColor white6 = setColorAlpha(Qt::white, 0.06);

    {
        C::ColorSet CS = C::View;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA3);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);

        setColor(CS, C::Fg, C::Secondary, C::Normal, rdFgA3);

        setColor(CS, C::Bg, C::Highlight, C::Normal, rdBgA2);
        setColor(CS, C::Fg, C::Highlight, C::Normal, rdFg2);

        setColor(CS, C::Bg, C::Negative, C::Normal, QColor(Qt::darkRed));
        setColor(CS, C::Fg, C::Negative, C::Normal, Qt::red);

        setColor(CS, C::Bg, C::Neutral, C::Normal, rdBgAccentBright);
        setColor(CS, C::Fg, C::Neutral, C::Normal, orange500);

        setColor(CS, C::Bg, C::Positive, C::Normal, QColor(Qt::darkGreen));
        setColor(CS, C::Fg, C::Positive, C::Normal, Qt::green);

        setColor(CS, C::Decoration, C::VisualFocus, C::Normal, setColorAlpha(Qt::white, 0.0) );
        setColor(CS, C::Decoration, C::VisualFocus, C::Focused, rdFg2 );

        setColor(CS, C::Decoration, C::Border, C::Normal, rdDividerBright );
        setColor(CS, C::Decoration, C::Border, C::Focused, rdFgA3 );
        setColor(CS, C::Decoration, C::Border, C::Hovered, rdFgA3 );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::white, 0.0) );

        setColor(CS, C::Decoration, C::Shadow, C::Normal, setColorAlpha(Qt::black, 0.46));

        setColor(CS, C::Decoration, C::Separator, C::Normal, rdDividerDim);

        setColor(CS, C::Decoration, C::Accent, C::Normal, orange500);
        setColor(CS, C::Fg, C::Link, C::Normal, orange500);
    }

    //window banner & miniplayer
    {
        C::ColorSet CS = C::Window;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA3);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgB2);
        setColor(CS, C::Decoration, C::Border, C::Normal, rdDividerDim);
    }

    //badges
    {
        C::ColorSet CS = C::Badge;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA1);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFg2);
    }

    //tab button: label FG/A3, active FG/1, accent underline drawn by the tab itself
    {
        C::ColorSet CS = C::TabButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(rdBgB2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, white6);
        setColor(CS, C::Bg, C::Primary, C::Hovered, white6);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA3);
        setColor(CS, C::Fg, C::Primary, C::Focused, rdFg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, rdFg2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, rdFg1);
    }

    //tool button = Figma "Icon Wrapper": icon FG/A2, hover background #FFFFFF 6%
    {
        C::ColorSet CS = C::ToolButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, white6);
        setColor(CS, C::Bg, C::Primary, C::Focused, white6);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA2);
        setColor(CS, C::Fg, C::Primary, C::Focused, rdFg2);
        setColor(CS, C::Fg, C::Primary, C::Hovered, rdFgA2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, orange500);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //menubar
    {
        C::ColorSet CS = C::MenuBar;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(rdBgA2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, rdBgA2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdBgA2);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);
    }

    //Item (list rows, menu options): hover/selected BG/A2, text FG/A1 -> FG/2 on hover
    {
        C::ColorSet CS = C::Item;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(rdBgA2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, rdBgA2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdBgA2);

        setColor(CS, C::Bg, C::Highlight, C::Normal, rdBgA2);
        setColor(CS, C::Bg, C::Highlight, C::Focused, rdBgA1);
        setColor(CS, C::Bg, C::Highlight, C::Hovered, rdBgA1);
        setColor(CS, C::Fg, C::Highlight, C::Normal, rdFg2);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, rdFg2);
        setColor(CS, C::Fg, C::Secondary, C::Normal, rdFgA3);

        setColor(CS, C::Decoration, C::Indicator, C::Normal, rdFgA4);
    }

    //Accent Buttons: solid accent with FG/B1 text (play button, onboarding Next, Continue Watching)
    {
        C::ColorSet CS = C::ButtonAccent;
        setColor(CS, C::Bg, C::Primary, C::Normal, orange500);
        setColor(CS, C::Bg, C::Primary, C::Hovered, orange800);
        setColor(CS, C::Bg, C::Primary, C::Pressed, rdAccentDim);
        setColor(CS, C::Bg, C::Primary, C::Disabled, rdBgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgB1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Standard Buttons: Figma "Cancel" (BG/A3, FG/A2)
    {
        C::ColorSet CS = C::ButtonStandard;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA3);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdBgA1);
        setColor(CS, C::Bg, C::Primary, C::Focused, rdBgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA2);
        setColor(CS, C::Fg, C::Primary, C::Focused, rdFg2);
        setColor(CS, C::Fg, C::Primary, C::Hovered, rdFg2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, rdFgA4);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //tooltip: Figma "audio value" (BG/B1 95%, FG/A1)
    {
        C::ColorSet CS = C::Tooltip;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgB1Transparent);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA1);
    }

    //slider: track BG/B2, played part accent
    {
        C::ColorSet CS = C::Slider;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgB2);
        setColor(CS, C::Bg, C::Primary, C::Focused, rdBgB2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, rdBgB2);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgAccentBright);

        setColor(CS, C::Fg, C::Primary, C::Normal, orange500);
        setColor(CS, C::Fg, C::Positive, C::Normal, "#0F7B0F");  //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, "#9D5D00");  //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, "#C42B1C");  //FIXME
    }

    //Combo box: Figma "Dropdown" (BG/B2 frame, BG/A4 option, FG/A2 text)
    {
        C::ColorSet CS = C::ComboBox;
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA2);
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA4);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgB2);
        setColor(CS, C::Bg, C::Highlight, C::Normal, rdBgA2);
    }

    //TextField: Figma inputs (BG/B2 fill, 2 px BG/A4 border, accent when focused)
    {
        C::ColorSet CS = C::TextField;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgB2);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFg2);
        setColor(CS, C::Fg, C::Secondary, C::Normal, rdFgA4);
        setColor(CS, C::Decoration, C::Border, C::Normal, rdBgA4 );
        setColor(CS, C::Decoration, C::Border, C::Focused, orange500 );
        setColor(CS, C::Decoration, C::Border, C::Hovered, rdDividerBright );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::white, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, rdAccentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, rdFg1);
    }

    //Switch: Figma "Toggle" (OFF knob FG/A4 on BG/A4, ON knob Accent/DIm on BG/Accent Bright)
    {
        C::ColorSet CS = C::Switch;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgA4);
        setColor(CS, C::Fg, C::Primary, C::Normal, rdFgA4);
        setColor(CS, C::Decoration, C::Border, C::Normal, rdBgB2);
        setColor(CS, C::Bg, C::Secondary, C::Normal, rdBgAccentBright);
        setColor(CS, C::Fg, C::Secondary, C::Normal, rdAccentDim);
    }

    //Spinbox
    {
        C::ColorSet CS = C::SpinBox;
        setColor(CS, C::Bg, C::Primary, C::Normal, rdBgB2);
        setColor(CS, C::Decoration, C::Border, C::Normal, rdBgA4 );
        setColor(CS, C::Decoration, C::Border, C::Focused, orange500 );
        setColor(CS, C::Decoration, C::Border, C::Hovered, rdDividerBright );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(Qt::white, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, rdAccentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, rdFg1);
    }
}

void SystemPalette::makeSystemPalette()
{
    if (!m_ctx)
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    auto palette = std::make_unique<ExternalPaletteImpl>(m_ctx, *this);
    if (!palette->init())
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    m_colorMap.clear();
    int ret = palette->update();
    if (ret != VLC_SUCCESS)
    {
        if (palette->isThemeDark())
            makeDarkPalette();
        else
            makeLightPalette();
    }
    else
    {
        m_isDark = palette->isThemeDark();
    }

    m_palettePriv = std::move(palette);
}
