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

// redesign: a Home section of the library (video 13:44-13:55, P6-20, F-15). Home shows a few
// rows per section and its ">" opens the section with up to MAX_ROWS rows.
//
// section:
//   "continueWatching"  videos started but not finished, latest first
//   "listenAgain"       songs played lately
//   "frequentFolders"   the folders of `ids`, in that order
//   "frequentPlaylists" the playlists of `ids`, in that order
//   "frequentArtists"   the artists of the songs played most
//   "latestStreams"     network streams played lately
class RdCollectionModel : public RdLibraryModel
{
    Q_OBJECT

    Q_PROPERTY(QString section READ section WRITE setSection NOTIFY sectionChanged FINAL)
    // rows to show, at most MAX_ROWS (0: MAX_ROWS)
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY limitChanged FINAL)
    Q_PROPERTY(QVariantList ids READ ids WRITE setIds NOTIFY idsChanged FINAL)

public:
    static constexpr int MAX_ROWS = 100;

    explicit RdCollectionModel(QObject* parent = nullptr);

    QString section() const { return m_section; }
    void setSection(const QString& section);

    int limit() const { return m_limit; }
    void setLimit(int limit);

    QVariantList ids() const { return m_ids; }
    void setIds(const QVariantList& ids);

signals:
    void sectionChanged();
    void limitChanged();
    void idsChanged();

protected:
    Loader createLoader() const override;
    bool canLoad() const override { return !m_section.isEmpty(); }

private:
    QString m_section;
    int m_limit = 0;
    QVariantList m_ids;
};

#endif // RDCOLLECTIONMODEL_HPP
