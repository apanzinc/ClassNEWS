import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import RinUI

FluentPage {
    id: domesticNewsPage

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 标题
        Text {
            text: qsTr("国内新闻")
            font.pixelSize: 24
            font.bold: true
            color: Utils.colors.textColor
        }

        // 新闻列表
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Repeater {
                model: [
                    {
                        title: "聚焦两会·十四届全国人大四次会议第二次全体会",
                        subtitle: "听取最高法工作报告：2025年最高人民法院结案31958件",
                        time: "2026-03-10"
                    },
                    {
                        title: "江西：以花为媒促消费",
                        subtitle: "绘就农文旅新图景，推动乡村振兴发展",
                        time: "2026-03-10"
                    },
                    {
                        title: "各地春耕备耕有序进行",
                        subtitle: "科技助力农业生产，确保粮食丰收",
                        time: "2026-03-09"
                    },
                    {
                        title: "全国铁路迎来返程客流高峰",
                        subtitle: "铁路部门加开列车，保障旅客出行",
                        time: "2026-03-09"
                    }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    color: Utils.colors.controlColor
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.fillHeight: true
                            radius: 4
                            color: Utils.colors.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: modelData.time
                                font.pixelSize: 11
                                color: "white"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: modelData.title
                                font.pixelSize: 14
                                font.bold: true
                                color: Utils.colors.textColor
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.subtitle
                                font.pixelSize: 12
                                color: Utils.colors.textSecondaryColor
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // 水印 - 铺满全屏的网格水印
    Item {
        anchors.fill: parent
        clip: true
        z: 9999
        opacity: 0.08

        Grid {
            anchors.fill: parent
            columns: 4
            spacing: 100

            Repeater {
                model: 20

                Column {
                    width: parent.width / 4
                    spacing: 4
                    rotation: -30

                    Text {
                        text: "开发版本 " + systemInfo.version
                        font.pixelSize: 14
                        font.bold: true
                        color: Utils.colors.textSecondaryColor
                    }

                    Text {
                        text: systemInfo.os
                        font.pixelSize: 12
                        color: Utils.colors.textSecondaryColor
                    }

                    Text {
                        text: "IP: " + systemInfo.ip
                        font.pixelSize: 12
                        color: Utils.colors.textSecondaryColor
                    }
                }
            }
        }
    }
}
