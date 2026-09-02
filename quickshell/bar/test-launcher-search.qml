import QtQuick
import Quickshell
import "modules/launcher/Search.js" as Search

// Self-check for how the launcher ranks applications. Run:
//   qs -p ./test-launcher-search.qml
//
// The bands only mean anything as an order, so that is what this asserts:
// a worse match of a better kind must still beat a better match of a worse one.
ShellRoot {
    id: root

    property var fails: []
    function check(name, ok) { if (!ok) root.fails.push(name) }

    function app(name, extra) {
        const a = { name: name, id: name.toLowerCase(), genericName: "", comment: "", execString: "" }
        for (const k in extra) a[k] = extra[k]
        return a
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            // 1. Subsequence matching: order matters, contiguity and word starts pay.
            check("subsequence found", Search.fuzzySubsequenceScore("firefox", "ffx") > 0)
            check("out-of-order is not a subsequence", Search.fuzzySubsequenceScore("firefox", "xff") === -1)
            check("missing character is not a subsequence", Search.fuzzySubsequenceScore("abc", "abcd") === -1)
            check("contiguous beats scattered",
                  Search.fuzzySubsequenceScore("abcz", "abc") > Search.fuzzySubsequenceScore("axbxc", "abc"))
            check("word starts pay",
                  Search.fuzzySubsequenceScore("a-b", "ab") > Search.fuzzySubsequenceScore("axb", "ab"))

            // 2. A non-match is -1, which is how the launcher filters.
            check("no match scores -1", Search.scoreApp(app("Firefox"), "zzz", false) === -1)
            check("a null app scores -1", Search.scoreApp(null, "a", false) === -1)

            // 3. The bands are strictly ordered.
            const exact     = Search.scoreApp(app("code"), "code", false)
            const prefix    = Search.scoreApp(app("codex editor"), "code", false)
            const boundary  = Search.scoreApp(app("visual studio code"), "code", false)
            const generic   = Search.scoreApp(app("Zed", { genericName: "code" }), "code", false)
            const keyword   = Search.scoreApp(app("Zed", { keywords: ["code"] }), "code", false)
            const substring = Search.scoreApp(app("xcodex"), "code", false)
            const fuzzy     = Search.scoreApp(app("c o d e"), "code", false)
            const elsewhere = Search.scoreApp(app("Zed", { comment: "code" }), "code", false)

            check("exact beats prefix", exact > prefix)
            check("prefix beats word boundary", prefix > boundary)
            check("word boundary beats generic name", boundary > generic)
            check("generic name beats keyword", generic > keyword)
            check("keyword beats substring", keyword > substring)
            check("substring beats fuzzy", substring > fuzzy)
            check("fuzzy beats a comment match", fuzzy > elsewhere)
            check("a comment match still counts", elsewhere > 0)

            // 4. Within the prefix band, the shorter name wins.
            check("shorter prefix match wins",
                  Search.scoreApp(app("code"), "cod", false) > Search.scoreApp(app("code - insiders"), "cod", false))

            // 5. The favourite bonus is flat, so it can lift a match one band but
            //    never two -- every gap above the prefix band is wider than it.
            check("a favourite outranks its equal",
                  Search.scoreApp(app("code"), "cod", true) > Search.scoreApp(app("code"), "cod", false))
            check("a favourite prefix match does outrank an exact match",
                  Search.scoreApp(app("codex"), "code", true) > Search.scoreApp(app("code"), "code", false))
            check("a favourite cannot jump two bands",
                  Search.scoreApp(app("visual studio code"), "code", true) < Search.scoreApp(app("code"), "code", false))
            check("the bonus is exactly FAVOURITE_BONUS",
                  Search.scoreApp(app("code"), "cod", true) - Search.scoreApp(app("code"), "cod", false) === Search.FAVOURITE_BONUS)

            // 6. An empty query lists everything, favourites first.
            check("empty query lists everything", Search.scoreApp(app("Anything"), "", false) > 0)
            check("empty query puts favourites first",
                  Search.scoreApp(app("Anything"), "", true) > Search.scoreApp(app("Anything"), "", false))

            if (root.fails.length === 0) {
                console.log("PASS  launcher search: subsequence, band order, and favourite bonus hold")
            } else {
                console.log("FAIL  launcher search: " + root.fails.length + " check(s) failed")
                for (const f of root.fails) console.log("        - " + f)
            }
            Qt.exit(root.fails.length === 0 ? 0 : 1)
        }
    }
}
