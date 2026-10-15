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

#include "opensubtitles.hpp"
#include "subtitle_web.hpp"

#include "qt.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <QUrl>

#include <algorithm>

namespace {

const QString apiBase = QStringLiteral("https://api.opensubtitles.com/api/v1");
// subtitle files are small; anything larger is not one
constexpr qint64 maxFileSize = 10 * 1024 * 1024;
// OpenSubtitles tokens last 24 hours
constexpr qint64 tokenLifetime = 23 * 3600;

// the session token of the account, shared by the dialog and the playback lookups
struct TokenCache
{
    QMutex lock;
    QString username;
    QByteArray token;
    qint64 created = 0;
};

TokenCache& tokenCache()
{
    static TokenCache cache;
    return cache;
}

QString networkError()
{
    return qtr("OpenSubtitles cannot be reached. Check the internet connection.");
}

QString statusError(const SubtitleWeb::Reply& reply)
{
    if (reply.status == 0)
        return networkError();
    if (reply.status == 401 || reply.status == 403)
        return qtr("OpenSubtitles did not accept the API key. Check it in Settings > Subtitles.");
    if (reply.status == 429)
        return qtr("OpenSubtitles asks to wait a moment before the next request.");
    if (reply.status >= 500)
        return qtr("OpenSubtitles is not available right now. Try again later.");

    const QString message = QJsonDocument::fromJson(reply.body).object().value(QStringLiteral("message")).toString();
    if (!message.isEmpty())
        return qtr("OpenSubtitles: %1").arg(message);
    return qtr("OpenSubtitles returned an error (%1).").arg(reply.status);
}

SubtitleWeb::Headers apiHeaders(const OpenSubtitles::Account& account, const QByteArray& token = {})
{
    SubtitleWeb::Headers headers {
        { "Api-Key", account.apiKey.trimmed().toUtf8() },
        { "Content-Type", "application/json" }
    };
    if (!token.isEmpty())
        headers.append({ "Authorization", "Bearer " + token });
    return headers;
}

// the account's session token, empty without an account; logs in when needed
QByteArray accountToken(vlc_object_t* obj, const OpenSubtitles::Account& account, QString* error)
{
    if (account.username.trimmed().isEmpty() || account.password.isEmpty())
        return {};

    TokenCache& cache = tokenCache();
    QMutexLocker locker(&cache.lock);
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    if (!cache.token.isEmpty() && cache.username == account.username.trimmed()
            && now - cache.created < tokenLifetime)
        return cache.token;

    const QJsonObject credentials {
        { QStringLiteral("username"), account.username.trimmed() },
        { QStringLiteral("password"), account.password }
    };
    const SubtitleWeb::Reply reply = SubtitleWeb::request(obj, "POST", QUrl(apiBase + QStringLiteral("/login")),
                                                          apiHeaders(account),
                                                          QJsonDocument(credentials).toJson(QJsonDocument::Compact));
    if (!reply.ok())
    {
        if (error)
            *error = reply.status == 401 ? qtr("OpenSubtitles did not accept the username or password.")
                                         : statusError(reply);
        return {};
    }

    cache.token = QJsonDocument::fromJson(reply.body).object().value(QStringLiteral("token")).toString().toUtf8();
    cache.username = account.username.trimmed();
    cache.created = now;
    return cache.token;
}

QString encoded(const QString& value)
{
    return QString::fromLatin1(QUrl::toPercentEncoding(value));
}

} // namespace

