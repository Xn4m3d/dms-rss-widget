import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankNewsRssTickerPill"

    // a horizontal scrolling pill can't work in a VERTICAL (left/right) main bar →
    // the enable toggle is disabled there (position: 2=left, 3=right).
    readonly property bool barVertical: {
        var bars = SettingsData.barConfigs || [];
        if (bars.length === 0)
            return false;
        var p = bars[0].position;
        return p === 2 || p === 3;
    }

    // mutual exclusion: only one ticker active at a time. Enabling this bar pill
    // turns OFF the desktop overlay ticker (dankNewsRssTicker.tickerBarEnabled).
    function disableDesktopOverlay() {
        var insts = SettingsData.desktopWidgetInstances || []
        for (var i = 0; i < insts.length; i++) {
            if (insts[i].widgetType === "dankNewsRssTicker")
                SettingsData.updateDesktopWidgetInstanceConfig(insts[i].id, {"tickerBarEnabled": false})
        }
    }

    // read/write the desktop card's hidden state (lives in the dankNewsRssTicker instance)
    function desktopCardHidden() {
        var insts = SettingsData.desktopWidgetInstances || []
        for (var i = 0; i < insts.length; i++)
            if (insts[i].widgetType === "dankNewsRssTicker")
                return !!(insts[i].config && insts[i].config.hideDesktopView)
        return false
    }
    function setDesktopCardHidden(hide) {
        var insts = SettingsData.desktopWidgetInstances || []
        for (var i = 0; i < insts.length; i++)
            if (insts[i].widgetType === "dankNewsRssTicker")
                SettingsData.updateDesktopWidgetInstanceConfig(insts[i].id, {"hideDesktopView": hide})
    }

    StyledText {
        width: parent.width
        text: "Dank News RSS & Ticker Pill"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Scrolling headlines in the bar. Reads the same items as the Dank RSS desktop widget (no extra fetching) — manage feeds from that widget."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        id: pillToggle
        enabled: !root.barVertical
        opacity: root.barVertical ? 0.4 : 1.0
        settingKey: "pillEnabled"
        label: "Enable this ticker"
        description: "Scroll headlines in the bar. Turning this ON switches OFF the desktop ticker bar — only one ticker can be active at a time. (You still need to add this widget to a bar via Settings → Bar.)"
        defaultValue: false
    }
    Connections {
        target: pillToggle
        function onValueChanged() {
            if (!pillToggle.isInitialized)
                return
            if (pillToggle.value)
                root.disableDesktopOverlay()
        }
    }

    StyledText {
        visible: root.barVertical
        width: parent.width
        text: "⚠️ Your main bar is vertical (left/right) — a horizontal scrolling pill can't run there. Use the desktop ticker bar instead (Settings → Desktop Widgets)."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    // hide the on-desktop RSS card (controls the dankNewsRssTicker instance directly)
    Row {
        width: parent.width
        spacing: Theme.spacingM

        Column {
            width: parent.width - hideCardToggle.width - Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS
            StyledText {
                text: "Hide the desktop card"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
            StyledText {
                width: parent.width
                text: "Hide the on-desktop RSS card and keep only this bar pill. (Controls the Dank RSS desktop widget.)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }

        DankToggle {
            id: hideCardToggle
            anchors.verticalCenter: parent.verticalCenter
            checked: root.desktopCardHidden()
            onToggled: isChecked => root.setDesktopCardHidden(isChecked)
        }
    }

    StyledText {
        width: parent.width
        text: "Prefer the ticker on the DESKTOP instead? (a full-width bar that docks under the main bar / at the screen bottom, or floats) → open Desktop Widgets, select the Dank RSS widget, and turn on ‘Enable ticker bar’. Enabling that switches this pill off automatically."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    DankButton {
        text: "Open Desktop Widgets →"
        iconName: "open_in_new"
        onClicked: Quickshell.execDetached(["dms", "ipc", "call", "settings", "openWith", "desktop_widgets"])
    }

    SliderSetting {
        settingKey: "tickerWidth"
        label: "Ticker width"
        description: "Visible width of the ticker in the bar (pixels)"
        defaultValue: 380
        minimum: 120
        maximum: 800
        unit: "px"
        leftIcon: "width"
    }

    SliderSetting {
        settingKey: "scrollSpeed"
        label: "Scroll speed"
        description: "How fast the headlines scroll (pixels per second)"
        defaultValue: 40
        minimum: 10
        maximum: 160
        unit: "px/s"
        leftIcon: "speed"
    }

    SliderSetting {
        settingKey: "maxItems"
        label: "Max items"
        description: "How many recent headlines to cycle through"
        defaultValue: 15
        minimum: 5
        maximum: 50
        unit: ""
        rightIcon: "list"
    }

    StringSetting {
        settingKey: "separator"
        label: "Separator"
        description: "Glyph shown between headlines"
        defaultValue: "•"
        placeholder: "•"
    }

    ToggleSetting {
        settingKey: "showSource"
        label: "Show source label"
        description: "Prefix each headline with its feed name, e.g. [Hacker News]"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "pauseOnHover"
        label: "Pause on hover"
        description: "Stop scrolling while the mouse is over the ticker so you can read"
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: "💡 Click the ticker to open a list of the latest items; click an item to open it in your browser."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
