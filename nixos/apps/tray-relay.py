#!/usr/bin/env python3
"""Relay tray items and notifications from the quarantine guest's private
session bus to the host's.

Flatpak applications in the quarantine domain run under `dbus-run-session`
because zypak -- the Chromium shim every Electron Flatpak runs under -- spawns
its renderers through a guest-local org.freedesktop.portal.Flatpak, and the
host's would spawn them on the host.  The side effect was that their tray icons
never left the domain: closing Vesktop "to tray" just lost the window, because
there was no tray on that bus to close to.

This owns org.kde.StatusNotifierWatcher on the guest bus.  For each item that
registers it opens a *separate* connection to the host bus (the socat forwarder
mujo-quarantine-session exports as MUJO_HOST_BUS) and forwards every message
both ways, so the host's watcher sees an ordinary StatusNotifierItem and can
call back into it for the icon, title and menu.  One connection per item,
because the item's identity on the host bus *is* the connection's unique name.

Notifications ride the same host connection when MUJO_RELAY_NOTIFICATIONS is
set; only the outbound call is carried, so notification actions do not come
back (the host proxy's policy is --call, not --broadcast).
"""

import asyncio
import os
import sys

from dbus_next import Message, MessageType, Variant
from dbus_next.aio import MessageBus

WATCHER = "org.kde.StatusNotifierWatcher"
WATCHER_PATH = "/StatusNotifierWatcher"
ITEM_PATH = "/StatusNotifierItem"
NOTIFY = "org.freedesktop.Notifications"
NOTIFY_PATH = "/org/freedesktop/Notifications"
DBUS = "org.freedesktop.DBus"
PROPS = "org.freedesktop.DBus.Properties"

INTROSPECT = """<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
  <interface name="org.kde.StatusNotifierWatcher">
    <method name="RegisterStatusNotifierItem"><arg type="s" direction="in"/></method>
    <method name="RegisterStatusNotifierHost"><arg type="s" direction="in"/></method>
    <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
    <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
    <property name="ProtocolVersion" type="i" access="read"/>
    <signal name="StatusNotifierItemRegistered"><arg type="s"/></signal>
    <signal name="StatusNotifierItemUnregistered"><arg type="s"/></signal>
    <signal name="StatusNotifierHostRegistered"/>
  </interface>
  <interface name="org.freedesktop.DBus.Properties">
    <method name="Get">
      <arg type="s" direction="in"/><arg type="s" direction="in"/>
      <arg type="v" direction="out"/>
    </method>
    <method name="GetAll">
      <arg type="s" direction="in"/><arg type="a{sv}" direction="out"/>
    </method>
  </interface>
</node>"""