QVector<OpenSubtitles::Result> OpenSubtitles::search(vlc_object_t* obj, const Account& account,
                                                     const QString& query, const QString& language,
                                                     int season, int episode, int pages, QString* error)
{
    QVector<Result> results;
    if (!account.enabled())
        return results;

    for (int page = 1; page <= std::max(pages, 1); ++page)
    {
        // OpenSubtitles redirects queries whose parameters are not in alphabetical order and in
        // lower case
        QStringList parameters;
        if (episode >= 0)
            parameters << QStringLiteral("episode_number=%1").arg(episode);
        if (!language.isEmpty())
            parameters << QStringLiteral("languages=%1").arg(encoded(language.toLower()));
        parameters << QStringLiteral("page=%1").arg(page);
        if (!query.trimmed().isEmpty())
            parameters << QStringLiteral("query=%1").arg(encoded(query.trimmed().toLower()));
        if (season >= 0)
            parameters << QStringLiteral("season_number=%1").arg(season);

        QUrl url(apiBase + QStringLiteral("/subtitles"));
        url.setQuery(parameters.join(QChar('&')), QUrl::StrictMode);

        const SubtitleWeb::Reply reply = SubtitleWeb::request(obj, "GET", url, apiHeaders(account));
        if (!reply.ok())
        {
            if (error)
                *error = statusError(reply);
            break;
        }

        const QJsonObject root = QJsonDocument::fromJson(reply.body).object();
        const QJsonArray data = root.value(QStringLiteral("data")).toArray();
        for (const QJsonValue& entry : data)
        {
            const QJsonObject attributes = entry.toObject().value(QStringLiteral("attributes")).toObject();
            const QJsonArray files = attributes.value(QStringLiteral("files")).toArray();
            if (files.isEmpty())
                continue;
            const QJsonObject file = files.first().toObject();
            const QJsonObject feature = attributes.value(QStringLiteral("feature_details")).toObject();

            Result result;
            result.fileId = file.value(QStringLiteral("file_id")).toVariant().toLongLong();
            result.fileName = file.value(QStringLiteral("file_name")).toString();
            result.release = attributes.value(QStringLiteral("release")).toString();
            if (result.fileName.isEmpty())
                result.fileName = result.release + QStringLiteral(".srt");
            result.language = attributes.value(QStringLiteral("language")).toString().toLower();
            result.downloads = attributes.value(QStringLiteral("download_count")).toInt();
            result.hearingImpaired = attributes.value(QStringLiteral("hearing_impaired")).toBool();
            result.season = feature.value(QStringLiteral("season_number")).toInt(-1);
            result.episode = feature.value(QStringLiteral("episode_number")).toInt(-1);
            if (result.fileId > 0)
                results.append(result);
        }

        if (page >= root.value(QStringLiteral("total_pages")).toInt(1))
            break;
    }
    return results;
}

QByteArray OpenSubtitles::download(vlc_object_t* obj, const Account& account, qint64 fileId,
                                   QString* fileName, QString* error)
{
    if (!account.enabled())
        return {};

    QString loginError;
    const QByteArray token = accountToken(obj, account, &loginError);
    if (!loginError.isEmpty())
    {
        if (error)
            *error = loginError;
        return {};
    }

    const QJsonObject request { { QStringLiteral("file_id"), fileId } };
    const SubtitleWeb::Reply reply = SubtitleWeb::request(obj, "POST", QUrl(apiBase + QStringLiteral("/download")),
                                                          apiHeaders(account, token),
                                                          QJsonDocument(request).toJson(QJsonDocument::Compact));
    if (!reply.ok())
    {
        if (error)
            *error = (reply.status == 406 || reply.status == 429)
                     ? qtr("The OpenSubtitles download limit is reached. Signing in to your account in Settings > Subtitles allows more downloads.")
                     : statusError(reply);
        return {};
    }

    const QJsonObject answer = QJsonDocument::fromJson(reply.body).object();
    const QString link = answer.value(QStringLiteral("link")).toString();
    if (fileName)
        *fileName = answer.value(QStringLiteral("file_name")).toString();
    // the file comes from OpenSubtitles' servers: HTTPS only, like the API
    if (link.isEmpty() || !link.startsWith(QLatin1String("https://"), Qt::CaseInsensitive))
    {
        if (error)
            *error = statusError(reply);
        return {};
    }

    const SubtitleWeb::Reply file = SubtitleWeb::fetch(obj, link, maxFileSize);
    if (!file.ok() || file.body.isEmpty())
    {
        if (error)
            *error = networkError();
        return {};
    }
    return file.body;
}
