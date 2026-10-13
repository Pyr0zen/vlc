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

#ifndef RDCONCATMODEL_HPP
#define RDCONCATMODEL_HPP

#include <QAbstractListModel>
#include <QHash>
#include <QPointer>

// redesign: two list models shown as one, the rows of `first` then the rows of `second` (a
// folder of the library: its subfolders, then its media). Nothing is copied: every row is read
// from its source model when the view asks for it, so paged models (MLBaseModel) keep loading
// only the pages on screen. Roles are matched by name; "rdFirst" tells which model a row is
// from and "rdSourceRow" its row there.
class RdConcatModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(QAbstractItemModel* first READ first WRITE setFirst NOTIFY firstChanged FINAL)
    Q_PROPERTY(QAbstractItemModel* second READ second WRITE setSecond NOTIFY secondChanged FINAL)
    Q_PROPERTY(int firstCount READ firstCount NOTIFY countChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)

public:
    explicit RdConcatModel(QObject* parent = nullptr);

    QAbstractItemModel* first() const { return m_first; }
    QAbstractItemModel* second() const { return m_second; }
    void setFirst(QAbstractItemModel* model);
    void setSecond(QAbstractItemModel* model);

    int firstCount() const;
    int count() const { return rowCount(); }

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

signals:
    void firstChanged();
    void secondChanged();
    void countChanged();

private:
    void setSource(QPointer<QAbstractItemModel>& slot, QAbstractItemModel* model);
    void connectSource(QAbstractItemModel* model);
    void rebuildRoles();
    int offsetOf(const QAbstractItemModel* model) const;
    QList<int> ownRoles(const QAbstractItemModel* model, const QList<int>& sourceRoles) const;

    QPointer<QAbstractItemModel> m_first;
    QPointer<QAbstractItemModel> m_second;

    // own role -> name, and name -> role of each source
    QHash<int, QByteArray> m_roleNames;
    QHash<QByteArray, int> m_firstRoles;
    QHash<QByteArray, int> m_secondRoles;
    int m_firstRole = -1;
    int m_sourceRowRole = -1;
};

#endif // RDCONCATMODEL_HPP
