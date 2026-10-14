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

// redesign: the library address line (video 10:22-10:27, IA-45, P5-08, F-14; Figma sidebar
// "Frame 323": gap 6, Inter 400 16 FG/A2, separator "▶" 8 px FG/A4). Earlier parts are gray,
// the last one brighter; clicking an earlier part goes up at once. When the line does not
// fit, the first parts fold into "..." (11:40), which goes to the folded part just above.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

Item {
    id: root

    property var crumbs: []
    // the full library shows the last part in semibold (IA-45); the compact one does not
    property bool boldLast: false

    signal crumbClicked(int index)

    implicitHeight: VLCStyle.dp(24)
    clip: true

    // how many parts are folded into "...": as few as fit
    readonly property int _folded: {
        const count = crumbs.length
        if (count <= 1)
            return 0
        for (let folded = 0; folded < count - 1; ++folded) {
            let w = folded > 0 ? normalMetrics.advanceWidth("...") + _separatorWidth : 0
            for (let i = folded; i < count; ++i) {
                const metrics = (i === count - 1) ? lastMetrics : normalMetrics
                w += metrics.advanceWidth(crumbs[i].title) + (i > folded ? _separatorWidth : 0)
            }
            if (w <= width)
                return folded
        }
        return count - 1
    }
    readonly property real _separatorWidth: VLCStyle.dp(8) + 2 * row.spacing

    FontMetrics {
        id: normalMetrics

        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_header
    }

    FontMetrics {
        id: lastMetrics

        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_header
        font.weight: root.boldLast ? Font.DemiBold : Font.Normal
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: VLCStyle.dp(6)

        Crumb {
            visible: root._folded > 0
            text: "..."
            onClicked: root.crumbClicked(root._folded - 1)
        }

        Separator {
            visible: root._folded > 0
        }

        Repeater {
            model: root.crumbs.length - root._folded

            delegate: Row {
                required property int index

                readonly property int crumbIndex: index + root._folded
                readonly property bool isLast: crumbIndex === root.crumbs.length - 1

                spacing: row.spacing

                Separator {
                    visible: index > 0
                }

                Crumb {
                    // the crumbs may shrink before the repeater drops this one
                    text: root.crumbs[crumbIndex]?.title ?? ""
                    last: isLast
                    bold: root.boldLast
                    width: isLast ? Math.min(implicitWidth, Math.max(0, root.width - parent.x)) : implicitWidth
                    onClicked: {
                        if (!isLast)
                            root.crumbClicked(crumbIndex)
                    }
                }
            }
        }
    }

    // Figma: an 8 px wide box, the glyph centred
    component Separator: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: VLCStyle.dp(8)
        horizontalAlignment: Text.AlignHCenter
        text: "▶"
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.dp(8)
        color: VLCStyle.palette.rdFgA4
    }

    component Crumb: T.AbstractButton {
        id: crumb

        property bool last: false
        property bool bold: false

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight
        hoverEnabled: true
        focusPolicy: last ? Qt.NoFocus : Qt.TabFocus

        Keys.onReturnPressed: crumb.clicked()
        Keys.onEnterPressed: crumb.clicked()

        Accessible.role: Accessible.Link
        Accessible.name: text

        contentItem: Text {
            id: label

            text: crumb.text
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
            font.weight: crumb.last && crumb.bold ? Font.DemiBold : Font.Normal
            // Figma: the bold last crumb (full library) is FG/A1
            color: crumb.last ? (crumb.bold ? VLCStyle.palette.rdFgA1 : VLCStyle.palette.rdFgA2)
                 : (crumb.hovered || crumb.visualFocus) ? VLCStyle.palette.rdFg2
                 : VLCStyle.palette.rdFgA2
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: crumb.last ? Qt.ArrowCursor : Qt.PointingHandCursor
        }
    }
}
