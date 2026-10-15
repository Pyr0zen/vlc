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

#include "rd_waveform_item.hpp"

#include <QHash>
#include <QPainter>
#include <QQuickWindow>
#include <QSGImageNode>
#include <QSGTexture>
#include <QtMath>

#include <algorithm>
#include <memory>
#include <vector>

namespace {

// the texture and the two cut views of it (the played row, the unplayed row)
class WaveformNode : public QSGNode
{
public:
    explicit WaveformNode(QQuickWindow* window)
        : played(window->createImageNode())
        , unplayed(window->createImageNode())
    {
        for (QSGImageNode* node : { played, unplayed })
        {
            node->setFiltering(QSGTexture::Linear);
            node->setOwnsTexture(false);
            appendChildNode(node);
        }
    }

    void setTexture(QSGTexture* newTexture)
    {
        played->setTexture(newTexture);
        unplayed->setTexture(newTexture);
        texture.reset(newTexture);
    }

    // children: deleted by QSGNode, after the texture they no longer draw
    QSGImageNode* played;
    QSGImageNode* unplayed;
    std::unique_ptr<QSGTexture> texture;
    int serial = -1;
};

// a rounded bar, `width` x `height` device pixels, ends fully round (Figma radius 4 on 2 px)
QImage barSprite(int width, int height, const QColor& color)
{
    QImage sprite(width, height, QImage::Format_ARGB32_Premultiplied);
    sprite.fill(Qt::transparent);
    QPainter painter(&sprite);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setPen(Qt::NoPen);
    painter.setBrush(color);
    const qreal radius = width / 2.0;
    painter.drawRoundedRect(QRectF(0, 0, width, height), radius, radius);
    return sprite;
}

} // namespace

RdWaveformItem::RdWaveformItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
    connect(this, &RdWaveformItem::playheadChanged, this, &RdWaveformItem::updateCuts);
    connect(this, &RdWaveformItem::lookChanged, this, &RdWaveformItem::invalidateImage);
}

RdWaveformItem::~RdWaveformItem()
{
    hold(false);
}

void RdWaveformItem::setSource(RdWaveform* source)
{
    if (source == m_source)
        return;
    hold(false);
    if (m_source)
        disconnect(m_source, nullptr, this, nullptr);
    m_source = source;
    if (m_source)
        connect(m_source, &RdWaveform::levelsChanged, this, [this]() {
            updateReady();
            invalidateImage();
        });
    hold(m_active && m_source);
    updateReady();
    invalidateImage();
    emit sourceChanged();
}

void RdWaveformItem::setActive(bool active)
{
    if (active == m_active)
        return;
    m_active = active;
    hold(m_active && m_source);
    updateReady();
    emit activeChanged();
}

void RdWaveformItem::hold(bool held)
{
    if (held == m_held)
        return;
    m_held = held;
    if (!m_source)
        return;
    if (held)
        m_source->acquire();
    else
        m_source->release();
}

void RdWaveformItem::updateReady()
{
    const bool ready = m_held && m_source && m_source->ready();
    if (ready == m_ready)
        return;
    m_ready = ready;
    invalidateImage();
    emit readyChanged();
}

void RdWaveformItem::invalidateImage()
{
    m_imageDirty = true;
    polish();
}

void RdWaveformItem::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
        invalidateImage();
}

void RdWaveformItem::itemChange(ItemChange change, const ItemChangeData& value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemDevicePixelRatioHasChanged || (change == ItemSceneChange && value.window))
        invalidateImage();
}

void RdWaveformItem::updatePolish()
{
    if (!m_imageDirty)
        return;
    m_imageDirty = false;
    paintImage();
    updateCuts();
    update();
}

