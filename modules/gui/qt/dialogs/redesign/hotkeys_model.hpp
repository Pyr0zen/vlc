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
#ifndef HOTKEYS_MODEL_HPP
#define HOTKEYS_MODEL_HPP

#include <QAbstractListModel>
#include <QString>
#include <QVector>

#include "maininterface/mainctx.hpp"

/**
 * redesign: VLC's hotkey configuration for the Keyboard Shortcuts dialog (video 15:57-16:03).
 *
 * The logic is the one of the preferences' KeySelectorControl
 * (dialogs/preferences/preferences_widgets.cpp): one row per "key-*" option of the main
 * module with its "global-key-*" twin, keys kept as VLC key strings separated by tabs,
 * a new key replaces the keys of its column, a key taken by another action is removed
 * from it, and save() writes the options with config_PutPsz, saves the configuration file
 * and reloads the interface preferences.
 *
 * Rows are grouped (Basic, Playback, ...) and can be filtered with searchText / searchField
 * (rows are inserted and removed, never reset, so a view keeps its delegates while filtering).
 * Row arguments of the invokable functions are rows of the filtered model.
 * The model is empty until reload() reads the configuration (the dialog does it when it opens).
 */
class HotkeysModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ getCtx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(QString searchText READ getSearchText WRITE setSearchText NOTIFY searchTextChanged FINAL)
    // 0: all fields, 1: action names, 2: hotkeys, 3: global hotkeys
    Q_PROPERTY(int searchField READ getSearchField WRITE setSearchField NOTIFY searchFieldChanged FINAL)
    Q_PROPERTY(bool dirty READ isDirty NOTIFY dirtyChanged FINAL)
    Q_PROPERTY(int count READ getCount NOTIFY countChanged FINAL)
    // group of the first visible row (its section header has no divider above)
    Q_PROPERTY(QString firstGroup READ getFirstGroup NOTIFY countChanged FINAL)

public:
    enum Roles {
        ActionRole = Qt::UserRole + 1,
        DescriptionRole,
        GroupRole,
        HotkeyRole,
        GlobalHotkeyRole,
        HotkeyIsDefaultRole,
        GlobalHotkeyIsDefaultRole,
        HasGlobalRole,
    };
    Q_ENUM(Roles)

    explicit HotkeysModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    MainCtx* getCtx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);
    QString getSearchText() const { return m_searchText; }
    void setSearchText(const QString& text);
    int getSearchField() const { return m_searchField; }
    void setSearchField(int field);
    bool isDirty() const { return m_dirty; }
    int getCount() const { return static_cast<int>(m_visible.size()); }
    QString getFirstGroup() const;

    // reads every hotkey from the configuration, dropping unsaved changes
    Q_INVOKABLE void reload();
    // writes the changed hotkeys and saves the configuration file; false if saving failed
    Q_INVOKABLE bool save();

    // VLC key string ("Ctrl+f") of a QML key event, empty for a lone modifier key
    Q_INVOKABLE QString keyFromEvent(int key, int modifiers) const;
    // VLC key string of a VLC key code (mouse wheel keys from WheelToVLCConverter)
    Q_INVOKABLE QString keyFromCode(int code) const;
    // how a VLC key string (several keys separated by tabs) is shown: "Ctrl + F, Space"
    Q_INVOKABLE QString displayKeys(const QString& keys) const;

    // action that already uses one of these keys in the same column, empty if none
    Q_INVOKABLE QString conflictingAction(int row, bool global, const QString& keys) const;
    Q_INVOKABLE QString defaultKeys(int row, bool global) const;
    // sets the keys of a row, removing them from any other action of the same column
    Q_INVOKABLE void assign(int row, bool global, const QString& keys);
    Q_INVOKABLE void clear(int row, bool global);
    Q_INVOKABLE void resetAll();

signals:
    void ctxChanged();
    void searchTextChanged();
    void searchFieldChanged();
    void dirtyChanged();
    void countChanged();

private:
    struct Entry
    {
        QString configName;
        QString globalConfigName;   // empty when the action has no global hotkey
        QString action;
        QString description;
        int group = 0;
        int order = 0;
        QString keys;
        QString globalKeys;
        QString defaultKeys;
        QString defaultGlobalKeys;
        QString savedKeys;
        QString savedGlobalKeys;
    };

    Entry* entryAt(int row);
    const Entry* entryAt(int row) const;
    QString& keysOf(Entry& entry, bool global) const;
    const QString& keysOf(const Entry& entry, bool global) const;
    bool matches(const Entry& entry) const;
    void updateFilter();
    void updateDirty();
    void notifyAllRowsChanged();

    MainCtx* m_ctx = nullptr;
    QVector<Entry> m_entries;
    QVector<int> m_visible;     // indexes in m_entries of the filtered rows
    QString m_searchText;
    int m_searchField = 0;
    bool m_dirty = false;
};

#endif // HOTKEYS_MODEL_HPP
