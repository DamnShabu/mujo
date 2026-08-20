.pragma library

function tryEvaluate(input) {
    var tokens = tokenize(input)
    if (!tokens || tokens.length === 0) return null

    var i = 0
    function next() { return tokens[i++] }
    function peek() { return tokens[i] }

    function parsePrimary() {
        var tok = next()
        if (tok === "(") {
            var v = parseExpr()
            if (next() !== ")") throw new Error("paren")
            return v
        }
        if (tok !== undefined && isFinite(parseFloat(tok))) return parseFloat(tok)
        throw new Error("num")
    }

    function parseUnary() {
        var op = peek()
        if (op === "-") { next(); return -parseUnary() }
        if (op === "+") { next(); return parseUnary() }
        return parsePrimary()
    }

    function parseTerm() {
        var v = parseUnary()
        while (peek() === "*" || peek() === "/") {
            var op = next()
            var r = parseUnary()
            if (op === "/" && r === 0) throw new Error("div0")
            v = op === "*" ? v * r : v / r
        }
        return v
    }

    function parseExpr() {
        var v = parseTerm()
        while (peek() === "+" || peek() === "-") {
            var op = next()
            v = op === "+" ? v + parseTerm() : v - parseTerm()
        }
        return v
    }

    try {
        var val = parseExpr()
        if (tokens[i] !== undefined) return null
        if (!isFinite(val)) return null
        return format(val)
    } catch (e) {
        return null
    }
}

function tokenize(input) {
    var s = input.replace(/\s+/g, "").replace(/\u2212/g, "-")
    if (s === "") return null

    var toks = []
    var i = 0
    while (i < s.length) {
        var c = s.charAt(i)
        if (c === "+" || c === "-" || c === "*" || c === "/" || c === "(" || c === ")") {
            toks.push(c)
            i++
        } else if (c >= "0" && c <= "9" || c === ".") {
            var j = i
            while (j < s.length && (s.charAt(j) >= "0" && s.charAt(j) <= "9" || s.charAt(j) === ".")) j++
            var token = s.slice(i, j)
            if (token.split(".").length > 2) return null
            toks.push(token)
            i = j
        } else {
            return null
        }
    }
    return toks
}

function format(val) {
    if (val === 0) return "0"
    var rounded = Math.round(val * 10000000000) / 10000000000
    return Math.round(rounded) === rounded ? String(Math.round(rounded)) : String(rounded)
}