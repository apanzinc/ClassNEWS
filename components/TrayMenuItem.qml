import QtQuick
import QtQuick.Layouts
import RinUI

Rectangle {
    id: root
    
    // 属性
    property string text: ""
    property string iconName: ""
    property color textColor: "#1A1A1A"
    property color hoverColor: "#F5F5F5"
    
    // 信号
    signal clicked()
    
    // 尺寸
    implicitHeight: 36
    radius: 4
    color: mouseArea.containsMouse ? hoverColor : "transparent"
    
    // 动画
    Behavior on color {
        ColorAnimation { duration: 100 }
    }
    
    // 鼠标区域
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.clicked()
        }
    }
    
    // 内容布局
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
        
        // 图标
        Icon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            name: root.iconName
            color: root.textColor
        }
        
        // 文本
        Text {
            Layout.fillWidth: true
            text: root.text
            font.pixelSize: 13
            color: root.textColor
            verticalAlignment: Text.AlignVCenter
        }
    }
}
