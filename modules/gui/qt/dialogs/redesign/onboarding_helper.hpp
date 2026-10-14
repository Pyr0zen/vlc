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
#ifndef ONBOARDING_HELPER_HPP
#define ONBOARDING_HELPER_HPP

#include <QObject>
#include <QString>
#include <QStringList>

#include "maininterface/mainctx.hpp"

/**
 * redesign (W8.3, video 19:47-19:54, Figma "Onboarding"): the settings side of the onboarding
 * that replaces VLC's first-run wizard (dialogs/firstrun/firstrunwizard.cpp).
 *
 * - colorScheme reads and sets the color scheme live (ColorSchemeModel::ColorScheme values);
 *   the accent color is MainCtx.accentColor, set directly from QML.
 * - finish() writes what the wizard wrote when it was accepted with the defaults the onboarding
 *   does not ask for (metadata network access on, as the wizard's preselected checkbox; the
 *   modern layout), adds the chosen media folder to the media library, saves the configuration
 *   and turns qt-privacy-ask off, so the onboarding is not shown again.
 * - skip() is the wizard's reject(): the same defaults, no media folder.
 */
class OnboardingHelper : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ getCtx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(int colorScheme READ getColorScheme WRITE setColorScheme NOTIFY colorSchemeChanged FINAL)

public:
    explicit OnboardingHelper(QObject* parent = nullptr);

    MainCtx* getCtx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);

    int getColorScheme() const;
    void setColorScheme(int scheme);

    // the user's Videos folder, as a native path (empty if the system has none)
    Q_INVOKABLE QString defaultMediaFolder() const;
    // native folder picker starting at `current`; empty when cancelled
    Q_INVOKABLE QString browseMediaFolder(const QString& current) const;

    // first key of a "key-*" hotkey option, one entry per keycap: "Shift+Left" -> SHIFT, ←
    Q_INVOKABLE QStringList keycaps(const QString& option) const;
    // the same for one VLC key string ("Ctrl+l"), for shortcuts that are not hotkey options
    Q_INVOKABLE QStringList keycapsForKey(const QString& key) const;

    // grows a normal (not maximized or fullscreen) main window to at least width x height,
    // within the screen's available area, and centers it when it had to grow
    Q_INVOKABLE void fitWindow(int width, int height) const;

    Q_INVOKABLE void finish(const QString& mediaFolder);
    Q_INVOKABLE void skip();

signals:
    void ctxChanged();
    void colorSchemeChanged();

private:
    void applyDefaults();
    void save();

    MainCtx* m_ctx = nullptr;
    bool m_done = false;
};

#endif // ONBOARDING_HELPER_HPP
