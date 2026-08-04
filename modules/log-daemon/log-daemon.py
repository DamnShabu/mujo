#!/usr/bin/env python3
"""Log-to-Obsidian conversion daemon.

Watches LOG_DAEMON_WATCH_DIR for new log files, summarises each with a local
Ollama model, and writes an Obsidian-flavoured Markdown note to
LOG_DAEMON_OUTPUT_DIR. Processed files are recorded in a ledger under
LOG_DAEMON_STATE_DIR so a file is only converted once.

Configuration comes entirely from the environment; the NixOS module in
nixos/features/log-daemon.nix sets these variables.
"""

import hashlib
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

import watchdog.events
import watchdog.observers


def env(name, default):
    return os.environ.get(name, default)


def parse_env():
    return {
        "watch_dir": Path(env("LOG_DAEMON_WATCH_DIR", ".")).expanduser(),
        "output_dir": Path(env("LOG_DAEMON_OUTPUT_DIR", "processed")).expanduser(),
        "state_dir": Path(env("LOG_DAEMON_STATE_DIR", ".log-daemon-state")).expanduser(),
        "ollama_url": env("LOG_DAEMON_OLLAMA_URL", "http://localhost:11434/api/generate"),
        "ollama_model": env("LOG_DAEMON_OLLAMA_MODEL", "llama3.2"),
        "ollama_timeout": int(env("LOG_DAEMON_OLLAMA_TIMEOUT", "30")),
        "extra_tags": [t for t in env("LOG_DAEMON_EXTRA_TAGS", "system").split(",") if t],
        "max_note_length": int(env("LOG_DAEMON_MAX_NOTE_LENGTH", "10000")),
    }


def slugify(name):
    base = Path(name).stem
    slug = re.sub(r"[^A-Za-z0-9]+", "-", base).strip("-").lower()
    return slug or "note"


def ledger_path(state_dir):
    return state_dir / "processed.json"


def load_ledger(state_dir):
    path = ledger_path(state_dir)
    if path.exists():
        try:
            return json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return {}


def save_ledger(state_dir, ledger):
    ledger_path(state_dir).parent.mkdir(parents=True, exist_ok=True)
    tmp = ledger_path(state_dir).with_suffix(".json.tmp")
    tmp.write_text(json.dumps(ledger, indent=2, sort_keys=True))
    tmp.replace(ledger_path(state_dir))


def file_id(path):
    stat = path.stat()
    return f"{path.name}:{stat.st_mtime_ns}:{stat.st_size}"


def summarise(cfg, content):
    prompt = (
        "You are a note-taking assistant. Summarise the following log entry into "
        "a concise Obsidian note with a title on the first line.\n\n" + content
    )
    body = json.dumps({
        "model": cfg["ollama_model"],
        "prompt": prompt,
        "stream": False,
    }).encode()
    req = urllib.request.Request(
        cfg["ollama_url"], data=body, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=cfg["ollama_timeout"]) as resp:
        return json.loads(resp.read())["response"].strip()


def build_note(cfg, name, content, summary):
    title = (summary.splitlines() or [""])[0].strip("# ").strip()[:80] or slugify(name)
    body = summary
    if len(body) > cfg["max_note_length"]:
        body = body[: cfg["max_note_length"]] + "\n<!-- TRUNCATED -->"
    tags = " ".join(f"#{t}" for t in cfg["extra_tags"])
    note = (
        f"---\n"
        f"title: {title}\n"
        f"source: {name}\n"
        f"date: {time.strftime('%Y-%m-%d')}\n"
        f"tags: {tags}\n"
        f"---\n\n"
        f"{body}\n"
    )
    return note, f"{slugify(name)}-{time.strftime('%Y%m%d-%H%M%S')}.md"


