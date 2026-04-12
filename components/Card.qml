import QtQuick
import QtQuick.Layouts
import RinUI

// Card Component - Following Fluent 2 Design Guidelines
// A card is a container for information and actions related to a single concept or object
Rectangle {
    id: card

    // Public properties
    property bool interactive: true
    property bool hovered: false
    property int cardRadius: 4  // Fluent 2 standard radius

    // Colors based on theme
    property color cardBackground: ThemeManager.get_theme() === "Dark" ? "#2D2D2D" : "#FFFFFF"
    property color cardBorder: ThemeManager.get_theme() === "Dark" ? "#3D3D3D" : "#E0E0E0"
    property color hoverColor: ThemeManager.get_theme() === "Dark" ? "#3D3D3D" : "#F5F5F5"
    property color pressedColor: ThemeManager.get_theme() === "Dark" ? "#4D4D4D" : "#E5E5E5"

    // Default size
    implicitWidth: 300
    implicitHeight: 200

    // Visual properties
    radius: cardRadius
    color: cardBackground
    border.width: 1
    border.color: cardBorder

    // Shadow effect (using layer for performance)
    layer.enabled: true
    layer.effect: ShaderEffectSource {
        // Simplified shadow for performance
    }

    // Hover effect
    Rectangle {
        id: hoverOverlay
        anchors.fill: parent
        radius: cardRadius
        color: card.hoverColor
        opacity: card.hovered && card.interactive ? 0.5 : 0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    // Mouse area for interaction
    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        enabled: card.interactive
        hoverEnabled: true

        onEntered: card.hovered = true
        onExited: card.hovered = false
        onPressed: hoverOverlay.color = card.pressedColor
        onReleased: hoverOverlay.color = card.hoverColor
    }
}
