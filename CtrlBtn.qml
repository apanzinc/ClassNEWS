import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Window 2.3
import RinUI

Base {
    id: root
    interactive: true
    property int mode: 0  //0:max 1:min 2:close
    property alias icon: icon.icon
    property var window: null  // 添加 window 属性

    // tooltip
    ToolTip {
        parent: parent
        delay: 500
        visible: mouseArea.containsMouse
        text: mode === 0 ? qsTr("Maximize") : mode === 1 ? qsTr("Minimize") : mode === 2 ? qsTr("Close") : qsTr("Unknown")
    }

    //关闭 最大化 最小化按钮
    function toggleControl(mode) {
        if (!window) {
            console.log("CtrlBtn: window is null")
            return
        }
        if (mode === 0) {
            // 最大化/还原窗口
            if (window.visibility === Window.Maximized) {
                window.setVisibility(Window.Windowed)
            } else {
                window.setVisibility(Window.Maximized)
            }
        } else if (mode===1) {
            window.showMinimized()
        } else if (mode===2) {
            if (window.transientParent) {
                window.visible = false
            } else {
                window.close()
            }
        }
    }

    implicitWidth: 48
    // 高度由父布局控制，不设置固定高度

    // 背景 / Background
    Rectangle {
        id: background
        anchors.fill: parent
        color: mode === 2 ? Theme.currentTheme.colors.captionCloseColor : Theme.currentTheme.colors.subtleSecondaryColor
        opacity: 0

        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }
    }


    // 按钮图标
    IconWidget {
        id: icon
        icon: mode === 0 ?
                window && window.visibility === Window.Maximized ?
                    "ic_fluent_square_multiple_20_regular" :
                    "ic_fluent_square_20_regular" :
            mode === 1 ?
                "ic_fluent_subtract_20_regular" :
            mode === 2 ?
                "ic_fluent_dismiss_20_regular"
            :
                "ic_fluent_circle_20_regular"  // unknown style
        size: mode === 0 ? 14 : 16
        anchors.centerIn: parent
    }

    // 鼠标区域 / MouseArea
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        onClicked: {
            toggleControl(mode)
        }
    }

    states: [
        State {
        name: "disabledCtrl"
            when: !enabled
            PropertyChanges {  // 禁用时禁止改变属性
                target: icon;
                opacity: 0.3614
            }
            PropertyChanges {  // 禁用时禁止改变属性
                target: root;
            }
        },
        State {
            name: "pressedCtrl"
            when: mouseArea.pressed
            PropertyChanges {
                target: background;
                opacity: 0.8
            }
            PropertyChanges {
                target: icon;
                opacity: 0.6063
                color: root.mode === 2 ? Theme.currentTheme.colors.captionCloseTextColor : textColor
            }
        },
        State {
            name: "hoveredCtrl"
            when: mouseArea.containsMouse
            PropertyChanges {
                target: background;
                opacity: 1
            }
            PropertyChanges {
                target: icon;
                opacity: root.mode === 2 ? 1 : 0.6063
                color: root.mode === 2 ? Theme.currentTheme.colors.captionCloseTextColor : textColor
            }
        }
    ]
}
