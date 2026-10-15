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

// redesign: an info panel over the video, opened by a settings sidebar toggle: "Show
// Metadata" (file information, Decision 24) and "Show Statistics" (Figma "playback" 5187:24492,
// Decision 13). The design has no frame for them, so they use the sidebar's parts (Decision
// 21): opaque BG/B1 card, radius 10, a 50 px BG/B2 header with a 20 px two-tone icon and the
// title, a close button like the dialogs' (32 px, hover tint), section headers like the
// sidebar's (Inter 500 16 FG/A1, 1 px Divider/Dim between sections) and label / value rows in
// Inter 14 (FG/A3 / FG/A2). The body scrolls when the panel is taller than the room it has.
//   sections: [ { title, rows: [ { label, value } or { label, key } ] } ]; a row with a key
//   shows values[key] (the statistics: the rows stay, only their texts change)
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Widgets.RdPanel {
    id: root

    property string title: ""
    property string iconName: ""
    property var sections: []
    property var values: ({})
    // shown instead of the sections when there is nothing to list
    property string placeholder: ""
    property real maximumHeight: VLCStyle.dp(600, VLCStyle.scale)

    signal closeRequested()

    readonly property SystemPalette rdPalette: VLCStyle.palette
    readonly property bool _empty: sections.length === 0 || placeholder !== ""

    implicitHeight: Math.min(maximumHeight, header.height + body.contentHeight)
    height: implicitHeight

    clip: true
    color: rdPalette.rdBgB1

    Accessible.role: Accessible.Pane
    Accessible.name: title

    Rectangle {
        id: header

        width: parent.width
        height: VLCStyle.rd_sidePanelTabHeight
        color: root.rdPalette.rdBgB2

        // rounded like the panel at the top, square at the bottom
        radius: root.radius

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.radius
            color: parent.color
        }

        Widgets.RdIcon {
            id: headerIcon

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(20)
            anchors.verticalCenter: parent.verticalCenter
            size: VLCStyle.dp(20)
            name: root.iconName
            color: root.rdPalette.rdFgA3
        }

        Text {
            anchors.left: headerIcon.right
            anchors.leftMargin: VLCStyle.dp(8)
            anchors.right: closeButton.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter

            text: root.title
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA2

            Accessible.role: Accessible.TitleBar
            Accessible.name: text
        }

        T.Button {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(9)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: VLCStyle.dp(32)
            implicitHeight: VLCStyle.dp(32)

            focusPolicy: Qt.StrongFocus
            Accessible.name: qsTr("Close %1").arg(root.title)

            onClicked: root.closeRequested()

            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

            background: Rectangle {
                radius: VLCStyle.rd_radius_small
                color: closeButton.hovered ? root.rdPalette.rdHoverOverlay : "transparent"
                border.width: closeButton.visualFocus ? VLCStyle.dp(1) : 0
                border.color: root.rdPalette.rdFgA3
            }

            contentItem: Item {
                Widgets.RdIcon {
                    anchors.centerIn: parent
                    name: "close"
                    color: closeButton.hovered ? root.rdPalette.rdFgA1 : root.rdPalette.rdFgA2
                }
            }
        }
    }

    Flickable {
        id: body

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: content.implicitHeight

        // like the sidebar pages: a scroll bar only while the body scrolls or is pointed at
        T.ScrollBar.vertical: Widgets.ScrollBarExt {
            id: scrollBar

            opacity: (scrollBar.active || scrollBar.interacting) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: VLCStyle.duration_short
                }
            }
        }

        Column {
            id: content

            width: body.width
            bottomPadding: VLCStyle.dp(20)

            Text {
                visible: root._empty
                width: parent.width
                topPadding: VLCStyle.dp(20)
                leftPadding: VLCStyle.dp(24)
                rightPadding: VLCStyle.dp(24)
                text: root.placeholder !== "" ? root.placeholder : qsTr("No media")
                wrapMode: Text.WordWrap
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.rdPalette.rdFgA3
            }

            Repeater {
                model: root._empty ? [] : root.sections

                delegate: Column {
                    id: section

                    required property var modelData
                    required property int index

                    width: content.width

                    // Figma draws the divider as a 0 px line between the sections
                    Rectangle {
                        visible: section.index > 0
                        width: parent.width
                        height: VLCStyle.dp(1)
                        color: root.rdPalette.rdDividerDim
                    }

                    Widgets.RdSectionHeader {
                        width: parent.width
                        text: section.modelData.title ?? ""
                    }

                    Item {
                        width: parent.width
                        height: VLCStyle.dp(10)
                    }

                    Repeater {
                        model: section.modelData.rows ?? []

                        delegate: Item {
                            id: infoRow

                            required property var modelData

                            readonly property string value: modelData.key !== undefined
                                                            ? (root.values[modelData.key] ?? "-")
                                                            : (modelData.value ?? "")

                            width: content.width
                            height: Math.max(VLCStyle.dp(28), valueText.implicitHeight + VLCStyle.dp(8))

                            Accessible.role: Accessible.StaticText
                            Accessible.name: (modelData.label ?? "") + ": " + value

                            Text {
                                id: labelText

                                x: VLCStyle.dp(24)
                                y: VLCStyle.dp(4)
                                width: Math.min(implicitWidth, (infoRow.width - 2 * VLCStyle.dp(24)) * 0.45)
                                text: infoRow.modelData.label ?? ""
                                elide: Text.ElideRight
                                font.family: VLCStyle.rd_fontFamily
                                font.pixelSize: VLCStyle.rd_fontSize_label
                                color: root.rdPalette.rdFgA3
                            }

                            Text {
                                id: valueText

                                anchors.left: labelText.right
                                anchors.leftMargin: VLCStyle.dp(16)
                                anchors.right: parent.right
                                anchors.rightMargin: VLCStyle.dp(24)
                                y: VLCStyle.dp(4)
                                text: infoRow.value
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                font.family: VLCStyle.rd_fontFamily
                                font.pixelSize: VLCStyle.rd_fontSize_label
                                color: root.rdPalette.rdFgA2
                            }
                        }
                    }
                }
            }
        }
    }
}
