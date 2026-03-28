import QtQuick
import QtQuick.Layouts
import RinUI

// 水印组件 - 可复用的网格水印
Item {
    id: watermarkRoot
    
    // 属性
    property int columns: 4
    property int spacing: 100
    property real opacity: 0.08
    property real rotation: -30
    property int zIndex: 9999
    
    anchors.fill: parent
    clip: true
    z: zIndex
    opacity: 0.08

    Grid {
        anchors.fill: parent
        columns: watermarkRoot.columns
        spacing: watermarkRoot.spacing

        Repeater {
            model: 20

            Column {
                width: parent.width / watermarkRoot.columns
                spacing: 4
                rotation: watermarkRoot.rotation

                Text {
                    text: "开发版本 " + (systemInfo ? systemInfo.version : "")
                    font.pixelSize: 14
                    font.bold: true
                    color: Utils.colors.textSecondaryColor
                    visible: systemInfo !== null && systemInfo.version !== undefined
                }

                Text {
                    text: systemInfo ? systemInfo.os : ""
                    font.pixelSize: 12
                    color: Utils.colors.textSecondaryColor
                    visible: systemInfo !== null && systemInfo.os !== undefined
                }

                Text {
                    text: "IP: " + (systemInfo ? systemInfo.ip : "")
                    font.pixelSize: 12
                    color: Utils.colors.textSecondaryColor
                    visible: systemInfo !== null && systemInfo.ip !== undefined
                }
            }
        }
    }
}
