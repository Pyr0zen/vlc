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
#include "rdfonts.hpp"

#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QStringList>

void loadRedesignFonts(QGuiApplication& app)
{
    // the five weights used by the design: 300, 400, 500, 600, 700
    static const char* const fontFiles[] = {
        ":/fonts/Inter-Light.ttf",
        ":/fonts/Inter-Regular.ttf",
        ":/fonts/Inter-Medium.ttf",
        ":/fonts/Inter-SemiBold.ttf",
        ":/fonts/Inter-Bold.ttf",
    };

    bool hasInter = false;
    for (const char* file : fontFiles)
    {
        const int id = QFontDatabase::addApplicationFont(QString::fromLatin1(file));
        if (id >= 0 && QFontDatabase::applicationFontFamilies(id).contains(QStringLiteral("Inter")))
            hasInter = true;
    }

    if (!hasInter)
        return;

    QFont font = app.font();
    font.setFamily(QStringLiteral("Inter"));
    app.setFont(font);
}
