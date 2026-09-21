import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Appearance — how the desktop looks: palette, and how much it moves.
SettingsPage {
    id: root

    brand: "appearance"
    title: "Appearance"
    subtitle: "Theme presets, accent colors, and motion dynamics."
    tab: "themes"

    sections: [
        { id: "themes", label: "Themes & Colors", component: themesSection,
          description: "Pick a palette, set an accent, and tune how solid surfaces are." },
        { id: "motion", label: "Motion Dynamics", component: motionSection,
          description: "How fast the desktop animates, domain by domain, down to not at all." }
    ]

    cardMap: ({
        "Appearance Mode": "themes",
        "Automated Day & Night Schedule": "themes",
        "Theme Presets": "themes",
        "Accent Color & Surface Opacity": "themes",
        "Motion Intensity Profile": "motion",
        "Interactive Motion Playground": "motion",
        "Granular Motion Domains": "motion",
        "Accessibility & Performance": "motion"
    })

    function revealCard(name) { return root.revealSection(name) }

    Component { id: themesSection; ColumnLayout { spacing: 14; ThemeGroup { Layout.fillWidth: true } } }
    Component { id: motionSection; ColumnLayout { spacing: 14; MotionGroup { Layout.fillWidth: true } } }
}
