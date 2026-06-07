import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankRssWidget"

    property int editingIndex: -1
    property int activeTab: 0   // 0 = General, 1 = Card, 2 = Ticker bar

    // --- Header ---
    StyledText {
        width: parent.width
        text: "Dank RSS Widget+"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Display RSS and Atom feeds on your desktop. Add feeds below and configure refresh intervals and appearance."
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
    }

    DankTabBar {
        id: rssTabBar
        width: parent.width
        height: 48
        model: [
            { "text": "General", "icon": "tune" },
            { "text": "Card", "icon": "space_dashboard" },
            { "text": "Ticker bar", "icon": "view_stream" }
        ]
        onTabClicked: index => {
            root.activeTab = index;
            currentIndex = index;
        }
        Component.onCompleted: {
            currentIndex = root.activeTab;
            Qt.callLater(updateIndicator);
        }
    }

    // breathing room between the tabs and the first section title
    Item {
        width: 1
        height: Theme.spacingM
    }

    // ===== Tab: General =====
    Column {
        id: tabGeneral
        width: parent.width
        spacing: Theme.spacingM
        visible: root.activeTab === 0
        // PluginSettings.reloadChildValues only iterates DIRECT children, so the
        // settings nested in this tab Column wouldn't reload (and would show their
        // default instead of the stored value). Propagate loadValue to them.
        function loadValue() {
            for (var i = 0; i < children.length; i++)
                if (children[i].loadValue)
                    children[i].loadValue();
        }

    // ─── Refresh Settings ───

    StyledText {
        width: parent.width
        text: "Refresh Settings"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "updateInterval"
        label: "Refresh Interval"
        description: "How often feeds are fetched (in minutes)"
        defaultValue: 30
        minimum: 5
        maximum: 1440
        unit: "min"
        // Note: stored as minutes in settings, converted to seconds in widget
    }

    SliderSetting {
        settingKey: "maxItems"
        label: "Maximum Items"
        description: "Maximum number of feed items to display"
        defaultValue: 20
        minimum: 5
        maximum: 50
        unit: ""
    }

    SelectionSetting {
        id: sortModeSetting
        settingKey: "sortMode"
        label: "Sort Order"
        description: "How feed items are ordered in the widget"
        options: [
            { label: "Newest First", value: "newest" },
            { label: "Oldest First", value: "oldest" },
            { label: "Group by Feed", value: "byFeed" }
        ]
        defaultValue: "newest"
    }

    SliderSetting {
        visible: sortModeSetting.value === "byFeed"
        settingKey: "maxPerFeed"
        label: "Items per Feed"
        description: "Maximum items shown from each feed when grouping"
        defaultValue: 5
        minimum: 1
        maximum: 20
        unit: ""
    }

    SelectionSetting {
        settingKey: "viewMode"
        label: "View Mode"
        description: "Compact shows title-only rows; Expanded shows descriptions and thumbnails"
        options: [
            { label: "Expanded", value: "expanded" },
            { label: "Compact", value: "compact" }
        ]
        defaultValue: "expanded"
    }

    ToggleSetting {
        settingKey: "notifyNewItems"
        label: "New Item Notifications"
        description: "Show a toast notification when new items appear after a refresh"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showFeedName"
        label: "Show Feed Source"
        description: "Display the feed name next to each item title"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showImages"
        label: "Show Thumbnails"
        description: "Display thumbnail images when available in feed items"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "openInBrowser"
        label: "Open Links in Browser"
        description: "Click feed items to open them in your browser"
        defaultValue: true
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
    }

    // ─── Feed Management ───

    StyledText {
        width: parent.width
        text: "Feed Management"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    // Add/Edit form
    StyledRect {
        width: parent.width
        height: addFeedColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: addFeedColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: root.editingIndex === -1 ? "Add Feed" : "Edit Feed"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Feed Name"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: nameField
                    width: parent.width
                    placeholderText: "e.g., Hacker News"
                    onFocusStateChanged: hasFocus => {
                        if (hasFocus) root.ensureItemVisible(nameField);
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Feed URL *"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: urlField
                    width: parent.width
                    placeholderText: "e.g., https://hnrss.org/newest"
                    onFocusStateChanged: hasFocus => {
                        if (hasFocus) root.ensureItemVisible(urlField);
                    }
                }
            }

            Row {
                spacing: Theme.spacingM

                DankButton {
                    text: root.editingIndex === -1 ? "Add Feed" : "Update Feed"
                    iconName: root.editingIndex === -1 ? "add" : "save"

                    onClicked: {
                        var url = urlField.text.trim();
                        if (!url) {
                            if (typeof ToastService !== "undefined") {
                                ToastService.showError("Please enter a feed URL");
                            }
                            return;
                        }

                        var name = nameField.text.trim() || url;
                        var feed = { name: name, url: url };

                        var currentFeeds = root.loadValue("feeds", []);
                        if (root.editingIndex === -1) {
                            currentFeeds = currentFeeds.concat([feed]);
                        } else {
                            currentFeeds[root.editingIndex] = feed;
                            root.editingIndex = -1;
                        }
                        root.saveValue("feeds", currentFeeds);

                        nameField.text = "";
                        urlField.text = "";
                    }
                }

                DankButton {
                    text: "Cancel"
                    iconName: "close"
                    visible: root.editingIndex !== -1
                    onClicked: {
                        root.editingIndex = -1;
                        nameField.text = "";
                        urlField.text = "";
                    }
                }
            }
        }
    }

    // Existing feeds list
    StyledRect {
        width: parent.width
        height: Math.max(120, feedsListColumn.implicitHeight + Theme.spacingL * 2)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: feedsListColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Configured Feeds"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ListView {
                id: feedsListView
                // bridge file-level ids into the delegate (a ListView delegate is an
                // isolated scope and can't see outer ids like root/nameField/urlField).
                property var settings: root
                property var nameFieldRef: nameField
                property var urlFieldRef: urlField
                width: parent.width
                height: Math.max(60, contentHeight)
                clip: true
                spacing: Theme.spacingXS
                model: root.loadValue("feeds", [])

                delegate: StyledRect {
                    id: feedDelegate
                    required property var modelData
                    required property int index
                    readonly property var settings: ListView.view.settings
                    readonly property var nameFieldRef: ListView.view.nameFieldRef
                    readonly property var urlFieldRef: ListView.view.urlFieldRef

                    width: feedsListView.width
                    height: feedInfoRow.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: feedItemMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                    RowLayout {
                        id: feedInfoRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "rss_feed"
                            size: 16
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: modelData.name || ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: modelData.url || ""
                                font.pixelSize: Theme.fontSizeSmall - 2
                                color: Theme.surfaceVariantText
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }
                        }

                        // Edit button
                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: editArea.containsMouse ? Theme.primary : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "edit"
                                size: 16
                                color: editArea.containsMouse ? Theme.onPrimary : Theme.surfaceVariantText
                            }

                            MouseArea {
                                id: editArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    feedDelegate.settings.editingIndex = index;
                                    var feed = feedDelegate.settings.loadValue("feeds", [])[index];
                                    feedDelegate.nameFieldRef.text = feed.name || "";
                                    feedDelegate.urlFieldRef.text = feed.url || "";
                                    feedDelegate.settings.ensureItemVisible(feedDelegate.nameFieldRef);
                                }
                            }
                        }

                        // Delete button
                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: deleteArea.containsMouse ? Theme.error : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "delete"
                                size: 16
                                color: deleteArea.containsMouse ? Theme.onError : Theme.surfaceVariantText
                            }

                            MouseArea {
                                id: deleteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var currentFeeds = feedDelegate.settings.loadValue("feeds", []);
                                    currentFeeds = currentFeeds.filter(function(_, i) { return i !== index; });
                                    feedDelegate.settings.saveValue("feeds", currentFeeds);
                                    if (feedDelegate.settings.editingIndex === index) {
                                        feedDelegate.settings.editingIndex = -1;
                                        feedDelegate.nameFieldRef.text = "";
                                        feedDelegate.urlFieldRef.text = "";
                                    } else if (feedDelegate.settings.editingIndex > index) {
                                        feedDelegate.settings.editingIndex--;
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: feedItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        propagateComposedEvents: true
                        onClicked: function(mouse) { mouse.accepted = false; }
                        onPressed: function(mouse) { mouse.accepted = false; }
                        onReleased: function(mouse) { mouse.accepted = false; }
                    }
                }

                // Empty state
                StyledText {
                    anchors.centerIn: parent
                    text: "No feeds configured yet"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    visible: feedsListView.count === 0
                }
            }
        }
    }

    // OPML Import
    StyledRect {
        width: parent.width
        height: opmlColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: opmlColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Import from OPML"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "Paste OPML/XML content to import feeds from other RSS readers"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankTextField {
                id: opmlField
                width: parent.width
                placeholderText: "Paste OPML XML here..."
                onFocusStateChanged: hasFocus => {
                    if (hasFocus) root.ensureItemVisible(opmlField);
                }
            }

            DankButton {
                text: "Import Feeds"
                iconName: "download"
                onClicked: {
                    var xml = opmlField.text.trim();
                    if (!xml) {
                        if (typeof ToastService !== "undefined")
                            ToastService.showError("Paste OPML content first");
                        return;
                    }
                    var imported = tabGeneral.parseOpml(xml);
                    if (imported.length === 0) {
                        if (typeof ToastService !== "undefined")
                            ToastService.showError("No feeds found in OPML");
                        return;
                    }
                    var currentFeeds = root.loadValue("feeds", []);
                    var existingUrls = {};
                    for (var i = 0; i < currentFeeds.length; i++) {
                        existingUrls[currentFeeds[i].url] = true;
                    }
                    var added = 0;
                    for (var j = 0; j < imported.length; j++) {
                        if (!existingUrls[imported[j].url]) {
                            currentFeeds.push(imported[j]);
                            added++;
                        }
                    }
                    root.saveValue("feeds", currentFeeds);
                    opmlField.text = "";
                    if (typeof ToastService !== "undefined")
                        ToastService.showInfo("Imported " + added + " feed" + (added !== 1 ? "s" : "") + " (" + (imported.length - added) + " duplicates skipped)");
                }
            }
        }
    }

    function parseOpml(xml) {
        var feeds = [];
        var outlineRegex = /<outline[^>]*xmlUrl=["']([^"']+)["'][^>]*>/gi;
        var match;
        while ((match = outlineRegex.exec(xml)) !== null) {
            var fullTag = match[0];
            var url = match[1].replace(/&amp;/g, "&");

            // Extract title or text attribute
            var titleMatch = fullTag.match(/(?:title|text)=["']([^"']+)["']/i);
            var name = titleMatch ? titleMatch[1].replace(/&amp;/g, "&") : url;

            feeds.push({ name: name, url: url });
        }
        return feeds;
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
    }

    // ─── Preset Feeds ───

    StyledText {
        width: parent.width
        text: "Quick Add"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Quickly add popular feeds"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    // News — US
    StyledText {
        width: parent.width
        text: "News — US"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.primary
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            text: "NPR"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("NPR", "https://feeds.npr.org/1001/rss.xml")
        }

        DankButton {
            text: "NYT"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("NYT", "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml")
        }

        DankButton {
            text: "CNN"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("CNN", "http://rss.cnn.com/rss/cnn_topstories.rss")
        }

        DankButton {
            text: "ABC News"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("ABC News", "https://feeds.abcnews.com/abcnews/topstories")
        }
    }

    // News — Global
    StyledText {
        width: parent.width
        text: "News — Global"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.primary
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            text: "BBC World"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("BBC World", "https://feeds.bbci.co.uk/news/world/rss.xml")
        }

        DankButton {
            text: "Al Jazeera"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Al Jazeera", "https://www.aljazeera.com/xml/rss/all.xml")
        }

        DankButton {
            text: "The Guardian"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("The Guardian", "https://www.theguardian.com/world/rss")
        }

        DankButton {
            text: "Deutsche Welle"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Deutsche Welle", "https://rss.dw.com/rdf/rss-en-all")
        }

        DankButton {
            text: "France 24"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("France 24", "https://www.france24.com/en/rss")
        }
    }

    // Finance
    StyledText {
        width: parent.width
        text: "Finance"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.primary
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            text: "CNBC"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("CNBC", "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10000664")
        }

        DankButton {
            text: "Yahoo Finance"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Yahoo Finance", "https://finance.yahoo.com/news/rssindex")
        }

        DankButton {
            text: "MarketWatch"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("MarketWatch", "https://feeds.content.dowjones.io/public/rss/mw_topstories")
        }
    }

    // Bitcoin & cryptocurrency
    StyledText {
        width: parent.width
        text: "Bitcoin & cryptocurrency"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.primary
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            text: "CoinDesk"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("CoinDesk", "https://www.coindesk.com/arc/outboundfeeds/rss/")
        }

        DankButton {
            text: "Cointelegraph"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Cointelegraph", "https://cointelegraph.com/rss")
        }

        DankButton {
            text: "Bitcoin Magazine"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Bitcoin Magazine", "https://bitcoinmagazine.com/feed")
        }

        DankButton {
            text: "Decrypt"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Decrypt", "https://decrypt.co/feed")
        }
    }

    // Tech
    StyledText {
        width: parent.width
        text: "Tech"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.primary
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            text: "Hacker News"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Hacker News", "https://hnrss.org/newest")
        }

        DankButton {
            text: "Ars Technica"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Ars Technica", "https://feeds.arstechnica.com/arstechnica/index")
        }

        DankButton {
            text: "The Verge"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("The Verge", "https://www.theverge.com/rss/index.xml")
        }

        DankButton {
            text: "Phoronix"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("Phoronix", "https://www.phoronix.com/rss.php")
        }

        DankButton {
            text: "9to5Linux"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("9to5Linux", "https://9to5linux.com/feed")
        }

        DankButton {
            text: "The Register"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("The Register", "https://www.theregister.com/headlines.atom")
        }
    }

    // Reddit
    StyledText {
        width: parent.width
        text: "Reddit"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.primary
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            text: "r/linux"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/linux", "https://www.reddit.com/r/linux/.rss")
        }

        DankButton {
            text: "r/niri"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/niri", "https://www.reddit.com/r/niri/.rss")
        }

        DankButton {
            text: "r/hyprland"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/hyprland", "https://www.reddit.com/r/hyprland/.rss")
        }

        DankButton {
            text: "r/fedora"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/fedora", "https://www.reddit.com/r/fedora/.rss")
        }

        DankButton {
            text: "r/archlinux"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/archlinux", "https://www.reddit.com/r/archlinux/.rss")
        }

        DankButton {
            text: "r/NixOS"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/NixOS", "https://www.reddit.com/r/NixOS/.rss")
        }

        DankButton {
            text: "r/Ubuntu"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/Ubuntu", "https://www.reddit.com/r/Ubuntu/.rss")
        }

        DankButton {
            text: "r/unixporn"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/unixporn", "https://www.reddit.com/r/unixporn/.rss")
        }

        DankButton {
            text: "r/wayland"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/wayland", "https://www.reddit.com/r/wayland/.rss")
        }

        DankButton {
            text: "r/linux_gaming"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/linux_gaming", "https://www.reddit.com/r/linux_gaming/.rss")
        }

        DankButton {
            text: "r/Bitcoin"
            iconName: "add"
            onClicked: tabGeneral.addPresetFeed("r/Bitcoin", "https://www.reddit.com/r/Bitcoin/.rss")
        }
    }

    function addPresetFeed(name, url) {
        var currentFeeds = root.loadValue("feeds", []);
        // Check for duplicate URL
        for (var i = 0; i < currentFeeds.length; i++) {
            if (currentFeeds[i].url === url) {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Feed already added");
                }
                return;
            }
        }
        currentFeeds = currentFeeds.concat([{ name: name, url: url }]);
        root.saveValue("feeds", currentFeeds);
        if (typeof ToastService !== "undefined") {
            ToastService.showInfo("Added " + name);
        }
    }

    }
    // ===== /Tab: General =====

    // ===== Tab: Card =====
    Column {
        id: tabCard
        width: parent.width
        spacing: Theme.spacingM
        visible: root.activeTab === 1
        function loadValue() {
            for (var i = 0; i < children.length; i++)
                if (children[i].loadValue)
                    children[i].loadValue();
        }

    // ─── Appearance Settings ───

    StyledText {
        width: parent.width
        text: "Appearance"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "showName"
        label: "Show name on the card"
        description: "Display the widget's Name (the ‘Name’ field of this desktop widget) at the top-left of the card, before the filter tags."
        defaultValue: true
    }

    SliderSetting {
        settingKey: "fontSize"
        label: "Font Size"
        description: "Text size for feed items"
        defaultValue: Theme.fontSizeSmall
        minimum: 8
        maximum: 24
        unit: "px"
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: "Background Opacity"
        defaultValue: 60
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        id: borderToggle
        settingKey: "enableBorder"
        label: "Enable Border"
        defaultValue: false
    }

    SliderSetting {
        opacity: borderToggle.value ? 1.0 : 0.2
        enabled: borderToggle.value
        settingKey: "borderThickness"
        label: "Border Thickness"
        defaultValue: 1
        minimum: 1
        maximum: 10
        unit: "px"
    }

    SliderSetting {
        opacity: borderToggle.value ? 1.0 : 0.2
        enabled: borderToggle.value
        settingKey: "borderOpacity"
        label: "Border Opacity"
        defaultValue: 100
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SelectionSetting {
        opacity: borderToggle.value ? 1.0 : 0.2
        enabled: borderToggle.value
        settingKey: "borderColor"
        label: "Border Color"
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Surface", value: "surface" }
        ]
        defaultValue: "primary"
    }
    }
    // ===== /Tab: Card =====

    // ===== Tab: Ticker bar =====
    Column {
        id: tabTicker
        width: parent.width
        spacing: Theme.spacingM
        visible: root.activeTab === 2
        function loadValue() {
            for (var i = 0; i < children.length; i++)
                if (children[i].loadValue)
                    children[i].loadValue();
        }

    // ===== Ticker bar header =====
    StyledText {
        width: parent.width
        text: "Scrolling ticker bar"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "A dedicated full-width bar that scrolls these feeds' headlines. Click a headline to open it. Uses the same items as the desktop widget — no extra fetching."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "Prefer it INSIDE the main bar (a small scrolling widget among the clock/tray)? That's a separate plugin sharing the same feeds — open it below, enable it, then add it to a bar via Settings → Bar."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    DankButton {
        text: "Open ‘Dank RSS Ticker’ (bar widget) →"
        iconName: "open_in_new"
        onClicked: Quickshell.execDetached(["dms", "ipc", "call", "settings", "openWith", "plugins"])
    }

    // each setting below gets a per-setting reset icon (right gutter) when changed;
    // tickerSettingsGroup.resetAll() drives the global reset button at the bottom.
    // Inline (NOT a separate component file): DMS's plugin loader doesn't resolve
    // sibling .qml files as types, so a custom <ResettableSetting> wouldn't load.
    Item {
        id: tickerSettingsGroup
        width: parent.width
        implicitHeight: tickerCol.height
        height: tickerCol.height
        property var settingItems: []
        Component.onCompleted: {
            var arr = [];
            for (var i = 0; i < tickerCol.children.length; i++) {
                var c = tickerCol.children[i];
                if (c.value !== undefined && c.defaultValue !== undefined)
                    arr.push(c);
            }
            settingItems = arr;
        }
        function loadValue() {
            for (var i = 0; i < tickerCol.children.length; i++)
                if (tickerCol.children[i].loadValue)
                    tickerCol.children[i].loadValue();
        }
        function resetAll() {
            for (var i = 0; i < tickerCol.children.length; i++) {
                var c = tickerCol.children[i];
                if (c.value !== undefined && c.defaultValue !== undefined && c.settingKey !== "tickerBarEnabled")
                    c.value = c.defaultValue;
            }
        }

        Column {
            id: tickerCol
            width: parent.width - 34
            spacing: Theme.spacingM

    ToggleSetting {
        id: tickerToggle
        settingKey: "tickerBarEnabled"
        label: "Enable ticker bar"
        description: "Show the scrolling headline bar on the desktop. Turning this ON switches OFF the in-bar ‘Dank RSS Ticker’ pill — only one ticker can be active at a time."
        defaultValue: false
    }
    // mutual exclusion: enabling the desktop overlay turns off the bar pill plugin.
    // Use PluginService.savePluginData (not SettingsData.setPluginSetting) so it ALSO
    // emits pluginDataChanged → the pill actually reloads and collapses.
    Connections {
        target: tickerToggle
        function onValueChanged() {
            if (!tickerToggle.isInitialized)
                return
            if (tickerToggle.value)
                PluginService.savePluginData("dankRssTicker", "pillEnabled", false)
        }
    }

    ToggleSetting {
        id: hideCardSetting
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "hideDesktopView"
        label: "Hide the desktop card"
        description: "Keep only the scrolling bar (hides the on-desktop widget, the bar stays). Tip: also enable ‘Click-through’ so the empty area doesn’t catch clicks."
        defaultValue: false
    }
    // Stay in sync with the pill companion's identical "Hide the desktop card" toggle:
    // both write hideDesktopView on this instance via the same mechanism, but a plain
    // ToggleSetting only reads its value once — re-load it whenever the instance config
    // changes elsewhere (e.g. the pill flips it). loadValue() no-ops if already in sync.
    Connections {
        target: SettingsData
        function onDesktopWidgetInstancesChanged() { hideCardSetting.loadValue() }
    }

    StyledText {
        width: parent.width
        text: "Position: hold right-click on the bar and drag it (it magnet-snaps to the top, under the main bar, and to the screen bottom — both dock with space reserved; in between it floats behind windows)."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        id: widthSlider
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerWidthPct"
        label: "Bar width"
        description: "Width of the bar as a percentage of the screen"
        defaultValue: 100
        minimum: 10
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerBarHeight"
        label: "Bar height"
        defaultValue: 24
        minimum: 16
        maximum: 60
        unit: "px"
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerDockOffset"
        label: "Vertical offset (docked)"
        description: "Nudge the docked bar up/down to align its edge with the tiled windows (no overlap)."
        defaultValue: 0
        minimum: -24
        maximum: 24
        unit: "px"
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerBgOpacity"
        label: "Bar background opacity"
        defaultValue: 60
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerCornerRadius"
        label: "Corner radius"
        description: "Rounded corners of the bar"
        defaultValue: 0
        minimum: 0
        maximum: 30
        unit: "px"
    }

    ToggleSetting {
        id: tickerBorderToggle
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerBorderEnabled"
        label: "Border"
        defaultValue: false
    }

    SliderSetting {
        opacity: (tickerToggle.value && tickerBorderToggle.value) ? 1.0 : 0.2
        enabled: tickerToggle.value && tickerBorderToggle.value
        settingKey: "tickerBorderThickness"
        label: "Border thickness"
        defaultValue: 1
        minimum: 1
        maximum: 8
        unit: "px"
    }

    SliderSetting {
        opacity: (tickerToggle.value && tickerBorderToggle.value) ? 1.0 : 0.2
        enabled: tickerToggle.value && tickerBorderToggle.value
        settingKey: "tickerBorderOpacity"
        label: "Border opacity"
        defaultValue: 100
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SelectionSetting {
        opacity: (tickerToggle.value && tickerBorderToggle.value) ? 1.0 : 0.2
        enabled: tickerToggle.value && tickerBorderToggle.value
        settingKey: "tickerBorderColor"
        label: "Border color"
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Surface", value: "surface" }
        ]
        defaultValue: "primary"
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerTitleFontSize"
        label: "Title font size"
        defaultValue: 13
        minimum: 9
        maximum: 24
        unit: "px"
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerSourceFontSize"
        label: "Source font size"
        defaultValue: 13
        minimum: 9
        maximum: 24
        unit: "px"
    }

    StringSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerFontFamily"
        label: "Font family"
        description: "Leave blank to use the theme font"
        defaultValue: ""
        placeholder: "Inter Variable"
    }

    ToggleSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerSourceBold"
        label: "Bold source label"
        defaultValue: true
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerScrollSpeed"
        label: "Scroll speed"
        defaultValue: 40
        minimum: 10
        maximum: 160
        unit: "px/s"
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerItemSpacing"
        label: "Spacing between headlines"
        defaultValue: 48
        minimum: 12
        maximum: 160
        unit: "px"
    }

    SelectionSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerItemMode"
        label: "Items to show"
        description: "Latest N across all feeds, or a few per source (round-robin)."
        options: [
            { label: "Latest items (all feeds mixed)", value: "latest" },
            { label: "Per source (N each)", value: "perSource" }
        ]
        defaultValue: "latest"
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerMaxItems"
        label: "Max items (latest mode)"
        defaultValue: 10
        minimum: 5
        maximum: 80
        unit: ""
    }

    SliderSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerPerSourceCount"
        label: "Items per source (per-source mode)"
        defaultValue: 3
        minimum: 1
        maximum: 5
        unit: ""
    }

    // separator: inline (not StringSetting) so it applies LIVE as you type and is
    // capped at 3 chars / one emoji. Mimics the setting interface
    // (settingKey/value/defaultValue/loadValue) so the reset feature picks it up.
    Column {
        id: sepSetting
        property string settingKey: "tickerSeparator"
        property string defaultValue: "•"
        property string value: defaultValue
        property bool isInitialized: false
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        width: parent.width
        spacing: Theme.spacingS

        function findSettings() {
            var it = parent;
            while (it) {
                if (it.saveValue !== undefined && it.loadValue !== undefined)
                    return it;
                it = it.parent;
            }
            return null;
        }
        function loadValue() {
            var s = findSettings();
            if (s && s.pluginService) {
                if (sepField.activeFocus && isInitialized)
                    return;
                isInitialized = false;
                value = s.loadValue(settingKey, defaultValue);
                sepField.text = value;
                isInitialized = true;
            }
        }
        Component.onCompleted: Qt.callLater(loadValue)
        onValueChanged: {
            if (sepField.text !== value)
                sepField.text = value;
            if (!isInitialized)
                return;
            var s = findSettings();
            if (s)
                s.saveValue(settingKey, value);
        }

        StyledText {
            text: "Separator"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        StyledText {
            width: parent.width
            text: "Shown between headlines — up to 3 characters or one emoji, applied as you type."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }
        DankTextField {
            id: sepField
            width: parent.width
            maximumLength: 3
            placeholderText: "•"
            onTextEdited: sepSetting.value = text
        }
    }

    ToggleSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerShowSource"
        label: "Show source label"
        defaultValue: true
    }

    ToggleSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerPauseOnHover"
        label: "Pause on hover"
        defaultValue: true
    }

    ToggleSetting {
        opacity: tickerToggle.value ? 1.0 : 0.2
        enabled: tickerToggle.value
        settingKey: "tickerShowInOverview"
        label: "Show in overview"
        description: "Keep the bar visible while the compositor overview (exposé) is open. Turn off to hide it during the overview."
        defaultValue: true
    }
        }   // end tickerCol Column

        Repeater {
            model: tickerSettingsGroup.settingItems
            delegate: DankActionButton {
                required property var modelData
                anchors.right: tickerSettingsGroup.right
                y: modelData ? modelData.y + (modelData.height - height) / 2 : 0
                buttonSize: 28
                iconName: "undo"
                iconSize: 15
                iconColor: Theme.surfaceVariantText
                visible: modelData && modelData.value !== modelData.defaultValue && modelData.settingKey !== "tickerBarEnabled"
                onClicked: if (modelData) modelData.value = modelData.defaultValue
            }
        }
    }   // end tickerSettingsGroup Item

    DankButton {
        text: "Reset ticker bar to defaults"
        iconName: "restart_alt"
        onClicked: tickerSettingsGroup.resetAll()
    }
    }
    // ===== /Tab: Ticker bar =====
}
