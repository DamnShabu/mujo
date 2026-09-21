import QtQuick
import "../../theme"
import "."

// The bar's three-zone geometry, shared by every style presenter.
//
// Each style used to anchor its own three BarSlots — left to the left edge,
// right to the right edge, centre to the middle of the screen — with nothing
// arbitrating between them. Two consequences: the same twenty lines lived in
// five files with quietly different margins, and a long window title or a
// crowded right cluster simply drew *on top of* the clock, because an anchor
// has no idea what its neighbours are doing.
//
// Here the zones negotiate. The right zone is measured first (its width depends
// on nothing else), the centre is screen-centred while it fits and slides into
// whatever gap is left when it does not, and the left zone is capped at the room
// the other two leave rather than growing over them. Nothing is expressed in
// pixels that a screen size cannot change.
Item {
    id: root

    property var niri
    property string screenName: ""
    property string focusedOutput: ""
    property var panelWindow
    property bool launcherOpen: false

    // Style knobs. Everything else is derived.
    property int edgeMargin: Theme.barMargin
    property int gap: Theme.groupPadding
    property bool wrapInCluster: true
    // The island style swaps the centre zone for its notch.
    property Component centerContent: null

    readonly property var leftModules: BarModuleRegistry.slot("left")
    readonly property var centerModules: BarModuleRegistry.slot("center")
    readonly property var rightModules: BarModuleRegistry.slot("right")

    // Breathing room *between* two zones, which is not the same as the spacing
    // inside one: the compact style legitimately runs a 2px intra-group gap, and
    // two groups 2px apart read as one group.
    readonly property int zoneGap: Math.max(root.gap, 10)

    // Exposed so test-bar-modular can assert the zones never overlap.
    readonly property alias leftItem: leftZone
    readonly property alias rightItem: rightZone
    readonly property alias centerItem: centerZone

    readonly property int freeWidth: Math.max(0, root.width - root.edgeMargin * 2)

    // The centre zone only earns its place if it still leaves the left zone
    // something to draw in; below that it is dropped rather than squeezed. Both
    // budgets are computed from the *right* zone's width alone — reading the
    // left zone's width here is what would make this a binding loop.
    readonly property int centerBudget: root.freeWidth - rightZone.width - centerZone.width - root.zoneGap * 2
    readonly property bool centerFits: root.centerBudget >= 40

    // What the left zone may occupy: everything the right zone, and the centre
    // when it fits, do not need. No floor — a left zone clipped to nothing on an
    // absurdly narrow bar still beats one drawn over the tray.
    readonly property int leftBudget: Math.max(0,
        root.freeWidth - rightZone.width - root.zoneGap
        - (root.centerFits ? centerZone.width + root.zoneGap : 0))

    BarSlot {
        id: leftZone
        modules: root.leftModules
        alignment: Qt.AlignLeft
        spacing: root.gap
        wrapInCluster: root.wrapInCluster
        maxWidth: root.leftBudget
        barWidth: root.width
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors.verticalCenter: parent.verticalCenter
        x: root.edgeMargin
    }

    BarSlot {
        id: rightZone
        modules: root.rightModules
        alignment: Qt.AlignRight
        spacing: root.gap
        wrapInCluster: root.wrapInCluster
        maxWidth: root.freeWidth
        barWidth: root.width
        panelWindow: root.panelWindow
        screenName: root.screenName
        niri: root.niri
        focusedOutput: root.focusedOutput
        launcherOpen: root.launcherOpen
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - root.edgeMargin - width
    }

    Loader {
        id: centerZone
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: root.centerContent ? root.centerContent : centerSlotC

        // Screen-centred while it fits, clamped into the free gap when it does
        // not, and dropped entirely when there is no gap at all — a clock drawn
        // over the tray is worse than no clock.
        readonly property real ideal: (root.width - width) / 2
        readonly property real lowest: leftZone.x + leftZone.width + root.zoneGap
        readonly property real highest: rightZone.x - root.zoneGap - width
        x: Math.max(lowest, Math.min(ideal, highest))
        visible: root.centerFits && highest >= lowest
        Behavior on x { NumberAnimation { duration: Anim.d(Anim.standard); easing.type: Anim.easeStandard } }
    }

    Component {
        id: centerSlotC
        BarSlot {
            modules: root.centerModules
            alignment: Qt.AlignHCenter
            spacing: root.gap
            wrapInCluster: root.wrapInCluster
            barWidth: root.width
            panelWindow: root.panelWindow
            screenName: root.screenName
            niri: root.niri
            focusedOutput: root.focusedOutput
            launcherOpen: root.launcherOpen
        }
    }
}
