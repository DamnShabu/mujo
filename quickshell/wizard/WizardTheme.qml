pragma Singleton
import QtQuick

QtObject {
  id: root

  // Core palette from theme.nix
  readonly property color bg: "#0F1419"
  readonly property color surface: "#131721"
  readonly property color surfaceLight: "#272D38"
  readonly property color border: "#3E4B59"
  readonly property color fg: "#E6E1CF"
  readonly property color fgLight: "#F3F4F5"
  readonly property color muted: "#8A8378"

  // Accent colors
  readonly property color accent: "#59C2FF"
  readonly property color accentDim: Qt.alpha("#59C2FF", 0.15)
  readonly property color accentBorder: Qt.alpha("#59C2FF", 0.4)

  // Semantic colors
  readonly property color success: "#B8CC52"
  readonly property color error: "#F07178"
  readonly property color warning: "#FFB454"

  // Frosted glass layers — low alpha so niri blur shows through
  readonly property color glassBg: Qt.alpha("#0F1419", 0.55)
  readonly property color glassCard: Qt.alpha("#131721", 0.45)
  readonly property color glassInput: Qt.alpha("#272D38", 0.45)
  readonly property color glassBorder: Qt.alpha("#3E4B59", 0.6)

  // Typography
  readonly property string mono: "JetBrainsMono Nerd Font"
  readonly property int fsTiny: 11
  readonly property int fsSmall: 13
  readonly property int fsBody: 15
  readonly property int fsTitle: 22
  readonly property int fsHero: 32

  // Spacing
  readonly property int padSmall: 6
  readonly property int padMedium: 12
  readonly property int padLarge: 20
  readonly property int padXLarge: 32

  // Radius
  readonly property int radiusSmall: 6
  readonly property int radiusMedium: 10
  readonly property int radiusLarge: 16
}
