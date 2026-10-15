/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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

#include "medialib.hpp"
#include "mlhelper.hpp"
#include "playlist/playlist_controller.hpp"
#include "util/shared_input_item.hpp"

#include <utility>
#include <vector>

#include <QQmlEngine>
#include <QRegularExpression>
#include <QUrl>

namespace {

// redesign (S2-04): the patterns of "qt-history-filter", separated by ';' (or '|', as VLC 3's
// filter): with * or ? a wildcard for a whole path, file name or title, else a piece of text
// found in one of them; case-insensitive, '\' and '/' alike
std::vector<QRegularExpression> historyPatterns(const QString& patterns)
{
    std::vector<QRegularExpression> result;
    const QStringList parts = patterns.split(QRegularExpression(QStringLiteral("[;|\\n]")),
                                             Qt::SkipEmptyParts);
    for (QString part : parts)
    {
        part = part.trimmed();
        if (part.isEmpty())
            continue;
        part.replace(QLatin1Char('\\'), QLatin1Char('/'));

        const bool wildcard = part.contains(QLatin1Char('*')) || part.contains(QLatin1Char('?'));
        QString expression;
        for (const QChar c : std::as_const(part))
        {
            if (c == QLatin1Char('*'))
                expression += QLatin1String(".*");
            else if (c == QLatin1Char('?'))
                expression += QLatin1Char('.');
            else
                expression += QRegularExpression::escape(QString(c));
        }
        if (wildcard)
            expression = QLatin1Char('^') + expression + QLatin1Char('$');
        result.emplace_back(expression, QRegularExpression::CaseInsensitiveOption);
    }
    return result;
}

bool matchesHistoryPattern(const std::vector<QRegularExpression>& patterns, const vlc_ml_media_t& media)
{
    QStringList texts;
    if (media.psz_title)
        texts << qfu(media.psz_title);
    if (media.psz_filename)
        texts << qfu(media.psz_filename);
    if (media.p_files)
    {
        for (const vlc_ml_file_t& file : ml_range_iterate<vlc_ml_file_t>(media.p_files))
        {
            if (file.i_type != VLC_ML_FILE_TYPE_MAIN || !file.psz_mrl)
                continue;
            const QUrl url = QUrl::fromEncoded(file.psz_mrl);
            texts << (url.isLocalFile() ? url.toLocalFile() : url.toString(QUrl::RemovePassword));
        }
    }
    for (QString& text : texts)
        text.replace(QLatin1Char('\\'), QLatin1Char('/'));

    for (const QRegularExpression& pattern : patterns)
    {
        for (const QString& text : std::as_const(texts))
        {
            if (pattern.match(text).hasMatch())
                return true;
        }
    }
    return false;
}

} // namespace

MediaLib::MediaLib(qt_intf_t *_intf, vlc::playlist::PlaylistController* playlistController, QObject *_parent)
    : QObject( _parent )
    , m_intf( _intf )
    , m_playlistController(playlistController)
    , m_ml( vlc_ml_instance_get( _intf ) )
    , m_event_cb( nullptr, [this](vlc_ml_event_callback_t* cb ) {
        vlc_ml_event_unregister_callback( m_ml, cb );
      })
{
    m_event_cb.reset( vlc_ml_event_register_callback( m_ml, MediaLib::onMediaLibraryEvent,
                                                      this ) );
    m_runner = new ThreadRunner();
}

MediaLib::~MediaLib()
{
    m_runner->destroy();
}