void RdWaveformItem::paintImage()
{
    ++m_imageSerial;
    m_image = QImage();
    m_barCount = 0;

    const QByteArray levels = m_source ? m_source->levels() : QByteArray();
    if (!m_ready || levels.isEmpty() || !window() || width() <= 0 || height() <= 0)
        return;

    // the row on whole device pixels: even bars and gaps at 125 % and 150 % too
    m_dpr = window()->effectiveDevicePixelRatio();
    const int imageWidth = qCeil(width() * m_dpr);
    m_rowHeight = qMax(1, qRound(height() * m_dpr));
    m_barPixels = qMax(1, qRound(m_barWidth * m_dpr));
    m_barPitch = qMax(m_barPixels + 1, qRound((m_barWidth + m_barSpacing) * m_dpr));
    const int padding = qMax(0, qRound(m_horizontalPadding * m_dpr));
    const int room = imageWidth - 2 * padding;
    m_barCount = room >= m_barPixels ? (room - m_barPixels) / m_barPitch + 1 : 0;
    if (m_barCount <= 0)
    {
        m_barCount = 0;
        return;
    }
    // Figma: the first bar `horizontalPadding` from the left end (the right end keeps at least
    // as much)
    m_firstBarX = padding;

    // each bar: the mean loudness of the slices it covers, the loudest bar reaching the top
    const qsizetype slices = levels.size();
    std::vector<double> loudness(static_cast<size_t>(m_barCount));
    double loudest = 0;
    for (int i = 0; i < m_barCount; ++i)
    {
        const qsizetype from = i * slices / m_barCount;
        const qsizetype to = qMax(from + 1, (i + 1) * slices / m_barCount);
        double sum = 0;
        for (qsizetype s = from; s < to; ++s)
            sum += static_cast<uchar>(levels[s]);
        loudness[static_cast<size_t>(i)] = sum / static_cast<double>(to - from);
        loudest = std::max(loudest, loudness[static_cast<size_t>(i)]);
    }

    // Figma: heights from the shortest to the tallest bar in fixed steps (2 to 14 by 2)
    const int steps = m_barStep > 0 ? qMax(0, qRound((m_barMaxHeight - m_barMinHeight) / m_barStep)) : 0;

    m_image = QImage(imageWidth, 2 * m_rowHeight, QImage::Format_ARGB32_Premultiplied);
    m_image.fill(Qt::transparent);
    QPainter painter(&m_image);

    // one sprite per bar height and row
    QHash<int, QImage> playedSprites;
    QHash<int, QImage> unplayedSprites;
    for (int i = 0; i < m_barCount; ++i)
    {
        const double ratio = loudest > 0 ? loudness[static_cast<size_t>(i)] / loudest : 0;
        const qreal barHeight = std::min(m_barMaxHeight, m_barMinHeight + qRound(ratio * steps) * m_barStep);
        int pixels = qBound(1, qRound(barHeight * m_dpr), m_rowHeight);
        // centered on a whole pixel: the same parity as the row
        if ((m_rowHeight - pixels) % 2 != 0)
            pixels = pixels < m_rowHeight ? pixels + 1 : pixels - 1;
        if (pixels <= 0)
            continue;

        auto played = playedSprites.find(pixels);
        if (played == playedSprites.end())
            played = playedSprites.insert(pixels, barSprite(m_barPixels, pixels, m_playedColor));
        auto unplayed = unplayedSprites.find(pixels);
        if (unplayed == unplayedSprites.end())
            unplayed = unplayedSprites.insert(pixels, barSprite(m_barPixels, pixels, m_unplayedColor));

        const int x = m_firstBarX + i * m_barPitch;
        const int y = (m_rowHeight - pixels) / 2;
        painter.drawImage(QPoint(x, y), *played);
        painter.drawImage(QPoint(x, m_rowHeight + y), *unplayed);
    }
}

void RdWaveformItem::updateCuts()
{
    int playedEnd = 0;
    int unplayedStart = 0;
    if (m_barCount > 0)
    {
        // the bars wholly left of the free space around the playhead are played, the bars
        // wholly right of it are not; a bar under it is not drawn
        const qreal reach = m_playheadWidth / 2 + m_playheadGap;
        const qreal left = (m_playheadX - reach) * m_dpr;
        const qreal right = (m_playheadX + reach) * m_dpr;

        const int lastPlayed = qBound(-1, qFloor((left - m_firstBarX - m_barPixels) / m_barPitch),
                                      m_barCount - 1);
        const int firstUnplayed = qBound(lastPlayed + 1, qCeil((right - m_firstBarX) / m_barPitch),
                                         m_barCount);
        playedEnd = lastPlayed >= 0 ? m_firstBarX + lastPlayed * m_barPitch + m_barPixels : 0;
        unplayedStart = firstUnplayed < m_barCount ? m_firstBarX + firstUnplayed * m_barPitch
                                                   : m_image.width();
    }
    if (playedEnd == m_playedEnd && unplayedStart == m_unplayedStart)
        return;
    m_playedEnd = playedEnd;
    m_unplayedStart = unplayedStart;
    update();
}

QSGNode* RdWaveformItem::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    if (!m_ready || m_image.isNull() || m_barCount == 0)
    {
        delete oldNode;
        return nullptr;
    }

    auto* node = static_cast<WaveformNode*>(oldNode);
    if (!node)
        node = new WaveformNode(window());
    if (node->serial != m_imageSerial)
    {
        node->setTexture(window()->createTextureFromImage(m_image, QQuickWindow::TextureHasAlphaChannel));
        node->serial = m_imageSerial;
    }

    const qreal rowHeight = m_rowHeight;
    const qreal imageWidth = m_image.width();
    node->played->setSourceRect(QRectF(0, 0, m_playedEnd, rowHeight));
    node->played->setRect(QRectF(0, 0, m_playedEnd / m_dpr, rowHeight / m_dpr));
    node->unplayed->setSourceRect(QRectF(m_unplayedStart, rowHeight, imageWidth - m_unplayedStart, rowHeight));
    node->unplayed->setRect(QRectF(m_unplayedStart / m_dpr, 0, (imageWidth - m_unplayedStart) / m_dpr,
                                   rowHeight / m_dpr));
    return node;
}
