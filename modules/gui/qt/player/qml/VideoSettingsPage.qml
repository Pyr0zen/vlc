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

// redesign: settings sidebar, Video tab (video 8:56-9:06 final version; Figma "video settings",
// "Video - Essential", "Video - Crop", "Video - Colors"). Defaults: flip and rotate (VLC's
// transform / rotate filters), zoom, aspect ratio and crop (VLC's video variables), HDR mode
// and resolution (options), renderer (VLC's renderer menu). Filters: VLC's video effects grouped
// like VLC's "Adjustments and Effects" tabs; Geometry, Overlay and Advanced have no Figma frame
// and follow the Essential / Colors cards (Decision 21).
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

RdSidePanelPage {
    id: root

    key: "videoSettings"

    // values may have changed elsewhere (VLC's effects dialog, hotkeys) while the page was hidden
    onActiveChanged: {
        if (active)
            RdEffects.refresh()
    }
    // a page created while its tab is already selected starts active
    Component.onCompleted: {
        if (active)
            RdEffects.refresh()
    }

    function parseNumber(text) {
        return parseFloat(String(text).replace(",", ".").replace(/[^0-9.+-]/g, ""))
    }

    function colorText(value) {
        return "#" + ("000000" + Number(value).toString(16)).slice(-6).toUpperCase()
    }

    // a binding reading RdEffects.values[key] follows only that value
    readonly property string _flip: RdEffects.values[RdEffects.videoFilterKey("transform")]
                                    ? String(RdEffects.values[RdEffects.videoKey("transform-type")]) : ""
    readonly property real _rotation: RdEffects.values[RdEffects.videoFilterKey("rotate")]
                                      ? Number(RdEffects.values[RdEffects.videoKey("rotate-angle")]) : 0

    Widgets.RdSettingsSection {
        title: qsTr("Defaults")
        showDivider: false

        Widgets.RdSettingRow {
            text: qsTr("Flip")
            rowHeight: VLCStyle.dp(37)

            below: Widgets.RdSegmented {
                width: parent.width
                model: [qsTr("None"), qsTr("Horizontal"), qsTr("Vertical")]
                currentIndex: root._flip === "hflip" ? 1 : root._flip === "vflip" ? 2 : 0
                Accessible.name: qsTr("Flip")
                onActivated: (index) => {
                    if (index === 0) {
                        RdEffects.setVideoFilterEnabled("transform", false)
                        return
                    }
                    RdEffects.setVideoValue("transform-type", index === 1 ? "hflip" : "vflip")
                    // the transform filter reads its type when it starts
                    if (RdEffects.videoFilterEnabled("transform"))
                        RdEffects.restartVideoFilter("transform")
                    else
                        RdEffects.setVideoFilterEnabled("transform", true)
                }
            }
        }

        Widgets.RdSettingRow {
            text: qsTr("Rotate")

            Widgets.RdValueBox {
                text: Math.round(root._rotation) + " " + qsTr("deg")
                Accessible.name: qsTr("Rotate")
                onEdited: (value) => {
                    const deg = root.parseNumber(value)
                    if (isNaN(deg))
                        return
                    const angle = ((Math.round(deg) % 360) + 360) % 360
                    RdEffects.setVideoValue("rotate-angle", angle)
                    RdEffects.setVideoFilterEnabled("rotate", angle !== 0)
                }
            }
        }

        DropdownRow {
            text: qsTr("Zoom")

            Widgets.RdChoiceDropdown {
                implicitWidth: VLCStyle.dp(220)
                choices: Player.zoom
                Accessible.name: qsTr("Zoom")
            }
        }

        DropdownRow {
            text: qsTr("HDR")
            visible: hdr.count > 0

            OptionDropdown {
                id: hdr

                option: "d3d11-hdr-mode"
                Accessible.name: qsTr("HDR")
            }
        }

        DropdownRow {
            text: qsTr("Resolution")

            OptionDropdown {
                option: "preferred-resolution"
                Accessible.name: qsTr("Resolution")
            }
        }

        DropdownRow {
            text: qsTr("Aspect Ratio")

            Widgets.RdChoiceDropdown {
                implicitWidth: VLCStyle.dp(220)
                choices: Player.aspectRatio
                Accessible.name: qsTr("Aspect Ratio")
            }
        }

        DropdownRow {
            text: qsTr("Crop")

            Widgets.RdChoiceDropdown {
                implicitWidth: VLCStyle.dp(220)
                choices: Player.crop
                Accessible.name: qsTr("Crop")
            }
        }

        // "Render: Local" is VLC's renderer / cast picker (Decision 24)
        DropdownRow {
            text: qsTr("Render")

            T.AbstractButton {
                id: renderButton

                implicitWidth: VLCStyle.dp(220)
                implicitHeight: VLCStyle.dp(48)

                Accessible.role: Accessible.ComboBox
                Accessible.name: qsTr("Render")

                onClicked: rendererMenu.popup(renderButton.mapToGlobal(0, renderButton.height))

                background: Rectangle {
                    radius: VLCStyle.rd_radius_normal
                    color: VLCStyle.palette.rdBgB2

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: VLCStyle.dp(2)
                        radius: VLCStyle.rd_radius_small
                        color: renderButton.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA4
                        border.width: renderButton.visualFocus ? VLCStyle.dp(1) : 0
                        border.color: VLCStyle.palette.rdFgA3
                    }
                }

                contentItem: Item {
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: VLCStyle.dp(16)
                        anchors.right: chevron.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: Player.rendererManager.useRenderer ? qsTr("Casting") : qsTr("Local")
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: VLCStyle.palette.rdFgA2
                    }

                    Widgets.RdIcon {
                        id: chevron

                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.dp(14)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_direction-down"
                        color: VLCStyle.palette.rdFgA2
                    }
                }

                QmlRendererMenu {
                    id: rendererMenu

                    ctx: MainCtx
                }
            }
        }
    }

    Widgets.RdSettingsSection {
        title: qsTr("Filters")

        FilterGroup {
            text: qsTr("Essential")
            entries: [
                { kind: "slider", module: "adjust", name: "hue", label: qsTr("Hue"), unit: "°", decimals: 0 },
                { kind: "slider", module: "adjust", name: "brightness", label: qsTr("Brightness"), decimals: 2 },
                { kind: "slider", module: "adjust", name: "contrast", label: qsTr("Contrast"), decimals: 2 },
                { kind: "slider", module: "adjust", name: "saturation", label: qsTr("Saturation"), decimals: 2 },
                { kind: "slider", module: "adjust", name: "gamma", label: qsTr("Gamma"), decimals: 2 },
                { kind: "toggle", module: "sharpen", label: qsTr("Sharpen") },
                { kind: "slider", module: "sharpen", name: "sharpen-sigma", label: qsTr("Sharpen Sigma"), decimals: 2 },
                { kind: "toggle", module: "gradfun", label: qsTr("Banding Removal") },
                { kind: "slider", module: "gradfun", name: "gradfun-radius", label: qsTr("Banding Removal Radius"), decimals: 0 },
                { kind: "toggle", module: "grain", label: qsTr("Film Grain") },
                { kind: "slider", module: "grain", name: "grain-variance", label: qsTr("Film Grain Variance"), decimals: 1 }
            ]
        }

        // VLC's live crop of the video output, in pixels
        FilterGroup {
            text: qsTr("Crop")
            entries: [
                { kind: "pixels", name: "crop-top", label: qsTr("Top") },
                { kind: "pixels", name: "crop-bottom", label: qsTr("Bottom") },
                { kind: "pixels", name: "crop-left", label: qsTr("Left") },
                { kind: "pixels", name: "crop-right", label: qsTr("Right") }
            ]
        }

        FilterGroup {
            text: qsTr("Colors")
            entries: [
                { kind: "toggle", module: "extract", label: qsTr("Color Extraction") },
                { kind: "color", module: "extract", name: "extract-component", label: qsTr("Color") },
                { kind: "toggle", module: "colorthres", label: qsTr("Color Threshold") },
                { kind: "color", module: "colorthres", name: "colorthres-color", label: qsTr("Color") },
                { kind: "slider", module: "colorthres", name: "colorthres-saturationthres", label: qsTr("Saturation"), decimals: 0, from: 0, to: 100 },
                { kind: "slider", module: "colorthres", name: "colorthres-similaritythres", label: qsTr("Similarity"), decimals: 0, from: 0, to: 100 },
                { kind: "toggle", module: "invert", label: qsTr("Negate Colors") },
                { kind: "toggle", module: "posterize", label: qsTr("Posterize") },
                { kind: "slider", module: "posterize", name: "posterize-level", label: qsTr("Posterize Level"), decimals: 0 },
                { kind: "toggle", module: "gradient", label: qsTr("Gradient") },
                { kind: "choice", module: "gradient", name: "gradient-mode", label: qsTr("Gradient") },
                { kind: "flag", module: "gradient", name: "gradient-color", label: qsTr("Color") },
                { kind: "flag", module: "gradient", name: "gradient-cartoon", label: qsTr("Cartoon") },
                { kind: "toggle", module: "sepia", label: qsTr("Sepia") },
                { kind: "slider", module: "sepia", name: "sepia-intensity", label: qsTr("Sepia Intensity"), decimals: 0 }
            ]
        }

        FilterGroup {
            text: qsTr("Geometry")
            entries: [
                { kind: "toggle", module: "magnify", label: qsTr("Interactive Zoom") },
                { kind: "toggle", module: "wall", label: qsTr("Wall") },
                { kind: "number", module: "wall", name: "wall-cols", label: qsTr("Columns") },
                { kind: "number", module: "wall", name: "wall-rows", label: qsTr("Rows") },
                { kind: "toggle", module: "puzzle", label: qsTr("Puzzle Game") },
                { kind: "number", module: "puzzle", name: "puzzle-cols", label: qsTr("Columns") },
                { kind: "number", module: "puzzle", name: "puzzle-rows", label: qsTr("Rows") }
            ]
        }

        FilterGroup {
            text: qsTr("Overlay")
            entries: [
                { kind: "toggle", module: "logo", label: qsTr("Logo") },
                { kind: "text", module: "logo", name: "logo-file", label: qsTr("Logo File") },
                { kind: "slider", module: "logo", name: "logo-opacity", label: qsTr("Opacity"), decimals: 0 },
                { kind: "toggle", module: "marq", label: qsTr("Marquee") },
                { kind: "text", module: "marq", name: "marq-marquee", label: qsTr("Text") },
                { kind: "toggle", module: "erase", label: qsTr("Logo Erase") },
                { kind: "text", module: "erase", name: "erase-mask", label: qsTr("Mask File") }
            ]
        }

        FilterGroup {
            text: qsTr("Advanced")
            entries: [
                { kind: "toggle", module: "anaglyph", label: qsTr("Anaglyph 3D") },
                { kind: "toggle", module: "mirror", label: qsTr("Mirror") },
                { kind: "toggle", module: "psychedelic", label: qsTr("Psychedelic") },
                { kind: "toggle", module: "wave", label: qsTr("Waves") },
                { kind: "toggle", module: "ripple", label: qsTr("Water Effect") },
                { kind: "toggle", module: "motiondetect", label: qsTr("Motion Detect") },
                { kind: "toggle", module: "gaussianblur", label: qsTr("Spatial Blur") },
                // read when the filter starts (not a command variable of gaussianblur)
                { kind: "slider", module: "gaussianblur", name: "gaussianblur-sigma", label: qsTr("Sigma"), decimals: 1, live: false },
                { kind: "toggle", module: "motionblur", label: qsTr("Motion Blur") },
                { kind: "slider", module: "motionblur", name: "blur-factor", label: qsTr("Factor"), decimals: 0 },
                { kind: "toggle", module: "antiflicker", label: qsTr("Anti-Flickering") },
                { kind: "slider", module: "antiflicker", name: "antiflicker-softening-size", label: qsTr("Softening"), decimals: 0 },
                { kind: "toggle", module: "hqdn3d", label: qsTr("Denoiser") },
                { kind: "slider", module: "hqdn3d", name: "hqdn3d-luma-spat", label: qsTr("Spatial Luma Strength"), decimals: 1 },
                { kind: "slider", module: "hqdn3d", name: "hqdn3d-luma-temp", label: qsTr("Temporal Luma Strength"), decimals: 1 },
                { kind: "slider", module: "hqdn3d", name: "hqdn3d-chroma-spat", label: qsTr("Spatial Chroma Strength"), decimals: 1 },
                { kind: "slider", module: "hqdn3d", name: "hqdn3d-chroma-temp", label: qsTr("Temporal Chroma Strength"), decimals: 1 },
                { kind: "toggle", module: "clone", label: qsTr("Clone") },
                { kind: "number", module: "clone", name: "clone-count", label: qsTr("Number of Clones") }
            ]
        }
    }

    // label on the left, a 220 px dropdown on the right (Figma "video settings": rows 68 px
    // apart, i.e. 63 plus the 5 px row spacing)
    component DropdownRow: Widgets.RdSettingRow {
        rowHeight: VLCStyle.dp(63)
    }

    // dropdown over the choices VLC declares for an option
    component OptionDropdown: Widgets.RdDropdown {
        property string option

        readonly property var _choices: RdEffects.optionChoices(option)
        readonly property var _current: RdEffects.values[RdEffects.optionKey(option)]

        implicitWidth: VLCStyle.dp(220)
        model: _choices.map((c) => c.text)
        currentIndex: _choices.findIndex((c) => String(c.value) === String(_current))
        onActivated: (index) => RdEffects.setOption(option, _choices[index].value)
    }

    // "Essential", "Crop"... sub-label, then the group's settings in an "Expand Settings" card
    component FilterGroup: ColumnLayout {
        id: group

        property alias text: groupLabel.text
        property var entries: []

        // (inline components cannot use the page's functions)
        function parseNumber(text) {
            return parseFloat(String(text).replace(",", ".").replace(/[^0-9.+-]/g, ""))
        }

        function colorText(value) {
            return "#" + ("000000" + Number(value).toString(16)).slice(-6).toUpperCase()
        }

        Layout.fillWidth: true
        spacing: VLCStyle.dp(5)

        Text {
            id: groupLabel

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(37)
            leftPadding: VLCStyle.dp(4)
            verticalAlignment: Text.AlignVCenter
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        Widgets.RdExpander {
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: VLCStyle.dp(5)

                Repeater {
                    model: group.entries

                    delegate: Loader {
                        required property var modelData

                        Layout.fillWidth: true
                        sourceComponent: {
                            switch (modelData.kind) {
                            case "toggle": return toggleEntry
                            case "slider": return sliderEntry
                            case "color": return colorEntry
                            case "choice": return choiceEntry
                            case "flag": return flagEntry
                            case "text": return textEntry
                            case "number": return numberEntry
                            case "pixels": return pixelsEntry
                            default: return null
                            }
                        }

                        readonly property var entry: modelData

                    // a filter on / off
                    Component {
                        id: toggleEntry

                        Widgets.RdSettingRow {
                            text: entry.label

                            Widgets.RdToggle {
                                checked: RdEffects.values[RdEffects.videoFilterKey(entry.module)]
                                Accessible.name: entry.label
                                onToggled: RdEffects.setVideoFilterEnabled(entry.module, checked)
                            }
                        }
                    }

                    // a numeric parameter; moving it turns its filter on. A parameter the filter
                    // reads only when it starts ("live: false") restarts the whole filter chain
                    // on every change: it is applied when the slider is released.
                    Component {
                        id: sliderEntry

                        Widgets.RdParamSlider {
                            id: paramSlider

                            readonly property var range: RdEffects.optionRange(entry.name)
                            readonly property real current: Number(RdEffects.values[RdEffects.videoKey(entry.name)])
                            readonly property bool live: entry.live ?? true
                            readonly property real shown: live ? current : restartCommit.shown

                            readonly property RdSliderCommit restartCommit: RdSliderCommit {
                                pressed: paramSlider.pressed
                                current: paramSlider.current
                                keyDelay: 300
                                tolerance: Math.pow(10, -(entry.decimals ?? 1)) / 2
                                onCommit: (v) => paramSlider.apply(v)
                            }

                            function apply(v) {
                                RdEffects.setVideoValue(entry.name, v)
                                if (!RdEffects.videoFilterEnabled(entry.module))
                                    RdEffects.setVideoFilterEnabled(entry.module, true)
                            }

                            text: entry.label
                            valueText: shown.toFixed(entry.decimals ?? 1) + (entry.unit ?? "")
                            from: entry.from ?? range.min ?? 0
                            to: entry.to ?? range.max ?? 1
                            stepSize: (entry.decimals ?? 1) === 0 ? 1 : Math.pow(10, -(entry.decimals ?? 1))
                            showTicks: false
                            value: shown
                            onMoved: (v) => {
                                if (live)
                                    apply(v)
                                else
                                    restartCommit.push(v)
                            }
                        }
                    }

                    Component {
                        id: colorEntry

                        Widgets.RdSettingRow {
                            text: entry.label

                            Widgets.RdValueBox {
                                readonly property string hex: group.colorText(RdEffects.values[RdEffects.videoKey(entry.name)])

                                text: hex
                                showSwatch: true
                                swatch: hex
                                Accessible.name: entry.label
                                onEdited: (value) => {
                                    const v = parseInt(String(value).replace("#", "").trim(), 16)
                                    if (!isNaN(v))
                                        RdEffects.setVideoValue(entry.name, v & 0xFFFFFF)
                                }
                            }
                        }
                    }

                    Component {
                        id: choiceEntry

                        Widgets.RdSettingRow {
                            text: entry.label
                            rowHeight: VLCStyle.dp(58)

                            Widgets.RdDropdown {
                                readonly property var _choices: RdEffects.optionChoices(entry.name)
                                readonly property var _current: RdEffects.values[RdEffects.videoKey(entry.name)]

                                implicitWidth: VLCStyle.dp(180)
                                model: _choices.map((c) => c.text)
                                currentIndex: _choices.findIndex((c) => String(c.value) === String(_current))
                                Accessible.name: entry.label
                                onActivated: (index) => RdEffects.setVideoValue(entry.name, _choices[index].value)
                            }
                        }
                    }

                    // a boolean (or 0 / 1) option of a filter
                    Component {
                        id: flagEntry

                        Widgets.RdSettingRow {
                            text: entry.label

                            Widgets.RdToggle {
                                checked: !!Number(RdEffects.values[RdEffects.videoKey(entry.name)])
                                Accessible.name: entry.label
                                onToggled: RdEffects.setVideoValue(entry.name, checked ? 1 : 0)
                            }
                        }
                    }

                    Component {
                        id: textEntry

                        Widgets.RdSettingRow {
                            text: entry.label

                            Widgets.RdValueBox {
                                implicitWidth: VLCStyle.dp(200)
                                text: String(RdEffects.values[RdEffects.videoKey(entry.name)])
                                Accessible.name: entry.label
                                onEdited: (value) => RdEffects.setVideoValue(entry.name, value)
                            }
                        }
                    }

                    Component {
                        id: numberEntry

                        Widgets.RdSettingRow {
                            text: entry.label

                            Widgets.RdValueBox {
                                text: String(RdEffects.values[RdEffects.videoKey(entry.name)])
                                Accessible.name: entry.label
                                onEdited: (value) => {
                                    const n = Math.round(group.parseNumber(value))
                                    if (!isNaN(n))
                                        RdEffects.setVideoValue(entry.name, n)
                                }
                            }
                        }
                    }

                    Component {
                        id: pixelsEntry

                        Widgets.RdSettingRow {
                            text: entry.label

                            Widgets.RdValueBox {
                                text: qsTr("%1 px").arg(Number(RdEffects.values[RdEffects.videoKey(entry.name)]) || 0)
                                Accessible.name: entry.label
                                onEdited: (value) => {
                                    const n = Math.round(group.parseNumber(value))
                                    if (!isNaN(n))
                                        RdEffects.setVideoValue(entry.name, Math.max(0, n))
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }
}