static void convertMLItemToPlaylistMedias(vlc_medialibrary_t* ml, const MLItemId & itemId, const QStringList &options, QVector<vlc::playlist::Media>& medias)
{
    //invalid item
    if (itemId.id == 0)
        return;

    if (itemId.type == VLC_ML_PARENT_UNKNOWN)
    {
        SharedInputItem item( vlc_ml_get_input_item( ml, itemId.id ), false );
        if (item)
            medias.push_back(vlc::playlist::Media(item.get(), options));
    }
    else
    {
        vlc_ml_query_params_t query = vlc_ml_query_params_create();
        ml_unique_ptr<vlc_ml_media_list_t> media_list(vlc_ml_list_media_of( ml, &query, itemId.type, itemId.id));
        if (media_list == nullptr || media_list->i_nb_items == 0)
            return;

        auto mediaRange = ml_range_iterate<vlc_ml_media_t>( media_list );
        std::transform(mediaRange.begin(), mediaRange.end(), std::back_inserter(medias), [&](vlc_ml_media_t& m) {
            SharedInputItem item(vlc_ml_get_input_item( ml, m.i_id ), false);
            return vlc::playlist::Media(item.get(), options);
        });
    }
}

static void convertQUrlToPlaylistMedias(QUrl mrl, const QStringList& options, QVector<vlc::playlist::Media>& medias)
{
    vlc::playlist::Media media{ mrl.toString(QUrl::FullyEncoded), mrl.fileName(), options };
    medias.push_back(media);
}

static void convertQStringToPlaylistMedias(const QString &mrl, const QStringList& options, QVector<vlc::playlist::Media>& medias)
{
    vlc::playlist::Media media{ mrl, mrl, options };
    medias.push_back(media);
}


static void convertQVariantListToPlaylistMedias(vlc_medialibrary_t* ml, QVariantList itemIdList, const QStringList& options, QVector<vlc::playlist::Media>& medias)
{
    for (const QVariant& varValue: itemIdList)
    {
        if (varValue.canConvert<QUrl>())
        {
            auto mrl = varValue.value<QUrl>();
            convertQUrlToPlaylistMedias(mrl, options, medias);
        }
        else if (varValue.canConvert<QString>())
        {
            auto mrl = varValue.value<QString>();
            convertQStringToPlaylistMedias(mrl, options, medias);
        }
        else if (varValue.canConvert<MLItemId>())
        {
            MLItemId itemId = varValue.value<MLItemId>();
            convertMLItemToPlaylistMedias(ml, itemId, options, medias);
        }
        // else ignore
    }
}

MLItemId MediaLib::deserializeMlItemIdFromString(const QString& serialized_id) {
    return MLItemId::fromString(serialized_id);
}

void MediaLib::addToPlaylist(const QString& mrl, const QStringList &options)
{
    QVector<vlc::playlist::Media> medias;
    convertQStringToPlaylistMedias(mrl, options, medias);
    m_playlistController->append(medias, false);
}

void MediaLib::addToPlaylist(const QUrl& mrl, const QStringList &options)
{
    QVector<vlc::playlist::Media> medias;
    convertQUrlToPlaylistMedias(mrl, options, medias);
    m_playlistController->append(medias, false);
}

// A specific item has been asked to be added to the playlist
void MediaLib::addToPlaylist(const MLItemId & itemId, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemId, options]
    (vlc_medialibrary_t* ml, Context& ctx){
        convertMLItemToPlaylistMedias(ml, itemId, options, ctx.medias);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
            m_playlistController->append(ctx.medias, false);
    });
}

void MediaLib::addToPlaylist(const QVariantList& itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
            m_playlistController->append(ctx.medias, false);
    });
}

// A specific item has been asked to be played,
// so it's added to the playlist and played
void MediaLib::addAndPlay(const MLItemId & itemId, const QStringList &options )
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemId, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertMLItemToPlaylistMedias(ml, itemId, options, ctx.medias);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
            m_playlistController->append(ctx.medias, true);
    });


}

void MediaLib::addAndPlay(const QString& mrl, const QStringList &options)
{
    vlc::playlist::Media media{ mrl, mrl, options };
    m_playlistController->append( QVector<vlc::playlist::Media>{media}, true );
}

