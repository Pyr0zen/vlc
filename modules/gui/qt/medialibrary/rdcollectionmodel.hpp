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

#ifndef RDCOLLECTIONMODEL_HPP
#define RDCOLLECTIONMODEL_HPP

#include "rdlibrarymodel.hpp"

// redesign: the library pages that are not folders: the Home sections (video 13:44-13:55,
// P6-20, F-15), Recent (P6-19), the Music lists (Albums, Artists, Genres, P6-02), Playlists
// (P6-15) and the media of an album, artist, genre or playlist (P6-03).
//
// section:
//   "continueWatching"  videos started but not finished, latest first
//   "listenAgain"       songs played lately
//   "frequentFolders"   the folders of `ids`, in that order
//   "frequentPlaylists" the playlists of `ids`, in that order
//   "frequentArtists"   the artists of the songs played most
//   "latestStreams"     network streams played lately
//   "recent"            everything played, latest first
//   "albums", "artists", "genres", "playlists"
//   "media"             the media of `parentId` (album, artist, genre or playlist)
class RdCollectionModel : public RdLibraryModel
{
    Q_OBJECT

    Q_PROPERTY(QString section READ section WRITE setSection NOTIFY sectionChanged FINAL)
    Q_PROPERTY(MLItemId parentId READ parentId WRITE setParentId NOTIFY parentIdChanged FINAL)
    // 0: no limit
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY limitChanged FINAL)
    Q_PROPERTY(QVariantList ids READ ids WRITE setIds NOTIFY idsChanged FINAL)

public:
    explicit RdCollectionModel(QObject* parent = nullptr);

    QString section() const { return m_section; }
    void setSection(const QString& section);

    MLItemId parentId() const { return m_parentId; }
    void setParentId(const MLItemId& id);

    int limit() const { return m_limit; }
    void setLimit(int limit);

    QVariantList ids() const { return m_ids; }
    void setIds(const QVariantList& ids);

signals:
    void sectionChanged();
    void parentIdChanged();
    void limitChanged();
    void idsChanged();

protected:
    Loader createLoader() const override;
    bool canLoad() const override;

private:
    QString m_section;
    MLItemId m_parentId;
    int m_limit = 0;
    QVariantList m_ids;
};

#endif // RDCOLLECTIONMODEL_HPP
