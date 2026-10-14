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

#include "rdconcatmodel.hpp"

RdConcatModel::RdConcatModel(QObject* parent)
    : QAbstractListModel(parent)
{
    rebuildRoles();
}

void RdConcatModel::setFirst(QAbstractItemModel* model)
{
    if (m_first == model)
        return;
    setSource(m_first, model);
    emit firstChanged();
}

void RdConcatModel::setSecond(QAbstractItemModel* model)
{
    if (m_second == model)
        return;
    setSource(m_second, model);
    emit secondChanged();
}

void RdConcatModel::setSource(QPointer<QAbstractItemModel>& slot, QAbstractItemModel* model)
{
    beginResetModel();
    if (slot)
        disconnect(slot, nullptr, this, nullptr);
    slot = model;
    if (model)
        connectSource(model);
    rebuildRoles();
    endResetModel();
    emit countChanged();
}

int RdConcatModel::firstCount() const
{
    return m_first ? m_first->rowCount() : 0;
}

int RdConcatModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return firstCount() + (m_second ? m_second->rowCount() : 0);
}

QVariant RdConcatModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= rowCount())
        return {};

    const int firstRows = firstCount();
    const bool fromFirst = index.row() < firstRows;
    const int sourceRow = fromFirst ? index.row() : index.row() - firstRows;

    if (role == m_firstRole)
        return fromFirst;
    if (role == m_sourceRowRole)
        return sourceRow;

    QAbstractItemModel* source = fromFirst ? m_first.data() : m_second.data();
    const QHash<QByteArray, int>& roles = fromFirst ? m_firstRoles : m_secondRoles;
    const auto sourceRole = roles.constFind(m_roleNames.value(role));
    if (!source || sourceRole == roles.cend())
        return {};
    // a paged source loads the page of this row if needed
    return source->data(source->index(sourceRow, 0), sourceRole.value());
}

QHash<int, QByteArray> RdConcatModel::roleNames() const
{
    return m_roleNames;
}

void RdConcatModel::rebuildRoles()
{
    m_roleNames.clear();
    m_firstRoles.clear();
    m_secondRoles.clear();

    QHash<QByteArray, int> own;
    int next = Qt::UserRole + 1;
    const auto addRoles = [&](const QAbstractItemModel* model, QHash<QByteArray, int>& sourceRoles) {
        if (!model)
            return;
        const QHash<int, QByteArray> names = model->roleNames();
        for (auto it = names.cbegin(); it != names.cend(); ++it)
        {
            sourceRoles.insert(it.value(), it.key());
            if (!own.contains(it.value()))
            {
                own.insert(it.value(), next);
                m_roleNames.insert(next, it.value());
                ++next;
            }
        }
    };
    addRoles(m_first, m_firstRoles);
    addRoles(m_second, m_secondRoles);

    m_firstRole = next++;
    m_roleNames.insert(m_firstRole, QByteArrayLiteral("rdFirst"));
    m_sourceRowRole = next++;
    m_roleNames.insert(m_sourceRowRole, QByteArrayLiteral("rdSourceRow"));
}

int RdConcatModel::offsetOf(const QAbstractItemModel* model) const
{
    return model == m_first ? 0 : firstCount();
}

QList<int> RdConcatModel::ownRoles(const QAbstractItemModel* model, const QList<int>& sourceRoles) const
{
    QList<int> result;
    if (sourceRoles.isEmpty())
        return result;
    const QHash<int, QByteArray> names = model->roleNames();
    for (int role : sourceRoles)
    {
        const QByteArray name = names.value(role);
        for (auto it = m_roleNames.cbegin(); it != m_roleNames.cend(); ++it)
        {
            if (it.value() == name)
            {
                result.append(it.key());
                break;
            }
        }
    }
    return result;
}

void RdConcatModel::connectSource(QAbstractItemModel* model)
{
    connect(model, &QAbstractItemModel::rowsAboutToBeInserted, this,
            [this, model](const QModelIndex& parent, int first, int last) {
        if (parent.isValid())
            return;
        const int offset = offsetOf(model);
        beginInsertRows({}, offset + first, offset + last);
    });
    connect(model, &QAbstractItemModel::rowsInserted, this, [this](const QModelIndex& parent) {
        if (parent.isValid())
            return;
        endInsertRows();
        emit countChanged();
    });

    connect(model, &QAbstractItemModel::rowsAboutToBeRemoved, this,
            [this, model](const QModelIndex& parent, int first, int last) {
        if (parent.isValid())
            return;
        const int offset = offsetOf(model);
        beginRemoveRows({}, offset + first, offset + last);
    });
    connect(model, &QAbstractItemModel::rowsRemoved, this, [this](const QModelIndex& parent) {
        if (parent.isValid())
            return;
        endRemoveRows();
        emit countChanged();
    });

    // moves and layout changes (sorting) are rare: the view reloads the visible rows
    connect(model, &QAbstractItemModel::rowsAboutToBeMoved, this, [this]() { beginResetModel(); });
    connect(model, &QAbstractItemModel::rowsMoved, this, [this]() {
        endResetModel();
        emit countChanged();
    });
    connect(model, &QAbstractItemModel::layoutAboutToBeChanged, this, [this]() { beginResetModel(); });
    connect(model, &QAbstractItemModel::layoutChanged, this, [this]() {
        endResetModel();
        emit countChanged();
    });
    connect(model, &QAbstractItemModel::modelAboutToBeReset, this, [this]() { beginResetModel(); });
    connect(model, &QAbstractItemModel::modelReset, this, [this]() {
        endResetModel();
        emit countChanged();
    });

    connect(model, &QAbstractItemModel::dataChanged, this,
            [this, model](const QModelIndex& topLeft, const QModelIndex& bottomRight, const QList<int>& roles) {
        if (!topLeft.isValid() || !bottomRight.isValid())
            return;
        const int offset = offsetOf(model);
        emit dataChanged(index(offset + topLeft.row()), index(offset + bottomRight.row()),
                         ownRoles(model, roles));
    });

    connect(model, &QObject::destroyed, this, [this]() {
        // the QPointer is already cleared
        beginResetModel();
        rebuildRoles();
        endResetModel();
        emit countChanged();
    });
}