def convert(cfg, path, note_name=None):
    try:
        # errors="replace": a binary file dropped into the watch dir must not
        # raise UnicodeDecodeError and crash the daemon.
        content = path.read_text(errors="replace")
    except OSError:
        return None
    if not content.strip():
        return None
    try:
        summary = summarise(cfg, content)
    except Exception as exc:  # ponytail: ollama down should not kill the daemon
        print(f"log-daemon: ollama summarisation failed for {path.name}: {exc}", file=sys.stderr)
        summary = content
    note, filename = build_note(cfg, path.name, content, summary)
    if note_name is None:
        note_name = filename
    cfg["output_dir"].mkdir(parents=True, exist_ok=True)
    (cfg["output_dir"] / note_name).write_text(note)
    print(f"log-daemon: converted {path.name} -> {note_name}")
    return note_name


def process(cfg, ledger, path):
    """Convert path once it is stable, then ledger it.

    Never raises on bad input: unreadable files are logged and left
    unledgered so a later change may still be processed.
    """
    # Let the writer finish: two consecutive identical stats mean the file is
    # stable. Bounded so a file that never stops growing is still converted.
    # ponytail: serial wait on the dispatch thread, fine for a personal inbox.
    for _ in range(10):
        try:
            st1 = path.stat()
        except OSError:
            return
        time.sleep(1)
        try:
            st2 = path.stat()
        except OSError:
            return
        if st1.st_size == st2.st_size and st1.st_mtime_ns == st2.st_mtime_ns:
            break
    try:
        f_id = file_id(path)
    except OSError:
        return
    entry = ledger.get(path.name)
    if isinstance(entry, dict) and entry.get("id") == f_id:
        return  # unchanged since last conversion
    old_note = entry.get("note") if isinstance(entry, dict) else None
    try:
        note_name = convert(cfg, path, note_name=old_note)
    except Exception as exc:  # ponytail: one bad file must not kill the daemon
        print(f"log-daemon: failed to convert {path.name}: {exc}", file=sys.stderr)
        return
    if note_name is None:
        return  # unreadable/empty: do NOT mark as processed
    ledger[path.name] = {"id": f_id, "note": note_name}
    save_ledger(cfg["state_dir"], ledger)


class Handler(watchdog.events.FileSystemEventHandler):
    def __init__(self, cfg, ledger):
        self.cfg = cfg
        self.ledger = ledger

    def on_created(self, event):
        if event.is_directory:
            return
        try:
            process(self.cfg, self.ledger, Path(event.src_path))
        except Exception as exc:  # ponytail: watchdog never guards handlers; we must
            print(f"log-daemon: error handling {event.src_path}: {exc}", file=sys.stderr)

    def on_modified(self, event):
        # Files written over more than a second emit on_modified after
        # on_created; reprocessing the stable file treats it as an update.
        self.on_created(event)


def main():
    cfg = parse_env()
    cfg["watch_dir"].mkdir(parents=True, exist_ok=True)
    cfg["output_dir"].mkdir(parents=True, exist_ok=True)
    cfg["state_dir"].mkdir(parents=True, exist_ok=True)

    ledger = load_ledger(cfg["state_dir"])

    # Convert anything that landed before the daemon started.
    for path in sorted(cfg["watch_dir"].iterdir()):
        if path.is_file():
            process(cfg, ledger, path)
    save_ledger(cfg["state_dir"], ledger)

    observer = watchdog.observers.Observer()
    observer.schedule(Handler(cfg, ledger), str(cfg["watch_dir"]), recursive=False)
    observer.start()
    print(f"log-daemon: watching {cfg['watch_dir']}")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        # ponytail: one runnable check for the note-building logic.
        cfg = parse_env()
        note, filename = build_note(cfg, "today.txt", "raw log", "# A title\nSome body.")
        assert filename.endswith(".md")
        assert "# A title" in note and "source: today.txt" in note
        # Empty ollama summary must not raise IndexError.
        note2, _ = build_note(cfg, "empty.txt", "raw log", "")
        assert "source: empty.txt" in note2 and "title: empty" in note2
        print("self-test ok")
        sys.exit(0)
    main()
