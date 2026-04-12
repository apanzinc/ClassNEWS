import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentWindowBase {
    id: updateWindow
    width: 500
    height: 400
    minimumWidth: 450
    minimumHeight: 350
    title: qsTr("发现新版本")

    property string newVersion: ""
    property string releaseDate: ""
    property string downloadUrl: ""
    property string changelog: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // 标题
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Icon {
                name: "ic_fluent_arrow_download_24_regular"
                size: 32
                color: Utils.colors.primaryColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: qsTr("发现新版本")
                    font.pixelSize: 20
                    font.bold: true
                    color: Utils.colors.textColor
                }

                Text {
                    text: qsTr("当前版本：%1 → 最新版本：%2").arg(systemInfo.version).arg(updateWindow.newVersion)
                    font.pixelSize: 12
                    color: Utils.colors.textSecondaryColor
                }
            }
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Utils.colors.dividerColor
        }

        // 更新信息
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Text {
                text: qsTr("发布日期：%1").arg(updateWindow.releaseDate)
                font.pixelSize: 12
                color: Utils.colors.textSecondaryColor
            }

            Text {
                text: qsTr("更新内容：")
                font.pixelSize: 13
                font.bold: true
                color: Utils.colors.textColor
            }

            // 更新日志滚动区域
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Utils.colors.layerColor
                        radius: 6

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 12
                            clip: true

                            Text {
                                width: parent.width
                                text: updateWindow.changelog
                                font.pixelSize: 12
                                color: Utils.colors.textColor
                                wrapMode: Text.Wrap
                            }
                        }
                    }
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Utils.colors.dividerColor
        }

        // 按钮
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("稍后再说")
                onClicked: updateWindow.close()
            }

            Button {
                text: qsTr("前往下载")
                highlighted: true
                icon.name: "ic_fluent_open_20_regular"
                onClicked: {
                    Qt.openUrlExternally(updateWindow.downloadUrl)
                    updateWindow.close()
                }
            }
        }
    }
}
