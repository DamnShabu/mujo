#!/usr/bin/env python3
"""Self-check for tray-relay.py. Needs dbus-daemon and python3-dbus-next; no VM.

Stands up two private session buses -- a fake "guest" and a fake "host" --
registers a tray item on the guest one through the relay, and asserts the three
things that break silently if the relay is wrong:

  1. the item reaches the host watcher at all,
  2. a property read on the host reaches the item at its *own* object path
     (the relay exports /StatusNotifierItem, the item lives elsewhere),
  3. a signal the item emits comes out on the host under the exported path.

    python3 nixos/apps/test-tray-relay.py
"""

import asyncio
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile

from dbus_next import Message, MessageType, PropertyAccess
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, dbus_property, method, signal

HERE = os.path.dirname(os.path.abspath(__file__))
ITEM_OWN_PATH = "/org/ayatana/NotificationItem/test"

_spec = importlib.util.spec_from_file_location("tray_relay", os.path.join(HERE, "tray-relay.py"))
tray_relay = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tray_relay)

CONFIG = """<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:path={sock}</listen>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
"""


def start_bus(tmp, name):
    sock = os.path.join(tmp, name)
    conf = os.path.join(tmp, f"{name}.conf")
    with open(conf, "w") as fh:
        fh.write(CONFIG.format(sock=sock))
    proc = subprocess.Popen(
        ["dbus-daemon", "--config-file", conf, "--nofork"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(200):
        if os.path.exists(sock):
            return proc, f"unix:path={sock}"
        subprocess.run(["sleep", "0.02"])
    proc.kill()
    raise RuntimeError(f"{name} bus did not start")


class FakeItem(ServiceInterface):
    def __init__(self):
        super().__init__("org.kde.StatusNotifierItem")

    @dbus_property(access=PropertyAccess.READ)
    def Title(self) -> "s":  # noqa: N802
        return "quarantined-app"

    @signal()
    def NewTitle(self):  # noqa: N802
        pass


class FakeWatcher(ServiceInterface):
    def __init__(self, registered):
        super().__init__("org.kde.StatusNotifierWatcher")
        self.registered = registered

    @method()
    def RegisterStatusNotifierItem(self, service: "s"):  # noqa: N802
        if not self.registered.done():
            self.registered.set_result(service)


async def run(guest_addr, host_addr):
    loop = asyncio.get_running_loop()
    registered = loop.create_future()
    saw_signal = loop.create_future()

    host = await MessageBus(bus_address=host_addr).connect()
    host.export("/StatusNotifierWatcher", FakeWatcher(registered))
    await host.request_name("org.kde.StatusNotifierWatcher")

    relay_bus = await MessageBus(bus_address=guest_addr).connect()
    relay = tray_relay.Relay(relay_bus, host_addr, False)
    await relay.start()

    item_bus = await MessageBus(bus_address=guest_addr).connect()
    item = FakeItem()
    item_bus.export(ITEM_OWN_PATH, item)
    await item_bus.request_name("org.test.Item")
    await item_bus.call(
        Message(
            destination="org.kde.StatusNotifierWatcher",
            path="/StatusNotifierWatcher",
            interface="org.kde.StatusNotifierWatcher",
            member="RegisterStatusNotifierItem",
            signature="s",
            body=[ITEM_OWN_PATH],
        )
    )

    item_name = await asyncio.wait_for(registered, 5)
    assert item_name.startswith(":"), f"expected a unique name, got {item_name}"

    reply = await host.call(
        Message(
            destination=item_name,
            path="/StatusNotifierItem",
            interface="org.freedesktop.DBus.Properties",
            member="Get",
            signature="ss",
            body=["org.kde.StatusNotifierItem", "Title"],
        )
    )
    assert reply.message_type == MessageType.METHOD_RETURN, reply.body
    assert reply.body[0].value == "quarantined-app", reply.body[0].value

    def on_host(msg):
        if (
            msg.message_type == MessageType.SIGNAL
            and msg.member == "NewTitle"
            and msg.path == "/StatusNotifierItem"
            and not saw_signal.done()
        ):
            saw_signal.set_result(msg.sender)
        return None

    host.add_message_handler(on_host)
    await host.call(
        Message(
            destination="org.freedesktop.DBus",
            path="/org/freedesktop/DBus",
            interface="org.freedesktop.DBus",
            member="AddMatch",
            signature="s",
            body=[f"type='signal',sender='{item_name}'"],
        )
    )
    item.NewTitle()
    assert await asyncio.wait_for(saw_signal, 5) == item_name


def main():
    if shutil.which("dbus-daemon") is None:
        print("skip: dbus-daemon not on PATH")
        return 0
    with tempfile.TemporaryDirectory() as tmp:
        buses = [start_bus(tmp, "guest"), start_bus(tmp, "host")]
        try:
            asyncio.run(run(buses[0][1], buses[1][1]))
        finally:
            for proc, _ in buses:
                proc.kill()
    print("ok: tray items cross from the guest bus to the host bus")
    return 0


if __name__ == "__main__":
    sys.exit(main())
