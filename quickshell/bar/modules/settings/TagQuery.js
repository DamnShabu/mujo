.pragma library

// Tag-query string handling, shared by the Wallhaven and Wallpaper Engine
// search boxes. Both accept the same syntax — space-separated tags, quoted
// when they contain a space, optionally prefixed with `#` or `+` — so the
// parsing lives here once rather than once per search box.

// Strip the decoration a tag may arrive with: a leading `#`/`+` and quotes.
function clean(tag) {
    if (!tag) return ""
    return tag.trim().replace(/^[#+]/, "").replace(/^"/, "").replace(/"$/, "")
}

// Quote a tag only when it needs it, so single-word queries stay readable.
function format(tag) {
    return tag.indexOf(" ") >= 0 ? '"' + tag + '"' : tag
}

// True when `query` already contains `tag` as a whole token, so re-clicking a
// tag chip does not append a duplicate.
function isInQuery(query, tag) {
    var target = clean(tag).toLowerCase()
    if (target === "") return false

    var q = query ? query.toLowerCase().trim() : ""
    if (q === "") return false

    if (q === target || q === "#" + target || q === "+" + target || q === '"' + target + '"') return true
    if (q.indexOf('"' + target + '"') >= 0) return true

    var re = /"([^"]+)"|(\S+)/g
    var match
    while ((match = re.exec(q)) !== null) {
        if (clean(match[1] || match[2]).toLowerCase() === target) return true
    }
    return false
}

// `text` with `tag` appended, or null when there is nothing to do — the tag is
// empty, or the query already has it.
function append(text, tag) {
    var tidy = clean(tag)
    if (tidy === "" || isInQuery(text, tidy)) return null
    var current = (text || "").trim()
    return current === "" ? format(tidy) : current + " " + format(tidy)
}

// `text` with its last token replaced by `tag` — what accepting a completion
// does, since the last token is the partial word being completed. Null when
// the tag is empty.
function replaceLastToken(text, tag) {
    var tidy = clean(tag)
    if (tidy === "") return null

    var txt = (text || "").trim()
    var lastSpace = txt.lastIndexOf(" ")
    if (lastSpace < 0) return format(tidy)

    var prefix = txt.substring(0, lastSpace).trim()
    if (isInQuery(prefix, tidy)) return prefix
    return prefix === "" ? format(tidy) : prefix + " " + format(tidy)
}

// The word the caret sits in — what a completion suggestion should replace,
// and what to ask the service to complete. Falls back to the whole query when
// the trailing word is too short to be worth completing on its own.
function lastToken(text) {
    var txt = (text || "").trim()
    var lastSpace = txt.lastIndexOf(" ")
    var token = (lastSpace >= 0 && lastSpace < txt.length - 1) ? txt.substring(lastSpace + 1).trim() : txt
    return token.length >= 2 ? token : txt
}
