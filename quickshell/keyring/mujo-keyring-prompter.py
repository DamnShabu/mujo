#!/usr/bin/env python3
"""mujō keyring prompter.

A drop-in replacement for gcr's GTK "system prompter". It owns the
``org.gnome.keyring.SystemPrompter`` bus name and implements the
``org.gnome.keyring.internal.Prompter`` interface that gnome-keyring-daemon
(and any Secret Service client) drives when a keyring/collection needs to be
unlocked or a secret confirmed.

The password never travels in cleartext over D-Bus: gcr uses an unauthenticated
Diffie-Hellman "secret exchange" to protect it. We reuse ``Gcr.SecretExchange``
(the exact same implementation the rest of gcr uses) rather than reimplement the
crypto, so we interoperate byte-for-byte with the daemon.

The actual UI is drawn by the mujō quickshell shell: for each prompt we connect
to its unix socket, send the prompt as one JSON line, and read one JSON line
back with the user's answer. If the shell is unreachable we cancel the prompt
(reply "no") so applications never hang forever.
"""

import json
import os
import sys

import gi

gi.require_version("Gcr", "4")
from gi.repository import Gcr, Gio, GLib  # noqa: E402

# ── D-Bus constants (from gcr/gcr-dbus-constants.h) ─────────────────────────
BUS_NAME = "org.gnome.keyring.SystemPrompter"
PROMPTER_PATH = "/org/gnome/keyring/Prompter"
PROMPTER_IFACE = "org.gnome.keyring.internal.Prompter"
CALLBACK_IFACE = "org.gnome.keyring.internal.Prompter.Callback"

REPLY_NONE = ""
REPLY_YES = "yes"
REPLY_NO = "no"
TYPE_PASSWORD = "password"
TYPE_CONFIRM = "confirm"

INTROSPECTION_XML = f"""
<node>
  <interface name="{PROMPTER_IFACE}">
    <method name="BeginPrompting">
      <arg name="callback" type="o" direction="in"/>
    </method>
    <method name="PerformPrompt">
      <arg name="callback" type="o" direction="in"/>
      <arg name="type" type="s" direction="in"/>
      <arg name="properties" type="a{{sv}}" direction="in"/>
      <arg name="exchange" type="s" direction="in"/>
    </method>
    <method name="StopPrompting">
      <arg name="callback" type="o" direction="in"/>
    </method>
  </interface>
</node>
"""

SOCKET_PATH = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"),
    "mujo-keyring.sock",
)


def log(*a):
    print("[mujo-keyring]", *a, file=sys.stderr, flush=True)


class ActivePrompt:
    """One prompting session, keyed by (caller bus name, callback object path)."""

    def __init__(self, caller, path):
        self.caller = caller  # unique bus name of the client
        self.path = path  # callback object path on the client
        self.exchange = Gcr.SecretExchange.new(None)
        self.received = False  # have we ingested the client's public key?
        self.props = {}  # last prompt properties (title/message/…)
        self.ptype = TYPE_PASSWORD
        self.ui_conn = None  # live socket connection to the shell UI
        self.watch_id = 0  # bus watch for the calling client

    def key(self):
        return (self.caller, self.path)


