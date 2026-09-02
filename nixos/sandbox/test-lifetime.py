#!/usr/bin/env python3
"""Self-check for the sandbox VM's lifetime guards. Prints PASS/FAIL, exits 1 on failure.

    python3 nixos/sandbox/test-lifetime.py

The VM holds 4 GiB while booted, so the thing worth testing is not that it
works but that it ever stops: mcp.py's request loop only ends on stdin EOF, and
an MCP client that stays alive while going idle used to pin that memory
indefinitely. These four cases cover both directions -- it must come down when
nobody is using it, and it must never come down while somebody is.

Runs mcp.py against a fake Machine, so it needs no QEMU and takes ~15s.
"""

import subprocess
import sys
import textwrap
from pathlib import Path

MCP = Path(__file__).with_name("mcp.py")

# Each case runs in its own process: mcp.py installs signal handlers and an
# atexit hook, and reads fd 0 to EOF, none of which survives being run twice in
# one interpreter.
HARNESS = '''
import os, subprocess, sys, threading, time

class FakeVM:
    """Just the slice of the driver's Machine API that mcp.py touches."""
    def __init__(self):
        self.booted = True
        self.crashed = 0
        self.started = 0
        self.execs = 0
        self.shared_dir = None
    def crash(self):   self.crashed += 1; self.booted = False
    def start(self):   self.started += 1; self.booted = True
    def execute(self, *a, **k): self.execs += 1; return (0, "1000\\n")
    def wait_for_unit(self, *a, **k): return None

class WedgedVM(FakeVM):
    """A VM whose monitor never answers: crash() blocks, exactly as
    wait_for_shutdown() does when QEMU has stopped reading the monitor socket.
    Its `pid` is a real child process, so the escalation has something to kill."""
    def __init__(self):
        super().__init__()
        self.proc = subprocess.Popen(["sleep", "300"])
        self.pid = self.proc.pid
    def crash(self):
        self.crashed += 1
        time.sleep(600)

MODE = sys.argv[1]
os.environ["MUJO_SANDBOX_IDLE_SEC"] = "2"
vm_obj = WedgedVM() if MODE == "wedged" else FakeVM()
g = {"machines": [vm_obj], "__name__": "__main__"}
src = open(%(mcp)r).read()

CALL = (b'{"jsonrpc":"2.0","id":1,"method":"tools/call",'
        b'"params":{"name":"exec","arguments":{"cmd":"true"}}}\\n')

def serve():
    try:
        exec(compile(src, "mcp.py", "exec"), g)
    except SystemExit:
        pass

r, w = os.pipe()

if MODE == "eof":
    # Client disconnects cleanly: stdin hits EOF, the loop ends, atexit runs.
    os.write(w, b'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\\n')
    os.close(w)
    os.dup2(r, 0)
    serve()
    import atexit; atexit._run_exitfuncs()
    ok = (not vm_obj.booted) and vm_obj.crashed >= 1
    detail = "booted=%%s crashed=%%d" %% (vm_obj.booted, vm_obj.crashed)
else:
    os.dup2(r, 0)
    threading.Thread(target=serve, daemon=True).start()

    if MODE == "idle":
        # The regression: a client that stays connected but stops calling.
        time.sleep(5)
        ok = (not vm_obj.booted) and vm_obj.crashed >= 1
        detail = "booted=%%s crashed=%%d" %% (vm_obj.booted, vm_obj.crashed)

    elif MODE == "active":
        # The watchdog must never pull the VM out from under a live client.
        for _ in range(6):
            os.write(w, CALL)
            time.sleep(1)
        ok = vm_obj.booted and vm_obj.crashed == 0
        detail = "booted=%%s crashed=%%d execs=%%d" %% (
            vm_obj.booted, vm_obj.crashed, vm_obj.execs)

    elif MODE == "wedged":
        # The ten-hour VM: crash() never returns, so without a deadline the
        # watchdog blocks holding _vm_lock and the 4 GiB is never reclaimed.
        time.sleep(28)
        alive = vm_obj.proc.poll() is None
        ok = (not alive) and (not vm_obj.booted)
        detail = "qemu_alive=%%s booted=%%s" %% (alive, vm_obj.booted)

    elif MODE == "reboot":
        # An idle teardown must cost the next caller a boot, not an error.
        time.sleep(5)
        went_down = not vm_obj.booted
        os.write(w, CALL)
        time.sleep(2)
        ok = went_down and vm_obj.booted and vm_obj.started >= 1
        detail = "went_down=%%s booted=%%s starts=%%d" %% (
            went_down, vm_obj.booted, vm_obj.started)

print(("PASS " if ok else "FAIL ") + MODE + "  " + detail)
sys.exit(0 if ok else 1)
''' % {"mcp": str(MCP)}

CASES = {
    "idle": "connected but idle -> VM is powered off",
    "eof": "client disconnects -> VM is powered off",
    "active": "continuous use -> VM stays up",
    "reboot": "after idle teardown -> next call boots it again",
    "wedged": "monitor never answers -> QEMU is SIGKILLed anyway",
}


def main():
    failed = 0
    for mode, what in CASES.items():
        p = subprocess.run(
            [sys.executable, "-c", HARNESS, mode],
            capture_output=True, text=True, timeout=90,
        )
        # mcp.py does os.dup2(2, 1) to keep stdout a clean JSON-RPC channel, so
        # the harness verdict surfaces on stderr. The exit status is the signal.
        ok = p.returncode == 0
        blob = (p.stdout + p.stderr).splitlines()
        detail = next(
            (ln for ln in reversed(blob) if ln.startswith(("PASS", "FAIL"))),
            "no result",
        )
        print(f"{'PASS' if ok else 'FAIL'} {mode}  {detail.split(chr(32) * 2)[-1]}")
        print(f"      {what}")
        failed += not ok
    print(textwrap.fill(
        f"{len(CASES) - failed}/{len(CASES)} sandbox lifetime checks passed", 80))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
