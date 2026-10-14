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

#ifndef SETTINGS_CATALOG_HPP
#define SETTINGS_CATALOG_HPP

#include <QHash>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QThreadPool>
#include <QUrl>
#include <QVariant>
#include <QVector>

#include "qt.hpp"

/**
 * redesign: what the Settings dialog knows about VLC's options beyond reading and writing them
 * (values go through RdEffects, the settings bridge shared with the settings sidebar).
 *
 * Every option of VLC and of its plugins is sorted into one of the dialog's 13 categories
 * (video 16:03-16:30: one page per category, its basic settings first, then its advanced ones),
 * from the category VLC itself files the option under. The rows the pages show by name
 * (`curated` in the .cpp) are left out of the generated lists, so no option shows twice.
 * The list is read once, on a worker thread, the first time a page asks for it.
 *
 * It also lists the plugins (video 18:28-18:47: they move to the Extensions page's advanced
 * options), and carries the few actions the pages need that no option covers: file and folder
 * pickers, the configuration folder, resetting every setting, the interface language (Windows).
 */
class SettingsCatalog : public QObject
{
    Q_OBJECT

    // the option list has been read (groups(), plugins(), matching())
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged FINAL)
    // the interface language can be chosen (Windows: VLC reads it from the registry)
    Q_PROPERTY(bool languageSupported READ languageSupported CONSTANT FINAL)

public:
    explicit SettingsCatalog(qt_intf_t* intf, QObject* parent = nullptr);
    ~SettingsCatalog() override;

    bool ready() const { return m_ready; }
    bool languageSupported() const;

    // reads the option list in the background, once
    Q_INVOKABLE void load();

    // the option exists in this build of VLC (platform and plugins differ)
    Q_INVOKABLE bool exists(const QString& name) const;
    // { name, type, text, description, min, max, default } of an option; type is one of
    // bool, integer, color, float, string, password, module, modules, file, savefile,
    // directory, font
    Q_INVOKABLE QVariantMap describe(const QString& name) const;

    // the options of a category the pages do not show by name, grouped by plugin:
    // [{ id, title, options: [name], keywords }]; with `filter`, only the options it matches
    Q_INVOKABLE QVariantList groups(const QString& category, const QString& filter = {}) const;
    // the number of options of a category `filter` matches (search counts)
    Q_INVOKABLE int matchCount(const QString& category, const QString& filter) const;

    // every plugin of VLC: [{ name, title, capability, score }], sorted by title
    Q_INVOKABLE QVariantList plugins(const QString& filter = {}) const;

    // dialogs (empty when cancelled)
    Q_INVOKABLE QString pickFile(const QString& title, const QString& current = {}, bool save = false) const;
    Q_INVOKABLE QString pickDirectory(const QString& title, const QString& current = {}) const;

    // opens VLC's configuration folder in the file manager
    Q_INVOKABLE void openConfigFolder() const;
    // every option back to its default, saved (VLC's "Reset Preferences")
    Q_INVOKABLE void resetAll();
    // forgets what was played (the library's Recent list); false without the media library
    Q_INVOKABLE bool clearHistory();

    // interface language (Windows): [{ value, text }], the current one ("auto" by default)
    Q_INVOKABLE QVariantList languages() const;
    Q_INVOKABLE QString language() const;
    Q_INVOKABLE void setLanguage(const QString& iso);

signals:
    void readyChanged();
    // after resetAll(): the pages read their values again
    void resetDone();

public:
    struct Option
    {
        QString name;
        QString text;
        QString longtext;
        QString group;      // plugin (or VLC core section) id
        QString category;
        int type = 0;
    };

    struct Group
    {
        QString id;
        QString title;
        QString category;
        QStringList options;
    };

    struct Plugin
    {
        QString name;
        QString title;
        QString capability;
        int score = 0;
    };

    struct Catalog
    {
        QHash<QString, Option> options;
        QVector<Group> groups;
        QVector<Plugin> plugins;
    };

private:
    bool matches(const Option& option, const Group& group, const QStringList& words) const;

    qt_intf_t* p_intf = nullptr;
    QThreadPool m_pool;
    bool m_loading = false;
    bool m_ready = false;
    Catalog m_catalog;
};

#endif // SETTINGS_CATALOG_HPP
