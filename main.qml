import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import RinUI
import "components"

FluentWindow {
    id: mainWindow
    width: 1000
    height: 700
    visible: true
    title: qsTr("ClassNEWS")
    icon: Qt.resolvedUrl("assets/logo.png")
    titleBarHeight: 48

    // 禁用 Mica 效果，使用纯色背景避免透明度问题
    color: Utils.colors.backgroundColor

    // 处理关闭事件 - 最小化到托盘而不是退出
    onClosing: function(close) {
        console.log("窗口关闭，最小化到托盘")
        close.accepted = false  // 阻止默认关闭行为
        mainWindow.hide()
    }

    // 视频播放器窗口实例
    property var videoPlayerWindow: null

    // 创建视频播放器窗口
    function createVideoPlayerWindow() {
        if (videoPlayerWindow === null) {
            var component = Qt.createComponent("pages/VideoPlayerWindow.qml")
            if (component.status === Component.Ready) {
                // 创建为顶级窗口（不设置父对象）
                videoPlayerWindow = component.createObject(null)
                videoPlayerWindow.mainWindow = mainWindow
                videoPlayerWindow.configManager = configManager  // 传递配置管理器
                videoPlayerWindow.windowClosed.connect(function() {
                    videoPlayerWindow = null
                })
                console.log("视频播放器窗口已创建")

                // 注册窗口到 WindowManager（用于 Windows 窗口缩放）
                if (windowManager && typeof windowManager.registerWindow === 'function') {
                    windowManager.registerWindow(videoPlayerWindow)
                }
            } else {
                console.error("无法创建视频播放器窗口:", component.errorString())
            }
        }
        return videoPlayerWindow
    }

    // 显示 InfoBar 提示
    function showInfoBar(title, text, severity, timeout, closable) {
        floatLayer.createInfoBar({
            title: title,
            text: text,
            severity: severity,
            timeout: timeout || 5000,
            closable: closable !== undefined ? closable : true,
            position: Position.BottomRight
        })
    }

    // 视频加载提示 Flyout
    Flyout {
        id: videoLoadingFlyout
        parent: mainWindow.contentItem || mainWindow
        text: qsTr("正在加载视频...")

        // 自动关闭定时器
        Timer {
            id: hideFlyoutTimer
            interval: 3000
            onTriggered: videoLoadingFlyout.close()
        }
    }

    // 下载对话框
    DownloadDialog {
        id: downloadDialog
    }

    // 更新窗口
    UpdateWindow {
        id: updateWindow
    }

    // 当前待下载的视频信息
    property var pendingDownload: null

    // 连接视频管理器的信号
    Connections {
        target: videoManager
        function onVideoParsed(videoUrl, title, options) {
            console.log("视频解析完成:", title, videoUrl, options)

            // 检查视频URL是否有效
            if (!videoUrl || videoUrl === "") {
                console.log("视频URL为空，不播放")
                return
            }

            // 检查是否有待处理的下载请求
            if (pendingDownload !== null && pendingDownload.title === title) {
                console.log("开始下载视频:", title)
                // 显示下载对话框，传入图片和摘要
                downloadDialog.openDialog(
                    pendingDownload.videoId,
                    title,
                    videoUrl,
                    pendingDownload.image,
                    pendingDownload.summary
                )
                // 清空待下载状态
                pendingDownload = null
                return
            }

            // 检查是否使用内置播放器
            if (videoManager.useInternalPlayer) {
                console.log("使用内置播放器")
                // 显示右上角提示
                videoLoadingFlyout.text = qsTr("正在加载视频: ") + title
                videoLoadingFlyout.open()
                hideFlyoutTimer.start()

                var player = createVideoPlayerWindow()
                if (player) {
                    player.loadVideo(videoUrl, title, options)
                    player.show()
                    player.raise()
                    player.requestActivate()
                } else {
                    // 使用 InfoBar 显示错误提示
                    mainWindow.showInfoBar(
                        qsTr("播放错误"),
                        qsTr("无法创建视频播放器窗口，请稍后重试"),
                        Severity.Error,
                        5000,
                        true
                    )
                }
            } else {
                console.log("使用系统播放器")
                // 使用系统默认播放器
                var result = videoManager.openWithExternalPlayer(videoUrl, title)
                if (result) {
                    // 显示提示
                    videoLoadingFlyout.text = qsTr("正在使用系统播放器打开: ") + title
                    videoLoadingFlyout.open()
                    hideFlyoutTimer.start()
                } else {
                    // 使用 InfoBar 显示错误提示
                    mainWindow.showInfoBar(
                        qsTr("播放错误"),
                        qsTr("无法使用系统播放器打开视频。\n\n可能原因：\n1. 视频格式不受支持\n2. 缺少视频解码器\n3. 未安装兼容的播放器\n\n建议：安装 VLC 或 PotPlayer，或使用内置播放器。"),
                        Severity.Error,
                        8000,
                        true
                    )
                }
            }
        }
        function onParseError(errorMsg) {
            console.log("视频解析失败:", errorMsg)
            // 显示错误提示
            videoLoadingFlyout.text = qsTr("视频加载失败: ") + errorMsg
            videoLoadingFlyout.open()
            hideFlyoutTimer.start()
            // 使用 InfoBar 显示错误提示
            mainWindow.showInfoBar(
                qsTr("播放失败"),
                errorMsg,
                Severity.Error,
                5000
            )
            // 如果有待下载任务，清空它
            if (pendingDownload !== null) {
                pendingDownload = null
            }
        }
    }

    // 连接下载管理器的信号
    Connections {
        target: downloadManager
        function onDownload_progress(downloadId, downloaded, total, speed) {
            if (downloadDialog.downloadId === downloadId) {
                var progress = total > 0 ? Math.round((downloaded / total) * 100) : 0
                var speedStr = downloadManager.formatSpeed(speed)
                downloadDialog.updateProgress(progress, speedStr, total)
            }
        }
        function onDownload_completed(downloadId, filePath) {
            if (downloadDialog.downloadId === downloadId) {
                downloadDialog.setStatus("completed")
            }
        }
        function onDownload_error(downloadId, errorMsg) {
            if (downloadDialog.downloadId === downloadId) {
                downloadDialog.setStatus("error")
            }
        }
        function onDownload_status_changed(downloadId, status) {
            if (downloadDialog.downloadId === downloadId) {
                downloadDialog.setStatus(status)
            }
        }
    }

    // 注意：更新检查器功能暂未实现
    /*
    // 连接更新检查器的信号
    Connections {
        target: updateChecker
        function onUpdateAvailable(version, releaseDate, downloadUrl, changelog) {
            console.log("发现新版本:", version, releaseDate)
            updateWindow.newVersion = version
            updateWindow.releaseDate = releaseDate
            updateWindow.downloadUrl = downloadUrl
            updateWindow.changelog = changelog
            updateWindow.open()
        }
        function onNoUpdate() {
            console.log("已是最新版本")
        }
        function onCheckFailed(errorMsg) {
            console.log("检查更新失败:", errorMsg)
        }
    }
    */

    // 连接协议管理器的信号
    Connections {
        target: protocolManager
        function onClosePlayerRequested() {
            console.log("收到关闭播放器请求")
            if (videoPlayerWindow !== null) {
                videoPlayerWindow.closePlayer()
            }
        }
        function onCloseMainWindowRequested() {
            console.log("收到关闭主窗口请求")
            mainWindow.hide()
        }
        function onTestResultReady(resultJson) {
            console.log("收到测试结果:", resultJson)
            // 显示测试结果对话框
            testResultDialog.testResult = resultJson
            testResultDialog.open()
        }
        function onProtocolNewsReady(pid, title, options) {
            console.log("获取到新闻，显示确认窗口:", pid, title)
            // 检查是否显示唤醒倒计时窗口
            var showNotification = configManager ? configManager.showNotificationWindow : true
            var countdownSeconds = configManager ? configManager.notificationCountdownSeconds : 5
            
            if (showNotification) {
                // 创建并显示视频播放提示窗口
                var notificationWindow = createVideoNotificationWindow()
                if (notificationWindow) {
                    notificationWindow.newsTitle = title
                    notificationWindow.pid = pid
                    notificationWindow.options = options
                    notificationWindow.countdownSeconds = countdownSeconds
                    notificationWindow.show()
                    notificationWindow.raise()
                    notificationWindow.requestActivate()
                }
            } else {
                // 直接播放，不显示通知窗口
                console.log("跳过通知窗口，直接播放:", pid)
                videoManager.parseVideo(pid, title, options)
            }
        }
        function onProtocolTriggered(pid, title, options) {
            console.log("收到协议播放请求:", pid, title)
            // 检查是否显示唤醒倒计时窗口
            var showNotification = configManager ? configManager.showNotificationWindow : true
            var countdownSeconds = configManager ? configManager.notificationCountdownSeconds : 5
            
            if (showNotification) {
                // 创建并显示视频播放提示窗口
                var notificationWindow = createVideoNotificationWindow()
                if (notificationWindow) {
                    notificationWindow.newsTitle = title
                    notificationWindow.pid = pid
                    notificationWindow.options = options
                    notificationWindow.countdownSeconds = countdownSeconds
                    notificationWindow.show()
                    notificationWindow.raise()
                    notificationWindow.requestActivate()
                }
            } else {
                // 直接播放，不显示通知窗口
                console.log("跳过通知窗口，直接播放:", pid)
                videoManager.parseVideo(pid, title, options)
            }
        }
    }

    // 测试结果对话框
    Dialog {
        id: testResultDialog
        title: qsTr("ClassNEWS 测试协议结果")
        modal: true
        anchors.centerIn: parent
        width: 450

        property string testResult: ""

        ColumnLayout {
            spacing: 16
            width: parent.width - 40

            Text {
                text: qsTr("软件状态正常，以下是详细信息：")
                font.pixelSize: 14
                color: Utils.colors.textColor
            }

            Rectangle {
                Layout.fillWidth: true
                height: testResultText.height + 20
                color: Utils.colors.layerColor
                radius: 4

                Text {
                    id: testResultText
                    anchors.centerIn: parent
                    text: testResultDialog.testResult
                    font.family: "Consolas, Monaco, monospace"
                    font.pixelSize: 12
                    color: Utils.colors.textColor
                }
            }
        }

        standardButtons: Dialog.Ok
    }

    // 视频播放通知窗口实例
    property var videoNotificationWindow: null

    // 创建视频播放通知窗口
    function createVideoNotificationWindow() {
        if (videoNotificationWindow === null) {
            var component = Qt.createComponent("components/VideoNotificationWindow.qml")
            if (component.status === Component.Ready) {
                // 创建为子窗口，设置目标窗口用于定位
                videoNotificationWindow = component.createObject(mainWindow)
                videoNotificationWindow.targetWindow = mainWindow
                videoNotificationWindow.windowClosed.connect(function() {
                    videoNotificationWindow = null
                })
                videoNotificationWindow.playNow.connect(function() {
                    console.log("立即播放视频:", videoNotificationWindow.pid)
                    if (videoManager && videoNotificationWindow.pid !== "") {
                        videoManager.parseVideoWithOptions(videoNotificationWindow.pid, videoNotificationWindow.newsTitle, videoNotificationWindow.options)
                    }
                })
                videoNotificationWindow.delayOneMinute.connect(function() {
                    console.log("延后一分钟播放:", videoNotificationWindow.newsTitle)
                    // 设置定时器，一分钟后播放
                    delayPlayTimer.pid = videoNotificationWindow.pid
                    delayPlayTimer.title = videoNotificationWindow.newsTitle
                    delayPlayTimer.options = videoNotificationWindow.options
                    delayPlayTimer.start()
                })

                // 注册窗口到 WindowManager（用于 Windows 窗口圆角和缩放）
                if (typeof windowManager !== 'undefined' && windowManager !== null && windowManager.registerWindow) {
                    windowManager.registerWindow(videoNotificationWindow)
                    console.log("视频播放通知窗口已注册到 WindowManager")
                } else {
                    console.log("windowManager 未定义，无法注册窗口")
                }

                console.log("视频播放通知窗口已创建")
            } else {
                console.error("无法创建视频播放通知窗口:", component.errorString())
            }
        }
        return videoNotificationWindow
    }

    // 延后播放定时器
    Timer {
        id: delayPlayTimer
        interval: 60000  // 60秒
        property string pid: ""
        property string title: ""
        property var options: null
        onTriggered: {
            console.log("延后播放时间到，开始播放:", title)
            if (videoManager && pid !== "") {
                videoManager.parseVideoWithOptions(pid, title, options)
            }
        }
    }

    // 侧边栏导航项 - 使用完整路径
    navigationItems: [
        {
            title: qsTr("首页"),
            page: projectBasePath + "/pages/Home.qml",
            icon: "ic_fluent_home_20_regular"
        },
        {
            title: qsTr("设置"),
            page: projectBasePath + "/pages/Settings.qml",
            icon: "ic_fluent_settings_20_regular"
        },
        {
            title: qsTr("关于"),
            page: projectBasePath + "/pages/About.qml",
            icon: "ic_fluent_info_20_regular"
        }
    ]

    // 对话框 - 作为属性定义
    property var basicDialog: Dialog {
        title: qsTr("RinUI 示例对话框")
        modal: true
        anchors.centerIn: parent
        width: 400

        ColumnLayout {
            spacing: 16

            Text {
                text: qsTr("这是一个使用 RinUI 组件库构建的对话框。\n\nRinUI 提供了 Fluent Design 风格的 UI 组件，包括按钮、复选框、滑块、对话框等。")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Utils.colors.textColor
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: console.log("对话框已接受")
        onRejected: console.log("对话框已取消")
    }

    // 自定义托盘菜单
    TrayMenu {
        id: trayMenu
        
        onShowWindowRequested: {
            mainWindow.show()
            mainWindow.raise()
            mainWindow.requestActivate()
        }
        
        onQuitRequested: {
            if (typeof trayManager !== 'undefined' && trayManager !== null) {
                trayManager.quitApplication()
            }
        }
    }
    
    // 连接托盘管理器的信号
    Connections {
        target: typeof trayManager !== 'undefined' ? trayManager : null
        function onNavigateToSettingsRequested() {
            console.log("导航到设置页面")
            // 使用 Qt.callLater 确保在组件加载完成后执行
            Qt.callLater(function() {
                if (typeof navigationView !== 'undefined' && navigationView !== null) {
                    navigationView.currentIndex = 1
                } else {
                    console.log("navigationView 未定义，尝试通过其他方式导航")
                    // 备用方案：发送信号通知导航
                }
            })
        }
    }

    // 初始化
    Component.onCompleted: {
        console.log("当前主题:", ThemeManager.get_theme());
        console.log("主题设置:", ThemeManager.get_theme_name());
        console.log("主题色:", ThemeManager.get_theme_color());
    }
}
