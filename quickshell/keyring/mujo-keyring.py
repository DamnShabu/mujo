#!/usr/bin/env python3
"""mujo-keyring — thin CLI over the Secret Service (gnome-keyring) for the
Settings app's Keyring panel. Uses secretstorage (D-Bus), the native Linux
credential store — no custom store.

Commands:
  list                          JSON array of items (label, attributes, locked…)
  get <item-path>               Print the secret value (stdout, raw)
  add <label> <account> <svc>   Create/replace an item; secret read from stdin
  remove <item-path>            Delete an item

Secrets are only emitted by `get`, on explicit request.
"""
import sys
import json

import secretstorage


def _conn():
    return secretstorage.dbus_init()


def cmd_list():
    conn = _conn()
    out = []
    for coll in secretstorage.get_all_collections(conn):
        try:
            cname = coll.get_label()
        except Exception:
            cname = "?"
        locked = coll.is_locked()
        try:
            items = list(coll.get_all_items())
        except Exception:
            items = []
        for item in items:
            try:
                attrs = item.get_attributes()
            except Exception:
                attrs = {}
            # Drop the internal schema attribute from the display set.
            attrs = {k: v for k, v in attrs.items() if k != "xdg:schema"}
            try:
                label = item.get_label()
            except Exception:
                label = "(unnamed)"
            out.append({
                "id": item.item_path,
                "label": label,
                "collection": cname,
                "locked": locked or item.is_locked(),
                "service": attrs.get("service") or attrs.get("application") or "",
                "account": attrs.get("account") or attrs.get("username") or "",
                "attributes": attrs,
            })
    out.sort(key=lambda x: (x["service"].lower(), x["label"].lower()))
    print(json.dumps(out))


def cmd_get(item_path):
    conn = _conn()
    item = secretstorage.item.Item(conn, item_path)
    if item.is_locked():
        item.unlock()
    sys.stdout.buffer.write(item.get_secret())
    sys.stdout.buffer.flush()


def cmd_add(label, account, service):
    conn = _conn()
    coll = secretstorage.get_default_collection(conn)
    if coll.is_locked():
        coll.unlock()
    secret = sys.stdin.buffer.read()
    attrs = {"xdg:schema": "org.freedesktop.Secret.Generic"}
    if account:
        attrs["account"] = account
    if service:
        attrs["service"] = service
    coll.create_item(label, attrs, secret, replace=True)
    print("ok")


def cmd_remove(item_path):
    conn = _conn()
    item = secretstorage.item.Item(conn, item_path)
    item.delete()
    print("ok")


def main(argv):
    if not argv:
        print("usage: mujo-keyring list|get|add|remove", file=sys.stderr)
        return 2
    cmd, rest = argv[0], argv[1:]
    try:
        if cmd == "list":
            cmd_list()
        elif cmd == "get" and rest:
            cmd_get(rest[0])
        elif cmd == "add" and len(rest) >= 3:
            cmd_add(rest[0], rest[1], rest[2])
        elif cmd == "remove" and rest:
            cmd_remove(rest[0])
        else:
            print("bad arguments", file=sys.stderr)
            return 2
    except secretstorage.exceptions.SecretServiceNotAvailableException as e:
        print(f"secret service unavailable: {e}", file=sys.stderr)
        return 1
    except Exception as e:  # surface, keep exit non-zero
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
