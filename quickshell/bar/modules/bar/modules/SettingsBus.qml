pragma Singleton
import QtQuick

// Tiny in-process signal bus so settings panels can request navigation without
// reaching up through parents (e.g. Overview cards, "open wallpaper library").
QtObject {
    signal navigate(string key)
    function go(key) { navigate(key) }
}
