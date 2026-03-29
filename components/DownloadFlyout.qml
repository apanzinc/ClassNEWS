import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import RinUI

// 下载浮出控件 - 显示下载选项和进度
Popup {
    id: downloadFlyout

    // 属性
    property string videoId: ""
    property string videoTitle: ""
    property string videoUrl: ""
    property string downloadId: ""
    property int downloadProgress: 0
    property string downloadStatus: "" // "", "downloading", "completed", "error", "cancelled"
    property string fileSize: ""
    property string downloadSpeed: ""

    // 信号
    signal startDownload()
    signal cancelDownload()
    signal openFolder()

    // 配置
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16

    // 尺寸
    implicitWidth: 320
    implicitHeight: contentLayout.implicitHeight + padding * 2

    // 背景
    background: Rectangle {
        radius: 8
        color: ThemeManager.get_theme() === "Dark" ? "#2D2D2D" : "#FFFFFF"
        border.width: 1
        border.color: ThemeManager.get_theme() === "Dark" ? "#3D3D3D" : "#E0E0E0"

        // 阴影效果
        layer.enabled: true
        layer.effect: ShaderEffectSource {
            // 简化阴影
        }
    }

    // 内容
    contentItem: ColumnLayout {
        id: contentLayout
        spacing: 12

        // 标题
        Text {
            text: "下载视频"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: ThemeManager.get_theme() === "Dark" ? "#FFFFFF" : "#000000"
            Layout.fillWidth: true
        }

        // 视频标题
        Text {
            text: downloadFlyout.videoTitle
            font.pixelSize: 13
            color: ThemeManager.get_theme() === "Dark" ? "#CCCCCC" : "#666666"
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: ThemeManager.get_theme() === "Dark" ? "#3D3D3D" : "#E0E0E0"
        }

        // 下载状态区域
        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true
            visible: downloadFlyout.downloadStatus !== ""

            // 状态文本
            RowLayout {
                spacing: 8

                Text {
                    text: {
                        switch(downloadFlyout.downloadStatus) {
                            case "downloading": return "正在下载..."
                            case "completed": return "下载完成"
                            case "error": return "下载失败"
                            case "cancelled": return "已取消"
                            default: return ""
                        }
                    }
                    font.pixelSize: 13
                    color: {
                        switch(downloadFlyout.downloadStatus) {
                            case "downloading": return "#0078D4"
                            case "completed": return "#107C10"
                            case "error": return "#D83B01"
                            case "cancelled": return "#797775"
                            default: return ThemeManager.get_theme() === "Dark" ? "#FFFFFF" : "#000000"
                        }
                    }
                }

                // 文件大小
                Text {
                    text: downloadFlyout.fileSize
                    font.pixelSize: 12
                    color: ThemeManager.get_theme() === "Dark" ? "#999999" : "#666666"
                    visible: downloadFlyout.fileSize !== ""
                }
            }

            // 进度条
            ProgressBar {
                id: progressBar
                Layout.fillWidth: true
                value: downloadFlyout.downloadProgress / 100
                visible: downloadFlyout.downloadStatus === "downloading"

                background: Rectangle {
                    implicitHeight: 4
                    radius: 2
                    color: ThemeManager.get_theme() === "Dark" ? "#3D3D3D" : "#E0E0E0"
                }

                contentItem: Rectangle {
                    width: progressBar.visualPosition * parent.width
                    height: 4
                    radius: 2
                    color: "#0078D4"
                }
            }

            // 下载速度和进度文本
            RowLayout {
                spacing: 8
                visible: downloadFlyout.downloadStatus === "downloading"

                Text {
                    text: downloadFlyout.downloadSpeed
                    font.pixelSize: 12
                    color: ThemeManager.get_theme() === "Dark" ? "#999999" : "#666666"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: downloadFlyout.downloadProgress + "%"
                    font.pixelSize: 12
                    color: ThemeManager.get_theme() === "Dark" ? "#999999" : "#666666"
                }
            }
        }

        // 按钮区域
        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.topMargin: 8

            // 开始下载按钮
            Button {
                text: "开始下载"
                visible: downloadFlyout.downloadStatus === "" || downloadFlyout.downloadStatus === "cancelled" || downloadFlyout.downloadStatus === "error"
                Layout.fillWidth: true

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 4
                    color: parent.pressed ? "#005A9E" : (parent.hovered ? "#106EBE" : "#0078D4")
                }

                onClicked: downloadFlyout.startDownload()
            }

            // 取消下载按钮
            Button {
                text: "取消"
                visible: downloadFlyout.downloadStatus === "downloading"
                Layout.fillWidth: true

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    color: ThemeManager.get_theme() === "Dark" ? "#FFFFFF" : "#000000"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 4
                    color: parent.pressed ? "#C7C7C7" : (parent.hovered ? "#E5E5E5" : "#F0F0F0")
                    border.width: 1
                    border.color: "#D1D1D1"
                }

                onClicked: downloadFlyout.cancelDownload()
            }

            // 打开文件夹按钮
            Button {
                text: "打开文件夹"
                visible: downloadFlyout.downloadStatus === "completed"
                Layout.fillWidth: true

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 4
                    color: parent.pressed ? "#005A9E" : (parent.hovered ? "#106EBE" : "#0078D4")
                }

                onClicked: downloadFlyout.openFolder()
            }

            // 关闭按钮
            Button {
                text: "关闭"
                visible: downloadFlyout.downloadStatus === "completed" || downloadFlyout.downloadStatus === "error"

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    color: ThemeManager.get_theme() === "Dark" ? "#FFFFFF" : "#000000"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 4
                    color: parent.pressed ? "#C7C7C7" : (parent.hovered ? "#E5E5E5" : "#F0F0F0")
                    border.width: 1
                    border.color: "#D1D1D1"
                }

                onClicked: downloadFlyout.close()
            }
        }
    }

    // 打开并定位到指定控件
    function openAt(parentItem, videoId, videoTitle, videoUrl) {
        downloadFlyout.videoId = videoId
        downloadFlyout.videoTitle = videoTitle
        downloadFlyout.videoUrl = videoUrl
        downloadFlyout.downloadId = ""
        downloadFlyout.downloadProgress = 0
        downloadFlyout.downloadStatus = ""
        downloadFlyout.fileSize = ""
        downloadFlyout.downloadSpeed = ""

        // 计算位置
        var parentPos = parentItem.mapToItem(null, 0, 0)
        var x = parentPos.x + parentItem.width / 2 - downloadFlyout.width / 2
        var y = parentPos.y + parentItem.height + 8

        downloadFlyout.x = x
        downloadFlyout.y = y
        downloadFlyout.open()
    }

    // 更新下载进度
    function updateProgress(progress, speed, totalBytes) {
        downloadFlyout.downloadProgress = progress
        downloadFlyout.downloadSpeed = speed
        if (totalBytes > 0) {
            downloadFlyout.fileSize = downloadManager.formatFileSize(totalBytes)
        }
    }

    // 设置下载状态
    function setStatus(status) {
        downloadFlyout.downloadStatus = status
    }

    // 设置下载ID
    function setDownloadId(id) {
        downloadFlyout.downloadId = id
    }
}
