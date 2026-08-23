#!/usr/bin/env bash
# Re-applies the Nix + QML language patch to the uv-installed graphify tool.
# Needed after `uv tool install --upgrade graphifyy` wipes site-packages.
# Usage: ./apply.sh   (from anywhere; paths are derived from this script)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SP="$(uv tool run --from graphifyy python -c 'import graphify, os; print(os.path.dirname(graphify.__file__))' 2>/dev/null)" \
  || SP="$("$HOME/.local/share/uv/tools/graphifyy/bin/python" -c 'import graphify, os; print(os.path.dirname(graphify.__file__))')"

echo "graphify at: $SP"

# 1. grammars into the tool venv
uv pip install --python "$HOME/.local/share/uv/tools/graphifyy/bin/python" -q tree-sitter-nix tree-sitter-qmljs

# 2. extractor module
cp "$SRC_DIR/nixqml.py" "$SP/extractors/nixqml.py"

# 3. idempotent wiring edits
"$HOME/.local/share/uv/tools/graphifyy/bin/python" - "$SP" <<'EOF'
import sys
from pathlib import Path

sp = Path(sys.argv[1])

# engine.py: import walkers + hooks (nix after ruby block; qml before class dispatch)
eng = sp / "extractors" / "engine.py"
s = eng.read_text()
if "from graphify.extractors.nixqml import" not in s:
    anchor = "from graphify.extractors.models import LanguageConfig"
    if anchor not in s:  # older layout
        anchor = "from .models import LanguageConfig"
    assert anchor in s, "engine.py models import not found"
    s = s.replace(anchor, anchor + "\nfrom graphify.extractors.nixqml import _nix_extra_walk, _qml_extra_walk", 1)
if "_nix_extra_walk(node, source, file_nid, stem, str_path," not in s:
    ruby_tail = "                                callable_def_nids, callable_class_nids,\n                                ruby_namespace):\n                return\n"
    assert s.count(ruby_tail) == 1, "ruby extra-walk block not found"
    s = s.replace(
        ruby_tail,
        ruby_tail + "\n        if config.ts_module == \"tree_sitter_nix\":\n            if _nix_extra_walk(node, source, file_nid, stem, str_path,\n                               nodes, edges, seen_ids, function_bodies,\n                               parent_class_nid, add_node, add_edge, walk):\n                return\n",
        1,
    )
qml_hook = (
    "        if config.ts_module == \"tree_sitter_qmljs\":\n"
    "            _qml_extra_walk(node, source, file_nid, stem, str_path,\n"
    "                            seen_ids, add_edge)\n"
)
if qml_hook not in s:
    cls_anchor = "        # Class types\n        if t in config.class_types:"
    assert s.count(cls_anchor) == 1, "class-types dispatch not found"
    s = s.replace(cls_anchor, qml_hook + "\n" + cls_anchor, 1)
eng.write_text(s)

# detect.py: extensions
det = sp / "detect.py"
d = det.read_text()
if "'.nix'" not in d:
    assert "CODE_EXTENSIONS = {'.py'," in d
    d = d.replace("CODE_EXTENSIONS = {'.py',", "CODE_EXTENSIONS = {'.nix', '.qml', '.py',", 1)
    det.write_text(d)

# extract.py: imports + dispatch
ex = sp / "extract.py"
e = ex.read_text()
if "extractors.nixqml import" not in e:
    anchor = "from graphify.extractors.apex import extract_apex  # noqa: F401"
    assert anchor in e, "apex import not found"
    e = e.replace(anchor, anchor + "\nfrom graphify.extractors.nixqml import extract_nix, extract_qml  # noqa: F401", 1)
if '".nix": extract_nix' not in e:
    assert "_DISPATCH: dict[str, Any] = {\n" in e
    e = e.replace("_DISPATCH: dict[str, Any] = {\n",
                  '_DISPATCH: dict[str, Any] = {\n    ".nix": extract_nix,\n    ".qml": extract_qml,\n', 1)
ex.write_text(e)
print("wiring OK")
EOF

# 4. verify against a real nix + qml file
REPO="$(git -C "$SRC_DIR/../.." rev-parse --show-toplevel 2>/dev/null || echo "$SRC_DIR/../..")"
NIX_FILE=$(find "$REPO/nixos" -name '*.nix' | head -1)
QML_FILE=$(find "$REPO/quickshell" -name '*.qml' | head -1)
"$HOME/.local/share/uv/tools/graphifyy/bin/python" - "$NIX_FILE" "$QML_FILE" <<'EOF'
import sys
from pathlib import Path
from graphify.extract import extract
for f in sys.argv[1:]:
    r = extract([Path(f).resolve()])
    rr = r[0] if isinstance(r, list) else r
    assert "nodes" in rr and rr["nodes"], f"{f}: no nodes"
    kinds = {e["relation"] for e in rr.get("edges", [])}
    print(f"{Path(f).name}: {len(rr['nodes'])} nodes, relations={sorted(kinds)}")
print("verify OK")
EOF
