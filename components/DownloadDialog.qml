import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import RinUI

// 下载对话框 - 让用户选择路径并显示下载进度
Dialog {
    id: downloadDialog

    // 属性
    property string videoId: ""
    property string videoTitle: ""
    property string videoUrl: ""
    property string videoImage: ""
    property string videoSummary: ""
    property string downloadId: ""
    property int downloadProgress: 0
    property string downloadStatus: "" // "", "downloading", "completed", "error", "cancelled"
    property string fileSize: ""
    property string downloadSpeed: ""
    property string savePath: ""

    // 对话框配置
    title: "下载视频"
    modal: true
    dim: true
    standardButtons: {
        if (downloadStatus === "") {
            return Dialog.Ok | Dialog.Cancel
        } else if (downloadStatus === "downloading") {
            return Dialog.Cancel
        } else if (downloadStatus === "completed") {
            return Dialog.Ok
        } else {
            return Dialog.Ok
        }
    }

    // 文件保存对话框
    FileDialog {
        id: fileDialog
        title: "选择保存位置"
        fileMode: FileDialog.SaveFile
        nameFilters: ["视频文件 (*.mp4)", "所有文件 (*)"]
        defaultSuffix: "mp4"

        onAccepted: {
            console.log("FileDialog accepted, selectedFiles:", selectedFiles)
            if (selectedFiles.length > 0) {
                downloadDialog.savePath = selectedFiles[0]
            }
        }
    }

    // 内容
    ColumnLayout {
        spacing: 12
        width: parent.width

        // 视频标题 - 改大改粗
        Text {
            text: downloadDialog.videoTitle
            font.pixelSize: 18
            font.bold: true
            color: Utils.colors.textColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // 副标题和图片区域
        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true
            visible: downloadDialog.videoSummary !== "" || downloadDialog.videoImage !== ""

            // 副标题
            Text {
                text: downloadDialog.videoSummary
                font.pixelSize: 13
                color: Utils.colors.textSecondaryColor
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: downloadDialog.videoSummary !== ""
            }

            // 视频图片
            Image {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                source: downloadDialog.videoImage
                fillMode: Image.PreserveAspectCrop
                visible: downloadDialog.videoImage !== ""
            }
        }

        // 保存路径显示 - 输入框样式
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true

            Text {
                text: "保存位置:"
                font.pixelSize: 12
                color: Utils.colors.textSecondaryColor
            }

            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                // 路径输入框 - 使用 RinUI TextField
                TextField {
                    id: pathInput
                    Layout.fillWidth: true
                    text: downloadDialog.savePath
                    placeholderText: "选择保存路径"
                    onTextChanged: {
                        downloadDialog.savePath = text
                    }
                }

                // 浏览按钮 - 使用 RinUI Button
                Button {
                    text: "浏览"
                    onClicked: {
                        // 设置默认文件名
                        var defaultName = downloadDialog.videoTitle.replace(/[<>:"/\\|?*]/g, "_") + ".mp4"
                        fileDialog.selectedFiles = [downloadDialog.getDefaultDownloadDir() + "/" + defaultName]
                        fileDialog.open()
                    }
                }
            }
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Utils.colors.borderColor
            visible: downloadDialog.downloadStatus !== ""
        }

        // 下载状态区域
        ColumnLayout {
            spacing: 12
            Layout.fillWidth: true
            visible: downloadDialog.downloadStatus !== ""

            // 状态文本
            RowLayout {
                spacing: 8

                Text {
                    text: {
                        switch(downloadDialog.downloadStatus) {
                            case "downloading": return "正在下载..."
                            case "completed": return "下载完成"
                            case "error": return "下载失败"
                            case "cancelled": return "已取消"
                            default: return ""
                        }
                    }
                    font.pixelSize: 14
                    color: {
                        switch(downloadDialog.downloadStatus) {
                            case "downloading": return "#0078D4"
                            case "completed": return "#107C10"
                            case "error": return "#D83B01"
                            case "cancelled": return "#797775"
                            default: return Utils.colors.textColor
                        }
                    }
                }

                // 文件大小
                Text {
                    text: downloadDialog.fileSize
                    font.pixelSize: 12
                    color: Utils.colors.textSecondaryColor
                    visible: downloadDialog.fileSize !== ""
                }
            }

            // 进度条
            ProgressBar {
                id: progressBar
                Layout.fillWidth: true
                value: downloadDialog.downloadProgress / 100
                visible: downloadDialog.downloadStatus === "downloading"

                background: Rectangle {
                    implicitHeight: 6
                    radius: 3
                    color: Utils.colors.borderColor
                }

                contentItem: Rectangle {
                    width: progressBar.visualPosition * parent.width
                    height: 6
                    radius: 3
                    color: "#0078D4"
                }
            }

            // 下载速度和进度文本
            RowLayout {
                spacing: 8
                visible: downloadDialog.downloadStatus === "downloading"

                Text {
                    text: downloadDialog.downloadSpeed
                    font.pixelSize: 12
                    color: Utils.colors.textSecondaryColor
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: downloadDialog.downloadProgress + "%"
                    font.pixelSize: 12
                    color: Utils.colors.textSecondaryColor
                }
            }
        }
    }

    // 获取默认下载目录
    function getDefaultDownloadDir() {
        return downloadManager.getDownloadDirectory()
    }

    // 打开对话框
    function openDialog(videoId, videoTitle, videoUrl, videoImage, videoSummary) {
        downloadDialog.videoId = videoId
        downloadDialog.videoTitle = videoTitle
        downloadDialog.videoUrl = videoUrl
        downloadDialog.videoImage = videoImage || ""
        downloadDialog.videoSummary = videoSummary || ""
        downloadDialog.downloadId = ""
        downloadDialog.downloadProgress = 0
        downloadDialog.downloadStatus = ""
        downloadDialog.fileSize = ""
        downloadDialog.downloadSpeed = ""

        // 设置默认文件名
        var defaultName = videoTitle.replace(/[<>:"/\\|?*]/g, "_") + ".mp4"
        downloadDialog.savePath = getDefaultDownloadDir() + "/" + defaultName

        downloadDialog.open()
    }

    // 更新下载进度
    function updateProgress(progress, speed, totalBytes) {
        downloadDialog.downloadProgress = progress
        downloadDialog.downloadSpeed = speed
        // 确保 totalBytes 是数字类型
        var size = parseInt(totalBytes) || 0
        if (size > 0) {
            downloadDialog.fileSize = downloadManager.formatFileSize(size)
        }
    }

    // 设置下载状态
    function setStatus(status) {
        downloadDialog.downloadStatus = status
    }

    // 设置下载ID
    function setDownloadId(id) {
        downloadDialog.downloadId = id
    }

    // 处理确定按钮
    onAccepted: {
        if (downloadStatus === "") {
            // 开始下载
            var downloadId = downloadManager.startDownloadWithPath(videoUrl, videoTitle, videoId, savePath)
            setDownloadId(downloadId)
            setStatus("downloading")
        } else if (downloadStatus === "completed") {
            // 打开文件夹
            downloadManager.openFolder(savePath)
            downloadDialog.close()
        }
    }

    // 处理取消按钮
    onRejected: {
        if (downloadStatus === "downloading") {
            // 取消下载
            downloadManager.cancelDownload(downloadId)
        }
        downloadDialog.close()
    }
}
