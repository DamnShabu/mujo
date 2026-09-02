.pragma library

// How the launcher ranks applications against what has been typed. Pure
// scoring, kept out of LauncherBody because it is the part worth reading on its
// own — and the part worth a self-check, which test-launcher-search.qml is.
//
// The scores are bands, one per kind of match, so a poor match of a better kind
// always outranks a good match of a worse kind: an exact name beats any prefix,
// a prefix beats any word boundary, and a fuzzy subsequence loses to all of
// them. Within a band the tie-break is position and length, so earlier and
// shorter wins.
//
// A favourite takes a flat bonus on top of whatever band it landed in. That is
// deliberately sticky: a favourited "codex" does outrank an exact match on
// "code". It cannot jump two bands, though, because every gap above the prefix
// band is wider than the bonus.
// ponytail: flat bonus, so it can jump exactly one band. Make it proportional
// to the band gap if that ordering ever surprises someone.

var EXACT_NAME = 10000
var PREFIX_NAME = 8500
var WORD_BOUNDARY_NAME = 7200
var EXACT_GENERIC = 6800
var PREFIX_GENERIC = 6300
var WORD_BOUNDARY_GENERIC = 5800
var EXACT_KEYWORD = 5500
var PREFIX_KEYWORD = 5200
var SUBSTRING_KEYWORD = 4700
var SUBSTRING_NAME = 4200
var FUZZY_NAME = 3000
var SUBSTRING_GENERIC = 2200
var SUBSTRING_ELSEWHERE = 1200

// An empty query lists everything, favourites first.
var NO_QUERY = 1000
var NO_QUERY_FAVOURITE = 10000

// Added to whichever band a favourite landed in.
var FAVOURITE_BONUS = 2500

// Score `pattern` as a subsequence of `str`: every character of the pattern must
// appear in order, and a match scores higher the more its characters run
// together and the more of them start a word. -1 when it is not a subsequence.
function fuzzySubsequenceScore(str, pattern) {
    var sIdx = 0, pIdx = 0
    var score = 0
    var consecutive = 0
    var prevMatchIdx = -1

    while (sIdx < str.length && pIdx < pattern.length) {
        if (str[sIdx] === pattern[pIdx]) {
            score += 20
            if (prevMatchIdx === sIdx - 1) {
                consecutive++
                score += consecutive * 15
            } else {
                consecutive = 0
            }
            if (sIdx === 0 || str[sIdx - 1] === " " || str[sIdx - 1] === "-" || str[sIdx - 1] === "_") {
                score += 35
            }
            prevMatchIdx = sIdx
            pIdx++
        }
        sIdx++
    }
    return pIdx === pattern.length ? Math.max(1, score) : -1
}

// Rank one desktop entry against a lowercased query. -1 means "no match at all",
// which is how the caller filters.
function scoreApp(app, q, isFav) {
    if (!app || !app.name) return -1
    if (!q) return isFav ? NO_QUERY_FAVOURITE : NO_QUERY

    var name = app.name.toLowerCase()
    var generic = (app.genericName || "").toLowerCase()
    var comment = (app.comment || "").toLowerCase()
    var exec = (app.execString || "").toLowerCase()
    var id = (app.id || "").toLowerCase()

    var s = -1

    if (name === q) {
        s = EXACT_NAME
    } else if (name.indexOf(q) === 0) {
        // Prefer the shortest name the query is a prefix of: "code" should find
        // Code before Code - Insiders.
        s = PREFIX_NAME + Math.max(0, 500 - (name.length - q.length) * 10)
    } else if (name.indexOf(" " + q) >= 0 || name.indexOf("-" + q) >= 0 || name.indexOf("_" + q) >= 0) {
        // A whole word inside the name, e.g. "code" in "Visual Studio Code".
        var idx = Math.max(name.indexOf(" " + q), Math.max(name.indexOf("-" + q), name.indexOf("_" + q)))
        s = WORD_BOUNDARY_NAME - idx * 15
    } else if (generic === q) {
        s = EXACT_GENERIC
    } else if (generic.indexOf(q) === 0) {
        s = PREFIX_GENERIC
    } else if (generic.indexOf(" " + q) >= 0) {
        s = WORD_BOUNDARY_GENERIC
    } else if (app.keywords) {
        for (var k = 0; k < app.keywords.length; k++) {
            var kw = String(app.keywords[k]).toLowerCase()
            if (kw === q) { s = EXACT_KEYWORD; break }
            if (kw.indexOf(q) === 0) { s = PREFIX_KEYWORD; break }
            if (kw.indexOf(q) > 0) { s = SUBSTRING_KEYWORD; break }
        }
    }

    if (s < 0 && name.indexOf(q) >= 0) {
        s = SUBSTRING_NAME - name.indexOf(q) * 20
    }

    if (s < 0) {
        var fz = fuzzySubsequenceScore(name, q)
        if (fz > 0) s = FUZZY_NAME + fz
    }

    if (s < 0 && generic.indexOf(q) >= 0) {
        s = SUBSTRING_GENERIC
    }
    if (s < 0 && (comment.indexOf(q) >= 0 || exec.indexOf(q) >= 0 || id.indexOf(q) >= 0)) {
        s = SUBSTRING_ELSEWHERE
    }

    if (s < 0) return -1
    return isFav ? s + FAVOURITE_BONUS : s
}
