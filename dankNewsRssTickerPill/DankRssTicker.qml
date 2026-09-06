import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Bar-widget companion to dankNewsRssTicker: a scrolling marquee of the latest
// headlines, read straight from the cache the desktop widget already writes
// (~/.cache/dankNewsRssTicker-items.json). Read-only: it never fetches feeds itself.
PluginComponent {
    id: root

    layerNamespacePlugin: "rss-ticker"

    // --- config (plugin_settings.json -> "dankNewsRssTickerPill") ---
    readonly property int maxItems: pluginData.maxItems || 15
    readonly property int scrollSpeed: pluginData.scrollSpeed || 40        // px/s
    readonly property int tickerWidth: pluginData.tickerWidth || 380       // visible width in the bar
    readonly property bool showSource: pluginData.showSource !== undefined ? pluginData.showSource : true
    readonly property string separator: pluginData.separator || "•"
    readonly property bool pauseOnHover: pluginData.pauseOnHover !== undefined ? pluginData.pauseOnHover : true
    // master on/off: when off, the pill collapses to nothing in the bar. Only one
    // ticker should be active at a time (this bar pill OR the desktop overlay).
    readonly property bool pillEnabled: pluginData.pillEnabled !== undefined ? pluginData.pillEnabled : false
    // a horizontal scrolling pill makes no sense in a VERTICAL (left/right) main bar —
    // force it off there (the settings toggle is disabled too). position: 2=left 3=right.
    readonly property bool barVertical: {
        var bars = SettingsData.barConfigs || [];
        if (bars.length === 0) return false;
        var p = bars[0].position;
        return p === 2 || p === 3;
    }
    readonly property bool pillActive: pillEnabled && !barVertical
    // on root so it resolves inside the Repeater delegates (nested ids like `clip`
    // don't resolve there — only `root` does).
    readonly property real tickerGap: Theme.spacingL * 2

    // When inactive, collapse the WHOLE pill (BasePill width 0 + opacity 0) via the
    // PluginComponent visibility mechanism — just zeroing the content width left the
    // pill's background/padding chrome visible in the bar.
    onPillActiveChanged: root.setVisibilityOverride(root.pillActive)
    Component.onCompleted: root.setVisibilityOverride(root.pillActive)

    // --- data ---
    property var items: []
    readonly property string cachePath: Paths.strip(Paths.home) + "/.cache/dankNewsRssTicker-items.json"

    function isSafeUrl(u) {
        return typeof u === "string" && /^https?:\/\//i.test(u)
    }

    function titleFor(it) {
        if (!it)
            return ""
        var t = ("" + (it.title || "")).replace(/\s+/g, " ").trim()
        if (root.showSource && it.source)
            return "[" + it.source + "] " + t
        return t
    }

    function openLink(link) {
        if (root.isSafeUrl(link))
            Quickshell.execDetached(["xdg-open", link])
    }

    // Auto-reloads whenever the desktop widget rewrites the cache.
    FileView {
        id: cacheView
        path: root.cachePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var arr = JSON.parse(text())
                if (!Array.isArray(arr))
                    arr = []
                root.items = arr.slice(0, root.maxItems)
            } catch (e) {
                root.items = []
            }
        }
        onLoadFailed: root.items = []
    }

    // Safety net in case a file-watch event is missed.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: cacheView.reload()
    }

    // --- the scrolling pill ---
    horizontalBarPill: Component {
        Item {
            id: clip
            clip: true
            visible: root.pillActive
            implicitWidth: root.pillActive ? root.tickerWidth : 0
            implicitHeight: root.widgetThickness

            readonly property bool paused: root.pauseOnHover && hoverArea.containsMouse
            readonly property real gap: root.tickerGap
            property real offset: 0
            readonly property real loopWidth: trackA.width + gap / 2

            // empty / loading fallback
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.items.length === 0
                text: "RSS…"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                opacity: 0.7
            }

            Row {
                id: trackA
                visible: root.items.length > 0
                anchors.verticalCenter: parent.verticalCenter
                x: -clip.offset
                spacing: clip.gap / 2
                Repeater {
                    model: root.items
                    Row {
                        spacing: 0
                        StyledText {
                            text: root.titleFor(modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            verticalAlignment: Text.AlignVCenter
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: root.tickerGap / 2; height: 1; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: root.separator
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            verticalAlignment: Text.AlignVCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 2
                        }
                    }
                }
            }

            // Second identical copy, glued to the right of the first, so the
            // loop is seamless: when offset == loopWidth, copy B sits exactly
            // where copy A started, and we reset offset to 0.
            Row {
                id: trackB
                visible: root.items.length > 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: trackA.right
                anchors.leftMargin: clip.gap / 2
                spacing: clip.gap / 2
                Repeater {
                    model: root.items
                    Row {
                        spacing: 0
                        StyledText {
                            text: root.titleFor(modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            verticalAlignment: Text.AlignVCenter
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: root.tickerGap / 2; height: 1; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: root.separator
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            verticalAlignment: Text.AlignVCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 2
                        }
                    }
                }
            }

            // Frame-driven scroll: true pause/resume with no jump.
            FrameAnimation {
                running: root.items.length > 0 && !clip.paused && clip.loopWidth > 0
                onTriggered: {
                    clip.offset += root.scrollSpeed * frameTime
                    if (clip.offset >= clip.loopWidth)
                        clip.offset -= clip.loopWidth
                }
            }

            // Hover detection only — NoButton lets clicks fall through to the
            // BasePill underneath, which toggles the popout.
            MouseArea {
                id: hoverArea
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
            }
        }
    }

    // --- dropdown list of items on click ---
    popoutContent: Component {
        PopoutComponent {
            id: pop
            headerText: "RSS — latest headlines"
            detailsText: root.items.length + " items · click to open"
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - pop.headerHeight - pop.detailsHeight - Theme.spacingXL

                DankListView {
                    anchors.fill: parent
                    clip: true
                    spacing: Theme.spacingXS
                    model: root.items

                    delegate: StyledRect {
                        width: ListView.view.width
                        height: itemCol.implicitHeight + Theme.spacingS * 2
                        radius: Theme.cornerRadius
                        color: itemArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Column {
                            id: itemCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            spacing: 2

                            StyledText {
                                width: parent.width
                                text: ("" + (modelData.title || "")).replace(/\s+/g, " ").trim()
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }

                            StyledText {
                                width: parent.width
                                text: [modelData.source, modelData.relativeTime].filter(Boolean).join(" · ")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.openLink(modelData.link)
                                pop.closePopout()
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 460
    popoutHeight: 520
}
