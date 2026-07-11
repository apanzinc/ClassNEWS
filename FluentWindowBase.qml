import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

ApplicationWindow {
    id: baseWindow
    property int hwnd: 0
    property bool isRinUIWindow: true

    flags: Qt.FramelessWindowHint | Qt.Window | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint | Qt.WindowCloseButtonHint
    color: "transparent"

    // 自定义属性
    property var icon: ""
    property alias titleEnabled: titleBar.titleEnabled
    property alias minimizeEnabled: titleBar.minimizeEnabled
    property bool maximizeEnabled: maximumHeight === 16777215 && maximumWidth === 16777215
    property alias closeEnabled: titleBar.closeEnabled

    property alias minimizeVisible: titleBar.minimizeVisible
    property alias maximizeVisible: titleBar.maximizeVisible
    property alias closeVisible: titleBar.closeVisible

    property int titleBarHeight: Theme.currentTheme.appearance.dialogTitleBarHeight
    property alias titleBarArea: titleBar.content

    // 直接添加子项
    property alias framelessMenuBar: menuBarArea.children
    default property alias content: contentArea.children
    property alias floatLayer: floatLayer

    // 布局
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.bottomMargin: Utils.windowDragArea
        anchors.leftMargin: Utils.windowDragArea
        anchors.rightMargin: Utils.windowDragArea
        spacing: 0

        // 顶部边距 - 为标题栏预留空间
        Item {
            Layout.preferredHeight: titleBar.height
            Layout.fillWidth: true
        }

        // menubar
        Item {
            id: menuBarArea
            Layout.fillWidth: true
        }

        // 主体内容区域
        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // 最大化样式
    onVisibilityChanged: {
        if (baseWindow.visibility === Window.Maximized) {
            background.radius = 0
            background.border.width = 1
            // 最大化时移除边距，确保内容完整显示
            mainLayout.anchors.leftMargin = 0
            mainLayout.anchors.rightMargin = 0
            mainLayout.anchors.bottomMargin = 0
        } else {
            background.radius = Theme.currentTheme.appearance.windowRadius
            background.border.width = 1
            // 恢复边距
            mainLayout.anchors.leftMargin = Utils.windowDragArea
            mainLayout.anchors.rightMargin = Utils.windowDragArea
            mainLayout.anchors.bottomMargin = Utils.windowDragArea
        }
    }

    // 标题栏 - 放在 ColumnLayout 之外，确保点击事件不被拦截
    TitleBar {
        id: titleBar
        window: baseWindow
        icon: baseWindow.icon || ""
        title: baseWindow.title || ""
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: baseWindow.titleBarHeight
        maximizeEnabled: baseWindow.maximizeEnabled
        z: 1000  // 确保标题栏在最上层
        
        // 最大化时调整标题栏位置
        states: State {
            name: "maximized"
            when: baseWindow.visibility === Window.Maximized
            PropertyChanges {
                target: titleBar
                anchors.topMargin: 0
                anchors.leftMargin: 0
                anchors.rightMargin: 0
            }
        }
    }

    // 背景样式
    background: Rectangle {
        id: background
        anchors.fill: parent
        color: Utils.backdropEnabled ? "transparent" : Theme.currentTheme.colors.backgroundColor
        border.color: Theme.currentTheme.colors.windowBorderColor
        layer.enabled: true
        border.width: 1
        radius: Theme.currentTheme.appearance.windowRadius
        z: -1
        clip: true

        Behavior on color {
            ColorAnimation {
                duration: Utils.backdropEnabled ? 0 : 150
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Utils.appearanceSpeed
        }
    }

    FloatLayer {
        id: floatLayer
        anchors.topMargin: titleBarHeight
        z: 998
    }
}
