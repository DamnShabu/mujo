import QtQuick

// The desktop right-click menu has been fully integrated into DesktopWidgets.qml.
// This solves Wayland input layering conflicts, ensuring that clicks on the
// empty desktop are reliably captured by the widget layer when no windows
// are focused.
//
// This file is kept as an empty stub to prevent 'Component not found' errors
// from shell.qml or the qmldir registry while keeping the architectural
// change self-contained.

Item {
    id: emptyStub
    visible: false
}
