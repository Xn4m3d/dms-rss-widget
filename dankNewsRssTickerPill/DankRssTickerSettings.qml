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

    // [patch:ux] Exact mirror of the control in the desktop widget's own panel (Settings →
    // Desktop Widgets → Dank News RSS & Ticker), so the user gets the same answer wherever
    // they land. Previously this panel offered "Enable this ticker" while the other offered
    // "Enable ticker bar": two near-homonyms, in two places, silently fighting each other.
    // The strip has exactly one home, so it is one choice. Storage is unchanged — this
    // plugin's pillEnabled, plus tickerBarEnabled / hideDesktopView on the desktop instance.
    // Making "Off" an explicit choice is also what removes the old dead end: it guarantees
    // the card stays visible instead of leaving the user with a blank desktop.
    property bool pillOn: false
    property bool desktopTickerOn: false
    property bool cardShown: true
    property bool hasDesktopInstance: false

    readonly property string headlinesMode: root.pillOn ? "bar" : (root.desktopTickerOn ? "desktop" : "off")
    readonly property var headlinesModeLabels: ["Off", "On the desktop (ticker bar)", "In the bar (pill)"]
    readonly property string headlinesModeLabel: root.headlinesMode === "bar" ? root.headlinesModeLabels[2] : (root.headlinesMode === "desktop" ? root.headlinesModeLabels[1] : root.headlinesModeLabels[0])

    function headlinesModeFromLabel(label) {
        if (label === root.headlinesModeLabels[2])
            return "bar"
        if (label === root.headlinesModeLabels[1])
            return "desktop"
        return "off"
    }

    // [patch:ux] Choosing "In the bar" only flips a setting — DMS still needs the widget to
    // be PLACED in a bar section, and nothing said so, so the pill silently never appeared.
    // Detect the placement so the reminder is shown only while it is actually missing.
    property bool pillPlacedInBar: false
    function refreshPillPlacement() {
        var bars = SettingsData.barConfigs || []
        for (var b = 0; b < bars.length; b++) {
            var zones = [bars[b].leftWidgets, bars[b].centerWidgets, bars[b].rightWidgets]
            for (var z = 0; z < zones.length; z++) {
                var list = zones[z] || []
                for (var i = 0; i < list.length; i++) {
                    var entry = list[i]
                    var id = (typeof entry === "string") ? entry : (entry && entry.id)
                    if (id === "dankNewsRssTickerPill") {
                        root.pillPlacedInBar = true
                        return
                    }
                }
            }
        }
        root.pillPlacedInBar = false
    }

    function desktopInstance() {
        var insts = SettingsData.desktopWidgetInstances || []
        for (var i = 0; i < insts.length; i++)
            if (insts[i].widgetType === "dankNewsRssTicker")
                return insts[i]
        return null
    }

    function patchDesktop(patch) {
        var inst = root.desktopInstance()
        if (inst)
            SettingsData.updateDesktopWidgetInstanceConfig(inst.id, patch)
    }

    function refreshHeadlinesState() {
        var inst = root.desktopInstance()
        var cfg = (inst && inst.config) || {}
        root.hasDesktopInstance = !!inst
        root.pillOn = !!root.loadValue("pillEnabled", false)
        root.desktopTickerOn = !!cfg.tickerBarEnabled
        root.cardShown = !cfg.hideDesktopView
        root.refreshPillPlacement()
    }

    function setHeadlinesMode(mode) {
        if (mode === "bar") {
            root.patchDesktop({"tickerBarEnabled": false})
            root.saveValue("pillEnabled", true)
        } else if (mode === "desktop") {
            root.saveValue("pillEnabled", false)
            root.patchDesktop({"tickerBarEnabled": true})
        } else {
            root.saveValue("pillEnabled", false)
            root.patchDesktop({"tickerBarEnabled": false, "hideDesktopView": false})
        }
        root.refreshHeadlinesState()
    }

    function setCardShown(shown) {
        root.patchDesktop({"hideDesktopView": !shown})
        root.refreshHeadlinesState()
    }

    Component.onCompleted: Qt.callLater(root.refreshHeadlinesState)

    // PluginSettings.onPluginServiceChanged only reloads DIRECT children, and this panel's
    // mode state lives on the root — so refresh it too whenever the service is (re)injected,
    // instead of relying on Component.onCompleted winning the ordering race. Connections adds
    // a handler alongside the base one rather than overriding it.
    Connections {
        target: root
        function onPluginServiceChanged() {
            root.refreshHeadlinesState()
        }
    }

    Connections {
        target: SettingsData
        function onDesktopWidgetInstancesChanged() {
            root.refreshHeadlinesState()
        }
        function onBarConfigsChanged() {
            root.refreshPillPlacement()
        }
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
        text: "Scrolling headlines in the bar. Reads the same items as the Dank News RSS & Ticker desktop widget (no extra fetching) — manage feeds from that widget."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    DankDropdown {
        width: parent.width
        text: "Scrolling headlines"
        description: root.headlinesMode === "bar" ? "In the bar: this widget also has to be placed in a bar section (Bar → Widgets) to show up." : "Where the scrolling headline strip lives. It can only be in one place at a time."
        currentValue: root.headlinesModeLabel
        options: root.headlinesModeLabels
        onValueChanged: newValue => root.setHeadlinesMode(root.headlinesModeFromLabel(newValue))
    }

    StyledText {
        visible: root.headlinesMode === "bar" && !root.pillPlacedInBar
        width: parent.width
        text: "⚠️ One step left: this widget isn’t in a bar yet, so nothing will show. Open Bar → Widgets and add ‘Dank News RSS & Ticker Pill’ to the Left, Center or Right Section."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warning
        wrapMode: Text.WordWrap
    }

    DankButton {
        visible: root.headlinesMode === "bar" && !root.pillPlacedInBar
        text: "Open Bar → Widgets →"
        iconName: "open_in_new"
        onClicked: Quickshell.execDetached(["dms", "ipc", "call", "settings", "openWith", "dankbar_widgets"])
    }

    StyledText {
        visible: root.headlinesMode === "bar" && root.pillPlacedInBar
        width: parent.width
        text: "✓ Placed in a bar."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        visible: !root.hasDesktopInstance
        width: parent.width
        text: "⚠️ The ‘Dank News RSS & Ticker’ desktop widget isn’t added yet. Add it from Settings → Desktop Widgets: it owns the feeds and fetches the items this pill displays."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    StyledText {
        visible: root.barVertical
        width: parent.width
        text: "⚠️ Your main bar is vertical (left/right) — a horizontal scrolling pill can't run there. Choose ‘On the desktop (ticker bar)’ instead."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    // Same control as in the desktop widget's panel — the card's visibility is genuinely
    // independent of where the headlines scroll, so it stays its own switch.
    Row {
        width: parent.width
        spacing: Theme.spacingM

        Column {
            width: parent.width - cardToggle.width - Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS
            StyledText {
                text: "Show the card on the desktop"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
            StyledText {
                width: parent.width
                text: root.headlinesMode === "off" ? "Locked on: with the headlines not scrolling anywhere, hiding the card too would leave nothing on screen." : "Turn off to keep only the scrolling strip. (Controls the Dank News RSS & Ticker desktop widget.)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }

        DankToggle {
            id: cardToggle
            anchors.verticalCenter: parent.verticalCenter
            enabled: root.headlinesMode !== "off" && root.hasDesktopInstance
            opacity: enabled ? 1.0 : 0.4
            checked: root.cardShown
            onToggled: isChecked => root.setCardShown(isChecked)
        }
    }

    StyledText {
        width: parent.width
        text: "Feeds, refresh interval and the card’s own appearance live in the desktop widget’s settings — this panel only styles the bar pill."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    DankButton {
        text: "Open Desktop Widgets →"
        iconName: "open_in_new"
        onClicked: Quickshell.execDetached(["dms", "ipc", "call", "settings", "openWith", "desktop_widgets"])
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
    }

    StyledText {
        width: parent.width
        text: "Bar pill appearance"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    // [patch:ux] These six settings only ever styled the BAR PILL, but nothing said so and
    // nothing greyed them out: with the headlines set to scroll on the desktop instead, the
    // user could drag every slider here and see absolutely nothing change. The desktop
    // ticker bar keeps its own width / speed / separator in the desktop widget's panel.
    StyledText {
        visible: root.headlinesMode !== "bar"
        width: parent.width
        text: root.headlinesMode === "desktop" ? "Inactive — the headlines are currently scrolling on the desktop. The desktop ticker bar has its own width, speed and separator in the desktop widget’s settings (button above)." : "Inactive — the headlines aren’t scrolling anywhere. Set ‘Scrolling headlines’ to ‘In the bar (pill)’ to use these."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warning
        wrapMode: Text.WordWrap
    }

    Column {
        id: pillAppearance
        width: parent.width
        spacing: Theme.spacingM
        enabled: root.headlinesMode === "bar"
        opacity: enabled ? 1.0 : 0.35

        // PluginSettings.reloadChildValues only walks DIRECT children, so the settings
        // nested in this Column would otherwise show their default instead of the stored
        // value. Propagate loadValue to them (same trick as the desktop widget's tabs).
        function loadValue() {
            for (var i = 0; i < children.length; i++)
                if (children[i].loadValue)
                    children[i].loadValue()
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

    }

    StyledText {
        width: parent.width
        text: "💡 Click the ticker to open a list of the latest items; click an item to open it in your browser."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
