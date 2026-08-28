"""MCP stdio server for the sandbox VM.

Runs as the NixOS test driver's test script, so the whole Machine API
(`machines`) is already in scope — this file is only the JSON-RPC shim.
"""

import atexit
import base64
import json
import os
import shlex
import signal
import sys
import threading
import time

# The driver logs to fd 1. Move fd 1 onto stderr so stdout stays a clean
# JSON-RPC channel, and keep a dup of the original to answer on.
_rpc = os.fdopen(os.dup(1), "wb")
os.dup2(2, 1)

# The driver appends `-nographic` when it finds no display in the environment,
# and that would override the `-display egl-headless` the guest needs for GL.
# So: claim a display, but a bogus one, so nothing can reach the real session.
os.environ["WAYLAND_DISPLAY"] = "mujo-sandbox-none"
os.environ.pop("DISPLAY", None)

vm = machines[0]  # noqa: F821  (injected by the test driver)
UID = 1000
SHARED_SHOT = "/tmp/shared/shot.png"
_size = []
_user = []

# ── VM lifetime ───────────────────────────────────────────────────────────
# The VM holds 4 GiB (virtualisation.memorySize) for as long as it is booted,
# and nothing here used to ever take it down: the loop below only ends on stdin
# EOF, so an MCP client that stays alive but stops calling — an agent session
# left open in another terminal — pinned that memory indefinitely. One was found
# resident for 1h41m holding 1.4 GB.
#
# Two guards. An idle watchdog powers the VM off after IDLE_SHUTDOWN_SEC with no
# tool call, and atexit/signal handlers take it down when this process ends by
# any route. Neither loses anything: ensure_up() boots on demand, so an idle
# teardown costs the next caller the same ~45s cold start the first call always
# paid, and the guest keeps no state worth saving (diskImage = null, tmpfs root,
# and the only host mount is read-only).
IDLE_SHUTDOWN_SEC = int(os.environ.get("MUJO_SANDBOX_IDLE_SEC", "600"))

# Guards every use of `vm`, so the watchdog can never pull the VM out from under
# an in-flight tool call. Reentrant: teardown() runs on the calling thread.
_vm_lock = threading.RLock()
_last_use = time.time()


def teardown(reason):
    """Power the VM off. Safe to call repeatedly and when already down."""
    with _vm_lock:
        if not vm.booted:
            return
        print(f"sandbox: {reason}; powering the VM off", file=sys.stderr)
        try:
            # crash() is one QMP/monitor 'quit' rather than a guest `poweroff`
            # that waits on the backdoor shell. An abandoned sandbox is exactly
            # the case where that shell may be wedged, and there is nothing to
            # flush, so the abrupt route is the reliable one here.
            vm.crash()
        except Exception as e:
            print(f"sandbox: teardown failed: {e}", file=sys.stderr)


