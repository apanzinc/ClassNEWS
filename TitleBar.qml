import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Layouts
import QtQuick.Window 2.3
import RinUI

Item {
    id: root
    property int titleBarHeight: Theme.currentTheme.appearance.dialogTitleBarHeight
    property alias title: titleLabel.text
    property alias icon: iconLabel.source
    property alias backgroundColor: rectBk.color

    // 自定义属性
    property bool titleEnabled: true
    property alias iconEnabled: iconLabel.visible
    property bool minimizeEnabled: true
    property bool maximizeEnabled: true
    property bool closeEnabled: true

    property alias minimizeVisible: minimizeBtn.visible
    property alias maximizeVisible: maximizeBtn.visible
    property alias closeVisible: closeBtn.visible

    // area
    default property alias content: contentItem.data


    height: titleBarHeight
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    clip: true
    z: 999

    implicitWidth: 200

    property var window: null
    function toggleMaximized() {
        if (!maximizeEnabled) {
            return
        }
        WindowManager.maximizeWindow(window)
    }

    Rectangle{
        id:rectBk
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            id: dragMouseArea
            anchors.fill: parent
            anchors.leftMargin: 48
            anchors.margins: Utils.windowDragArea
            propagateComposedEvents: true
            acceptedButtons: Qt.LeftButton
            
            // 关键修复：启用 hover 以正确跟踪鼠标状态
            hoverEnabled: true
            
            // 使用纯 Qt 方式实现拖动
            property point startMousePos: Qt.point(0, 0)
            property point startWindowPos: Qt.point(0, 0)
            property bool dragging: false

            onPressed: (mouse) => {
                // 记录初始位置
                startMousePos = Qt.point(mouse.x, mouse.y)
                startWindowPos = Qt.point(window.x, window.y)
                dragging = true
                // 强制捕获鼠标
                mouse.accepted = true
            }
            
            onReleased: {
                dragging = false
            }
            
            onPositionChanged: (mouse) => {
                if (!dragging) return
                if (window.isMaximized || window.isFullScreen || window.visibility === Window.Maximized) {
                    return
                }
                
                // 计算偏移量并移动窗口
                var deltaX = mouse.x - startMousePos.x
                var deltaY = mouse.y - startMousePos.y
                window.x = startWindowPos.x + deltaX
                window.y = startWindowPos.y + deltaY
            }
            
            onCanceled: {
                dragging = false
            }
            
            // 关键修复：当鼠标进入时重置状态
            onEntered: {
                // 重置拖动状态
                if (dragging && !pressed) {
                    dragging = false
                }
            }
            
            // 关键修复：当鼠标离开时清理状态
            onExited: {
                if (dragging && !pressed) {
                    dragging = false
                }
            }
            
            onDoubleClicked: toggleMaximized()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 48
        // 窗口标题 / Window Title

        RowLayout {
            id: titleRow
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.leftMargin: 16
            spacing: 16
            opacity: root.titleEnabled

            //图标
            IconWidget {
                id: iconLabel
                size: 16
                Layout.alignment: Qt.AlignVCenter
                // anchors.verticalCenter: parent.verticalCenter
                visible: icon || source
            }

            //标题
            Text {
                id: titleLabel
                Layout.alignment: Qt.AlignVCenter
                // anchors.verticalCenter:  parent.verticalCenter

                typography: Typography.Caption
                text: qsTr("Fluent TitleBar")
            }
        }

        Item {
            // custom
            id: contentItem
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        }

        // 窗口按钮 / Window Controls
        RowLayout {
            width: implicitWidth
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignRight
            spacing: 0
            CtrlBtn {
                id: minimizeBtn
                mode: 1
                enabled: root.minimizeEnabled
                window: root.window  // 传入 window 属性
                Layout.fillHeight: true
            }
            CtrlBtn {
                id: maximizeBtn
                mode: 0
                enabled: root.maximizeEnabled
                window: root.window  // 传入 window 属性
                Layout.fillHeight: true

            }
            CtrlBtn {
                id: closeBtn
                mode: 2
                enabled: root.closeEnabled
                window: root.window  // 传入 window 属性
                Layout.fillHeight: true
            }
        }
    }
}
