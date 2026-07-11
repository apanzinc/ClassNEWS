import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import RinUI

Rectangle {
    id: aboutPage
    color: Utils.colors.backgroundColor

    // 当前主题属性，用于触发横幅图片更新
    property string currentTheme: ThemeManager.get_theme()
    // 响应式断点：窄屏时提高横幅高度，给文字留出空间
    property bool isNarrow: width < 900

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

        // 横幅区域 - 卡片样式
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(aboutPage.height * 0.35, 200)
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 24
            Layout.bottomMargin: 12
            radius: 8
            color: Utils.colors.cardColor
            border.color: Utils.colors.cardBorderColor
            border.width: 1
            clip: true

            // 图片
            Image {
                id: bannerImage
                anchors.fill: parent
                anchors.margins: -1
                source: aboutPage.currentTheme === "Dark" ? Qt.resolvedUrl("../assets/about-wallpaper-dark.png") : Qt.resolvedUrl("../assets/about-wallpaper.png")
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: bannerImage.width
                        height: bannerImage.height
                        radius: 8
                    }
                }
            }

            // 文字可读性遮罩
            Rectangle {
                anchors.fill: parent
                radius: 8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: aboutPage.currentTheme === "Dark" ? "#66000000" : "#33000000" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // 横幅文案：左对齐，垂直居中
            Column {
                anchors.left: parent.left
                anchors.leftMargin: aboutPage.isNarrow ? 28 : 40
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * (aboutPage.isNarrow ? 0.88 : 0.64)
                spacing: aboutPage.isNarrow ? 10 : 12

                Row {
                    spacing: 10

                    Image {
                        width: aboutPage.isNarrow ? 26 : 30
                        height: width
                        source: Qt.resolvedUrl("../assets/logo.png")
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("ClassNEWS")
                        color: "white"
                        font.pixelSize: aboutPage.isNarrow ? 18 : 22
                        font.bold: true
                    }
                }

                Text {
                    width: parent.width
                    text: qsTr("你的新闻，\n比想象中更自动。")
                    color: "white"
                    font.pixelSize: aboutPage.isNarrow ? 28 : 38
                    font.bold: true
                    lineHeight: 1.06
                    lineHeightMode: Text.ProportionalHeight
                    wrapMode: Text.WordWrap
                }
            }
        }

        // 内容区域 - 使用 Flickable 实现滚动
        Flickable {
            id: aboutFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            contentHeight: contentColumn.height
            clip: true

            // 优化滚动性能
            interactive: true
            flickableDirection: Flickable.VerticalFlick
            maximumFlickVelocity: 1500
            flickDeceleration: 1500
            boundsBehavior: Flickable.StopAtBounds
            synchronousDrag: false
            pressDelay: 100

            // 鼠标滚轮优化 - 平滑滚动动画
            property bool wheelScrolling: false
            
            Behavior on contentY {
                enabled: aboutFlickable.wheelScrolling
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
            
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                onWheel: (wheel) => {
                    var delta = wheel.angleDelta.y
                    var scrollStep = 80
                    aboutFlickable.wheelScrolling = true
                    if (delta > 0) {
                        aboutFlickable.contentY = Math.max(0, aboutFlickable.contentY - scrollStep)
                    } else if (delta < 0) {
                        aboutFlickable.contentY = Math.min(aboutFlickable.contentHeight - aboutFlickable.height,
                                                           aboutFlickable.contentY + scrollStep)
                    }
                    aboutWheelTimer.restart()
                    wheel.accepted = true
                }
            }
            
            Timer {
                id: aboutWheelTimer
                interval: 200
                onTriggered: aboutFlickable.wheelScrolling = false
            }

            // 触摸优化
            MultiPointTouchArea {
                anchors.fill: parent
                touchPoints: [TouchPoint { id: aboutTouch1 }]
                property real startY: 0
                property real startContentY: 0

                onPressed: (touchPoints) => {
                    if (touchPoints.length === 1) {
                        startY = touchPoints[0].y
                        startContentY = aboutFlickable.contentY
                    }
                }

                onUpdated: (touchPoints) => {
                    if (touchPoints.length === 1) {
                        var deltaY = touchPoints[0].y - startY
                        aboutFlickable.contentY = Math.max(0, Math.min(startContentY - deltaY,
                            aboutFlickable.contentHeight - aboutFlickable.height))
                    }
                }
            }

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

                // 官网链接
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("官网")

                    Hyperlink {
                        text: "news.apanzinc.top"
                        url: "https://news.apanzinc.top/"
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

            // 编译信息
            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("编译信息")
                icon.name: "ic_fluent_info_20_regular"

                // 编译人
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("编译人")

                    Hyperlink {
                        text: systemInfo.builder
                        url: "mailto:" + systemInfo.builderEmail
                    }
                }

                // 编译日期
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("编译日期")

                    Text {
                        text: systemInfo.buildDate
                        color: Utils.colors.textSecondaryColor
                    }
                }

                // Git 提交
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("Git 提交")

                    Text {
                        text: systemInfo.gitCommit
                        color: Utils.colors.textSecondaryColor
                    }
                }

                // Git 分支
                SettingItem {
                    Layout.fillWidth: true
                    title: qsTr("Git 分支")

                    Text {
                        text: systemInfo.gitBranch
                        color: Utils.colors.textSecondaryColor
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

}
