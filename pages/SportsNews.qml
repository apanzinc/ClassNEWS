import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import RinUI

FluentPage {
    id: sportsNewsPage

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 标题
        Text {
            text: qsTr("体育新闻")
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
                        title: "2026年女篮世界杯资格赛将于3月11日至17日进行",
                        subtitle: "中国女篮将参加资格赛，为世界杯正赛名额而战",
                        time: "2026-03-10"
                    },
                    {
                        title: "2026年女足亚洲杯：中国女足三连胜",
                        subtitle: "小组第一出线，展现强劲实力",
                        time: "2026-03-10"
                    },
                    {
                        title: "NBA常规赛：湖人队取得关键胜利",
                        subtitle: "詹姆斯砍下30分，带领球队击败对手",
                        time: "2026-03-09"
                    },
                    {
                        title: "中超联赛新赛季开幕",
                        subtitle: "各支球队蓄势待发，争夺联赛冠军",
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
