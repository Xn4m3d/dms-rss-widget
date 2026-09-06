import QtQuick
import QtQuick.Layouts
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    // --- Settings from pluginData ---
    property var feeds: pluginData.feeds ?? []
    property int updateInterval: (pluginData.updateInterval ?? 30) * 60  // stored as minutes, used as seconds
    property int maxItems: pluginData.maxItems ?? 20
    property real backgroundOpacity: (pluginData.backgroundOpacity ?? 60) / 100
    property bool enableBorder: pluginData.enableBorder ?? false
    property int borderThickness: pluginData.borderThickness ?? 1
    property real borderOpacity: (pluginData.borderOpacity ?? 100) / 100
    property string borderColor: pluginData.borderColor ?? "primary"
    property bool showFeedName: pluginData.showFeedName ?? true
    property bool openInBrowser: pluginData.openInBrowser ?? true
    property bool showImages: pluginData.showImages ?? true
    property string sortMode: pluginData.sortMode ?? "newest"  // "newest", "oldest", "byFeed"
    property int maxPerFeed: pluginData.maxPerFeed ?? 5  // per-feed cap when grouping by feed
    property string viewMode: pluginData.viewMode ?? "expanded"  // "compact" or "expanded"
    property int fontSize: pluginData.fontSize ?? Theme.fontSizeSmall
    property bool notifyNewItems: pluginData.notifyNewItems ?? true
    // [patch:ui] show the instance "Name" (from the DMS desktop-widget settings)
    // on the card, left of the filter tags. Toggle to hide it.
    property bool showName: pluginData.showName ?? true
    readonly property string instanceName: root.instanceData ? (root.instanceData.name ?? "") : ""

    // [patch:tickerbar] optional full-width scrolling headline bar (a layer-shell
    // surface hosted by this desktop plugin). All options live here / in settings.
    property bool hideDesktopView: pluginData.hideDesktopView ?? false   // hide the on-desktop card, keep the bar
    property bool tickerBarEnabled: pluginData.tickerBarEnabled ?? false
    // single placement model: a full-screen top overlay; the strip is positioned via
    // the vertical % (docked at 0/100 = foreground + reserves space; detached in
    // between = background). No placement/layer picker (those were dropped).
    // [patch:tickerbar] reliable "below": position the bar explicitly just under
    // the main DankBar (mirrors its reserved height) instead of relying on
    // exclusive-zone stacking, which is unreliable for a window hosted inside the
    // desktop-widget surface.
    readonly property var _mainBar: (SettingsData.barConfigs && SettingsData.barConfigs.length > 0) ? SettingsData.barConfigs[0] : null
    readonly property int _mbInnerPad: _mainBar ? (_mainBar.innerPadding ?? 4) : 4
    readonly property real _mbWidgetThk: Math.max(20, 26 + _mbInnerPad * 0.6)
    readonly property real _mbThk: Math.max(_mbWidgetThk + _mbInnerPad + 4, Theme.barHeight - 4 - (8 - _mbInnerPad))
    // main bar edge: 0=top 1=bottom 2=left 3=right (number in barConfigs). Hidden / no
    // config → no reservation (the overlay just uses the full screen).
    readonly property int mbPosition: _mainBar ? (_mainBar.position ?? 0) : -1
    readonly property bool _mbVisible: _mainBar ? (_mainBar.visible ?? true) : false
    readonly property bool _mbVertical: _mbVisible && (mbPosition === 2 || mbPosition === 3)
    readonly property bool _mbAtBottom: _mbVisible && mbPosition === 1
    readonly property real _mbReserve: _mbVisible ? (_mbThk + (_mainBar.spacing ?? 4) + (_mainBar.bottomGap ?? 0)) : 0
    // only the bar's own edge is reserved; the ticker docks against it (or the screen edge)
    readonly property real mainBarReservedTop:    (_mbVisible && mbPosition === 0) ? _mbReserve : 0
    readonly property real mainBarReservedBottom: _mbAtBottom ? _mbReserve : 0
    readonly property real mainBarReservedLeft:   (_mbVisible && mbPosition === 2) ? _mbReserve : 0
    readonly property real mainBarReservedRight:  (_mbVisible && mbPosition === 3) ? _mbReserve : 0
    // which SCREEN edge the docked bar sits at (vPct 0 follows the main bar, so it flips
    // when the bar is at the bottom). Drives the foreground layer + the reservation spacer.
    readonly property bool tickerDockedScreenTop: (tickerVerticalPct < 1 && !_mbAtBottom) || (tickerVerticalPct > 99 && _mbAtBottom)
    readonly property bool tickerDockedScreenBottom: (tickerVerticalPct > 99 && !_mbAtBottom) || (tickerVerticalPct < 1 && _mbAtBottom)
    // When the main bar moves (or the docked edge flips) we DROP the reservation spacer
    // for a moment, then rebuild it once the main bar has re-settled at its new edge. Two
    // exclusive-zone surfaces racing for the same screen edge is what shoved the main bar
    // inward; recreating the spacer LAST (after the bar settles) makes it reserve ABOVE the
    // bar — the same reason the vertical-bar case (spacer dropped) and cold start both work.
    property bool _spacerSettling: false
    function _resettleSpacer() { root._spacerSettling = true; spacerSettleTimer.restart(); }
    onMbPositionChanged: root._resettleSpacer()
    onTickerDockedScreenTopChanged: root._resettleSpacer()
    Timer { id: spacerSettleTimer; interval: 600; onTriggered: root._spacerSettling = false }
    property int tickerBarHeight: pluginData.tickerBarHeight ?? 24
    property real tickerBgOpacity: (pluginData.tickerBgOpacity ?? 60) / 100
    property int tickerTitleFontSize: pluginData.tickerTitleFontSize ?? 13
    property int tickerSourceFontSize: pluginData.tickerSourceFontSize ?? 13
    property string tickerFontFamily: (pluginData.tickerFontFamily && pluginData.tickerFontFamily.length > 0) ? pluginData.tickerFontFamily : Theme.fontFamily
    property bool tickerSourceBold: pluginData.tickerSourceBold ?? true
    property int tickerScrollSpeed: pluginData.tickerScrollSpeed ?? 40
    property real tickerItemSpacing: pluginData.tickerItemSpacing ?? 48
    property string tickerItemMode: pluginData.tickerItemMode ?? "latest"          // "latest" | "perSource"
    property int tickerMaxItems: pluginData.tickerMaxItems ?? 10
    property int tickerPerSourceCount: pluginData.tickerPerSourceCount ?? 3
    property string tickerSeparator: pluginData.tickerSeparator ?? "•"
    property bool tickerShowSource: pluginData.tickerShowSource ?? true
    property bool tickerPauseOnHover: pluginData.tickerPauseOnHover ?? true
    property bool tickerHovered: false
    // [patch:tickerbar] size / position / style
    property real tickerWidthPct: pluginData.tickerWidthPct ?? 100         // % of screen width
    property real tickerHorizontalPct: pluginData.tickerHorizontalPct ?? 50   // 0=left .. 100=right (when width<100)
    property real tickerVerticalPct: pluginData.tickerVerticalPct ?? 0     // "below": 0=just under main bar .. 100=screen bottom
    // fine vertical nudge (px) applied only when DOCKED (top/bottom), to align the
    // bar's edge with the tiled windows. Reservation follows when nudging down.
    property int tickerDockOffset: pluginData.tickerDockOffset ?? 0
    // whether the bar stays visible while the compositor overview is open
    property bool tickerShowInOverview: pluginData.tickerShowInOverview ?? true
    // the ticker windows are top-level layer-shell surfaces; gate them on the instance
    // being enabled so disabling the widget also tears down the ticker (not just the card).
    readonly property bool _instanceEnabled: root.instanceData ? (root.instanceData.enabled !== false) : true
    property int tickerCornerRadius: pluginData.tickerCornerRadius ?? 0
    property bool tickerBorderEnabled: pluginData.tickerBorderEnabled ?? false
    property int tickerBorderThickness: pluginData.tickerBorderThickness ?? 1
    property real tickerBorderOpacity: (pluginData.tickerBorderOpacity ?? 100) / 100
    property string tickerBorderColor: pluginData.tickerBorderColor ?? "primary"
    readonly property color tickerResolvedBorderColor: {
        switch (root.tickerBorderColor) {
            case "secondary": return Theme.secondary;
            case "surface": return Theme.surfaceText;
            default: return Theme.primary;
        }
    }
    // pause scrolling while dragging position/size (avoids jank/latency)
    property bool _tickerAdjusting: false
    function _tickerMarkAdjusting() { root._tickerAdjusting = true; tickerAdjustTimer.restart(); }
    Timer { id: tickerAdjustTimer; interval: 350; onTriggered: root._tickerAdjusting = false }
    // live drag overrides: avoid persisting on every mouse move; persist on
    // release. -1 means "use the stored value".
    property real _tickerVLive: -1
    property real _tickerHLive: -1
    property real _tickerWLive: -1
    readonly property real effTickerVPct: _tickerVLive >= 0 ? _tickerVLive : root.tickerVerticalPct
    readonly property real effTickerHPct: _tickerHLive >= 0 ? _tickerHLive : root.tickerHorizontalPct
    readonly property real effTickerWPct: _tickerWLive >= 0 ? _tickerWLive : root.tickerWidthPct
    onTickerVerticalPctChanged: { _tickerVLive = -1; _tickerMarkAdjusting(); }
    onTickerHorizontalPctChanged: { _tickerHLive = -1; _tickerMarkAdjusting(); }
    onTickerWidthPctChanged: { _tickerWLive = -1; _tickerMarkAdjusting(); }
    onTickerBarHeightChanged: _tickerMarkAdjusting()
    // ticker edit mode (right-click held on the bar): drag = move, S = toggle
    // width 100/50%, left-click an edge = resize. State on root so the title
    // MouseAreas (inside an inline Component, where only `root` resolves) can
    // disable themselves while editing.
    property bool tickerEditing: false
    property bool tickerResizing: false
    property var tickerItems: []
    // [patch:tickerbar] derive the scrolling list from the in-memory feedItems
    // (no extra fetch) per the chosen item mode.
    function rebuildTicker() {
        var src = root.feedItems || [];
        if (root.tickerItemMode === "perSource") {
            var bySrc = {}, order = [];
            for (var i = 0; i < src.length; i++) {
                var s = src[i].source || "";
                if (!bySrc[s]) { bySrc[s] = []; order.push(s); }
                bySrc[s].push(src[i]);
            }
            var out = [];
            for (var k = 0; k < root.tickerPerSourceCount; k++)
                for (var o = 0; o < order.length; o++)
                    if (bySrc[order[o]][k]) out.push(bySrc[order[o]][k]);
            root.tickerItems = out;
        } else {
            root.tickerItems = src.slice(0, root.tickerMaxItems);
        }
    }
    onFeedItemsChanged: rebuildTicker()
    onTickerItemModeChanged: rebuildTicker()
    onTickerMaxItemsChanged: rebuildTicker()
    onTickerPerSourceCountChanged: rebuildTicker()

    // --- Internal state ---
    property var feedItems: []
    property bool isLoading: true   // [patch:resize] start loading -> resize/recreate shows a spinner, not the empty placeholder
    property int pendingFetches: 0
    property int _fetchSeq: 0   // [patch:dedup] run token; results from a superseded fetch are dropped
    property var windowRef: null
    property int previousItemCount: 0
    property var readLinks: ({})  // track clicked links

    // [patch:filter] source filter: "" = show all; a source name shows only that feed.
    property string activeFilter: ""
    // [patch:filter] unique source labels derived from the configured feeds (each = one tag)
    property var sources: {
        var seen = {};
        var list = [];
        for (var i = 0; i < root.feeds.length; i++) {
            var f = root.feeds[i];
            var label = (f && f.name && ("" + f.name).length) ? f.name : ((f && f.url) ? f.url : "");
            if (label && !seen[label]) { seen[label] = true; list.push(label); }
        }
        return list;
    }

    property color resolvedBorderColor: {
        switch (borderColor) {
            case "secondary": return Theme.secondary;
            case "surface": return Theme.surfaceText;
            default: return Theme.primary;
        }
    }

    // --- Lifecycle ---
    Component.onCompleted: {
        root.windowRef = Window.window ?? null;
        root.seedFromCache();   // [patch:cache] show last items instantly on recreate (resize/right-click)
        initialRunTimer.running = true;
    }

    // [patch:cache] persist fetched items so a recreated widget shows them instantly
    // (no blank) then refreshes in the background.
    property string _cacheFile: "~/.cache/dankNewsRssTicker-items.json"
    // Resolved (non-shell) form of the same path, for FileView — see writeCache().
    readonly property string _cachePath: Paths.strip(Paths.home) + "/.cache/dankNewsRssTicker-items.json"
    function isSafeUrl(u) { return typeof u === "string" && /^https?:\/\//i.test(u); }   // [patch:secure] scheme allowlist for open/Image/cache

    // [patch:overview] In Niri's "overview" (all-workspaces preview), selecting a workspace
    // delivers that click to this background layer-shell surface; in the surface's own
    // (unscaled) coords it can land on an item -> spurious xdg-open. Ignore clicks while in
    // overview, plus a short window after it closes (the close event and the pointer delivery
    // are async, so inOverview may already be false at click time).
    property bool _overviewGuard: false
    function _clickFromOverview() { return NiriService.inOverview || root._overviewGuard; }
    Connections {
        target: NiriService
        function onInOverviewChanged() {
            if (NiriService.inOverview)
                root._overviewGuard = true;
            else
                overviewReleaseTimer.restart();
        }
    }
    Timer {
        id: overviewReleaseTimer
        interval: 450
        onTriggered: root._overviewGuard = false
    }

    // [patch:opacity] Right-drag (= DMS desktop edit mode) + mouse wheel adjusts ONLY the card
    // background alpha. Tags / "Mark all read" / gear / feed text stay fully opaque (they are
    // children drawn over the withAlpha() fill, not affected by it). Live value with a debounced
    // persist to the instance config (backgroundOpacity is stored 0-100).
    property real liveBackgroundOpacity: -1   // -1 => use the pluginData value
    readonly property real effectiveBackgroundOpacity: liveBackgroundOpacity >= 0 ? liveBackgroundOpacity : root.backgroundOpacity
    onBackgroundOpacityChanged: root.liveBackgroundOpacity = -1   // resync after our persist / a settings-slider change
    function nudgeBackgroundOpacity(delta) {
        root.liveBackgroundOpacity = Math.max(0, Math.min(1, root.effectiveBackgroundOpacity + delta));
        opacityPersistTimer.restart();
    }
    Timer {
        id: opacityPersistTimer
        interval: 600
        onTriggered: if (root.liveBackgroundOpacity >= 0) root.setData("backgroundOpacity", Math.round(root.liveBackgroundOpacity * 100))
    }

    // [patch:tickerbar] same gesture for the ticker bar: right-hold + wheel tunes its opacity.
    property real tickerLiveBgOpacity: -1
    readonly property real effectiveTickerBgOpacity: tickerLiveBgOpacity >= 0 ? tickerLiveBgOpacity : root.tickerBgOpacity
    onTickerBgOpacityChanged: root.tickerLiveBgOpacity = -1
    function nudgeTickerBgOpacity(delta) {
        root.tickerLiveBgOpacity = Math.max(0, Math.min(1, root.effectiveTickerBgOpacity + delta));
        tickerOpacityPersistTimer.restart();
    }
    Timer {
        id: tickerOpacityPersistTimer
        interval: 600
        onTriggered: if (root.tickerLiveBgOpacity >= 0) root.setData("tickerBgOpacity", Math.round(root.tickerLiveBgOpacity * 100))
    }

    function seedFromCache() {
        Proc.runCommand("rssCacheRead", ["sh", "-c", "cat " + root._cacheFile + " 2>/dev/null"], function(out, code) {
            // The widget is recreated on resize / right-click, so this async callback can
            // land after the old instance is gone — feedModel is then null and touching
            // .count threw, losing the seed and logging a TypeError.
            if (!feedModel) return;
            if (feedModel.count > 0) return;
            if (code !== 0 || !out || !out.trim()) return;
            try {
                var items = JSON.parse(out);
                if (!items || !items.length) return;
                root.feedItems = items;
                root.rebuildModel();   // [patch:filter]
            } catch (e) {}
        });
    }
    // [patch:cache-write] This used to shell out to
    //     sh -c 'mkdir -p ~/.cache && printf %s "$1" > <file>'   with the whole JSON as $1.
    // Linux caps a SINGLE argv entry at MAX_ARG_STRLEN (128 KiB), so past roughly five or six
    // feeds the exec failed with E2BIG ("Process failed to start") and the cache silently kept
    // stale contents — and the bar pill, which only ever reads this file, showed a partial set.
    // FileView has no argv limit and writes atomically.
    property bool _cacheDirReady: false
    FileView {
        id: cacheWriter
        path: root._cachePath
        atomicWrites: true
        blockWrites: true
        printErrors: false
    }
    function writeCache(items) {
        if (!root._cacheDirReady) {
            Paths.mkdir(Paths.strip(Paths.home) + "/.cache");
            root._cacheDirReady = true;
        }
        cacheWriter.setText(JSON.stringify(items || []));
    }

    onVisibleChanged: root.handleVisibilityChange()
    onWidgetWidthChanged: root.handleVisibilityChange()
    onWidgetHeightChanged: root.handleVisibilityChange()

    Component.onDestruction: {
        timer.running = false;
    }

    function isRunnable() {
        const win = root.windowRef;
        const winVisible = win === null ? true : !!win.visible;
        return root.visible && winVisible && root.widgetWidth > 0 && root.widgetHeight > 0;
    }

    onFeedsChanged: {
        // an explicit feed change (add/edit/remove from settings) must apply live, even
        // if the widget isn't currently "runnable" (e.g. the settings modal covers it) —
        // so force the refetch instead of gating it on isRunnable().
        fetchAllFeeds(true);
        timer.restart();
    }

    function handleVisibilityChange() {
        if (root.isRunnable()) {
            if (!timer.running && root.feeds.length > 0) {
                fetchAllFeeds();
                timer.running = true;
            }
        } else {
            timer.running = false;
        }
    }

    // [patch:filter] (re)build the visible model from the master feedItems list,
    // applying the active source filter.
    function rebuildModel() {
        feedModel.clear();
        var items = root.feedItems || [];
        var shown = 0;
        for (var i = 0; i < items.length && shown < root.maxItems; i++) {   // [patch:filter] maxItems cap applied AFTER the source filter (per view)
            if (root.activeFilter === "" || items[i].source === root.activeFilter) {
                feedModel.append(items[i]);
                shown++;
            }
        }
    }

    onActiveFilterChanged: {
        root.rebuildModel();
        if (root.activeFilter !== "")
            filterResetTimer.restart();   // [patch:filter] auto-clear after 120 s
        else
            filterResetTimer.stop();
    }

    // --- Timers ---
    Timer {
        id: timer
        interval: root.updateInterval * 1000
        repeat: true
        running: false
        onTriggered: root.fetchAllFeeds()
    }

    Timer {
        id: initialRunTimer
        interval: 150   // [patch:resize] was 1500 — re-fetch fast after a resize-triggered recreate
        repeat: false
        running: false
        onTriggered: root.handleVisibilityChange()
    }

    // [patch:filter] a source filter auto-clears after 120 s so the widget always
    // returns to showing every feed.
    Timer {
        id: filterResetTimer
        interval: 120000
        repeat: false
        running: false
        onTriggered: root.activeFilter = ""
    }

    // --- Feed fetching ---
    function fetchAllFeeds(force) {
        if (!force && !root.isRunnable()) return;
        if (root.feeds.length === 0) {
            root.feedItems = [];
            feedModel.clear();
            return;
        }

        root.isLoading = true;
        var seq = ++root._fetchSeq;   // [patch:dedup] token for this run; older in-flight runs are dropped
        root.pendingFetches = root.feeds.length;
        var allItems = [];

        for (var i = 0; i < root.feeds.length; i++) {
            fetchFeed(i, allItems, seq);
        }
    }

    function fetchFeed(index, collector, seq) {
        var feed = root.feeds[index];
        var url = feed.url || "";
        var name = feed.name || url;

        if (!url) {
            if (seq === root._fetchSeq) {   // [patch:dedup] ignore stale runs
                root.pendingFetches--;
                if (root.pendingFetches <= 0) finalizeFetch(collector);
            }
            return;
        }

        // [patch:dedup] null id => a unique Proc per call. Reusing "rssFetch:"+index across
        // overlapping runs let the 2nd run mutate the shared, persistent debounce entry that the
        // 1st (already-launched) proc still referenced, so one feed's items got pushed twice.
        Proc.runCommand(null, ["curl", "-sS", "--connect-timeout", "5", "--max-time", "10", "-L", "--proto", "=http,https", "--proto-redir", "=http,https", "--max-redirs", "5", "--max-filesize", "5000000", "-A", "Mozilla/5.0 (X11; Linux x86_64) DankRssWidget/1.0", url], function(output, exitCode) {  // [patch:secure] http(s) only, bound redirects + size
            if (!root || seq !== root._fetchSeq)   // [patch:dedup] drop stale results — or bail if the component was torn down mid-fetch (root null)
                return;
            if (exitCode === 0 && output && output.trim().length > 0) {
                var body = (output.length > 5000000) ? output.slice(0, 5000000) : output;  // [patch:secure] bound XML size (ReDoS)
                var items = parseFeed(body, name);
                for (var j = 0; j < items.length; j++) {
                    collector.push(items[j]);
                }
            }

            root.pendingFetches--;
            if (root.pendingFetches <= 0) {
                finalizeFetch(collector);
            }
        });
    }

    function finalizeFetch(items) {
        // [patch:dedup] de-duplicate by link (safety net against overlapping fetches or a feed repeating an item)
        var _seen = {};
        var _uniq = [];
        for (var d = 0; d < items.length; d++) {
            var _k = items[d].link || ("#" + d);
            if (!_seen[_k]) { _seen[_k] = true; _uniq.push(items[d]); }
        }
        items = _uniq;

        // Sort based on sortMode
        if (root.sortMode === "oldest") {
            items.sort(function(a, b) { return a.timestamp - b.timestamp; });
        } else if (root.sortMode === "byFeed") {
            // Sort newest within each feed first, then apply per-feed cap
            items.sort(function(a, b) { return b.timestamp - a.timestamp; });
            var feedCounts = {};
            items = items.filter(function(item) {
                var src = item.source || "";
                feedCounts[src] = (feedCounts[src] || 0) + 1;
                return feedCounts[src] <= root.maxPerFeed;
            });
            // Then group by source name
            items.sort(function(a, b) {
                if (a.source < b.source) return -1;
                if (a.source > b.source) return 1;
                return b.timestamp - a.timestamp;
            });
        } else {
            // "newest" — default
            items.sort(function(a, b) { return b.timestamp - a.timestamp; });
        }

        // [patch:filter] Do NOT cap to maxItems here. feedItems is the master list across all
        // sources; a global cap before filtering lets a high-volume feed (e.g. Hacker News)
        // crowd out a quiet one (e.g. Merox) entirely -> filtering the quiet source shows
        // nothing even though it was fetched. The maxItems cap is applied per-view in
        // rebuildModel(), AFTER the source filter. (Feeds are self-bounded, so this stays small.)

        // Notify on new items
        if (root.notifyNewItems && root.previousItemCount > 0 && items.length > root.previousItemCount) {
            var newCount = items.length - root.previousItemCount;
            if (typeof ToastService !== "undefined") {
                ToastService.showInfo(newCount + " new item" + (newCount > 1 ? "s" : "") + " in RSS Feeds");
            }
        }
        root.previousItemCount = items.length;

        root.feedItems = items;
        root.rebuildModel();   // [patch:filter] populate model honoring the active source filter
        root.isLoading = false;
        if (items.length > 0) root.writeCache(items);   // [patch:cache]
    }

    // --- XML Parsing ---
    function parseFeed(xml, sourceName) {
        // Auto-detect: Atom feeds contain <feed, RSS feeds contain <rss or <channel
        if (xml.indexOf("<feed") !== -1) {
            return parseAtomFeed(xml, sourceName);
        }
        return parseRssFeed(xml, sourceName);
    }

    function parseRssFeed(xml, sourceName) {
        var items = [];
        var itemRegex = /<item[\s>]([\s\S]*?)<\/item>/gi;
        var match;

        while ((match = itemRegex.exec(xml)) !== null) {
            var block = match[1];
            var title = extractTag(block, "title");
            var link = extractTag(block, "link");
            var description = extractTag(block, "description");
            var pubDate = extractTag(block, "pubDate");

            if (!title && !link) continue;

            items.push({
                title: cleanText(title || "Untitled"),
                link: link || "",
                description: cleanText(stripHtml(description || "")),
                dateStr: pubDate || "",
                timestamp: pubDate ? new Date(pubDate).getTime() || 0 : 0,
                source: sourceName,
                relativeTime: pubDate ? getRelativeTime(new Date(pubDate)) : "",
                imageUrl: extractImageUrl(block, description || "")
            });
        }
        return items;
    }

    function parseAtomFeed(xml, sourceName) {
        var items = [];
        var entryRegex = /<entry[\s>]([\s\S]*?)<\/entry>/gi;
        var match;

        while ((match = entryRegex.exec(xml)) !== null) {
            var block = match[1];
            var title = extractTag(block, "title");
            var summary = extractTag(block, "summary") || extractTag(block, "content");
            var updated = extractTag(block, "updated") || extractTag(block, "published");

            // Atom links use href attribute
            var linkMatch = block.match(/<link[^>]*href=["']([^"']+)["'][^>]*\/?>/i);
            // Prefer alternate link
            var altLinkMatch = block.match(/<link[^>]*rel=["']alternate["'][^>]*href=["']([^"']+)["'][^>]*\/?>/i);
            var link = altLinkMatch ? altLinkMatch[1] : (linkMatch ? linkMatch[1] : "");

            if (!title && !link) continue;

            items.push({
                title: cleanText(title || "Untitled"),
                link: link,
                description: cleanText(stripHtml(summary || "")),
                dateStr: updated || "",
                timestamp: updated ? new Date(updated).getTime() || 0 : 0,
                source: sourceName,
                relativeTime: updated ? getRelativeTime(new Date(updated)) : "",
                imageUrl: extractImageUrl(block, summary || "")
            });
        }
        return items;
    }

    function extractImageUrl(block, content) {
        var url = "";

        // Try media:thumbnail (Reddit, many feeds)
        var m = block.match(/<media:thumbnail[^>]*url=["']([^"']+)["']/i);
        if (m) { url = m[1]; }

        // Try media:content with image type
        if (!url) {
            m = block.match(/<media:content[^>]*url=["']([^"']+)["'][^>]*type=["']image\//i);
            if (m) url = m[1];
        }

        // Try media:content (any, often images)
        if (!url) {
            m = block.match(/<media:content[^>]*url=["']([^"']+)["']/i);
            if (m) url = m[1];
        }

        // Try enclosure with image type
        if (!url) {
            m = block.match(/<enclosure[^>]*type=["']image\/[^"']*["'][^>]*url=["']([^"']+)["']/i);
            if (m) url = m[1];
        }
        if (!url) {
            m = block.match(/<enclosure[^>]*url=["']([^"']+)["'][^>]*type=["']image\//i);
            if (m) url = m[1];
        }

        // Try <img> tag in content/description
        if (!url) {
            var decoded = content.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&");
            m = decoded.match(/<img[^>]*src=["']([^"']+)["']/i);
            if (m) url = m[1];
        }

        // Decode HTML entities in the URL itself
        if (url) {
            url = url.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"');
        }

        return url;
    }

    function extractTag(xml, tagName) {
        // Match both regular content and CDATA sections
        var regex = new RegExp("<" + tagName + "[^>]*>\\s*(?:<!\\[CDATA\\[([\\s\\S]*?)\\]\\]>|([\\s\\S]*?))\\s*<\\/" + tagName + ">", "i");
        var match = xml.match(regex);
        if (match) {
            return (match[1] !== undefined ? match[1] : match[2]) || "";
        }
        return "";
    }

    function cleanText(text) {
        if (!text) return "";
        // Decode common HTML entities
        text = text.replace(/&amp;/g, "&");
        text = text.replace(/&lt;/g, "<");
        text = text.replace(/&gt;/g, ">");
        text = text.replace(/&quot;/g, '"');
        text = text.replace(/&#39;/g, "'");
        text = text.replace(/&apos;/g, "'");
        text = text.replace(/&#x([0-9a-fA-F]+);/g, function(m, hex) {
            return String.fromCharCode(parseInt(hex, 16));
        });
        text = text.replace(/&#(\d+);/g, function(m, dec) {
            return String.fromCharCode(parseInt(dec, 10));
        });
        // Collapse whitespace
        text = text.replace(/\s+/g, " ").trim();
        return text;
    }

    function stripHtml(text) {
        if (!text) return "";
        return text.replace(/<[^>]+>/g, "");
    }

    function getRelativeTime(date) {
        if (!date || isNaN(date.getTime())) return "";
        var now = new Date();
        var diff = Math.floor((now.getTime() - date.getTime()) / 1000);

        if (diff < 60) return "just now";
        if (diff < 3600) return Math.floor(diff / 60) + "m ago";
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
        if (diff < 604800) return Math.floor(diff / 86400) + "d ago";
        return date.toLocaleDateString();
    }

    // --- Data model ---
    ListModel {
        id: feedModel
    }

    // --- UI ---
    Rectangle {
        anchors.fill: parent
        visible: !root.hideDesktopView   // [patch:tickerbar] hide the on-desktop card while keeping the bar alive
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, root.effectiveBackgroundOpacity)   // [patch:opacity] live-tunable card fill
        border.width: root.enableBorder ? root.borderThickness : 0
        border.color: Theme.withAlpha(root.resolvedBorderColor, root.borderOpacity * root.effectiveBackgroundOpacity)   // [patch:opacity] border fades with the card
        clip: true

        // [patch:opacity] wheel-while-right-held (= DMS drag/edit mode) tunes the card opacity.
        // Sits on top (z) so it sees the wheel BEFORE the ListView; NoButton + hoverEnabled:false
        // => never steals clicks/hover. Passes the wheel through (accepted=false) unless the
        // right button is held, so a plain wheel still scrolls the list.
        MouseArea {
            anchors.fill: parent
            z: 100
            acceptedButtons: Qt.NoButton
            hoverEnabled: false
            onWheel: wheel => {
                if (wheel.buttons & Qt.RightButton) {
                    root.nudgeBackgroundOpacity(wheel.angleDelta.y > 0 ? 0.04 : -0.04);
                    wheel.accepted = true;
                } else {
                    wheel.accepted = false;
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            // --- Top bar --- [patch:ui][patch:filter] no item-count title bar.
            // Left: clickable source tags (filter). Right: "Mark all read" then ⚙️ settings.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                // [patch:ui] instance "Name" (from DMS desktop-widget settings), left of the tags
                StyledText {
                    visible: root.showName && root.instanceName.length > 0
                    text: root.instanceName
                    font.pixelSize: root.fontSize
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    Layout.maximumWidth: 140
                    Layout.alignment: Qt.AlignVCenter
                }

                // [patch:filter] One tag per source. Click a tag to show only that feed for
                // 120 s (then it auto-resets to all). Scrolls horizontally when many feeds.
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    contentWidth: tagRow.implicitWidth
                    contentHeight: height
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.sources.length > 0

                    Row {
                        id: tagRow
                        height: parent.height
                        spacing: Theme.spacingXS

                        // "✕ All" reset chip — only while a filter is active
                        Rectangle {
                            visible: root.activeFilter !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            height: 22
                            width: allChipText.implicitWidth + Theme.spacingM
                            radius: height / 2
                            color: Theme.withAlpha(Theme.primary, 0.25)
                            border.width: 1
                            border.color: Theme.primary

                            StyledText {
                                id: allChipText
                                anchors.centerIn: parent
                                text: "✕ All"
                                font.pixelSize: root.fontSize - 2
                                color: Theme.primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root._clickFromOverview()) return;   // [patch:overview]
                                    root.activeFilter = "";
                                }
                            }
                        }

                        Repeater {
                            model: root.sources

                            Rectangle {
                                id: tagChip
                                required property string modelData
                                property bool active: root.activeFilter === modelData

                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                width: Math.min(chipText.implicitWidth, 140) + Theme.spacingM
                                radius: height / 2
                                color: active ? Theme.withAlpha(Theme.primary, 0.25)
                                              : (chipArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15)
                                                                        : Theme.surfaceContainerHigh)
                                border.width: active ? 1 : 0
                                border.color: Theme.primary

                                StyledText {
                                    id: chipText
                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, 140)
                                    text: tagChip.modelData
                                    font.pixelSize: root.fontSize - 2
                                    color: tagChip.active ? Theme.primary : Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root._clickFromOverview()) return;   // [patch:overview]
                                        // toggle: clicking the active tag returns to "all"
                                        root.activeFilter = (root.activeFilter === tagChip.modelData) ? "" : tagChip.modelData;
                                    }
                                }
                            }
                        }
                    }
                }

                // keep the right-side buttons pinned to the edge when there are no tags
                Item { Layout.fillWidth: true; visible: root.sources.length === 0 }

                // Mark all read / unread toggle
                Rectangle {
                    visible: feedModel.count > 0

                    property bool allRead: {
                        if (feedModel.count === 0) return false;
                        for (var i = 0; i < feedModel.count; i++) {
                            if (!root.readLinks[feedModel.get(i).link]) return false;
                        }
                        return true;
                    }

                    width: allReadRow.implicitWidth + Theme.spacingM * 2
                    height: 24; radius: Theme.cornerRadius
                    color: markAllArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                    RowLayout {
                        id: allReadRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: parent.parent.allRead ? "remove_done" : "done_all"
                            size: 14
                            color: markAllArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        }

                        StyledText {
                            text: parent.parent.allRead ? "Mark all unread" : "Mark all read"
                            font.pixelSize: root.fontSize - 2
                            color: markAllArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        }
                    }

                    MouseArea {
                        id: markAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.allRead) {
                                root.readLinks = ({});
                            } else {
                                var newRead = Object.assign({}, root.readLinks);
                                for (var i = 0; i < feedModel.count; i++) {
                                    var link = feedModel.get(i).link;
                                    if (link) newRead[link] = true;
                                }
                                root.readLinks = newRead;
                            }
                        }
                    }
                }

                // [patch:ui] ⚙️ settings — moved to the RIGHT of "Mark all read".
                Rectangle {
                    width: 28
                    height: 28
                    radius: Theme.cornerRadius
                    color: manageArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "settings"
                        size: 16
                        color: manageArea.containsMouse ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: manageArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root._clickFromOverview()) return;   // [patch:overview]
                            Quickshell.execDetached(["dms", "ipc", "call", "settings", "focusOrToggleWith", "desktop_widgets"]);
                        }
                    }
                }
            }

            // --- Separator ---
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outlineVariant
            }

            // --- Feed list ---
            ListView {
                id: feedListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: root.viewMode === "compact" ? 1 : Theme.spacingXS
                model: feedModel
                visible: feedModel.count > 0

                delegate: Rectangle {
                    id: itemDelegate
                    property bool isRead: root.readLinks[model.link] === true

                    width: feedListView.width
                    height: itemColumn.implicitHeight + Theme.spacingS * 2
                    radius: root.viewMode === "compact" ? 0 : Theme.cornerRadius
                    opacity: isRead ? 0.5 : 1.0
                    color: itemMouseArea.containsMouse
                        ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.95)   // [patch:opacity] hover reveals a readable backing even when the card is transparent
                        : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.shortDuration }
                    }

                    RowLayout {
                        id: itemColumn
                        anchors.fill: parent
                        anchors.margins: root.viewMode === "compact" ? Theme.spacingXS : Theme.spacingS
                        spacing: Theme.spacingS

                        // Text content
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.viewMode === "compact" ? 0 : 2

                            // Source + Title row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                StyledText {
                                    visible: root.showFeedName
                                    text: model.source || ""
                                    font.pixelSize: root.fontSize
                                    font.weight: Font.Medium
                                    color: isRead ? Theme.surfaceVariantText : Theme.primary
                                    Layout.maximumWidth: 120
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    visible: root.showFeedName
                                    text: "\u00b7"
                                    font.pixelSize: root.fontSize
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: model.title || ""
                                    font.pixelSize: root.fontSize
                                    font.weight: Font.Medium
                                    color: isRead ? Theme.surfaceVariantText : Theme.surfaceText
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    wrapMode: Text.NoWrap
                                }

                                // Compact mode: inline date
                                StyledText {
                                    visible: root.viewMode === "compact" && (model.relativeTime || "") !== ""
                                    text: model.relativeTime || ""
                                    font.pixelSize: root.fontSize - 2
                                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.7)
                                }
                            }

                            // Description (hidden in compact mode)
                            StyledText {
                                visible: root.viewMode !== "compact" && (model.description || "") !== ""
                                text: model.description || ""
                                font.pixelSize: root.fontSize
                                color: Theme.surfaceVariantText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }

                            // Date (hidden in compact mode — shown inline instead)
                            StyledText {
                                visible: root.viewMode !== "compact" && (model.relativeTime || "") !== ""
                                text: model.relativeTime || ""
                                font.pixelSize: root.fontSize - 2
                                color: Theme.withAlpha(Theme.surfaceVariantText, 0.7)
                            }
                        }

                        // Thumbnail (hidden in compact mode)
                        Rectangle {
                            id: thumbRect
                            visible: root.viewMode !== "compact" && root.showImages && root.isSafeUrl(model.imageUrl) && thumbImage.status !== Image.Error   // [patch:secure] http(s) only
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            clip: true

                            Image {
                                id: thumbImage
                                anchors.fill: parent
                                source: (root.showImages && root.isSafeUrl(model.imageUrl)) ? model.imageUrl : ""   // [patch:secure] http(s) only
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root._clickFromOverview()) return;   // [patch:overview] ignore overview-select clicks
                            if (!model.link) return;
                            var newRead = Object.assign({}, root.readLinks);

                            if (newRead[model.link]) {
                                // Already read: toggle back to unread
                                delete newRead[model.link];
                                root.readLinks = newRead;
                            } else {
                                // Unread: mark read + open link
                                newRead[model.link] = true;
                                root.readLinks = newRead;

                                if (root.openInBrowser) {
                                    if (root.isSafeUrl(model.link)) {   // [patch:secure] only open http(s) links
                                        Quickshell.execDetached(["xdg-open", model.link]);
                                    } else if (typeof ToastService !== "undefined") {
                                        ToastService.showError("Blocked a non-http(s) link");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- Empty state ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: feedModel.count === 0 && !root.isLoading
                spacing: Theme.spacingS

                Item { Layout.fillHeight: true }

                DankIcon {
                    name: "rss_feed"
                    size: Theme.iconSize * 2
                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.4)
                    Layout.alignment: Qt.AlignHCenter
                }

                StyledText {
                    text: root.feeds.length === 0 ? "No feeds configured" : "No items loaded"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    visible: root.feeds.length === 0
                    text: "Add feeds in the widget settings"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.6)
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillHeight: true }
            }

            // --- Loading state ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: feedModel.count === 0 && root.isLoading
                spacing: Theme.spacingS

                Item { Layout.fillHeight: true }

                DankIcon {   // [patch:ui] real animated spinner (was static text only)
                    name: "progress_activity"
                    size: Theme.iconSize
                    color: Theme.surfaceVariantText
                    Layout.alignment: Qt.AlignHCenter
                    NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: true }
                }

                StyledText {
                    text: "Loading feeds..."
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // [patch:tickerbar] the optional full-width scrolling headline bar.
    // Gated on tickerBarEnabled + a real on-desktop instance (so it never
    // spawns from a non-instance/global context). Reuses root.feedItems.
    Variants {
        model: (root.tickerBarEnabled && root.isInstance && root._instanceEnabled) ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData

            id: win
            // docked = stuck right under the main bar (vertical position ~0) or at the
            // screen bottom (~100). Based on the STORED value so the layer settles on
            // release (not during a live drag, which can't re-commit a surface mid-grab).
            readonly property bool dockedTop: root.tickerDockedScreenTop
            readonly property bool dockedBottom: root.tickerDockedScreenBottom
            readonly property bool docked: dockedTop || dockedBottom
            onDockedChanged: win._recommit()

            WlrLayershell.namespace: "dms:rss-ticker-bar"
            // docked → Top (above normal windows; bar popouts/menus that open afterwards
            // stack above it, so they're not covered) + a reservation spacer. detached
            // (floating) → Bottom (behind windows).
            WlrLayershell.layer: win.docked ? WlrLayer.Top : WlrLayer.Bottom
            // proven DMS pattern (cf. desktop-widget grid 'G' key): Exclusive
            // keyboard focus while editing (OnDemand when Hyprland uses a focus
            // grab), so the 'S' key reaches us.
            WlrLayershell.keyboardFocus: {
                if (root.tickerEditing)
                    return CompositorService.useHyprlandFocusGrab ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive;
                return WlrKeyboardFocus.None;
            }

            color: "transparent"
            // A full-screen transparent overlay; the strip is positioned by QML at the
            // main bar's height — deterministic, unlike layer-shell exclusive-zone
            // stacking which raced/overlapped here. A separate spacer window reserves
            // the docked strip's height.
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            margins.bottom: 0
            implicitHeight: win.screen ? win.screen.height : 1080
            exclusiveZone: -1
            // Only the visible strip captures input; the rest of a full-screen
            // "below" overlay is click-through.
            mask: Region { item: tickerStrip }

            // Re-commit the layer-shell surface when the layer/placement changes
            // live — otherwise the compositor keeps the old layer (e.g. a top bar
            // switched from "background" stays stuck behind windows).
            function _recommit() {
                win.visible = false;
                recommitTimer.restart();
            }
            Timer {
                id: recommitTimer
                interval: 40
                onTriggered: win.visible = true
            }
            // re-commit when the docked SCREEN edge flips (main bar moved, or the bar
            // re-commit when the main bar moves — the full-screen overlay can otherwise get
            // stuck on a live position switch (e.g. the strip vanishing after right→top).
            Connections {
                target: root
                function onMbPositionChanged() { win._recommit(); }
            }

            HyprlandFocusGrab {
                active: CompositorService.isHyprland && root.tickerEditing
                windows: [win]
            }

            Item {
                id: tickerStrip
                // hide while the compositor overview is open, unless allowed
                visible: !(NiriService.inOverview && !root.tickerShowInOverview)
                // horizontal band: leave room for a left/right main bar (full width otherwise)
                readonly property real _bandLeft: root.mainBarReservedLeft
                readonly property real _bandWidth: Math.max(80, win.width - root.mainBarReservedLeft - root.mainBarReservedRight)
                width: Math.round(_bandWidth * (root.effTickerWPct / 100))
                x: Math.round(_bandLeft + (_bandWidth - width) * (root.effTickerHPct / 100))
                height: root.tickerBarHeight
                // vertical band between the top/bottom reservations. vPct 0 = docked against
                // the main bar (or the screen top if the bar is on a side); 100 = far edge.
                // When the main bar is at the bottom the direction flips so the ticker
                // "follows" it (docks just above it).
                y: {
                    var bandTop = root.mainBarReservedTop;
                    var bandBottom = win.height - root.mainBarReservedBottom;
                    var avail = Math.max(0, bandBottom - bandTop - root.tickerBarHeight);
                    var base = root._mbAtBottom
                        ? (bandBottom - root.tickerBarHeight) - avail * (root.effTickerVPct / 100)
                        : bandTop + avail * (root.effTickerVPct / 100);
                    if (win.docked)
                        base += root.tickerDockOffset;
                    return Math.round(Math.max(0, Math.min(win.height - root.tickerBarHeight, base)));
                }

            Rectangle {
                anchors.fill: parent
                radius: root.tickerCornerRadius
                color: Theme.withAlpha(Theme.surfaceContainer, root.effectiveTickerBgOpacity)
                border.width: root.tickerBorderEnabled ? root.tickerBorderThickness : 0
                border.color: Theme.withAlpha(root.tickerResolvedBorderColor, root.tickerBorderOpacity)
            }

            // [patch:tickerbar] edit mode — sits UNDER the headlines (which keep
            // their own click-to-open MouseAreas, disabled while editing). Right
            // press = grab (titles ignore right → it falls through here).
            MouseArea {
                id: editArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: root.tickerResizing ? Qt.SizeHorCursor : (root.tickerEditing ? Qt.SizeAllCursor : Qt.ArrowCursor)

                property real grabDX: 0
                property real grabDY: 0
                property real grabLeft: 0
                readonly property int resizeZone: 22

                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.tickerEditing = true;
                        root.tickerHovered = true;
                        keyCatcher.forceActiveFocus();
                        root._tickerMarkAdjusting();
                        if (mouse.x > tickerStrip.width - editArea.resizeZone) {
                            // bottom-right edge → resize width (left edge stays fixed)
                            root.tickerResizing = true;
                            editArea.grabLeft = tickerStrip.x;
                        } else {
                            root.tickerResizing = false;
                            var g = editArea.mapToItem(null, mouse.x, mouse.y);
                            editArea.grabDX = g.x - tickerStrip.x;
                            editArea.grabDY = g.y - tickerStrip.y;
                        }
                        mouse.accepted = true;
                    } else {
                        mouse.accepted = false;
                    }
                }

                onPositionChanged: mouse => {
                    if (!root.tickerEditing)
                        return;
                    var g = editArea.mapToItem(null, mouse.x, mouse.y);
                    root._tickerMarkAdjusting();
                    if (root.tickerResizing) {
                        // width only within the horizontal band; left edge fixed (adjust hPct),
                        // magnet → full band width.
                        var bandLeft = root.mainBarReservedLeft;
                        var bandW = Math.max(80, win.width - root.mainBarReservedLeft - root.mainBarReservedRight);
                        var bandRight = bandLeft + bandW;
                        var minW = Math.max(120, bandW * 0.10);
                        var newW = Math.max(minW, Math.min(bandW, Math.min(bandRight, g.x) - editArea.grabLeft));
                        var wpct = newW / bandW * 100;
                        if (wpct >= 95) {
                            root._tickerWLive = 100;
                            root._tickerHLive = 0;
                        } else {
                            root._tickerWLive = wpct;
                            var denomW = Math.max(1, bandW - newW);
                            root._tickerHLive = Math.max(0, Math.min(100, (editArea.grabLeft - bandLeft) / denomW * 100));
                        }
                        return;
                    }
                    var bandTop = root.mainBarReservedTop;
                    var bandBottom = win.height - root.mainBarReservedBottom;
                    var availY = Math.max(1, bandBottom - bandTop - root.tickerBarHeight);
                    var yTop = (g.y - editArea.grabDY);   // the strip's new top edge
                    var vraw = root._mbAtBottom
                        ? Math.max(0, Math.min(100, ((bandBottom - root.tickerBarHeight) - yTop) / availY * 100))
                        : Math.max(0, Math.min(100, (yTop - bandTop) / availY * 100));
                    var snap = 3;   // tight magnet: snaps to the main bar (0) / far edge (100) only when close
                    if (vraw < snap)
                        vraw = 0;
                    else if (vraw > 100 - snap)
                        vraw = 100;
                    root._tickerVLive = vraw;
                    if (root.effTickerWPct < 100) {
                        var bandLeft = root.mainBarReservedLeft;
                        var bandW = Math.max(80, win.width - root.mainBarReservedLeft - root.mainBarReservedRight);
                        var availX = Math.max(1, bandW - tickerStrip.width);
                        root._tickerHLive = Math.max(0, Math.min(100, ((g.x - editArea.grabDX) - bandLeft) / availX * 100));
                    }
                }

                onReleased: mouse => {
                    if (mouse.button === Qt.RightButton && root.tickerEditing) {
                        if (root._tickerVLive >= 0) root.setData("tickerVerticalPct", Math.round(root._tickerVLive));
                        if (root._tickerHLive >= 0) root.setData("tickerHorizontalPct", Math.round(root._tickerHLive));
                        if (root._tickerWLive >= 0) root.setData("tickerWidthPct", Math.round(root._tickerWLive));
                        root.tickerResizing = false;
                        root.tickerEditing = false;
                        root.tickerHovered = false;
                    }
                }
            }

            Item {
                id: tband
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                clip: true

                property real offset: 0
                readonly property real loopWidth: ttrackA.width + root.tickerItemSpacing / 2

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.tickerItems.length === 0
                    text: "RSS…"
                    font.pixelSize: root.tickerTitleFontSize
                    font.family: root.tickerFontFamily
                    color: Theme.surfaceVariantText
                    opacity: 0.7
                }

                // inline Component: inside it only the top-level `root` id resolves
                // reliably (nested ids like `tband` do not) -> reference root.* only.
                Component {
                    id: ttrack
                    Row {
                        spacing: root.tickerItemSpacing / 2
                        Repeater {
                            model: root.tickerItems
                            Row {
                                spacing: 0
                                Row {
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter
                                    StyledText {
                                        visible: root.tickerShowSource && !!modelData.source
                                        text: modelData.source ? (modelData.source + ":") : ""
                                        font.pixelSize: root.tickerSourceFontSize
                                        font.family: root.tickerFontFamily
                                        font.weight: root.tickerSourceBold ? Font.Bold : Font.Normal
                                        color: Theme.primary
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    StyledText {
                                        text: ("" + (modelData.title || "")).replace(/\s+/g, " ").trim()
                                        font.pixelSize: root.tickerTitleFontSize
                                        font.family: root.tickerFontFamily
                                        color: Theme.surfaceText
                                        verticalAlignment: Text.AlignVCenter
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !root.tickerEditing
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.isSafeUrl(modelData.link))
                                                    Quickshell.execDetached(["xdg-open", modelData.link]);
                                            }
                                        }
                                    }
                                }
                                // half-gap before the separator; the outer Row's
                                // spacing gives the matching half-gap after it, so
                                // the separator sits centered between headlines.
                                Item { width: root.tickerItemSpacing / 2; height: 1; anchors.verticalCenter: parent.verticalCenter }
                                StyledText {
                                    text: root.tickerSeparator
                                    font.pixelSize: root.tickerTitleFontSize
                                    font.family: root.tickerFontFamily
                                    color: Theme.surfaceVariantText
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    // emoji glyphs sit high in their line box; nudge down a touch
                                    anchors.verticalCenterOffset: 2
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: ttrackA
                    visible: root.tickerItems.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    x: -tband.offset
                    sourceComponent: ttrack
                }
                Loader {
                    id: ttrackB
                    visible: root.tickerItems.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: ttrackA.right
                    anchors.leftMargin: root.tickerItemSpacing / 2
                    sourceComponent: ttrack
                }

                FrameAnimation {
                    running: root.tickerItems.length > 0 && tband.loopWidth > 0 && !root._tickerAdjusting && !(root.tickerPauseOnHover && root.tickerHovered)
                    onTriggered: {
                        tband.offset += root.tickerScrollSpeed * frameTime;
                        if (tband.offset >= tband.loopWidth)
                            tband.offset -= tband.loopWidth;
                    }
                }
            }

            // [patch:tickerbar] single hover zone ON TOP (NoButton → clicks and the
            // right-drag grab pass through to the headlines / editArea below). Fixes
            // pause-on-hover over titles (the per-title + editArea hover handlers
            // fought, so a title hover ended up clearing the flag).
            MouseArea {
                id: stripHover
                anchors.fill: parent
                z: 100
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                // hint the width-resize zone (right edge) with a horizontal-resize cursor
                cursorShape: (stripHover.mouseX > tickerStrip.width - 22) ? Qt.SizeHorCursor : (root.tickerEditing ? Qt.SizeAllCursor : Qt.ArrowCursor)
                onContainsMouseChanged: root.tickerHovered = containsMouse
                // right-hold + wheel tunes the bar opacity (same gesture as the card)
                onWheel: wheel => {
                    if (wheel.buttons & Qt.RightButton) {
                        root.nudgeTickerBgOpacity(wheel.angleDelta.y > 0 ? 0.04 : -0.04);
                        wheel.accepted = true;
                    } else {
                        wheel.accepted = false;
                    }
                }
            }
            }

            // [patch:tickerbar] catches 'S' while editing → toggle width 100/50%
            Item {
                id: keyCatcher
                focus: root.tickerEditing
                Keys.onPressed: event => {
                    if (root.tickerEditing && event.key === Qt.Key_S) {
                        root.setData("tickerWidthPct", root.effTickerWPct >= 100 ? 50 : 100);
                        event.accepted = true;
                    }
                }
            }

            // [patch:tickerbar] shortcuts hint, shown bottom-center while editing
            // (right-click held), like the desktop card edit hint.
            Rectangle {
                visible: root.tickerEditing
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 48
                width: hintRow.implicitWidth + Theme.spacingL * 2
                height: hintRow.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainer, 0.96)
                border.width: 1
                border.color: Theme.withAlpha(Theme.primary, 0.6)

                Row {
                    id: hintRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingL
                    StyledText {
                        text: "↕ Drag: move" + (root.effTickerWPct < 100 ? " (free)" : "")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: "S: width 100% ⇄ 50%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: "↔ Right edge: resize width"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }
                }
            }
        }
    }

    // [patch:tickerbar] reservation spacer: when the bar is docked under the main
    // bar (placement "below" + vertical position ~0), a thin invisible top bar
    // reserves barHeight so windows tile BELOW the ticker — its exclusive zone
    // sums with the main bar's. The visible bar stays the deterministic overlay.
    Variants {
        model: (root.tickerBarEnabled && root.isInstance && root._instanceEnabled && !root._spacerSettling && (root.tickerDockedScreenTop || root.tickerDockedScreenBottom)) ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "dms:rss-ticker-spacer"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            // anchor to whichever SCREEN edge the bar is docked against → reserves that strip.
            // Inset by a left/right main bar's width so the spacer only covers the BAND
            // (beside the vertical bar) — reserving the corner above it would shove the
            // vertical bar inward (margins are 0 for a top/bottom bar → full width).
            anchors {
                top: root.tickerDockedScreenTop
                bottom: root.tickerDockedScreenBottom
                left: true
                right: true
            }
            margins.left: root.mainBarReservedLeft
            margins.right: root.mainBarReservedRight
            implicitHeight: root.tickerBarHeight
            // reserve a few px less than the bar height so desktop content tucks
            // a little closer under the bar (less wasted gap).
            exclusiveZone: Math.max(0, root.tickerBarHeight + Math.max(0, root.tickerDockOffset))
            mask: Region {}
        }
    }
}