class Prompter:
    def __init__(self):
        self.connection = None
        self.active = {}  # (caller, path) -> ActivePrompt

    # ── lifecycle ───────────────────────────────────────────────────────────
    def run(self):
        self.loop = GLib.MainLoop()
        Gio.bus_own_name(
            Gio.BusType.SESSION,
            BUS_NAME,
            Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT | Gio.BusNameOwnerFlags.REPLACE,
            self._on_bus_acquired,
            self._on_name_acquired,
            self._on_name_lost,
        )
        self.loop.run()

    def _on_bus_acquired(self, connection, name):
        self.connection = connection
        node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION_XML)
        connection.register_object(
            PROMPTER_PATH,
            node.interfaces[0],
            self._on_method_call,
            None,
            None,
        )
        log("registered", PROMPTER_PATH)

    def _on_name_acquired(self, connection, name):
        log("owning", name)

    def _on_name_lost(self, connection, name):
        # Either the bus went away or another agent replaced us.
        log("lost name", name, "— exiting")
        self.loop.quit()

    # ── D-Bus method dispatch ───────────────────────────────────────────────
    def _on_method_call(self, conn, sender, path, iface, method, params, invocation):
        try:
            if method == "BeginPrompting":
                (callback_path,) = params.unpack()
                self._begin(sender, callback_path, invocation)
            elif method == "PerformPrompt":
                callback_path, ptype, props, exchange = params.unpack()
                self._perform(sender, callback_path, ptype, props, exchange, invocation)
            elif method == "StopPrompting":
                (callback_path,) = params.unpack()
                self._stop(sender, callback_path, invocation)
            else:
                invocation.return_error_literal(
                    Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, method
                )
        except Exception as e:  # never let an exception kill the bus handler
            log("method", method, "error:", repr(e))
            try:
                invocation.return_value(GLib.Variant("()", ()))
            except Exception:
                pass

    def _begin(self, sender, callback_path, invocation):
        key = (sender, callback_path)
        if key in self.active:
            invocation.return_error_literal(
                Gio.dbus_error_quark(),
                Gio.DBusError.FAILED,
                "Already begun prompting for this callback",
            )
            return
        active = ActivePrompt(sender, callback_path)
        # Drop the session (and any showing dialog) if the calling client dies.
        active.watch_id = Gio.bus_watch_name_on_connection(
            self.connection,
            sender,
            Gio.BusNameWatcherFlags.NONE,
            None,
            lambda c, n: self._caller_vanished(key),
        )
        self.active[key] = active
        invocation.return_value(GLib.Variant("()", ()))
        # Signal readiness; carries our DH public key via begin().
        self._send_ready(active, REPLY_NONE, None)

    def _perform(self, sender, callback_path, ptype, props, exchange, invocation):
        active = self.active.get((sender, callback_path))
        if active is None:
            invocation.return_error_literal(
                Gio.dbus_error_quark(),
                Gio.DBusError.FAILED,
                "Not begun prompting for this callback",
            )
            return
        invocation.return_value(GLib.Variant("()", ()))

        if not active.exchange.receive(exchange):
            log("invalid secret exchange received")
            self._send_ready(active, REPLY_NO, None)
            return
        active.received = True
        active.ptype = ptype
        active.props = props or {}

        self._ask_ui(active)

    def _stop(self, sender, callback_path, invocation):
        invocation.return_value(GLib.Variant("()", ()))
        active = self.active.pop((sender, callback_path), None)
        if active is None:
            return
        self._teardown(active)
        # Let the client know we're done with this callback.
        self.connection.call(
            active.caller,
            active.path,
            CALLBACK_IFACE,
            "PromptDone",
            None,
            None,
            Gio.DBusCallFlags.NO_AUTO_START,
            -1,
            None,
            None,
        )

    def _caller_vanished(self, key):
        active = self.active.pop(key, None)
        if active is not None:
            log("calling client vanished — tearing down prompt")
            self._teardown(active)

    def _teardown(self, active):
        """Close the shell UI connection (dismissing any showing dialog) and
        stop watching the caller."""
        if active.ui_conn is not None:
            try:
                active.ui_conn.close(None)
            except Exception:
                pass
            active.ui_conn = None
        if active.watch_id:
            Gio.bus_unwatch_name(active.watch_id)
            active.watch_id = 0

    # ── reply path ──────────────────────────────────────────────────────────
    def _send_ready(self, active, response, secret, choice_chosen=None):
        if not active.received:
            sent = active.exchange.begin()
        else:
            sent = active.exchange.send(
                secret if secret is not None else "", -1 if secret else 0
            )

        props = {}
        if choice_chosen is not None:
            props["choice-chosen"] = GLib.Variant("b", bool(choice_chosen))

        self.connection.call(
            active.caller,
            active.path,
            CALLBACK_IFACE,
            "PromptReady",
            GLib.Variant("(sa{sv}s)", (response, props, sent)),
            None,
            Gio.DBusCallFlags.NO_AUTO_START,
            -1,
            None,
            self._on_ready_done,
            active,
        )

    def _on_ready_done(self, conn, res, active):
        try:
            conn.call_finish(res)
        except GLib.Error as e:
            # Client vanished / rejected — drop the session.
            log("PromptReady failed:", e.message)
            self.active.pop(active.key(), None)

    # ── UI over the shell's unix socket ─────────────────────────────────────
    def _ask_ui(self, active):
        def s(key):
            v = active.props.get(key)
            return v if isinstance(v, str) else ""

        def b(key):
            v = active.props.get(key)
            return bool(v) if isinstance(v, bool) else False

        request = {
            "type": active.ptype,
            "title": s("title"),
            "message": s("message"),
            "description": s("description"),
            "warning": s("warning"),
            "choice_label": s("choice-label"),
            "choice_chosen": b("choice-chosen"),
            "password_new": b("password-new"),
            "continue_label": s("continue-label"),
            "cancel_label": s("cancel-label"),
        }

        client = Gio.SocketClient.new()
        addr = Gio.UnixSocketAddress.new(SOCKET_PATH)
        client.connect_async(addr, None, self._on_ui_connected, (active, request))

    def _on_ui_connected(self, client, res, data):
        active, request = data
        try:
            conn = client.connect_finish(res)
        except GLib.Error as e:
            log("shell unreachable (%s) — cancelling prompt" % e.message)
            self._send_ready(active, REPLY_NO, None)
            return

        active.ui_conn = conn
        line = (json.dumps(request) + "\n").encode()
        ostream = conn.get_output_stream()
        istream = Gio.DataInputStream.new(conn.get_input_stream())

        def on_written(stream, wres):
            try:
                stream.write_all_finish(wres)
            except GLib.Error as e:
                log("write failed:", e.message)
                self._send_ready(active, REPLY_NO, None)
                conn.close_async(0, None, None)
                return
            istream.read_line_async(0, None, on_line, None)

        def on_line(stream, lres, _):
            try:
                raw, _len = stream.read_line_finish_utf8(lres)
            except GLib.Error as e:
                log("read failed:", e.message)
                raw = None
            conn.close_async(0, None, None)
            if active.ui_conn is conn:
                active.ui_conn = None
            self._handle_ui_reply(active, raw)

        ostream.write_all_async(line, 0, None, on_written)

    def _handle_ui_reply(self, active, raw):
        # If the session was already torn down (client vanished / StopPrompting),
        # there's no one to reply to.
        if active.key() not in self.active:
            return
        if not raw:
            self._send_ready(active, REPLY_NO, None)
            return
        try:
            reply = json.loads(raw)
        except Exception:
            self._send_ready(active, REPLY_NO, None)
            return

        # Only echo choice-chosen back if the prompt actually offered a choice.
        offered_choice = (
            isinstance(active.props.get("choice-label"), str)
            and active.props.get("choice-label") != ""
        )
        choice = reply.get("choice_chosen") if offered_choice else None

        if reply.get("response") == REPLY_YES:
            secret = reply.get("password", "") if active.ptype == TYPE_PASSWORD else ""
            self._send_ready(active, REPLY_YES, secret, choice_chosen=choice)
        else:
            self._send_ready(active, REPLY_NO, None, choice_chosen=choice)


if __name__ == "__main__":
    Prompter().run()