void MediaLib::addAndPlay(const QUrl& mrl, const QStringList &options)
{
    vlc::playlist::Media media{ mrl.toString(QUrl::FullyEncoded), mrl.fileName(), options };
    m_playlistController->append( QVector<vlc::playlist::Media>{media}, true );
}


void MediaLib::addAndPlay(const QVariantList& itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
            m_playlistController->append(ctx.medias, true);
    });
}

void MediaLib::insertIntoPlaylist(const size_t index, const QVariantList &itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx )
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias);
    },
    //UI thread
    [this, index]
    (quint64, Context& ctx) {
        if (!ctx.medias.isEmpty())
            m_playlistController->insert( index, ctx.medias );
    });
}

void MediaLib::reload()
{
    runOnMLThread(this,
    //ML thread
    [](vlc_medialibrary_t* ml){
        vlc_ml_reload_folder(ml, nullptr);
    });
}

void MediaLib::mlInputItem(const QVector<MLItemId>& itemIdVector, QJSValue callback)
{
    if (!callback.isCallable()) // invalid argument
    {
        msg_Warn(m_intf, "callback is not callbable");
        return;
    }

    struct Ctx {
        std::vector<SharedInputItem> items;
    };

    if (itemIdVector.empty())
    {
        //call the callback with and empty list
        auto jsEngine = qjsEngine(this);
        if (!jsEngine)
            return;
        auto jsArray = jsEngine->newArray(0);
        callback.call({jsArray});
        return;
    }

    auto it = m_inputItemQuery.find(itemIdVector);

    if (it == m_inputItemQuery.end())
    {
        it = m_inputItemQuery.insert(itemIdVector, {callback});
    }
    else
    {
        // be patient

        for (const auto& it2 : it.value())
        {
            if (callback.strictlyEquals(it2))
                return;
        }

        it.value().push_back(callback); // FIXME: Use an ordered set
        return;
    }

    runOnMLThread<Ctx>(this,
    //ML thread
    [itemIdVector](vlc_medialibrary_t* ml, Ctx& ctx){
        for (auto mlId : itemIdVector)
        {
            // NOTE: When we have a parent it's a collection of media(s).
            if (mlId.type == VLC_ML_PARENT_UNKNOWN)
            {
                ctx.items.emplace_back(vlc_ml_get_input_item(ml, mlId.id), false);
            }
            else
            {
                ml_unique_ptr<vlc_ml_media_list_t> list;

                vlc_ml_query_params_t query = vlc_ml_query_params_create();

                list.reset(vlc_ml_list_media_of(ml, &query, mlId.type, mlId.id));

                if (list == nullptr)
                    continue;

                for (const vlc_ml_media_t & media : ml_range_iterate<vlc_ml_media_t>(list))
                    ctx.items.emplace_back(vlc_ml_get_input_item(ml, media.i_id), false);
            }
        }
    },
    //UI thread
    [this, it](quint64, Ctx& ctx) mutable
    {
        auto jsEngine = qjsEngine(this);
        if (!jsEngine)
            return;

        auto jsArray = jsEngine->newArray(ctx.items.size());

        int i  = 0;
        for (const auto& inputItem : ctx.items)
        {
            jsArray.setProperty(i, jsEngine->toScriptValue(inputItem));
            i++;
        }

        for (const auto& cb : std::as_const(it.value()))
        {
            cb.call({jsArray});
        }

        m_inputItemQuery.erase(it);
    });
}

