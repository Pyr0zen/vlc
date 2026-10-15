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

#ifndef OPENSUBTITLES_HPP
#define OPENSUBTITLES_HPP

#include <QByteArray>
#include <QString>
#include <QVector>

#include <vlc_common.h>

/**
 * redesign (Add Subtitles, W6.5, P3-07 / P3-08): the OpenSubtitles.com REST API (v1) behind
 * the dialog's "From OpenSubtitles" source: search by name, season, episode and language, and
 * download a result. It needs the user's own API key (Settings > Subtitles); an account
 * (username and password) raises the daily download quota.
 *
 * Every call blocks on the network: run them on a worker thread (see SubtitleWeb).
 */
class OpenSubtitles
{
public:
    struct Account
    {
        QString apiKey;
        QString username;
        QString password;

        bool enabled() const { return !apiKey.trimmed().isEmpty(); }
    };

    struct Result
    {
        qint64 fileId = 0;
        QString fileName;
        // two letter code ("en", "pt-br")
        QString language;
        QString release;
        int season = -1;
        int episode = -1;
        int downloads = 0;
        bool hearingImpaired = false;
    };

    // `error` gets a sentence for the user when the search fails
    static QVector<Result> search(vlc_object_t* obj, const Account& account, const QString& query,
                                  const QString& language, int season, int episode, int pages,
                                  QString* error);

    // the subtitle file of a result; `fileName` gets the name OpenSubtitles gives it
    static QByteArray download(vlc_object_t* obj, const Account& account, qint64 fileId,
                               QString* fileName, QString* error);
};

#endif // OPENSUBTITLES_HPP
