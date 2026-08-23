"""Nix and QML structural extraction.

Nix walker adapted from Graphify-Labs/graphify#1048 (binding nodes +
`import ./x.nix` / `imports = [ ... ]` edges on tree-sitter-nix).
QML adds component-reference edges (`Wallpaper {}` -> Wallpaper.qml)
on top of the generic JS-shaped machinery in tree-sitter-qmljs.
"""
from __future__ import annotations

from pathlib import Path

from .base import _make_id, _read_text
from .models import LanguageConfig

# ── Nix ───────────────────────────────────────────────────────────────────────


def _nix_get_import_argument(node, source: bytes) -> str | None:
    curr = node
    while curr.type == "apply_expression":
        func_child = curr.child(0)
        if func_child and func_child.type == "variable_expression":
            id_node = func_child.child(0)
            if id_node and id_node.type == "identifier" and _read_text(id_node, source).strip() == "import":
                arg_node = curr.child(1)
                if arg_node:
                    if arg_node.type == "path_expression":
                        return _read_text(arg_node, source).strip()
                    elif arg_node.type == "string_expression":
                        return _read_text(arg_node, source).strip().strip("\"'")
                    elif arg_node.type == "spath_expression":
                        return _read_text(arg_node, source).strip()
        curr = func_child
    return None


def _nix_add_import_edge(path_str: str, parent_nid: str, line: int, add_edge_fn, str_path: str):
    if path_str.startswith("<"):
        return
    try:
        resolved_path = (Path(str_path).parent / path_str).resolve()
        if resolved_path.exists() and resolved_path.is_file():
            imported_nid = _make_id(str(resolved_path))
            add_edge_fn(parent_nid, imported_nid, "imports", line, context="import")
    except Exception:
        pass


def _nix_extra_walk(node, source: bytes, file_nid: str, stem: str, str_path: str,
                    nodes: list, edges: list, seen_ids: set, function_bodies: list,
                    parent_class_nid: str | None, add_node_fn, add_edge_fn, walk_fn) -> bool:
    """Handle bindings and imports for Nix. Returns True if handled."""
    parent_nid = parent_class_nid if parent_class_nid else file_nid
    import_arg = _nix_get_import_argument(node, source)
    if import_arg:
        _nix_add_import_edge(import_arg, parent_nid, node.start_point[0] + 1, add_edge_fn, str_path)

    if node.type == "binding":
        attrpath_node = None
        expr_node = None

        for child in node.children:
            if child.type == "attrpath":
                attrpath_node = child
            elif child.type.endswith("_expression"):
                expr_node = child

        if not attrpath_node and node.children:
            attrpath_node = node.children[0]
        if not expr_node and len(node.children) > 2:
            expr_node = node.children[2]

        if attrpath_node and expr_node:
            attr_name = _read_text(attrpath_node, source).strip()
            if attr_name == "imports":
                if expr_node.type == "list_expression":
                    for child in expr_node.children:
                        if child.type == "path_expression":
                            _nix_add_import_edge(_read_text(child, source).strip(), parent_nid,
                                                 node.start_point[0] + 1, add_edge_fn, str_path)
                        elif child.type == "string_expression":
                            _nix_add_import_edge(_read_text(child, source).strip().strip("\"'"), parent_nid,
                                                 node.start_point[0] + 1, add_edge_fn, str_path)
                        elif child.type in ("parenthesized_expression", "apply_expression"):
                            walk_fn(child, parent_nid)
                return True
            else:
                is_complex = expr_node.type in (
                    "function_expression", "attrset_expression",
                    "rec_attrset_expression", "let_expression", "apply_expression"
                )
                if is_complex:
                    binding_nid = (_make_id(parent_nid, attr_name) if parent_nid and parent_nid != file_nid
                                   else _make_id(stem, attr_name))
                    line = node.start_point[0] + 1
                    add_node_fn(binding_nid, attr_name, line)
                    add_edge_fn(parent_nid, binding_nid, "defines", line)
                    walk_fn(expr_node, binding_nid)
                    return True
    return False


_NIX_CONFIG = LanguageConfig(
    ts_module="tree_sitter_nix",
)

# ── QML ───────────────────────────────────────────────────────────────────────


def _qml_extra_walk(node, source: bytes, file_nid: str, stem: str, str_path: str,
                    seen_ids: set, add_edge_fn) -> bool:
    """`Foo {}` whose Foo.qml exists as a sibling file -> imports edge."""
    if node.type != "ui_object_definition":
        return False
    name_node = next((c for c in node.children if c.type == "identifier"), None)
    if name_node is None:
        return False
    target = Path(str_path).parent / f"{_read_text(name_node, source)}.qml"
    if not target.exists():
        return False
    tgt_nid = _make_id(str(target))
    key = ("qml-import", file_nid, tgt_nid)
    if key in seen_ids:
        return False
    seen_ids.add(key)
    add_edge_fn(file_nid, tgt_nid, "imports", node.start_point[0] + 1, context="qml-component")
    return False


_QML_CONFIG = LanguageConfig(
    ts_module="tree_sitter_qmljs",
    class_types=frozenset({"ui_object_definition"}),
    name_fallback_child_types=("identifier",),
    body_fallback_child_types=("ui_object_initializer",),
    function_types=frozenset({"function_declaration"}),
    call_types=frozenset({"call_expression", "new_expression"}),
    call_function_field="function",
    call_accessor_node_types=frozenset({"member_expression"}),
    call_accessor_field="property",
    call_accessor_object_field="object",
    function_boundary_types=frozenset({
        "function_declaration", "function_expression", "arrow_function", "method_definition",
    }),
)


def extract_nix(path: Path) -> dict:
    from .engine import _extract_generic
    return _extract_generic(path, _NIX_CONFIG)


def extract_qml(path: Path) -> dict:
    from .engine import _extract_generic
    return _extract_generic(path, _QML_CONFIG)