# Poll often enough to be responsive without busy-waiting: 30s in the default
# 600s configuration, and proportionally tighter when the timeout is shortened.
_WATCH_TICK = min(30, max(1, IDLE_SHUTDOWN_SEC // 4))


def _idle_watchdog():
    while True:
        time.sleep(_WATCH_TICK)
        with _vm_lock:
            idle = time.time() - _last_use
            if vm.booted and idle > IDLE_SHUTDOWN_SEC:
                teardown(f"idle for {int(idle)}s")


threading.Thread(target=_idle_watchdog, daemon=True).start()
atexit.register(lambda: teardown("server exiting"))
try:
    for _sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(_sig, lambda *_: sys.exit(0))
except (ValueError, OSError) as e:
    print(f"sandbox: signal handlers unavailable ({e})", file=sys.stderr)


def user_name():
    if not _user:
        _user.append(vm.execute(f"id -nu {UID}")[1].strip())
    return _user[0]


def ensure_up():
    if vm.booted:
        return
    t_start = time.time()
    print(f"sandbox: booting VM...", file=sys.stderr)
    vm.start()
    t_qemu = time.time()
    print(f"sandbox: vm.start() took {t_qemu - t_start:.2f}s, waiting for multi-user.target...", file=sys.stderr)
    vm.wait_for_unit("multi-user.target")
    t_multi = time.time()
    print(f"sandbox: multi-user.target reached in {t_multi - t_qemu:.2f}s, waiting for niri.service...", file=sys.stderr)
    try:
        vm.wait_for_unit("niri.service", user=user_name(), timeout=180)
    except Exception as e:  # a dead compositor is still worth screenshotting
        print(f"niri did not come up: {e}", file=sys.stderr)
    t_niri = time.time()
    print(f"sandbox: niri.service reached in {t_niri - t_multi:.2f}s, waiting for quickshell...", file=sys.stderr)
    if wait_for_shell(0):
        t_qs = time.time()
        print(f"sandbox: quickshell shell_state ready in {t_qs - t_niri:.2f}s (Total cold boot: {t_qs - t_start:.2f}s)", file=sys.stderr)
        time.sleep(0.5)


def run(cmd, timeout=120):
    """Run a command in the guest as root, stderr folded into stdout."""
    ensure_up()
    return vm.execute(f"({cmd}) 2>&1", check_return=False, timeout=timeout)[1]


def user_run(cmd, timeout=120):
    """Run a command in the guest as the sandbox user, inside their session."""
    inner = (
        f"export XDG_RUNTIME_DIR=/run/user/{UID}; "
        'export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"; '
        + cmd
    )
    return run(f"runuser -u {user_name()} -- /bin/sh -c {shlex.quote(inner)}", timeout)


def shell_state():
    """(config loads so far, systemd restarts so far) for qs-bar."""
    ready_file = vm.shared_dir / "qs_ready"
    if ready_file.exists():
        try:
            return (len(ready_file.read_text().splitlines()), 0)
        except Exception:
            return (1, 0)
    return (0, 0)


def wait_for_shell(base_loads, base_restarts=None, timeout=30):
    deadline = time.time() + timeout
    ready_file = vm.shared_dir / "qs_ready"
    while time.time() < deadline:
        if ready_file.exists():
            try:
                loads = len(ready_file.read_text().splitlines())
                if loads > base_loads:
                    return True
            except Exception:
                pass
        time.sleep(0.02)
    # Fallback to journalctl check only if file check timed out
    out = user_run(
        "journalctl --user -u qs-bar --no-pager | grep -c 'Configuration Loaded'; "
        "systemctl --user show qs-bar.service -p NRestarts --value"
    )
    nums = [int(n) for n in out.split() if n.isdigit()]
    loads, restarts = tuple((nums + [0, 0])[:2])
    return loads > base_loads


def screenshot():
    """Grab the display with grim directly into the shared exchange dir."""
    ensure_up()
    host_png = vm.shared_dir / "shot.png"
    host_png.unlink(missing_ok=True)
    out = user_run(f"grim {SHARED_SHOT}")
    if not host_png.exists():
        raise RuntimeError(f"grim failed: {out.strip()}")
    png = host_png.read_bytes()
    # PNG IHDR: width and height are big-endian u32 at offsets 16 and 20.
    _size[:] = [
        int.from_bytes(png[16:20], "big"),
        int.from_bytes(png[20:24], "big"),
    ]
    return png


def screen_size():
    if not _size:
        screenshot()
    return _size


def send_input(events):
    vm.qmp_client.send("input-send-event", {"events": events})


def click(x, y, button="left"):
    w, h = screen_size()
    ax = x * 32767 // max(w - 1, 1)
    ay = y * 32767 // max(h - 1, 1)
    # Batch position and press into one QMP transaction, followed by release
    send_input(
        [
            {"type": "abs", "data": {"axis": "x", "value": ax}},
            {"type": "abs", "data": {"axis": "y", "value": ay}},
            {"type": "btn", "data": {"button": button, "down": True}},
        ]
    )
    time.sleep(0.01)
    send_input([{"type": "btn", "data": {"button": button, "down": False}}])


TOOLS = [
    {
        "name": "screenshot",
        "description": "Take a PNG screenshot of the sandbox display.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "click",
        "description": "Click at pixel coordinates on the sandbox display.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "x": {"type": "integer"},
                "y": {"type": "integer"},
                "button": {"type": "string", "enum": ["left", "middle", "right"]},
            },
            "required": ["x", "y"],
        },
    },
    {
        "name": "type",
        "description": "Type text into the focused window.",
        "inputSchema": {
            "type": "object",
            "properties": {"text": {"type": "string"}},
            "required": ["text"],
        },
    },
    {
        "name": "key",
        "description": "Press a key combo, QEMU sendkey syntax (e.g. 'meta_l-spc', 'ctrl-alt-f2', 'ret').",
        "inputSchema": {
            "type": "object",
            "properties": {"keys": {"type": "string"}},
            "required": ["keys"],
        },
    },
    {
        "name": "logs",
        "description": "Read the tail of a systemd user unit's journal (default qs-bar, the shell).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "unit": {"type": "string"},
                "lines": {"type": "integer"},
            },
        },
    },
    {
        "name": "reload",
        "description": "Restart the shell so it picks up working-tree edits, then report its state.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "exec",
        "description": "Run a shell command inside the sandbox as root and return its combined output.",
        "inputSchema": {
            "type": "object",
            "properties": {"cmd": {"type": "string"}},
            "required": ["cmd"],
        },
    },
]


