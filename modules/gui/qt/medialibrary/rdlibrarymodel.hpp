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

#ifndef RDLIBRARYMODEL_HPP
#define RDLIBRARYMODEL_HPP

// redesign: base of the library models of the redesigned library (video 9:35-13:55, BUILD_PLAN
// W5.x). A model loads every row of one library page on the media library thread, then sorts
// and filters them on the UI thread. Library pages are small (a folder, a history section), so
// unlike MLBaseModel nothing is paged; this is what makes the "Unwatched First" and "Watched
// First" sort orders possible (the media library cannot sort by watched state).

#include <QAbstractListModel>
#include <QSet>
#include <QTimer>

#include <functional>
#include <memory>
#include <vector>

#include "mlqmltypes.hpp"

class MediaLib;
struct vlc_medialibrary_t;
struct vlc_ml_event_callback_t;
struct vlc_ml_event_t;

// one row of a library page
struct RdLibraryItem
{
    enum Kind { Media, Folder, Playlist, Artist, Album, Genre, Stream };

    Kind kind = Media;
    MLItemId id;
    QString title;
    QString subtitle;    // artist of a song, track count of a container
    QString mrl;
    QString thumbnail;
    QString artist;
    QString album;
    double progress = -1.;  // 0..1 while a media is being watched, -1 otherwise
    bool watched = false;   // played to the end at least once
    bool isVideo = false;
    bool isFavorite = false;
    qint64 duration = 0;    // ms
    qint64 modified = 0;    // file modification date (s), "Newest First" / "Oldest First"
    int trackNumber = 0;
    int discNumber = 0;
    int count = 0;          // media in a folder, playlist, album, artist, genre
    bool thumbnailMissing = false;
};

using RdLibraryItemList = std::vector<RdLibraryItem>;

// conversions from the media library structures (to be called on the media library thread)
namespace RdLibraryItems
{
RdLibraryItem fromMedia(vlc_medialibrary_t* ml, const struct vlc_ml_media_t& media);
RdLibraryItem fromFolder(const struct vlc_ml_folder_t& folder);
RdLibraryItem fromPlaylist(const struct vlc_ml_playlist_t& playlist);
RdLibraryItem fromArtist(const struct vlc_ml_artist_t& artist);
// folder MRLs compare without their trailing slash
QString normalizedMrl(const QString& mrl);
}

class RdLibraryModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(MediaLib* ml READ ml WRITE setMl NOTIFY mlChanged FINAL)
    // "" keeps the loading order; see sortItems() for the other keys
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY sortKeyChanged FINAL)
    Q_PROPERTY(QString searchPattern READ searchPattern WRITE setSearchPattern NOTIFY searchPatternChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)
    Q_PROPERTY(int mediaCount READ mediaCount NOTIFY countChanged FINAL)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged FINAL)

public:
    enum Roles {
        KIND = Qt::UserRole + 1,
        ID,
        TITLE,
        SUBTITLE,
        MRL,
        THUMBNAIL,
        PROGRESS,
        WATCHED,
        IS_VIDEO,
        IS_FAVORITE,
        DURATION,
        COUNT_ROLE,
        ARTIST,
        ALBUM,
        IS_CONTAINER
    };

    explicit RdLibraryModel(QObject* parent = nullptr);
    ~RdLibraryModel() override;

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    MediaLib* ml() const { return m_mediaLib; }
    void setMl(MediaLib* ml);

    QString sortKey() const { return m_sortKey; }
    void setSortKey(const QString& key);

    QString searchPattern() const { return m_searchPattern; }
    void setSearchPattern(const QString& pattern);

    int count() const { return static_cast<int>(m_items.size()); }
    int mediaCount() const;
    bool loading() const { return m_loading; }

    // the row's data as a JS object (menus, drag and drop, the mini player)
    Q_INVOKABLE QVariantMap get(int row) const;
    // the media rows from `row` on, in display order (play a folder from a file on)
    Q_INVOKABLE QVariantList mediaIdsFrom(int row) const;

public slots:
    void reload();

signals:
    void mlChanged();
    void sortKeyChanged();
    void searchPatternChanged();
    void countChanged();
    void loadingChanged();
    void loaded();

protected:
    // the loading function runs on the media library thread: it must only use the copies it
    // captured, never `this`
    using Loader = std::function<RdLibraryItemList(vlc_medialibrary_t* ml)>;
    virtual Loader createLoader() const = 0;
    // media library events that change the page (any change by default)
    virtual bool isRelevantEvent(int eventType) const;
    // the model may only load once its parameters are set
    virtual bool canLoad() const { return true; }

    void scheduleReload();

private:
    static void onMlEvent(void* data, const vlc_ml_event_t* event);
    void applyItems(RdLibraryItemList&& items);
    void rebuild();
    void sortItems(RdLibraryItemList& items) const;
    void requestThumbnails();

    MediaLib* m_mediaLib = nullptr;
    std::unique_ptr<vlc_ml_event_callback_t, std::function<void(vlc_ml_event_callback_t*)>> m_eventCallback;
    QTimer m_reloadTimer;
    quint64 m_taskId = 0;
    bool m_loading = false;

    QString m_sortKey;
    QString m_searchPattern;

    RdLibraryItemList m_all;
    RdLibraryItemList m_items;
    QSet<int64_t> m_thumbnailRequested;
};

#endif // RDLIBRARYMODEL_HPP
