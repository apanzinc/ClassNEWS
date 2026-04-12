import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import RinUI

FluentPage {
    id: settingsPage

    spacing: 24

    // 属性：是否已完成初始化
    property bool initialized: false

    // 重启提示对话框
    Dialog {
        id: restartDialog
        title: qsTr("设置已更改")
        modal: true
        standardButtons: Dialog.Ok
        width: 400

        // 确保对话框居中显示
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            spacing: 16
            width: parent.width

            Text {
                text: qsTr("需要重启应用才能生效，请手动重启应用。")
                wrapMode: Text.Wrap
                color: Utils.colors.textColor
                Layout.fillWidth: true
            }
        }
    }

    // 三重确认对话框 - 第一步
    Dialog {
        id: confirmDialog1
        title: qsTr("警告：清除全部数据")
        modal: true
        width: 450
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            spacing: 16
            width: parent.width

            Text {
                text: qsTr("您确定要清除全部数据吗？")
                font.bold: true
                font.pixelSize: 16
                color: Utils.colors.textColor
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("此操作将删除所有配置文件、日志文件和临时文件，且无法恢复！")
                wrapMode: Text.Wrap
                color: Utils.colors.errorColor
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("点击「确认」继续，点击「取消」放弃操作。")
                wrapMode: Text.Wrap
                color: Utils.colors.textSecondaryColor
                Layout.fillWidth: true
            }
        }

        standardButtons: Dialog.Cancel | Dialog.Ok

        onAccepted: confirmDialog2.open()
    }

    // 三重确认对话框 - 第二步
    Dialog {
        id: confirmDialog2
        title: qsTr("再次确认")
        modal: true
        width: 450
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            spacing: 16
            width: parent.width

            Text {
                text: qsTr("您真的确定吗？")
                font.bold: true
                font.pixelSize: 16
                color: Utils.colors.textColor
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("所有设置、历史记录和缓存数据都将被永久删除！")
                wrapMode: Text.Wrap
                color: Utils.colors.errorColor
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("这是第二次确认，点击「确认」进行最后一次确认。")
                wrapMode: Text.Wrap
                color: Utils.colors.textSecondaryColor
                Layout.fillWidth: true
            }
        }

        standardButtons: Dialog.Cancel | Dialog.Ok

        onAccepted: confirmDialog3.open()
    }

    // 三重确认对话框 - 第三步（最终确认）
    Dialog {
        id: confirmDialog3
        title: qsTr("最终确认")
        modal: true
        width: 450
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            spacing: 16
            width: parent.width

            Text {
                text: qsTr("最后一次确认")
                font.bold: true
                font.pixelSize: 16
                color: Utils.colors.textColor
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("清除全部数据后，应用将恢复到初始状态，所有个人设置都将丢失！")
                wrapMode: Text.Wrap
                color: "#FF0000"
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("点击「确认」立即清除所有数据，点击「取消」放弃操作。")
                wrapMode: Text.Wrap
                color: Utils.colors.textSecondaryColor
                Layout.fillWidth: true
            }
        }

        standardButtons: Dialog.Cancel | Dialog.Ok

        onAccepted: {
            clearDataSuccessDialog.open()
        }
    }

    // 清除数据成功提示
    Dialog {
        id: clearDataSuccessDialog
        title: qsTr("数据已清除")
        modal: true
        width: 400
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            spacing: 16
            width: parent.width

            Text {
                text: qsTr("全部数据已成功清除！")
                font.bold: true
                color: Utils.colors.textColor
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("应用将在您点击「确定」后关闭，请重新启动应用。")
                wrapMode: Text.Wrap
                color: Utils.colors.textSecondaryColor
                Layout.fillWidth: true
            }
        }

        standardButtons: Dialog.Ok

        onAccepted: {
            // 执行清除操作，clearAllData 会强制退出应用
            console.log("开始清除数据...")
            if (configManager) {
                console.log("configManager 存在，调用 clearAllData")
                configManager.clearAllData()
                console.log("clearAllData 调用完成")
            } else {
                console.log("configManager 不存在！")
            }
        }
    }

    // 视频播放器窗口实例
    property var videoPlayerWindow: null

    // 创建视频播放器窗口
    function createVideoPlayerWindow() {
        if (videoPlayerWindow === null) {
            var component = Qt.createComponent("pages/VideoPlayerWindow.qml")
            if (component.status === Component.Ready) {
                videoPlayerWindow = component.createObject(settingsPage)
                // 传递主窗口引用给视频播放器
                videoPlayerWindow.mainWindow = settingsPage.Window.window
                videoPlayerWindow.windowClosed.connect(function() {
                    videoPlayerWindow = null
                })
                // 注册窗口到 WindowManager（用于 Windows 窗口缩放）
                console.log("Settings windowManager 类型:", typeof windowManager)
                if (typeof windowManager !== 'undefined') {
                    console.log("Settings windowManager.registerWindow:", windowManager.registerWindow)
                    Qt.callLater(function() {
                        if (videoPlayerWindow && windowManager.registerWindow) {
                            windowManager.registerWindow(videoPlayerWindow)
                            console.log("Settings 视频播放器窗口已注册到 WindowManager")
                        }
                    })
                } else {
                    console.log("Settings windowManager 未定义")
                }
            } else {
                console.error("无法创建视频播放器窗口:", component.errorString())
            }
        }
        return videoPlayerWindow
    }

    // 打开视频播放器
    function openVideoPlayer(source, title, pid) {
        // 检查是否使用内置播放器
        if (useInternalPlayerSwitch.checked) {
            var player = createVideoPlayerWindow()
            if (player) {
                // 构建播放选项，传入 pid 用于断点续播
                var options = {}
                if (pid) {
                    options.pid = pid
                    console.log("Settings openVideoPlayer: 传入 pid =", pid)
                }
                player.loadVideo(source, title, options)
                player.show()
                player.raise()
                player.requestActivate()
            }
        } else {
            // 使用系统播放器
            var result = videoManager.openWithExternalPlayer(source, title)
            if (!result) {
                // 如果外部播放器打开失败，提示用户
                externalPlayerErrorDialog.open()
            }
        }
    }

    // 外部播放器错误提示对话框
    Dialog {
        id: externalPlayerErrorDialog
        title: qsTr("播放器打开失败")
        modal: true
        standardButtons: Dialog.Ok
        width: 400
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            spacing: 16
            width: parent.width

            Text {
                text: qsTr("无法使用系统播放器打开视频。可能的原因：\n\n" +
                          "1. 视频格式不受支持\n" +
                          "2. 缺少视频解码器（如 H.264/H.265）\n" +
                          "3. 未安装兼容的视频播放器\n\n" +
                          "建议：安装 VLC 或 PotPlayer 播放器，或使用内置播放器。")
                wrapMode: Text.Wrap
                color: Utils.colors.textColor
                Layout.fillWidth: true
            }
        }
    }

    // 顶部间距
    Item {
        height: 0
    }

    // 常规设置
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        spacing: 8

        // 标题
        Text {
            text: qsTr("常规")
            font.pixelSize: 14
            font.bold: true
            color: Utils.colors.textColor
        }

        // 开机自动启动
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("开机自动启动")
            description: qsTr("系统启动时自动在后台运行 ClassNEWS")

            Switch {
                id: autoStartSwitch
                checked: configManager ? configManager.autoStart : false
                onCheckedChanged: {
                    if (configManager) {
                        configManager.autoStart = checked
                    }
                }
            }
        }
    }

    // 个性化设置
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        spacing: 8

        // 标题
        Text {
            text: qsTr("个性化")
            font.pixelSize: 14
            font.bold: true
            color: Utils.colors.textColor
        }

        // 应用主题
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("应用主题")
            description: qsTr("选择亮色、暗色或跟随系统")

            ComboBox {
                id: themeComboBox
                model: [qsTr("跟随系统"), qsTr("亮色"), qsTr("暗色")]

                Component.onCompleted: {
                    var themeName = ThemeManager.get_theme_name()
                    if (themeName === "Light") {
                        currentIndex = 1
                    } else if (themeName === "Dark") {
                        currentIndex = 2
                    } else {
                        currentIndex = 0
                    }
                    settingsPage.initialized = true
                }

                onCurrentIndexChanged: {
                    if (!settingsPage.initialized) {
                        return
                    }
                    var themeValue = ""
                    if (currentIndex === 0) {
                        themeValue = "Auto"
                    } else if (currentIndex === 1) {
                        themeValue = "Light"
                    } else if (currentIndex === 2) {
                        themeValue = "Dark"
                    }
                    ThemeManager.toggle_theme(themeValue)
                    // 主题切换不需要重启
                }
            }
        }

        // 强调色
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("强调色")
            description: qsTr("选择应用的主题颜色")

            RowLayout {
                spacing: 8

                // 系统默认
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Utils.primaryColor
                    border.width: ThemeManager.get_theme_color() === "" || ThemeManager.get_theme_color() === Utils.primaryColor ? 2 : 0
                    border.color: Utils.colors.textColor

                    MouseArea {
                        Layout.fillWidth: true
        Layout.fillHeight: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ThemeManager.set_theme_color("")
                            restartDialog.open()
                        }
                    }
                }

                // 图标红
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: "#EF3E4B"
                    border.width: ThemeManager.get_theme_color() === "#EF3E4B" ? 2 : 0
                    border.color: Utils.colors.textColor

                    MouseArea {
                        Layout.fillWidth: true
        Layout.fillHeight: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ThemeManager.set_theme_color("#EF3E4B")
                            restartDialog.open()
                        }
                    }
                }

                // apanzinc蓝
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: "#027CFF"
                    border.width: ThemeManager.get_theme_color() === "#027CFF" ? 2 : 0
                    border.color: Utils.colors.textColor

                    MouseArea {
                        Layout.fillWidth: true
        Layout.fillHeight: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ThemeManager.set_theme_color("#027CFF")
                            restartDialog.open()
                        }
                    }
                }

                // 星澜紫
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: "#E100FF"
                    border.width: ThemeManager.get_theme_color() === "#E100FF" ? 2 : 0
                    border.color: Utils.colors.textColor

                    MouseArea {
                        Layout.fillWidth: true
        Layout.fillHeight: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ThemeManager.set_theme_color("#E100FF")
                            restartDialog.open()
                        }
                    }
                }

                // 自定义颜色按钮
                RoundButton {
                    width: 28
                    height: 28
                    flat: true
                    icon.name: "ic_fluent_color_20_regular"
                    
                    onClicked: {
                        // 打开颜色选择器或输入框
                        customColorDialog.open()
                    }
                }

                // 自定义颜色对话框
                Dialog {
                    id: customColorDialog
                    title: qsTr("自定义颜色")
                    modal: true
                    standardButtons: Dialog.Ok | Dialog.Cancel
                    width: 300
                    
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2

                    ColumnLayout {
                        spacing: 16
                        width: parent.width

                        TextField {
                            id: colorInput
                            placeholderText: qsTr("输入十六进制颜色，如 #FF0000")
                            text: ThemeManager.get_theme_color()
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 50
                            height: 50
                            radius: 25
                            color: colorInput.text
                            border.width: 2
                            border.color: Utils.colors.textColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    onAccepted: {
                        if (colorInput.text.match(/^#[0-9A-Fa-f]{6}$/)) {
                            ThemeManager.set_theme_color(colorInput.text)
                            restartDialog.open()
                        }
                    }
                }
            }
        }
    }

    // 视频播放器设置（独立大类，优先级最高）
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        spacing: 8

        // 标题
        Text {
            text: qsTr("视频播放器")
            font.pixelSize: 14
            font.bold: true
            color: Utils.colors.textColor
        }

        // 使用内置播放器
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("使用内置播放器")
            description: useInternalPlayerSwitch.checked ? qsTr("使用 ClassNEWS 内置播放器") : qsTr("使用系统默认播放器")

            Switch {
                id: useInternalPlayerSwitch
                checked: configManager ? configManager.useInternalPlayer : true
                onCheckedChanged: {
                    if (configManager) {
                        configManager.useInternalPlayer = checked
                    }
                    if (videoManager) {
                        videoManager.useInternalPlayer = checked
                    }
                }
            }
        }

        // 默认音量（仅使用内置播放器时显示）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("默认音量")
            description: qsTr("当协议未指定音量时使用的默认音量（0-100）")
            visible: useInternalPlayerSwitch.checked

            SpinBox {
                id: defaultVolumeSpinBox
                from: 0
                to: 100
                value: configManager ? configManager.defaultVolume : 80
                onValueModified: {
                    if (configManager) {
                        configManager.defaultVolume = value
                    }
                }
            }
        }

        // 默认倍速（仅使用内置播放器时显示）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("默认倍速")
            description: qsTr("当协议未指定倍速时使用的默认播放速度")
            visible: useInternalPlayerSwitch.checked

            ComboBox {
                id: defaultPlaybackRateComboBox
                model: ["0.5x", "0.75x", "1.0x", "1.25x", "1.5x", "2.0x"]
                currentIndex: {
                    var rate = configManager ? configManager.defaultPlaybackRate : 1.0
                    if (rate === 0.5) return 0
                    if (rate === 0.75) return 1
                    if (rate === 1.0) return 2
                    if (rate === 1.25) return 3
                    if (rate === 1.5) return 4
                    if (rate === 2.0) return 5
                    return 2
                }
                onCurrentIndexChanged: {
                    if (configManager) {
                        var rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                        configManager.defaultPlaybackRate = rates[currentIndex]
                    }
                }
            }
        }

        // 默认进度（跳过片头，仅使用内置播放器时显示）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("默认进度")
            description: qsTr("播放时自动跳过的片头时长（0-300秒）")
            visible: useInternalPlayerSwitch.checked

            SpinBox {
                id: defaultProgressSpinBox
                from: 0
                to: 300
                value: configManager ? configManager.defaultProgress : 0
                onValueModified: {
                    if (configManager) {
                        configManager.defaultProgress = value
                    }
                }
            }
        }

        // 自动重播（仅使用内置播放器时显示）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("自动重播")
            description: qsTr("视频播放结束后自动从头开始播放")
            visible: useInternalPlayerSwitch.checked

            Switch {
                id: autoReplaySwitch
                checked: configManager ? configManager.autoReplay : false
                onCheckedChanged: {
                    if (configManager) {
                        configManager.autoReplay = checked
                    }
                }
            }
        }

        // 自动续播（仅使用内置播放器时显示）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("自动续播")
            description: qsTr("视频播放结束后自动播放下一个")
            visible: useInternalPlayerSwitch.checked

            Switch {
                id: autoContinueSwitch
                checked: configManager ? configManager.autoContinue : true
                onCheckedChanged: {
                    if (configManager) {
                        configManager.autoContinue = checked
                    }
                }
            }
        }
    }

    // 协议设置
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        spacing: 8

        // 标题
        Text {
            text: qsTr("协议")
            font.pixelSize: 14
            font.bold: true
            color: Utils.colors.textColor
        }

        // 协议注册（卡片式开关）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("协议注册")
            description: qsTr("开启后允许第三方应用通过 classnews:// 协议调用视频播放")

            Switch {
                id: protocolSwitch
                checked: protocolManager ? protocolManager.isProtocolRegistered() : false
                onCheckedChanged: {
                    if (protocolManager) {
                        if (checked) {
                            var result = protocolManager.registerProtocol()
                            if (!result) {
                                protocolSwitch.checked = false
                            }
                        } else {
                            var result = protocolManager.unregisterProtocol()
                            if (!result) {
                                protocolSwitch.checked = true
                            }
                        }
                    }
                }
            }
        }

        // 显示唤醒倒计时窗口（协议注册后才显示）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("显示唤醒倒计时窗口")
            description: qsTr("通过协议唤醒时显示倒计时提示窗口")
            visible: protocolSwitch.checked
            enabled: protocolSwitch.checked

            Switch {
                id: showNotificationWindowSwitch
                checked: configManager ? configManager.showNotificationWindow : true
                enabled: protocolSwitch.checked
                onCheckedChanged: {
                    if (configManager) {
                        configManager.showNotificationWindow = checked
                    }
                }
            }
        }

        // 倒计时秒数（协议注册后才显示）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("倒计时秒数")
            description: qsTr("设置唤醒窗口的倒计时时间（1-60 秒）")
            visible: protocolSwitch.checked
            enabled: protocolSwitch.checked && showNotificationWindowSwitch.checked

            SpinBox {
                id: notificationCountdownSpinBox
                from: 1
                to: 60
                value: configManager ? configManager.notificationCountdownSeconds : 5
                enabled: protocolSwitch.checked && showNotificationWindowSwitch.checked
                onValueModified: {
                    if (configManager) {
                        configManager.notificationCountdownSeconds = value
                    }
                }
            }
        }

        // 全屏播放（协议注册后才显示，仅内置播放器生效）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("协议调用时全屏播放")
            description: fullScreenPlaybackSwitch.checked ? qsTr("通过协议唤醒时自动进入全屏模式（仅内置播放器）") : qsTr("通过协议唤醒时保持窗口模式")
            visible: protocolSwitch.checked
            enabled: useInternalPlayerSwitch.checked

            Switch {
                id: fullScreenPlaybackSwitch
                checked: configManager ? configManager.fullscreenPlayback : false
                enabled: useInternalPlayerSwitch.checked
                onCheckedChanged: {
                    if (configManager) {
                        configManager.fullscreenPlayback = checked
                    }
                }
            }
        }

        // 协议帮助链接（协议注册后才显示）
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("协议文档")
            description: qsTr("查看 classnews:// 协议的详细使用说明")
            visible: protocolSwitch.checked

            Button {
                text: qsTr("查看")
                onClicked: Qt.openUrlExternally("https://classnews.apanzinc.top/protocol")
            }
        }
    }

    // 高级设置
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 24
        Layout.rightMargin: 24
        spacing: 8

        // 标题
        Text {
            text: qsTr("高级")
            font.pixelSize: 14
            font.bold: true
            color: Utils.colors.textColor
        }

        // 日志设置
        SettingExpander {
            Layout.fillWidth: true
            title: qsTr("日志管理")
            icon.name: "ic_fluent_document_text_20_regular"

            // 查看日志
            SettingItem {
                Layout.fillWidth: true
                title: qsTr("查看日志")

                Button {
                    text: qsTr("打开")
                    onClicked: logViewerDialog.open()
                }
            }

            // 清除日志
            SettingItem {
                Layout.fillWidth: true
                title: qsTr("清除日志")

                Button {
                    text: qsTr("清除")
                    onClicked: {
                        if (appLogger) {
                            appLogger.clearLogs()
                        }
                    }
                }
            }

            // 打开日志文件夹
            SettingItem {
                Layout.fillWidth: true
                title: qsTr("日志文件夹位置")

                Button {
                    text: qsTr("打开")
                    onClicked: {
                        if (appLogger) {
                            Qt.openUrlExternally("file:///" + appLogger.getLogDirPath())
                        }
                    }
                }
            }

            // 显示详细日志选项（仅在调试模式下显示）
            SettingItem {
                Layout.fillWidth: true
                title: qsTr("显示详细日志")
                description: qsTr("记录点击事件等详细信息")
                visible: debugModeSwitch.checked ? true : false

                Switch {
                    checked: configManager ? configManager.showDebugDetails : false
                    onCheckedChanged: {
                        if (configManager) {
                            configManager.showDebugDetails = checked
                        }
                        if (appLogger) {
                            appLogger.showDebugDetails = checked
                        }
                    }
                }
            }

            // Git 提交
            SettingItem {
                Layout.fillWidth: true
                title: qsTr("Git 提交")

                Text {
                    text: systemInfo.gitCommit
                    color: Utils.colors.textSecondaryColor
                    font.family: Utils.fontFamily
                }
            }
        }

        // 调试模式
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("调试模式")
            description: qsTr("启用开发者调试功能")

            Switch {
                id: debugModeSwitch
                checked: false
            }
        }

        // 清除全部数据
        SettingCard {
            Layout.fillWidth: true
            title: qsTr("清除全部数据")
            description: qsTr("删除所有配置文件、日志和临时文件，恢复初始状态")

            Button {
                text: qsTr("清除")
                highlighted: true
                onClicked: confirmDialog1.open()
            }
        }

        // 调试工具（仅在调试模式下显示）
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: debugModeSwitch.checked

            // 标题
            Text {
                text: qsTr("调试工具")
                font.pixelSize: 14
                font.bold: true
                color: Utils.colors.textColor
            }

            // 视频URL输入
            SettingCard {
                Layout.fillWidth: true
                title: qsTr("视频URL")
                description: qsTr("输入视频文件路径或网络URL")

                RowLayout {
                    spacing: 8

                    TextField {
                        id: videoUrlInput
                        Layout.preferredWidth: 250
                        placeholderText: qsTr("输入视频URL")
                    }

                    Button {
                        text: qsTr("播放")
                        onClicked: {
                            if (videoUrlInput.text.trim() !== "") {
                                openVideoPlayer(videoUrlInput.text.trim(), qsTr("调试视频"))
                            }
                        }
                    }
                }
            }

            // 测试视频源
            SettingCard {
                Layout.fillWidth: true
                title: qsTr("测试视频")
                description: qsTr("播放测试视频")

                Button {
                    text: qsTr("播放")
                    onClicked: {
                        // 使用公开的测试视频URL
                        openVideoPlayer("https://www.w3schools.com/html/mov_bbb.mp4", qsTr("测试视频"))
                    }
                }
            }

            // 快速播放
            SettingCard {
                Layout.fillWidth: true
                title: qsTr("快速播放")
                description: qsTr("一键播放朝闻天下")

                Button {
                    text: qsTr("朝闻天下")
                    onClicked: videoManager.playProgramByName("朝闻天下")
                }
            }

            // ButtonGroup for InfoBar test radio buttons
            ButtonGroup {
                id: infoBarTypeGroup
            }

            // InfoBar 测试
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // 标题
                Text {
                    text: qsTr("InfoBar 通知测试")
                    font.pixelSize: 14
                    font.bold: true
                    color: Utils.colors.textColor
                }

                // 通知设置（使用 SettingExpander）
                SettingExpander {
                    Layout.fillWidth: true
                    title: qsTr("通知设置")
                    description: qsTr("配置通知类型和选项")
                    icon.name: "ic_fluent_mail_20_regular"
                    
                    // 可折叠内容区域 - 使用 SettingItem
                    SettingItem {
                        title: qsTr("通知类型")
                        description: qsTr("选择通知的严重程度")
                        
                        RowLayout {
                            spacing: 8
                            
                            RadioButton {
                                id: infoTypeRadio
                                text: qsTr("普通")
                                checked: true
                                ButtonGroup.group: infoBarTypeGroup
                            }
                            
                            RadioButton {
                                id: warningTypeRadio
                                text: qsTr("警告")
                                ButtonGroup.group: infoBarTypeGroup
                            }
                            
                            RadioButton {
                                id: errorTypeRadio
                                text: qsTr("错误")
                                ButtonGroup.group: infoBarTypeGroup
                            }
                            
                            RadioButton {
                                id: successTypeRadio
                                text: qsTr("成功")
                                ButtonGroup.group: infoBarTypeGroup
                            }
                        }
                    }
                    
                    SettingItem {
                        title: qsTr("通知选项")
                        description: qsTr("自定义通知行为")
                        
                        RowLayout {
                            spacing: 16
                            
                            CheckBox {
                                id: closableCheckBox
                                text: qsTr("显示关闭按钮")
                                checked: true
                            }
                            
                            CheckBox {
                                id: autoCloseCheckBox
                                text: qsTr("自动关闭")
                                checked: true
                            }
                            
                            RowLayout {
                                spacing: 8
                                enabled: autoCloseCheckBox.checked
                                
                                Text {
                                    text: qsTr("关闭时间:")
                                    color: enabled ? Utils.colors.textColor : Utils.colors.textSecondaryColor
                                }
                                
                                SpinBox {
                                    id: timeoutSpinBox
                                    from: 1000
                                    to: 30000
                                    stepSize: 1000
                                    value: 5000
                                    enabled: autoCloseCheckBox.checked
                                }
                                
                                Text {
                                    text: qsTr("毫秒")
                                    color: autoCloseCheckBox.checked ? Utils.colors.textColor : Utils.colors.textSecondaryColor
                                }
                            }
                        }
                    }
                }

                // 测试按钮
                SettingCard {
                    Layout.fillWidth: true
                    title: qsTr("发送通知")
                    description: qsTr("点击按钮显示测试通知")

                    Button {
                        text: qsTr("显示通知")
                        highlighted: true
                        onClicked: {
                            console.log("测试：显示 InfoBar 通知")
                            
                            // 确定通知类型
                            var severity = Severity.Info
                            if (warningTypeRadio.checked) {
                                severity = Severity.Warning
                            } else if (errorTypeRadio.checked) {
                                severity = Severity.Error
                            } else if (successTypeRadio.checked) {
                                severity = Severity.Success
                            }
                            
                            // 生成通知文本
                            var typeText = ""
                            switch(severity) {
                                case Severity.Info: typeText = "普通"; break;
                                case Severity.Warning: typeText = "警告"; break;
                                case Severity.Error: typeText = "错误"; break;
                                case Severity.Success: typeText = "成功"; break;
                            }
                            
                            if (settingsPage.Window.window && settingsPage.Window.window.showInfoBar) {
                                settingsPage.Window.window.showInfoBar(
                                    qsTr("测试通知 - ") + typeText,
                                    qsTr("这是一条") + typeText + qsTr("类型的 InfoBar 通知"),
                                    severity,
                                    autoCloseCheckBox.checked ? timeoutSpinBox.value : 0,
                                    closableCheckBox.checked
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // 协议帮助对话框
    Dialog {
        id: protocolHelpDialog
        title: qsTr("classnews:// 协议说明")
        modal: true
        width: 550
        height: 480
        standardButtons: Dialog.Close

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        contentItem: ColumnLayout {
            spacing: 16
            anchors.margins: 20

            Text {
                text: qsTr("什么是 classnews:// 协议？")
                font.bold: true
                font.pixelSize: 16
                color: Utils.colors.textColor
            }

            Text {
                text: qsTr("classnews:// 是一个自定义 URL 协议，允许其他应用程序或网页直接调用 ClassNEWS 播放视频。")
                wrapMode: Text.Wrap
                color: Utils.colors.textColor
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("使用格式：")
                font.bold: true
                font.pixelSize: 14
                color: Utils.colors.textColor
            }

            Rectangle {
                Layout.fillWidth: true
                height: 80
                color: ThemeManager.get_theme() === "Dark" ? "#2D2D2D" : "#F0F0F0"
                radius: 4

                TextArea {
                    Layout.fillWidth: true
        Layout.fillHeight: true
                    anchors.margins: 8
                    readOnly: true
                    wrapMode: Text.Wrap
                    color: Utils.colors.textColor
                    font.family: "Consolas, monospace"
                    font.pixelSize: 12
                    text: "classnews://play?pid=VIDEO_ID&title=VIDEO_TITLE\n\n示例：\nclassnews://play?pid=20240315001&title=新闻联播"
                }
            }

            Text {
                text: qsTr("参数说明：")
                font.bold: true
                font.pixelSize: 14
                color: Utils.colors.textColor
            }

            Text {
                text: qsTr("• pid: 视频ID（必需）\n• title: 视频标题（可选）")
                wrapMode: Text.Wrap
                color: Utils.colors.textColor
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }

            Button {
                text: qsTr("查看完整文档")
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    Qt.openUrlExternally("docs/PROTOCOL.md")
                    protocolHelpDialog.close()
                }
            }
        }
    }

    // 日志查看器对话框
    Dialog {
        id: logViewerDialog
        title: qsTr("应用日志")
        modal: true
        width: 800
        height: 600

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            // 日志级别筛选
            RowLayout {
                spacing: 8

                Text {
                    text: qsTr("筛选级别:")
                    color: Utils.colors.textColor
                }

                ComboBox {
                    id: logLevelFilter
                    model: ["全部", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
                    currentIndex: 0
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("刷新")
                    onClicked: updateLogDisplay()
                }

                Button {
                    text: qsTr("复制到剪贴板")
                    onClicked: {
                        if (appLogger) {
                            var clipboard = Qt.application.clipboard
                            if (clipboard) {
                                clipboard.text = logTextArea.text
                            }
                        }
                    }
                }
            }

            // 日志显示区域
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: ThemeManager.get_theme() === "Dark" ? "#1E1E1E" : "#F5F5F5"
                radius: 4

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    contentHeight: logTextArea.height
                    clip: true

                    TextArea {
                        id: logTextArea
                        width: parent.width
                        readOnly: true
                        wrapMode: Text.Wrap
                        color: ThemeManager.get_theme() === "Dark" ? "#D4D4D4" : "#333333"
                        font.family: "Consolas, Monaco, monospace"
                        font.pixelSize: 12
                        text: ""
                    }

                    ScrollBar.vertical: ScrollBar {}
                }
            }

            // 状态栏
            RowLayout {
                spacing: 8

                Text {
                    id: logStatusText
                    text: qsTr("日志文件: ") + (appLogger ? appLogger.getLogFilePath() : "")
                    color: Utils.colors.textSecondaryColor
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        onOpened: updateLogDisplay()

        function updateLogDisplay() {
            if (!appLogger) return

            var logs = ""
            if (logLevelFilter.currentIndex === 0) {
                logs = appLogger.getLogs()
            } else {
                var level = logLevelFilter.model[logLevelFilter.currentIndex]
                logs = appLogger.getLogsByLevel(level)
            }
            logTextArea.text = logs || qsTr("暂无日志")
        }
    }

    // 底部填充
    Item {
        Layout.fillHeight: true
    }


}
