import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import RinUI

Rectangle {
    id: aboutPage
    color: Utils.colors.backgroundColor

    // 当前主题属性，用于触发横幅图片更新
    property string currentTheme: ThemeManager.get_theme()

    // 定时检查主题变化
    Timer {
        interval: 500
        running: aboutPage.visible
        repeat: true
        onTriggered: {
            var newTheme = ThemeManager.get_theme()
            if (newTheme !== aboutPage.currentTheme) {
                aboutPage.currentTheme = newTheme
            }
        }
    }

    // 许可证对话框
    Dialog {
        id: licenseDialog
        title: qsTr("许可证协议")
        modal: true
        anchors.centerIn: parent
        width: 600
        height: 500

        contentItem: Rectangle {
            color: "transparent"

            Flickable {
                anchors.fill: parent
                anchors.margins: 16
                contentHeight: licenseText.height
                ScrollBar.vertical: ScrollBar {}

                Text {
                    id: licenseText
                    width: parent.width
                    text: qsTr("GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007\n\nCopyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>\nEveryone is permitted to copy and distribute verbatim copies\nof this license document, but changing it is not allowed.\n\n[此处省略完整许可证文本...]")
                    wrapMode: Text.WordWrap
                    color: Utils.colors.textColor
                }
            }
        }

        standardButtons: Dialog.Ok
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 横幅区域
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(aboutPage.height * 0.35, 200)
            color: "transparent"
            radius: 8
            clip: true

            Image {
                id: bannerImage
                anchors.fill: parent
                source: aboutPage.currentTheme === "Dark" ? Qt.resolvedUrl("../assets/about-wallpaper-dark.png") : Qt.resolvedUrl("../assets/about-wallpaper.png")
                fillMode: Image.PreserveAspectCrop
            }

            // 底部渐变遮罩
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.7; color: "transparent" }
                    GradientStop { position: 1.0; color: Utils.colors.backgroundColor }
                }
            }

            // Banner 文字内容
            ColumnLayout {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 24
                spacing: 8

                Text {
                    text: qsTr("你的新闻，比想象中更自动。")
                    font.pixelSize: 16
                    color: Utils.colors.backgroundColor
                }

                Text {
                    text: qsTr("ClassNEWS")
                    font.pixelSize: 32
                    font.bold: true
                    color: Utils.colors.backgroundColor
                }
            }

            // 顶部圆角遮罩
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Utils.colors.backgroundColor }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        // 内容区域 - 使用 Flickable 实现滚动
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 0
            contentHeight: contentColumn.height
            clip: true

            ColumnLayout {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 24
                spacing: 16

                // 项目信息
                SettingExpander {
                    Layout.fillWidth: true
                    title: qsTr("ClassNEWS")
                    description: systemInfo.yearRange
                    icon.source: Qt.resolvedUrl("../assets/logo.png")

                    content: RowLayout {
                        spacing: 8

                        InfoBadge {
                            text: qsTr("Beta")
                        }

                        Text {
                            text: systemInfo.version
                            color: Utils.colors.textColor
                        }
                    }

                // 仓库链接
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("仓库链接")

                    Hyperlink {
                        text: "github.com/apanzinc/ClassNEWS"
                        url: "https://github.com/apanzinc/ClassNEWS"
                    }
                }

                // 问题反馈
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("问题反馈")

                    Hyperlink {
                        text: qsTr("QQ群: 975885354")
                        url: "https://qm.qq.com/q/NxkIMMeue"
                    }
                }

                // 许可证
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("许可证")

                    Hyperlink {
                        text: "AGPL-3.0"
                        url: "https://github.com/apanzinc/ClassNEWS/blob/main/LICENSE"
                    }
                }
            }

            // 作者信息
            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("apanzinc")
                description: qsTr("作者")
                icon.source: "https://static.apanzinc.top/apanzinc/128.png"

                // 个人网站
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("个人网站")

                    Hyperlink {
                        text: "apanzinc.top"
                        url: "https://apanzinc.top"
                    }
                }

                // GitHub
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("GitHub")

                    Hyperlink {
                        text: "github.com/apanzinc"
                        url: "https://github.com/apanzinc"
                    }
                }
            }

            // 感谢
            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("感谢")
                icon.name: "ic_fluent_heart_20_regular"

                // 佛祖
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("佛祖")

                    Text {
                        text: qsTr("位于 main.py，保佑代码永无 BUG")
                        color: Utils.colors.textSecondaryColor
                    }
                }

                // RinUI
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("RinUI")

                    Hyperlink {
                        text: "github.com/RinLit-233-shiroko/Rin-UI"
                        url: "https://github.com/RinLit-233-shiroko/Rin-UI"
                    }
                }

                // Qt
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("Qt")

                    Hyperlink {
                        text: "qt.io"
                        url: "https://www.qt.io/"
                    }
                }

                // Fluent Design
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("Fluent Design")

                    Hyperlink {
                        text: "microsoft.com/design/fluent"
                        url: "https://www.microsoft.com/design/fluent/"
                    }
                }
            }

            // 赞助
            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("赞助")
                icon.name: "ic_fluent_gift_20_regular"

                // 赞助链接
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("支持开发")

                    Hyperlink {
                        text: "爱发电"
                        url: "https://afdian.com/a/apanzinc"
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
            }
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

    // 水印组件
    Loader {
        anchors.fill: parent
        source: "../components/Watermark.qml"
    }
}
