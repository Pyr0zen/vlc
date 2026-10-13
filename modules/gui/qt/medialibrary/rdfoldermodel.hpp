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

#ifndef RDFOLDERMODEL_HPP
#define RDFOLDERMODEL_HPP

#include "rdlibrarymodel.hpp"

// redesign: one level of the folder-based Videos and Music categories (video 10:56-12:12,
// P5-16, P5-29, F-14): without a folder, the library folders of the category; with a folder,
// its subfolders followed by its media of the category (videos or songs).
class RdFolderModel : public RdLibraryModel
{
    Q_OBJECT

    Q_PROPERTY(MLItemId folderId READ folderId WRITE setFolderId NOTIFY folderIdChanged FINAL)
    // "video" or "music": which media a folder lists
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY categoryChanged FINAL)
    // library folders added to this category, and to the other one; media library folders added
    // before the redesign (in neither list) show in both categories
    Q_PROPERTY(QStringList categoryMrls READ categoryMrls WRITE setCategoryMrls NOTIFY categoryMrlsChanged FINAL)
    Q_PROPERTY(QStringList otherMrls READ otherMrls WRITE setOtherMrls NOTIFY otherMrlsChanged FINAL)

public:
    explicit RdFolderModel(QObject* parent = nullptr);

    MLItemId folderId() const { return m_folderId; }
    void setFolderId(const MLItemId& id);

    QString category() const { return m_category; }
    void setCategory(const QString& category);

    QStringList categoryMrls() const { return m_categoryMrls; }
    void setCategoryMrls(const QStringList& mrls);

    QStringList otherMrls() const { return m_otherMrls; }
    void setOtherMrls(const QStringList& mrls);

signals:
    void folderIdChanged();
    void categoryChanged();
    void categoryMrlsChanged();
    void otherMrlsChanged();

protected:
    Loader createLoader() const override;
    bool canLoad() const override { return !m_category.isEmpty(); }

private:
    MLItemId m_folderId;
    QString m_category;
    QStringList m_categoryMrls;
    QStringList m_otherMrls;
};

#endif // RDFOLDERMODEL_HPP