void MediaLib::filterHistory(const QString& patterns, bool all)
{
    std::vector<QRegularExpression> expressions = historyPatterns(patterns);
    if (expressions.empty())
        return;
    // a history change adds at the top: its newest entries are enough then (0: all)
    const uint32_t count = all ? 0 : 20;
    const std::function<void(vlc_medialibrary_t*)> filter =
        [expressions = std::move(expressions), count](vlc_medialibrary_t* ml)
    {
        vlc_ml_query_params_t params = vlc_ml_query_params_create();
        params.i_nbResults = count;
        ml_unique_ptr<vlc_ml_media_list_t> list{ vlc_ml_list_history( ml, &params, VLC_ML_HISTORY_TYPE_GLOBAL ) };
        if (!list)
            return;
        // VLC_ML_MEDIA_SET_PLAYED false: removeFromHistory(), which also forgets the position;
        // the history change it sends finds nothing more to remove
        for (const vlc_ml_media_t& media : ml_range_iterate<vlc_ml_media_t>(list))
        {
            if (matchesHistoryPattern(expressions, media))
                vlc_ml_media_set_played(ml, media.i_id, false);
        }
    };
    runOnMLThread(this, filter, static_cast<const char*>("MLHistoryFilter"));
}

vlc_ml_event_callback_t* MediaLib::registerEventListener( void (*callback)(void*, const vlc_ml_event_t*), void* data)
{
    return vlc_ml_event_register_callback( m_ml , callback , data ) ;
}

void MediaLib::unregisterEventListener(vlc_ml_event_callback_t* cb)
{
    vlc_ml_event_unregister_callback( m_ml , cb );
}

void MediaLib::onMediaLibraryEvent( void* data, const vlc_ml_event_t* event )
{
    MediaLib* self = static_cast<MediaLib*>( data );
    switch ( event->i_type )
    {
        case VLC_ML_EVENT_PARSING_PROGRESS_UPDATED:
        {
            int percent =  event->parsing_progress.i_percent;
            QMetaObject::invokeMethod(self, [self, percent]() {
                self->m_parsingProgress = percent;
                self->emit parsingProgressChanged(percent);
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_STARTED:
        {
            QMetaObject::invokeMethod(self, [self]() {
                self->m_discoveryPending = true;
                self->emit discoveryPendingChanged(self->m_discoveryPending);
                self->emit discoveryStarted();
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_PROGRESS:
        {
            const QUrl entryPoint{ event->discovery_progress.psz_entry_point };
            const QString entryPointStr = entryPoint.isLocalFile()
                                              ? entryPoint.toLocalFile()
                                              : entryPoint.toDisplayString();

            QMetaObject::invokeMethod(self, [self, entryPointStr]() {
                self->m_discoveryEntryPoint = entryPointStr;
                self->emit discoveryEntryPointChanged(entryPointStr);
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_COMPLETED:
        {
            QMetaObject::invokeMethod(self, [self]() {
                self->m_discoveryPending = false;
                self->emit discoveryPendingChanged(self->m_discoveryPending);
                self->emit discoveryCompleted();
            });
            break;
        }
        case VLC_ML_EVENT_HISTORY_CHANGED:
        {
            // redesign (S2-04): forget at once what "Never remember items matching" names
            QMetaObject::invokeMethod(self, [self]() {
                char* patterns = var_InheritString(self->m_intf, "qt-history-filter");
                const QString text = qfu(patterns);
                free(patterns);
                if (!text.trimmed().isEmpty())
                    self->filterHistory(text, false);
            });
            break;
        }
        case VLC_ML_EVENT_BACKGROUND_IDLE_CHANGED:
        {
            bool idle = event->background_idle_changed.b_idle;
            QMetaObject::invokeMethod(self, [self, idle]() {
                self->m_idle = idle;
                self->emit idleChanged();
            });
            break;
        }
        default:
            break;
    }
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                std::function< void()> uiCb,
                const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [uiCb](quint64, NoCtx&){
        uiCb();
    },
    queue);
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                std::function< void(quint64)> uiCb, const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [uiCb](quint64 requestId, NoCtx&){
        uiCb(requestId);
    },
    queue);
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [](quint64, NoCtx&){
    },
    queue);
}

void MediaLib::cancelMLTask(const QObject* object, quint64 taskId)
{
    m_runner->cancelTask(object, taskId);
}

