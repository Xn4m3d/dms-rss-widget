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

// [patch:atom-prefix] An Atom document may declare its namespace with a prefix on the
// root element (<atom:feed><atom:entry><atom:title>...). Every regex in parseAtomFeed
// matches unprefixed tags only, so such a feed parses to zero items and disappears in
// silence — the same failure mode as the routing bug above, a different cause.
// Normalising the ROOT's own prefix away once is cheaper and safer than making each
// entry-level regex namespace-aware: a prefix-tolerant extractTag would also match
// <atom:link rel="self"> inside an RSS item and hijack the <link> lookup.
// Reported upstream by BrendonJL while regression-testing the routing fix (BrendonJL#7).

// Removes ONE namespace prefix from element tags: "<atom:entry>" -> "<entry>".
// Only the prefix asked for is touched, so media:, dc: and content: elements a feed
// carries for extra data survive, and xmlns:atom="..." attributes are left alone.
function stripNamespacePrefix(xml, prefix) {
    if (!xml || !prefix)
        return xml;
    var escaped = prefix.replace(/[.*+?^${}()|[\]\\-]/g, "\\$&");
    return xml.replace(new RegExp("<(/?)" + escaped + ":", "gi"), "<$1");
}

// The document's root element exactly as written, prefix included, or "" if there is
// none. The scan skips the XML declaration, processing instructions, comments and the
// DOCTYPE (internal subset included), so a "<feed" mentioned in a comment or a doctype
// cannot pass for the root.
function rootElementRaw(xml) {
    if (!xml)
        return "";
    var i = 0;
    while (i < xml.length) {
        var lt = xml.indexOf("<", i);
        if (lt === -1)
            return "";
        var next = xml.charAt(lt + 1);
        if (next === "?") {
            var pi = xml.indexOf("?>", lt + 2);
            if (pi === -1)
                return "";
            i = pi + 2;
        } else if (next === "!") {
            if (xml.substr(lt + 2, 2) === "--") {
                var comment = xml.indexOf("-->", lt + 4);
                if (comment === -1)
                    return "";
                i = comment + 3;
            } else {
                var gt = xml.indexOf(">", lt + 2);
                var bracket = xml.indexOf("[", lt + 2);
                if (bracket !== -1 && (gt === -1 || bracket < gt)) {
                    var close = xml.indexOf("]", bracket + 1);
                    gt = close === -1 ? -1 : xml.indexOf(">", close + 1);
                }
                if (gt === -1)
                    return "";
                i = gt + 1;
            }
        } else {
            var m = /^<\s*([A-Za-z_][A-Za-z0-9:_.-]*)/.exec(xml.substr(lt, 256));
            return m ? m[1] : "";
        }
    }
    return "";
}

// Root tag name, lowercased and prefix-free ("rdf:RDF" -> "rdf", "atom:feed" -> "feed").
function rootElementName(xml) {
    var raw = rootElementRaw(xml);
    var colon = raw.indexOf(":");
    return (colon === -1 ? raw : raw.substr(colon + 1)).toLowerCase();
}

// The root's own namespace prefix ("atom" for <atom:feed>), or "" when it has none.
function rootElementPrefix(xml) {
    var raw = rootElementRaw(xml);
    var colon = raw.indexOf(":");
    return colon === -1 ? "" : raw.substr(0, colon);
}

function parseAtomFeed(xml, sourceName) {
    xml = stripNamespacePrefix(xml, rootElementPrefix(xml));

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
// The format is a property of the ROOT element, so that is what decides; the containers
// actually present only break the tie when the root tells us nothing (junk input).
function parseFeed(xml, sourceName) {
    var root = rootElementName(xml);
    if (root === "feed")
        return parseAtomFeed(xml, sourceName);
    if (root === "rss" || root === "rdf")
        return parseRssFeed(xml, sourceName);
    var hasItems = /<item[\s>]/i.test(xml);
    var hasEntries = /<entry[\s>]/i.test(xml) || /<[A-Za-z0-9_.-]+:entry[\s>]/i.test(xml);
    return hasEntries && !hasItems ? parseAtomFeed(xml, sourceName) : parseRssFeed(xml, sourceName);
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
    parseOpml,
    stripNamespacePrefix,
    rootElementName,
    rootElementPrefix
};
