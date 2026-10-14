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

#ifndef RDSUBFOLDERMODEL_HPP
#define RDSUBFOLDERMODEL_HPP

#include "mlbasemodel.hpp"
#include "mlhelper.hpp"

#include <QSet>
#include <QTimer>

// redesign: the folders of one level of the folder-based Videos and Music categories (video
// 10:56-12:12, P5-16, P5-29, F-14). Without a parent: the library folders of the category;
// with a parent folder: its subfolders. The media of a folder come from VLC's MLVideoModel /
// MLAudioModel with the folder as parent. Rows load on demand like every MLBaseModel.
class RdSubfolderModel : public MLBaseModel
{
    Q_OBJECT

    // library folders added to this category, and to the other one; media library folders
    // added before the redesign (in neither list) show in both categories
    Q_PROPERTY(QStringList categoryMrls READ categoryMrls WRITE setCategoryMrls NOTIFY categoryMrlsChanged FINAL)
    Q_PROPERTY(QStringList otherMrls READ otherMrls WRITE setOtherMrls NOTIFY otherMrlsChanged FINAL)

public:
    enum Roles
    {
        FOLDER_ID = Qt::UserRole + 1,
        FOLDER_TITLE,
        FOLDER_MRL,
        FOLDER_COUNT,
        FOLDER_NB_VIDEOS,
        FOLDER_NB_AUDIOS
    };

    explicit RdSubfolderModel(QObject* parent = nullptr);

    QHash<int, QByteArray> roleNames() const override;

    QStringList categoryMrls() const { return m_categoryMrls; }
    void setCategoryMrls(const QStringList& mrls);

    QStringList otherMrls() const { return m_otherMrls; }
    void setOtherMrls(const QStringList& mrls);

signals:
    void categoryMrlsChanged();
    void otherMrlsChanged();

protected:
    QVariant itemRoleData(const MLItem* item, int role = Qt::DisplayRole) const override;
    vlc_ml_sorting_criteria_t nameToCriteria(QByteArray name) const override;
    std::unique_ptr<MLListCacheLoader> createMLLoader() const override;
    void onVlcMlEvent(const MLEvent& event) override;

private:
    struct Loader : public MLListCacheLoader::MLOp
    {
        Loader(const RdSubfolderModel& model);

        size_t count(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const override;
        std::vector<std::unique_ptr<MLItem>> load(vlc_medialibrary_t* ml,
                                                  const vlc_ml_query_params_t* queryParams) const override;
        std::unique_ptr<MLItem> loadItemById(vlc_medialibrary_t* ml, MLItemId itemId) const override;

    private:
        struct Folders
        {
            ml_unique_ptr<vlc_ml_folder_list_t> list;
            std::vector<ml_unique_ptr<vlc_ml_folder_t>> extra;
            std::vector<const vlc_ml_folder_t*> sorted;
        };

        // every folder of the level, filtered and sorted. VLC's media library returns all the
        // subfolders of a folder in one query (it ignores offset and limit there); only the
        // rows of the requested page become model items.
        void folders(vlc_medialibrary_t* ml, Folders& result) const;
        // the category's own folders that are not library folders (a folder inside a library
        // folder of the other category)
        void addInnerFolders(vlc_medialibrary_t* ml, Folders& result) const;

        QSet<QString> m_mine;
        QSet<QString> m_others;
    };

    QStringList m_categoryMrls;
    QStringList m_otherMrls;
    // a scan sends one event per folder found or updated: the level reloads at most this often
    QTimer m_scanResetTimer;
};

#endif // RDSUBFOLDERMODEL_HPP
