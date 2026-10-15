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

#include "add_subtitles_model.hpp"

int AddSubtitlesModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : int(m_rows.size());
}

QVariant AddSubtitlesModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};
    const Row& row = m_rows.at(index.row());
    switch (role)
    {
    case VideoNameRole:
        return row.videoName;
    case NameRole:
        return row.name;
    case SelectedRole:
        return row.selected;
    case MatchedRole:
        return row.candidate >= 0;
    case ManualRole:
        return row.manual;
    default:
        return {};
    }
}

QHash<int, QByteArray> AddSubtitlesModel::roleNames() const
{
    return {
        { VideoNameRole, "videoName" },
        { NameRole, "name" },
        { SelectedRole, "selected" },
        { MatchedRole, "matched" },
        { ManualRole, "manual" }
    };
}

void AddSubtitlesModel::setRows(const QVector<Row>& rows)
{
    const qsizetype oldCount = m_rows.size();
    beginResetModel();
    m_rows = rows;
    endResetModel();
    if (oldCount != m_rows.size())
        emit countChanged();
}

void AddSubtitlesModel::setRow(int row, const Row& value)
{
    if (row < 0 || row >= m_rows.size())
        return;
    m_rows[row] = value;
    emit dataChanged(index(row), index(row));
}
