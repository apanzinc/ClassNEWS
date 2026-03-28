import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtMultimedia
import RinUI

FluentWindow {
    id: videoPlayerWindow
    title: qsTr("视频播放器")
    width: 900
    height: 600
    minimumWidth: 600
    minimumHeight: 400
    visible: false
    titleBarHeight: 48

    // 设置窗口图标
    icon: Qt.resolvedUrl("../assets/video.png")

    // 添加一个虚拟导航项来确保 NavigationView 正确初始化
    navigationItems: [
        {
            title: qsTr("视频"),
            page: "",
            icon: "ic_fluent_play_20_regular"
        }
    ]

    // 禁用透明效果，使用纯色背景
    color: Utils.colors.backgroundColor

    // 视频源属性
    property url videoSource: ""
    property string videoTitle: qsTr("视频播放")
    property bool isPlaying: false
    property bool isFullscreen: false
    property real playbackRate: 1.0
    property string videoId: ""  // 视频ID，用于断点续播

    // 主窗口引用
    property var mainWindow: null

    // 配置管理器引用
    property var configManager: null

    // 保存窗口正常状态的几何信息
    property var normalGeometry: ({x: 0, y: 0, width: 900, height: 600})

    // 断点续播相关
    property int resumePosition: 0
    property bool hasResumed: false
    property bool showResumeNotification: false

    // 关闭时发出信号
    signal windowClosed()

    onClosing: {
        console.log("视频播放器窗口正在关闭，保存播放进度...")
        // 保存播放进度
        if (videoPlayerWindow.videoId && videoPlayer.position > 10000) {  // 只保存大于10秒的进度
            var progressToSave = videoPlayer.position
            if (configManager) {
                configManager.saveVideoProgress(videoPlayerWindow.videoId, progressToSave)
                console.log("保存播放进度:", videoPlayerWindow.videoId, progressToSave)
            }
        }
        videoPlayer.stop()
        videoPlayer.source = ""  // 清空视频源
        windowClosed()
    }

    // 确保窗口关闭时释放资源
    onVisibleChanged: {
        if (!visible) {
            videoPlayer.stop()
        }
    }

    // 显示主窗口
    function showMainWindow() {
        try {
            // 使用传递进来的主窗口引用
            if (videoPlayerWindow.mainWindow && videoPlayerWindow.mainWindow.show) {
                videoPlayerWindow.mainWindow.show()
                videoPlayerWindow.mainWindow.raise()
                videoPlayerWindow.mainWindow.requestActivate()
                console.log("主窗口已显示")
            } else {
                console.log("主窗口引用无效，无法显示")
            }
        } catch (e) {
            console.log("显示主窗口时出错:", e)
        }
    }

    // 媒体播放器
    MediaPlayer {
        id: videoPlayer
        source: videoPlayerWindow.videoSource
        videoOutput: videoOutput
        playbackRate: videoPlayerWindow.playbackRate
        audioOutput: AudioOutput {
            id: audioOutput
            volume: volumeSlider.value / 100
        }

        onPlaybackStateChanged: {
            videoPlayerWindow.isPlaying = (playbackState === MediaPlayer.PlayingState)

            // 检测视频播放结束（StoppedState 且位置接近结尾）
            if (playbackState === MediaPlayer.StoppedState) {
                if (videoPlayer.duration > 0 && videoPlayer.position >= videoPlayer.duration - 1000) {
                    console.log("视频播放结束")
                    // 检查自动重播设置
                    if (configManager && configManager.getAutoReplay()) {
                        console.log("自动重播已开启，重新开始播放")
                        videoPlayer.position = 0
                        videoPlayer.play()
                        // 清除保存的进度
                        if (videoPlayerWindow.videoId) {
                            configManager.clearVideoProgress(videoPlayerWindow.videoId)
                        }
                    }
                }
            }
        }

        onErrorOccurred: function(error, errorString) {
            console.error("视频播放错误:", error, errorString)
            errorText.text = qsTr("播放错误: ") + errorString
            errorText.visible = true
        }

        onSourceChanged: {
            console.log("视频源已更改:", source)
            errorText.visible = false
        }

        onMediaStatusChanged: {
            console.log("媒体状态变化:", mediaStatus)
            // 处理加载失败的情况
            if (mediaStatus === MediaPlayer.InvalidMedia) {
                errorText.text = qsTr("无法加载视频，格式不支持或缺少解码器")
                errorText.visible = true
            }
            // 媒体加载完成，自动开始播放
            else if (mediaStatus === MediaPlayer.LoadedMedia) {
                console.log("媒体加载完成，自动播放")

                // 检查是否需要断点续播
                if (!videoPlayerWindow.hasResumed && videoPlayerWindow.videoId && configManager) {
                    var savedPosition = configManager.getVideoProgress(videoPlayerWindow.videoId)
                    if (savedPosition > 10000) {  // 大于10秒才提示续播
                        // 先跳转到上次播放位置继续播放
                        videoPlayer.position = savedPosition
                        videoPlayer.play()

                        var seconds = Math.floor(savedPosition / 1000)
                        var minutes = Math.floor(seconds / 60)
                        var remainingSeconds = seconds % 60
                        var timeStr = minutes + ":" + (remainingSeconds < 10 ? "0" : "") + remainingSeconds

                        videoPlayerWindow.resumePosition = savedPosition
                        videoPlayerWindow.showResumeNotification = true
                        resumeNotificationTimer.start()
                        console.log("已从上次位置继续播放:", timeStr, "位置:", savedPosition)
                    } else {
                        // 没有保存的进度，从头开始播放
                        videoPlayer.play()
                    }
                    videoPlayerWindow.hasResumed = true
                } else {
                    // 正常播放
                    videoPlayer.play()
                }
            }
        }

        onBufferProgressChanged: {
            // 自动缓冲控制：当缓冲不足时暂停，缓冲足够时恢复
            if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
                if (videoPlayer.bufferProgress < 0.05) {
                    // 缓冲不足5%，暂停播放等待缓冲
                    console.log("缓冲不足，自动暂停")
                    videoPlayer.pause()
                    autoResumeTimer.start()
                }
            }
        }
    }

    // 自动恢复播放定时器
    Timer {
        id: autoResumeTimer
        interval: 1000  // 每秒检查一次
        repeat: true
        onTriggered: {
            if (videoPlayer.bufferProgress >= 0.2) {
                // 缓冲达到20%，恢复播放
                console.log("缓冲足够，恢复播放")
                videoPlayer.play()
                autoResumeTimer.stop()
            }
        }
    }

    // 进度更改后播放重试定时器
    Timer {
        id: progressPlayRetryTimer
        interval: 1000  // 等待1秒
        repeat: false
        onTriggered: {
            console.log("进度更改后尝试播放...")
            // 如果当前没有在播放，尝试播放
            if (videoPlayer.playbackState !== MediaPlayer.PlayingState) {
                videoPlayer.play()
                // 启动二次检查定时器
                secondPlayCheckTimer.start()
            }
        }
    }

    // 二次检查定时器 - 如果1秒后还没播放成功，再试一次
    Timer {
        id: secondPlayCheckTimer
        interval: 1000  // 再等待1秒
        repeat: false
        onTriggered: {
            console.log("二次检查播放状态...")
            // 如果仍然没有播放，再试一次
            if (videoPlayer.playbackState !== MediaPlayer.PlayingState &&
                videoPlayer.mediaStatus !== MediaPlayer.InvalidMedia) {
                console.log("播放未成功，再次尝试...")
                videoPlayer.play()
            }
        }
    }

    // 控制栏显示状态
    property bool controlsVisible: false

    // 自动隐藏定时器
    Timer {
        id: hideControlsTimer
        interval: 3000  // 3秒后自动隐藏
        repeat: false
        onTriggered: {
            // 如果正在拖动进度条或音量条，不隐藏
            if (!progressSlider.pressed && !volumeSlider.pressed) {
                controlsVisible = false
            }
        }
    }

    // 内容区域
    Rectangle {
        anchors.fill: parent
        color: "black"
        radius: 8  // 添加圆角
        clip: true  // 裁剪内容到圆角区域

        // 视频输出
        VideoOutput {
            id: videoOutput
            anchors.fill: parent
        }

        // 加载动画 - 视频缓冲时显示
        Rectangle {
            id: videoLoadingOverlay
            anchors.fill: parent
            color: "black"
            visible: showLoading
            z: 5

            // 属性：是否显示加载
            property bool showLoading: {
                // 初始加载状态（没有加载到视频）
                if (videoPlayer.mediaStatus === MediaPlayer.LoadingMedia ||
                    videoPlayer.mediaStatus === MediaPlayer.NoMedia) {
                    return true
                }
                // 自动暂停缓冲中
                if (videoPlayer.playbackState === MediaPlayer.PausedState && autoResumeTimer.running) {
                    return true
                }
                // 播放中卡顿
                if (isStalled) {
                    return true
                }
                return false
            }

            // 属性：是否真正卡顿（播放中但画面不动）
            property bool isStalled: false
            property real lastPosition: 0
            property int stallCheckCount: 0

            // 卡顿检测定时器
            Timer {
                id: stallCheckTimer
                interval: 500  // 每500ms检查一次
                running: videoPlayer.playbackState === MediaPlayer.PlayingState &&
                         videoPlayer.mediaStatus === MediaPlayer.BufferedMedia
                repeat: true
                onTriggered: {
                    var currentPos = videoPlayer.position
                    var currentBuffer = videoPlayer.bufferProgress

                    // 如果位置没有变化，可能是卡顿
                    if (currentPos === videoLoadingOverlay.lastPosition) {
                        videoLoadingOverlay.stallCheckCount++

                        // 连续2次（1秒）位置没有变化，判定为卡顿
                        if (videoLoadingOverlay.stallCheckCount >= 2) {
                            videoLoadingOverlay.isStalled = true
                        }
                    } else {
                        // 位置有变化，重置计数
                        videoLoadingOverlay.stallCheckCount = 0
                        videoLoadingOverlay.isStalled = false
                    }

                    videoLoadingOverlay.lastPosition = currentPos
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 16

                // 使用 ProgressRing 组件
                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "../components/ProgressRing.qml"
                    onLoaded: {
                        item.running = true
                        item.size = 64
                        item.ringColor = "white"
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: loadingText
                    color: "white"
                    font.pixelSize: 14

                    property string loadingText: {
                        if (videoPlayer.mediaStatus === MediaPlayer.LoadingMedia ||
                            videoPlayer.mediaStatus === MediaPlayer.NoMedia) {
                            return qsTr("正在加载视频...")
                        } else if (videoPlayer.playbackState === MediaPlayer.PausedState && autoResumeTimer.running) {
                            return qsTr("正在缓冲，请稍候...")
                        } else if (videoLoadingOverlay.isStalled) {
                            return qsTr("视频播放缓慢，正在缓冲...")
                        }
                        return qsTr("请稍候...")
                    }
                }

                // 缓冲进度条
                ProgressBar {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 200
                    visible: videoPlayer.bufferProgress > 0 && videoPlayer.bufferProgress < 1
                    value: videoPlayer.bufferProgress
                    from: 0
                    to: 1
                }

                // 缓冲百分比文本
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: videoPlayer.bufferProgress > 0 && videoPlayer.bufferProgress < 1
                    text: Math.round(videoPlayer.bufferProgress * 100) + "%"
                    color: "#aaaaaa"
                    font.pixelSize: 12
                }
            }
        }

        // 错误提示
        Text {
            id: errorText
            visible: false
            anchors.centerIn: parent
            color: "#ff5252"
            font.pixelSize: 16
            text: ""
            z: 10
        }

        // 断点续播通知
        Rectangle {
            id: resumeNotification
            visible: videoPlayerWindow.showResumeNotification
            anchors.top: parent.top
            anchors.topMargin: 80
            anchors.horizontalCenter: parent.horizontalCenter
            width: resumeNotificationLayout.width + 40
            height: resumeNotificationLayout.height + 30
            color: Utils.colors.layerColor
            radius: 8
            opacity: visible ? 1 : 0
            z: 20

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            RowLayout {
                id: resumeNotificationLayout
                anchors.centerIn: parent
                spacing: 15

                Text {
                    text: qsTr("已从上次位置 ") + formatTime(videoPlayerWindow.resumePosition) + qsTr(" 继续播放")
                    color: Utils.colors.textColor
                    font.pixelSize: 14
                }

                Button {
                    text: qsTr("从头开始")
                    onClicked: {
                        videoPlayerWindow.showResumeNotification = false
                        videoPlayer.position = 0
                        videoPlayer.play()
                        // 清除保存的进度
                        if (videoPlayerWindow.videoId && configManager) {
                            configManager.clearVideoProgress(videoPlayerWindow.videoId)
                        }
                        console.log("用户选择从头开始播放")
                    }
                }

                Button {
                    text: qsTr("知道了")
                    highlighted: true
                    onClicked: {
                        videoPlayerWindow.showResumeNotification = false
                    }
                }
            }
        }

        // 时间格式化函数
        function formatTime(ms) {
            var totalSeconds = Math.floor(ms / 1000)
            var minutes = Math.floor(totalSeconds / 60)
            var seconds = totalSeconds % 60
            return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
        }

        // 点击视频显示控制栏
        MouseArea {
            id: videoClickArea
            anchors.fill: parent
            onClicked: {
                // 点击视频任意位置显示控制栏
                controlsVisible = true
                hideControlsTimer.restart()
            }
            onDoubleClicked: {
                toggleFullscreen()
            }
        }

        // 控制栏背景
        Rectangle {
            id: controlsBackground
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 100
            color: Utils.colors.layerColor
            opacity: controlsVisible || progressSlider.pressed || volumeSlider.pressed ? 1 : 0
            visible: opacity > 0
            radius: 8
            z: 10

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        // 控制栏内容
        ColumnLayout {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            anchors.bottomMargin: 20
            anchors.leftMargin: 32
            anchors.rightMargin: 24
            spacing: 12
            opacity: controlsBackground.opacity
            visible: controlsBackground.visible
            z: 12

            // 进度条 - 使用秒为单位，0-100的百分比
            Slider {
                id: progressSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                value: videoPlayer.duration > 0 ? (videoPlayer.position / videoPlayer.duration) * 100 : 0
                stepSize: 0.1  // 小步长，精确控制
                live: true  // 拖动时实时更新

                // 拖动时更新视频位置
                onValueChanged: {
                    if (pressed && videoPlayer.duration > 0) {
                        videoPlayer.position = (value / 100) * videoPlayer.duration
                    }
                }

                // 拖动结束后启动播放重试定时器
                onPressedChanged: {
                    if (!pressed && videoPlayer.duration > 0) {
                        // 用户释放进度条，等待1秒后尝试播放
                        console.log("进度更改完成，启动播放重试定时器")
                        progressPlayRetryTimer.start()
                    }
                }

                // 时间提示 - 显示目标时间
                ToolTip {
                    visible: progressSlider.pressed
                    text: videoPlayer.duration > 0 ? formatTime((progressSlider.value / 100) * videoPlayer.duration) : "00:00"
                }
            }

            // 控制按钮行
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // 播放/暂停按钮
                RoundButton {
                    id: playPauseBtn
                    icon.name: videoPlayerWindow.isPlaying ? "ic_fluent_pause_20_filled" : "ic_fluent_play_20_filled"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    highlighted: true

                    onClicked: {
                        if (videoPlayerWindow.isPlaying) {
                            videoPlayer.pause()
                        } else {
                            videoPlayer.play()
                        }
                    }
                }

                // 停止按钮
                ToolButton {
                    icon.name: "ic_fluent_stop_20_regular"
                    flat: true

                    onClicked: {
                        videoPlayer.stop()
                    }
                }

                // 时间显示
                Text {
                    text: formatTime(videoPlayer.position) + " / " + formatTime(videoPlayer.duration)
                    color: Utils.colors.textColor
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignVCenter
                }

                // 弹性空间
                Item {
                    Layout.fillWidth: true
                }

                // 播放速度按钮
                DropDownButton {
                    text: playbackRate.toFixed(1) + "x"
                    flat: true

                    MenuItem {
                        text: "0.5x"
                        onTriggered: {
                            videoPlayerWindow.playbackRate = 0.5
                        }
                    }
                    MenuItem {
                        text: "0.75x"
                        onTriggered: {
                            videoPlayerWindow.playbackRate = 0.75
                        }
                    }
                    MenuItem {
                        text: "1.0x"
                        onTriggered: {
                            videoPlayerWindow.playbackRate = 1.0
                        }
                    }
                    MenuItem {
                        text: "1.25x"
                        onTriggered: {
                            videoPlayerWindow.playbackRate = 1.25
                        }
                    }
                    MenuItem {
                        text: "1.5x"
                        onTriggered: {
                            videoPlayerWindow.playbackRate = 1.5
                        }
                    }
                    MenuItem {
                        text: "2.0x"
                        onTriggered: {
                            videoPlayerWindow.playbackRate = 2.0
                        }
                    }
                }

                // 音量控制
                RowLayout {
                    spacing: 4

                    ToolButton {
                        icon.name: audioOutput.volume === 0 ? "ic_fluent_speaker_mute_20_regular" :
                                   audioOutput.volume < 0.3 ? "ic_fluent_speaker_0_20_regular" :
                                   audioOutput.volume < 0.7 ? "ic_fluent_speaker_1_20_regular" :
                                   "ic_fluent_speaker_2_20_regular"
                        flat: true

                        onClicked: {
                            if (audioOutput.volume > 0) {
                                audioOutput.volume = 0
                                volumeSlider.value = 0
                            } else {
                                audioOutput.volume = 0.5
                                volumeSlider.value = 50
                            }
                        }
                    }

                    Slider {
                        id: volumeSlider
                        Layout.preferredWidth: 100
                        from: 0
                        to: 100
                        value: 50
                        stepSize: 1

                        onValueChanged: {
                            audioOutput.volume = value / 100
                        }
                    }
                }

                // 全屏切换按钮
                ToolButton {
                    icon.name: videoPlayerWindow.isFullscreen ? "ic_fluent_arrow_minimize_20_regular" : "ic_fluent_arrow_maximize_20_regular"
                    flat: true

                    onClicked: {
                        toggleFullscreen()
                    }
                }
            }
        }
    }

    // 键盘快捷键
    Shortcut {
        sequence: "Space"
        onActivated: {
            if (videoPlayerWindow.isPlaying) {
                videoPlayer.pause()
            } else {
                videoPlayer.play()
            }
        }
    }

    Shortcut {
        sequence: "F"
        onActivated: toggleFullscreen()
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            // 使用实际窗口状态判断
            if (videoPlayerWindow.visibility === Window.FullScreen) {
                exitFullscreen()
            }
        }
    }

    Shortcut {
        sequence: "Left"
        onActivated: {
            videoPlayer.position = Math.max(0, videoPlayer.position - 5000)
        }
    }

    Shortcut {
        sequence: "Right"
        onActivated: {
            videoPlayer.position = Math.min(videoPlayer.duration, videoPlayer.position + 5000)
        }
    }

    Shortcut {
        sequence: "Up"
        onActivated: {
            volumeSlider.value = Math.min(100, volumeSlider.value + 5)
        }
    }

    Shortcut {
        sequence: "Down"
        onActivated: {
            volumeSlider.value = Math.max(0, volumeSlider.value - 5)
        }
    }

    // 格式化时间
    function formatTime(ms) {
        if (ms <= 0 || isNaN(ms)) return "00:00"
        var seconds = Math.floor(ms / 1000)
        var minutes = Math.floor(seconds / 60)
        var hours = Math.floor(minutes / 60)
        seconds = seconds % 60
        minutes = minutes % 60

        if (hours > 0) {
            return pad(hours) + ":" + pad(minutes) + ":" + pad(seconds)
        }
        return pad(minutes) + ":" + pad(seconds)
    }

    function pad(num) {
        return num < 10 ? "0" + num : num
    }

    // 切换全屏
    function toggleFullscreen() {
        // 检测窗口实际状态，而不是依赖 isFullscreen 属性
        if (videoPlayerWindow.visibility === Window.FullScreen) {
            exitFullscreen()
        } else {
            enterFullscreen()
        }
    }

    // 保存原始边距
    property int originalWindowDragArea: 0

    function enterFullscreen() {
        // 保存当前几何信息和窗口状态
        normalGeometry = {
            x: videoPlayerWindow.x,
            y: videoPlayerWindow.y,
            width: videoPlayerWindow.width,
            height: videoPlayerWindow.height,
            isMaximized: videoPlayerWindow.visibility === Window.Maximized
        }

        // 保存并移除窗口边距（避免全屏时出现白边）
        originalWindowDragArea = Utils.windowDragArea
        Utils.windowDragArea = 0

        // 隐藏标题栏
        videoPlayerWindow.titleBarHeight = 0
        videoPlayerWindow.showFullScreen()
        videoPlayerWindow.isFullscreen = true
    }

    function exitFullscreen() {
        // 恢复窗口边距
        Utils.windowDragArea = originalWindowDragArea

        // 恢复标题栏高度
        videoPlayerWindow.titleBarHeight = 48
        
        // 如果之前是最大化状态，恢复到最大化；否则恢复到正常大小
        if (normalGeometry.isMaximized) {
            videoPlayerWindow.showMaximized()
        } else {
            videoPlayerWindow.showNormal()
            videoPlayerWindow.x = normalGeometry.x
            videoPlayerWindow.y = normalGeometry.y
            videoPlayerWindow.width = normalGeometry.width
            videoPlayerWindow.height = normalGeometry.height
        }
        videoPlayerWindow.isFullscreen = false
    }

    // 加载视频
    function loadVideo(source, title, options) {
        options = options || {}
        console.log("加载视频:", title, source, options)
        videoPlayerWindow.videoSource = source

        // 处理标题，移除可能导致显示问题的字符
        var cleanTitle = title ? title.replace(/[\/\\:*?"<>|]/g, " ") : qsTr("视频播放")
        videoPlayerWindow.videoTitle = cleanTitle
        videoPlayerWindow.title = cleanTitle

        // 设置视频ID（用于断点续播）
        videoPlayerWindow.videoId = options.pid || ""
        videoPlayerWindow.hasResumed = false
        videoPlayerWindow.showResumeNotification = false

        // 应用播放选项
        if (options.rate) {
            videoPlayerWindow.playbackRate = options.rate
            console.log("设置播放倍率:", options.rate)
        }
        if (options.volume !== undefined) {
            volumeSlider.value = options.volume
            console.log("设置音量:", options.volume)
        }

        videoPlayer.stop()
        errorText.visible = false

        // 临时置顶窗口，确保在最前面显示
        videoPlayerWindow.flags = videoPlayerWindow.flags | Qt.WindowStaysOnTopHint
        // 100ms后取消置顶，让用户可以正常操作
        topmostTimer.start()

        // 检查视频源是否有效
        if (!source || source.toString() === "") {
            console.error("视频源为空")
            errorText.text = qsTr("视频源为空")
            errorText.visible = true
            return
        }

        // 设置视频源
        videoPlayer.source = source

        // 检查是否是 MP4 格式
        var sourceStr = source.toString()
        if (sourceStr.endsWith(".mp4") || sourceStr.includes(".mp4?")) {
            console.log("检测到 MP4 格式视频")
        }

        // 延迟一点开始播放，确保视频源已加载
        playTimer.options = options
        playTimer.start()
    }

    // 播放定时器
    Timer {
        id: playTimer
        interval: 500
        repeat: false
        property var options: {}
        onTriggered: {
            console.log("开始播放视频")
            videoPlayer.play()

            // 如果有开始时间选项，跳转到指定位置
            if (options && options.time && options.time > 0) {
                console.log("跳转到开始时间:", options.time, "秒")
                videoPlayer.position = options.time * 1000  // 转换为毫秒
            }
        }
    }

    // 临时置顶定时器（100ms后取消置顶）
    Timer {
        id: topmostTimer
        interval: 100
        repeat: false
        onTriggered: {
            // 取消置顶，恢复普通窗口
            videoPlayerWindow.flags = videoPlayerWindow.flags & ~Qt.WindowStaysOnTopHint
            console.log("视频播放器已取消置顶")
        }
    }

    // 续播通知定时器（5秒后自动隐藏）
    Timer {
        id: resumeNotificationTimer
        interval: 5000
        repeat: false
        onTriggered: {
            videoPlayerWindow.showResumeNotification = false
        }
    }

    // 播放视频
    function play() {
        videoPlayer.play()
    }

    // 暂停视频
    function pause() {
        videoPlayer.pause()
    }

    // 停止视频
    function stop() {
        videoPlayer.stop()
    }

    // 跳转到指定位置并继续播放
    function resumeFromPosition(position) {
        videoPlayer.position = position
        videoPlayer.play()
        videoPlayerWindow.showResumeNotification = false
        console.log("已跳转到上次播放位置:", position)
    }

    // 关闭窗口
    function closePlayer() {
        videoPlayerWindow.close()
    }
}
