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

#ifndef ADD_SUBTITLES_MODEL_HPP
#define ADD_SUBTITLES_MODEL_HPP

#include <QAbstractListModel>
#include <QVector>

/**
 * redesign (Add Subtitles, W6.5): the rows of the dialog's body.
 * - "To This File": one row per subtitle file (Figma "subtitle one"), checked when selected;
 * - "To This Folder" / "To This Playlist": one row per video with the subtitle matched to it
 *   (Figma "Add Subtitles to Playlist/Folder": video, dashed leader, "subtitle multiple").
 * The controller (AddSubtitles) fills it; QML shows it in a ListView, rows created on demand.
 */
class AddSubtitlesModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)

public:
    enum Roles {
        VideoNameRole = Qt::UserRole + 1,
        NameRole,
        SelectedRole,
        MatchedRole,
        ManualRole
    };

    struct Row
    {
        // folder and playlist rows: the video
        QString videoName;
        QString videoMrl;
        // the subtitle: its name, and its candidate in the controller's list (-1: none)
        QString name;
        int candidate = -1;
        // file rows: checked
        bool selected = false;
        // folder and playlist rows: matched by hand
        bool manual = false;
    };

    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_rows.size()); }
    const QVector<Row>& rows() const { return m_rows; }
    const Row& at(int row) const { return m_rows.at(row); }

    void setRows(const QVector<Row>& rows);
    void setRow(int row, const Row& value);

signals:
    void countChanged();

private:
    QVector<Row> m_rows;
};

#endif // ADD_SUBTITLES_MODEL_HPP