class Relay:
    def __init__(self, guest, host_addr, relay_notifications):
        self.guest = guest
        self.host_addr = host_addr
        self.relay_notifications = relay_notifications
        # guest unique name -> (host connection, item object path)
        self.items = {}
        self.notify_host = None

    # ── setup ─────────────────────────────────────────────────────────────

    async def start(self):
        self.guest.add_message_handler(self._on_guest)
        await self.guest.request_name(WATCHER)
        await self._add_match(
            self.guest, f"type='signal',interface='{DBUS}',member='NameOwnerChanged'"
        )
        if self.relay_notifications:
            self.notify_host = await MessageBus(bus_address=self.host_addr).connect()
            await self.guest.request_name(NOTIFY)
        self._announce_host()

    async def _add_match(self, bus, rule):
        await bus.call(
            Message(
                destination=DBUS,
                path="/org/freedesktop/DBus",
                interface=DBUS,
                member="AddMatch",
                signature="s",
                body=[rule],
            )
        )

    def _announce_host(self):
        # Applications that wait for a tray to exist watch for this rather than
        # polling IsStatusNotifierHostRegistered.
        self.guest.send(
            Message(
                message_type=MessageType.SIGNAL,
                path=WATCHER_PATH,
                interface=WATCHER,
                member="StatusNotifierHostRegistered",
            )
        )

    # ── guest bus ─────────────────────────────────────────────────────────

    def _on_guest(self, msg):
        if msg.message_type == MessageType.SIGNAL:
            if msg.interface == DBUS and msg.member == "NameOwnerChanged":
                name, _old, new = msg.body
                if not new and name in self.items:
                    asyncio.get_running_loop().create_task(self._drop(name))
                return None
            entry = self.items.get(msg.sender)
            if entry is not None:
                host, item_path = entry
                host.send(
                    Message(
                        message_type=MessageType.SIGNAL,
                        path=ITEM_PATH if msg.path == item_path else msg.path,
                        interface=msg.interface,
                        member=msg.member,
                        signature=msg.signature,
                        body=msg.body,
                    )
                )
            return None

        if msg.message_type != MessageType.METHOD_CALL:
            return None

        if msg.interface == "org.freedesktop.DBus.Introspectable":
            return Message.new_method_return(msg, "s", [INTROSPECT])

        if msg.path == NOTIFY_PATH:
            if self.notify_host is None:
                return None
            asyncio.get_running_loop().create_task(self._forward_notify(msg))
            return True

        if msg.path != WATCHER_PATH:
            return None

        if msg.member == "RegisterStatusNotifierItem":
            asyncio.get_running_loop().create_task(self._register(msg.sender, msg.body[0]))
            return Message.new_method_return(msg)
        if msg.member == "RegisterStatusNotifierHost":
            return Message.new_method_return(msg)
        if msg.interface == PROPS:
            props = {
                "RegisteredStatusNotifierItems": Variant(
                    "as", [b.unique_name for b, _ in self.items.values()]
                ),
                "IsStatusNotifierHostRegistered": Variant("b", True),
                "ProtocolVersion": Variant("i", 0),
            }
            if msg.member == "GetAll":
                return Message.new_method_return(msg, "a{sv}", [props])
            if msg.member == "Get" and msg.body[1] in props:
                return Message.new_method_return(msg, "v", [props[msg.body[1]]])
        return None

    # ── item bridging ─────────────────────────────────────────────────────

    async def _register(self, sender, arg):
        # The spec lets an application pass either its bus name or the object
        # path of the item; which one it picked decides where the other half
        # comes from.
        if arg.startswith("/"):
            service, item_path = sender, arg
        else:
            service, item_path = arg, ITEM_PATH

        owner = service
        if not owner.startswith(":"):
            reply = await self.guest.call(
                Message(
                    destination=DBUS,
                    path="/org/freedesktop/DBus",
                    interface=DBUS,
                    member="GetNameOwner",
                    signature="s",
                    body=[service],
                )
            )
            if reply is None or reply.message_type != MessageType.METHOD_RETURN:
                return
            owner = reply.body[0]

        if owner in self.items:
            return

        host = await MessageBus(bus_address=self.host_addr).connect()
        self.items[owner] = (host, item_path)
        host.add_message_handler(lambda m: self._on_host(owner, m))
        await self._add_match(self.guest, f"type='signal',sender='{owner}'")
        await host.call(
            Message(
                destination=WATCHER,
                path=WATCHER_PATH,
                interface=WATCHER,
                member="RegisterStatusNotifierItem",
                signature="s",
                body=[host.unique_name],
            )
        )
        self._announce_host()

    def _on_host(self, owner, msg):
        if msg.message_type != MessageType.METHOD_CALL:
            return None
        asyncio.get_running_loop().create_task(self._to_guest(owner, msg))
        return True

    async def _to_guest(self, owner, msg):
        entry = self.items.get(owner)
        if entry is None:
            return
        host, item_path = entry
        reply = await self.guest.call(
            Message(
                destination=owner,
                path=item_path if msg.path == ITEM_PATH else msg.path,
                interface=msg.interface,
                member=msg.member,
                signature=msg.signature,
                body=msg.body,
            )
        )
        if reply is None:
            return
        host.send(
            Message(
                message_type=reply.message_type,
                destination=msg.sender,
                reply_serial=msg.serial,
                error_name=reply.error_name,
                signature=reply.signature,
                body=reply.body,
            )
        )

    async def _drop(self, owner):
        host, _ = self.items.pop(owner)
        # Dropping the connection is what unregisters the item: the host's
        # watcher tracks the name, not a call we could make.
        host.disconnect()

    # ── notifications ─────────────────────────────────────────────────────

    async def _forward_notify(self, msg):
        reply = await self.notify_host.call(
            Message(
                destination=NOTIFY,
                path=NOTIFY_PATH,
                interface=msg.interface,
                member=msg.member,
                signature=msg.signature,
                body=msg.body,
            )
        )
        if reply is None:
            return
        self.guest.send(
            Message(
                message_type=reply.message_type,
                destination=msg.sender,
                reply_serial=msg.serial,
                error_name=reply.error_name,
                signature=reply.signature,
                body=reply.body,
            )
        )


async def main():
    host_addr = os.environ.get("MUJO_HOST_BUS")
    if not host_addr:
        print("mujo-tray-relay: MUJO_HOST_BUS is unset", file=sys.stderr)
        return 1
    guest = await MessageBus().connect()
    relay = Relay(guest, host_addr, os.environ.get("MUJO_RELAY_NOTIFICATIONS") == "1")
    await relay.start()
    await guest.wait_for_disconnect()
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
