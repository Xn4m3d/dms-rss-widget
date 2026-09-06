// Extracted pure-JS logic from DankRssWidget.qml and DankRssWidgetSettings.qml
// These functions are identical to the QML versions, extracted for testability.

function extractTag(xml, tagName) {
    var regex = new RegExp("<" + tagName + "[^>]*>\\s*(?:<!\\[CDATA\\[([\\s\\S]*?)\\]\\]>|([\\s\\S]*?))\\s*<\\/" + tagName + ">", "i");
    var match = xml.match(regex);
    if (match) {
        return (match[1] !== undefined ? match[1] : match[2]) || "";
    }
    return "";
}

function cleanText(text) {
    if (!text) return "";
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
    text = text.replace(/\s+/g, " ").trim();
    return text;
}

function stripHtml(text) {
    if (!text) return "";
    return text.replace(/<[^>]+>/g, "");
}

function getRelativeTime(date, now) {
    if (!date || isNaN(date.getTime())) return "";
    now = now || new Date();
    var diff = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diff < 60) return "just now";
    if (diff < 3600) return Math.floor(diff / 60) + "m ago";
    if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
    if (diff < 604800) return Math.floor(diff / 86400) + "d ago";
    return date.toLocaleDateString();
}

function extractImageUrl(block, content) {
    var url = "";

    var m = block.match(/<media:thumbnail[^>]*url=["']([^"']+)["']/i);
    if (m) { url = m[1]; }

    if (!url) {
        m = block.match(/<media:content[^>]*url=["']([^"']+)["'][^>]*type=["']image\//i);
        if (m) url = m[1];
    }

    if (!url) {
        m = block.match(/<media:content[^>]*url=["']([^"']+)["']/i);
        if (m) url = m[1];
    }

    if (!url) {
        m = block.match(/<enclosure[^>]*type=["']image\/[^"']*["'][^>]*url=["']([^"']+)["']/i);
        if (m) url = m[1];
    }
    if (!url) {
        m = block.match(/<enclosure[^>]*url=["']([^"']+)["'][^>]*type=["']image\//i);
        if (m) url = m[1];
    }

    if (!url) {
        var decoded = content.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&");
        m = decoded.match(/<img[^>]*src=["']([^"']+)["']/i);
        if (m) url = m[1];
    }

    if (url) {
        url = url.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"');
    }

    return url;
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

        var linkMatch = block.match(/<link[^>]*href=["']([^"']+)["'][^>]*\/?>/i);
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
            imageUrl: extractImageUrl(block, summary || "")
        });
    }
    return items;
}

// [patch:atom-detect] This used to route on `xml.indexOf("<feed") !== -1`, i.e. the
// substring "<feed" ANYWHERE in the document. Plenty of RSS 2.0 feeds carry an element
// whose name merely starts with "feed" — CNBC ships <feed_asset>, FeedBurner ships
// <feedburner:*> — so they were handed to the Atom parser, which finds no <entry> and
// returns nothing. The whole feed then vanished with no error anywhere.
// Decide on the container that is actually present, and only fall back to the real root
// element when a document somehow carries both.
function parseFeed(xml, sourceName) {
    var hasItems = /<item[\s>]/i.test(xml);
    var hasEntries = /<entry[\s>]/i.test(xml);
    if (hasEntries && !hasItems) {
        return parseAtomFeed(xml, sourceName);
    }
    if (hasItems && !hasEntries) {
        return parseRssFeed(xml, sourceName);
    }
    var rootMatch = /^\s*(?:<\?xml[^>]*\?>\s*)?(?:<!--[\s\S]*?-->\s*)*<\s*([A-Za-z0-9:_.-]+)/.exec(xml);
    var root = rootMatch ? rootMatch[1].toLowerCase().replace(/^[^:]*:/, "") : "";
    return root === "feed" ? parseAtomFeed(xml, sourceName) : parseRssFeed(xml, sourceName);
}

function parseOpml(xml) {
    var feeds = [];
    var outlineRegex = /<outline[^>]*xmlUrl=["']([^"']+)["'][^>]*>/gi;
    var match;
    while ((match = outlineRegex.exec(xml)) !== null) {
        var fullTag = match[0];
        var url = match[1].replace(/&amp;/g, "&");

        var titleMatch = fullTag.match(/(?:title|text)=["']([^"']+)["']/i);
        var name = titleMatch ? titleMatch[1].replace(/&amp;/g, "&") : url;

        feeds.push({ name: name, url: url });
    }
    return feeds;
}

module.exports = {
    extractTag,
    cleanText,
    stripHtml,
    getRelativeTime,
    extractImageUrl,
    parseRssFeed,
    parseAtomFeed,
    parseFeed,
    parseOpml
};