def text(s):
    return [{"type": "text", "text": s if s.strip() else "(no output)"}]


def call(name, a):
    """Serialise every VM touch and mark the server as active."""
    global _last_use
    with _vm_lock:
        _last_use = time.time()
        try:
            return _dispatch(name, a)
        finally:
            # Also stamp on the way out, so a call longer than the idle window
            # is not immediately followed by a teardown.
            _last_use = time.time()


def _dispatch(name, a):
    if name == "screenshot":
        png = screenshot()
        w, h = _size
        return [
            {"type": "text", "text": f"{w}x{h}"},
            {
                "type": "image",
                "data": base64.b64encode(png).decode(),
                "mimeType": "image/png",
            },
        ]
    if name == "click":
        ensure_up()
        click(int(a["x"]), int(a["y"]), a.get("button", "left"))
        return text(f"clicked {a['x']},{a['y']}")
    if name == "type":
        ensure_up()
        vm.send_chars(a["text"])
        return text(f"typed {len(a['text'])} chars")
    if name == "key":
        ensure_up()
        vm.send_key(a["keys"])
        return text(f"pressed {a['keys']}")
    if name == "logs":
        unit = a.get("unit", "qs-bar")
        n = int(a.get("lines", 100))
        return text(
            user_run(f"journalctl --user -u {shlex.quote(unit)} -n {n} --no-pager")
        )
    if name == "reload":
        loads, restarts = shell_state()
        user_run("systemctl --user restart qs-bar.service")
        if wait_for_shell(loads, restarts):
            # ponytail: fixed settle — the load event fires before the layer
            # surfaces are mapped and painted, so an immediate screenshot
            # catches an empty desktop. Poll for a stable frame if 3s ever
            # stops being enough.
            time.sleep(0.3)
            return text("shell reloaded from the working tree and back on screen")
        return text(
            "shell did not come back up; last log lines:\n"
            + user_run("journalctl --user -u qs-bar -n 30 --no-pager")
        )
    if name == "exec":
        return text(run(a["cmd"]))
    raise ValueError(f"unknown tool {name}")


def send(msg):
    _rpc.write((json.dumps(msg) + "\n").encode())
    _rpc.flush()


def reply(mid, **kw):
    if mid is not None:
        send({"jsonrpc": "2.0", "id": mid, **kw})


if os.environ.get("MUJO_SANDBOX_STANDALONE") == "1":
    print("sandbox: standalone mode requested, booting VM for live observation...", file=sys.stderr)
    ensure_up()
    print("sandbox: VM is active. Live display stream listening on 127.0.0.1:5920", file=sys.stderr)
    while True:
        with _vm_lock:
            _last_use = time.time()
        time.sleep(2)

while True:
    line = sys.stdin.readline()
    if not line:
        break
    if not line.strip():
        continue
    with _vm_lock:
        _last_use = time.time()
    req = json.loads(line)
    mid, method = req.get("id"), req.get("method")
    try:
        if method == "initialize":
            params = req.get("params") or {}
            reply(
                mid,
                result={
                    "protocolVersion": params.get("protocolVersion", "2024-11-05"),
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "mujo-sandbox", "version": "0.1.0"},
                },
            )
        elif method == "tools/list":
            reply(mid, result={"tools": TOOLS})
        elif method == "tools/call":
            p = req["params"]
            reply(mid, result={"content": call(p["name"], p.get("arguments") or {})})
        elif method == "ping":
            reply(mid, result={})
        else:
            reply(mid, error={"code": -32601, "message": f"unknown method {method}"})
    except Exception as e:
        import traceback
        reply(mid, error={"code": -32000, "message": traceback.format_exc()})
