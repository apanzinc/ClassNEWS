import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import RinUI

FluentPage {
    id: internationalNewsPage

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 标题
        Text {
            text: qsTr("国际新闻")
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
                        title: "美以对伊朗发动军事打击，伊朗展开反击",
                        subtitle: "10日凌晨伊朗多地传出爆炸声，国际油价9日显著上涨",
                        time: "2026-03-10"
                    },
                    {
                        title: "古巴专家：美国试图围困古巴",
                        subtitle: "但无法得逞，古巴人民将继续坚持发展道路",
                        time: "2026-03-10"
                    },
                    {
                        title: "匈牙利呼吁解除对俄制裁",
                        subtitle: "强调制裁对欧洲经济造成负面影响",
                        time: "2026-03-10"
                    },
                    {
                        title: "联合国安理会召开紧急会议",
                        subtitle: "讨论中东地区局势发展",
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
