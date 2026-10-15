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
#ifndef RD_WAVEFORM_ITEM_HPP
#define RD_WAVEFORM_ITEM_HPP

#include <QColor>
#include <QImage>
#include <QPointer>
#include <QQuickItem>

#include "player/rd_waveform.hpp"

/**
 * redesign: the bars of the waveform seek bar (P6-06, IB-24; Figma Controls "Property
 * 1=waveform", "Frame 21"): a row of thin rounded bars as tall as the audio is loud, the
 * played ones left of the playhead in `playedColor`, the others in `unplayedColor`, and a
 * `playheadGap` free around the playhead (the seek bar draws the trough and the playhead).
 *
 * Drawing: the bars are painted once into one texture, a played row and an unplayed row, and
 * shown by two image nodes cut at the playhead. Playback and dragging only move the two cuts,
 * and only when the playhead crosses a bar, so a moving playhead costs no painting and no
 * upload. The texture is painted again only when the size, the screen scale, the colors (live
 * accent and theme) or the levels change. Bars sit on whole device pixels at every scale.
 *
 * `source` is the RdWaveform singleton; while `active`, the item holds it (acquire()), which
 * starts the scan of the playing file. `ready`: the bars are shown.
 */
class RdWaveformItem : public QQuickItem
{
    Q_OBJECT

    Q_PROPERTY(RdWaveform* source READ source WRITE setSource NOTIFY sourceChanged FINAL)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged FINAL)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged FINAL)

    // the playhead's center and width in item coordinates, and the space kept free beside it
    Q_PROPERTY(qreal playheadX MEMBER m_playheadX NOTIFY playheadChanged FINAL)
    Q_PROPERTY(qreal playheadWidth MEMBER m_playheadWidth NOTIFY playheadChanged FINAL)
    Q_PROPERTY(qreal playheadGap MEMBER m_playheadGap NOTIFY playheadChanged FINAL)

    Q_PROPERTY(QColor playedColor MEMBER m_playedColor NOTIFY lookChanged FINAL)
    Q_PROPERTY(QColor unplayedColor MEMBER m_unplayedColor NOTIFY lookChanged FINAL)

    // bar geometry: width, space between bars, shortest and tallest bar, the height step
    // between bar sizes, and the space kept free at both ends of the row
    Q_PROPERTY(qreal barWidth MEMBER m_barWidth NOTIFY lookChanged FINAL)
    Q_PROPERTY(qreal barSpacing MEMBER m_barSpacing NOTIFY lookChanged FINAL)
    Q_PROPERTY(qreal barMinHeight MEMBER m_barMinHeight NOTIFY lookChanged FINAL)
    Q_PROPERTY(qreal barMaxHeight MEMBER m_barMaxHeight NOTIFY lookChanged FINAL)
    Q_PROPERTY(qreal barStep MEMBER m_barStep NOTIFY lookChanged FINAL)
    Q_PROPERTY(qreal horizontalPadding MEMBER m_horizontalPadding NOTIFY lookChanged FINAL)

public:
    explicit RdWaveformItem(QQuickItem* parent = nullptr);
    ~RdWaveformItem() override;

    RdWaveform* source() const { return m_source; }
    void setSource(RdWaveform* source);
    bool active() const { return m_active; }
    void setActive(bool active);
    bool ready() const { return m_ready; }

signals:
    void sourceChanged();
    void activeChanged();
    void readyChanged();
    void playheadChanged();
    void lookChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
    void updatePolish() override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;

private:
    void hold(bool held);
    void updateReady();
    void invalidateImage();
    void paintImage();
    void updateCuts();

    QPointer<RdWaveform> m_source;
    bool m_active = false;
    bool m_held = false;
    bool m_ready = false;

    qreal m_playheadX = -1;
    qreal m_playheadWidth = 0;
    qreal m_playheadGap = 0;
    QColor m_playedColor;
    QColor m_unplayedColor;
    qreal m_barWidth = 2;
    qreal m_barSpacing = 3;
    qreal m_barMinHeight = 2;
    qreal m_barMaxHeight = 14;
    qreal m_barStep = 2;
    qreal m_horizontalPadding = 6;

    // the painted bars (GUI thread, made in updatePolish): the played row on top, the unplayed
    // row below, `m_rowHeight` device pixels each; `m_imageSerial` counts the paintings
    QImage m_image;
    int m_imageSerial = 0;
    bool m_imageDirty = true;
    qreal m_dpr = 1;
    int m_rowHeight = 0;
    // the bar row in device pixels: first bar's left edge, distance between bars, bar width
    int m_firstBarX = 0;
    int m_barPitch = 1;
    int m_barPixels = 1;
    int m_barCount = 0;

    // the cuts in device pixels: the played bars end at `m_playedEnd`, the unplayed bars
    // start at `m_unplayedStart`
    int m_playedEnd = 0;
    int m_unplayedStart = 0;
};

#endif // RD_WAVEFORM_ITEM_HPP
