import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import RinUI

FluentWindow {
    id: textViewerWindow
    title: qsTr("内容阅读")
    width: 720
    height: 600
    minimumWidth: 480
    minimumHeight: 400
    visible: true
    titleBarHeight: 48

    icon: Qt.resolvedUrl("../assets/logo.png")

    // 虚拟导航项，确保 NavigationView 正确初始化
    navigationItems: [
        {
            title: qsTr("阅读"),
            page: "",
            icon: "ic_fluent_reading_mode_20_regular"
        }
    ]

    color: Utils.colors.backgroundColor

    // 主窗口引用
    property var mainWindow: null

    // 内容属性
    property string textTitle: qsTr("内容阅读")
    property string textContent: ""
    property string sourceUrl: ""   // 原文链接（可为空）

    // 关闭时发出信号
    signal windowClosed()

    onClosing: {
        console.log("文本展示窗口正在关闭")
        textViewerWindow.windowClosed()
    }

    // 加载文本内容
    function loadText(title, content, url, options) {
        options = options || {}
        console.log("========== 加载文本 ==========")
        console.log("  title:", title)
        console.log("  content 长度:", content ? content.length : 0)
        console.log("  url:", url)
        textViewerWindow.textTitle = title || qsTr("内容阅读")
        textViewerWindow.textContent = content || ""
        textViewerWindow.sourceUrl = url || ""
        textViewerWindow.title = textViewerWindow.textTitle
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12

        // 标题
        Text {
            Layout.fillWidth: true
            text: textViewerWindow.textTitle
            font.pixelSize: 20
            font.bold: true
            color: Utils.colors.textColor
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        // 原文链接入口（仅当有链接且无正文时突出显示）
        Button {
            visible: textViewerWindow.sourceUrl !== ""
            text: qsTr("打开原文链接")
            icon.name: "ic_fluent_link_20_regular"
            onClicked: {
                Qt.openUrlExternally(textViewerWindow.sourceUrl)
            }
        }

        // 正文
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: bodyText.height

            ScrollBar.vertical: ScrollBar {}

            Text {
                id: bodyText
                width: parent.width
                text: textViewerWindow.textContent !== ""
                      ? textViewerWindow.textContent
                      : qsTr("暂无正文内容。\n\n如果该内容提供了原文链接，请点击上方按钮查看。")
                textFormat: Text.MarkdownText
                font.pixelSize: 14
                color: Utils.colors.textColor
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                lineHeight: 1.4
                onLinkActivated: function(link) {
                    Qt.openUrlExternally(link)
                }
            }
        }
    }
}
