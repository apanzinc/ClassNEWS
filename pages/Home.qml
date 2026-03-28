import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import RinUI

Rectangle {
    id: homePage
    color: "transparent"

    // 问候语更新定时器
    Timer {
        id: greetingTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: greetingText.text = greetingText.getGreeting()
    }

    // 根据窗口宽度决定布局
    property bool isCompact: width < 800

    // 刷新状态
    property bool isRefreshing: false

    // 视频播放器窗口实例
    property var videoPlayerWindow: null



    // 创建视频播放器窗口
    function createVideoPlayerWindow() {
        console.log("createVideoPlayerWindow 被调用, videoPlayerWindow:", videoPlayerWindow)
        if (videoPlayerWindow === null) {
            console.log("创建新窗口...")
            var component = Qt.createComponent("pages/VideoPlayerWindow.qml")
            console.log("组件状态:", component.status, "错误:", component.errorString())
            if (component.status === Component.Ready) {
                // 创建为顶级窗口（不设置父对象）
                videoPlayerWindow = component.createObject(null)
                console.log("窗口已创建:", videoPlayerWindow)
                // 传递主窗口引用给视频播放器
                videoPlayerWindow.mainWindow = homePage.Window.window
                videoPlayerWindow.windowClosed.connect(function() {
                    videoPlayerWindow = null
                })
                // 注册窗口到 WindowManager（用于 Windows 窗口缩放）
                console.log("检查 windowManager...")
                console.log("windowManager 类型:", typeof windowManager)
                console.log("windowManager 对象:", windowManager)
                if (typeof windowManager !== 'undefined' && windowManager !== null) {
                    console.log("windowManager 已定义，检查 registerWindow...")
                    console.log("registerWindow 方法:", windowManager.registerWindow)
                    if (windowManager.registerWindow) {
                        console.log("调用 registerWindow...")
                        windowManager.registerWindow(videoPlayerWindow)
                        console.log("视频播放器窗口已注册到 WindowManager")
                    } else {
                        console.log("windowManager 没有 registerWindow 方法")
                    }
                } else {
                    console.log("windowManager 未定义或为 null")
                }
            } else {
                console.error("无法创建视频播放器窗口:", component.errorString())
            }
        } else {
            console.log("使用已有窗口:", videoPlayerWindow)
        }
        return videoPlayerWindow
    }

    // 打开视频播放器
    function openVideoPlayer(source, title) {
        var player = createVideoPlayerWindow()
        if (player) {
            player.loadVideo(source, title)
            player.show()
            player.raise()
            player.requestActivate()
            // 隐藏主窗口
            hideMainWindow()
        }
    }

    // 隐藏主窗口
    function hideMainWindow() {
        var mainWindow = homePage.Window.window
        if (mainWindow) {
            mainWindow.hide()
        }
    }

    // 显示主窗口
    function showMainWindow() {
        var mainWindow = homePage.Window.window
        if (mainWindow) {
            mainWindow.show()
            mainWindow.raise()
            mainWindow.requestActivate()
        }
    }

    // 加载动画 - 新闻加载时显示（表情包动画）
    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        color: Utils.colors.backgroundColor
        visible: newsManager && newsManager.news ? newsManager.news.length === 0 : true
        z: 100

        Column {
            anchors.centerIn: parent
            spacing: 16

            // 表情包加载动画
            AnimatedImage {
                id: loadingGif
                anchors.horizontalCenter: parent.horizontalCenter
                source: "../assets/01.gif"
                width: 80
                height: 80
                fillMode: Image.PreserveAspectFit
                playing: loadingOverlay.visible
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("与服务器通讯中...")
                color: Utils.colors.textColor
                font.pixelSize: 14
            }
        }

        // 顶部进度条
        ProgressBar {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 0
            height: 3
            indeterminate: true
        }
    }

    // 使用 Flickable 实现滚动
    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: contentColumn.height
        clip: true
        visible: newsManager && newsManager.news ? newsManager.news.length > 0 : false

        // 滚动条
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: 16

            // 顶部刷新进度条容器（带动画，覆盖在内容上方）
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                Layout.topMargin: -3
                Layout.bottomMargin: 0
                z: 100

                ProgressBar {
                    anchors.top: parent.top
                    width: parent.width
                    height: homePage.isRefreshing ? 3 : 0
                    indeterminate: true
                    Behavior on height {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            // 顶部边距
            Item {
                Layout.preferredHeight: 8
            }

              // 标题栏（随时间变化的问候语）+ 刷新按钮
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 8

                Text {
                    id: greetingText
                    Layout.fillWidth: true
                    font.pixelSize: 24
                    font.bold: true
                    color: Utils.colors.textColor

                    // 问候语库 - 日常问候
                    property var greetings: {
                        "dawn": [  // 凌晨 0-5点
                            "夜深了，注意休息",
                            "早点休息，明天见",
                            "熬夜伤身，快去睡觉",
            "晚安，好梦"
                        ],
                        "earlyMorning": [  // 清晨 5-8点
                            "早安，新的一天开始了",
                            "早上好，愿你今天好心情",
                            "早安，记得吃早餐",
                            "早起的人，运气不会差"
                        ],
                        "morning": [  // 上午 8-11点
                            "上午好，今天也要加油",
                            "美好的一天开始了",
                            "上午好，保持好心情",
                            "愿你今天顺顺利利"
                        ],
                        "noon": [  // 中午 11-13点
                            "午餐时间，好好吃饭",
                            "中午好，休息一下",
                            "吃饱饭，下午更有劲",
                            "午休一下，精神更好"
                        ],
                        "afternoon": [  // 下午 13-17点
                            "下午好，继续加油",
                            "下午时光，保持专注",
                            "别犯困，再坚持一下",
                            "下午了，喝杯茶提提神"
                        ],
                        "evening": [  // 傍晚 17-19点
                            "傍晚好，今天过得怎么样",
                            "下班了，放松一下",
                            "傍晚时光，享受宁静",
                            "晚餐时间，好好享受"
                        ],
                        "night": [  // 晚上 19-23点
                            "晚上好，今天辛苦了",
                            "夜晚时光，放松身心",
                            "晚上是休息的好时机",
                            "愿你有个愉快的夜晚"
                        ],
                        "lateNight": [  // 深夜 23-0点
                            "夜深了，该休息了",
                            "该睡觉了，别熬夜",
                            "休息好，明天才有精神",
                            "早睡早起，身体好"
                        ]
                    }

                    function getGreeting() {
                        var hour = new Date().getHours();
                        var period;
                        
                        // 确定时间段
                        if (hour >= 0 && hour < 5) {
                            period = "dawn";
                        } else if (hour >= 5 && hour < 8) {
                            period = "earlyMorning";
                        } else if (hour >= 8 && hour < 11) {
                            period = "morning";
                        } else if (hour >= 11 && hour < 13) {
                            period = "noon";
                        } else if (hour >= 13 && hour < 17) {
                            period = "afternoon";
                        } else if (hour >= 17 && hour < 19) {
                            period = "evening";
                        } else if (hour >= 19 && hour < 23) {
                            period = "night";
                        } else {
                            period = "lateNight";
                        }
                        
                        // 从对应时间段随机选择一条问候语
                        var options = greetings[period];
                        var randomIndex = Math.floor(Math.random() * options.length);
                        return qsTr(options[randomIndex]);
                    }

                    text: getGreeting()
                }

                // 刷新按钮
                RoundButton {
                    id: refreshButton
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    flat: true
                    icon.name: "ic_fluent_arrow_sync_20_regular"
                    enabled: !homePage.isRefreshing

                    onClicked: {
                        if (homePage.isRefreshing) return
                        homePage.isRefreshing = true
                        // 同时刷新问候语
                        greetingText.text = greetingText.getGreeting()
                        // 延迟刷新新闻，等卡片动画完成
                        refreshTimer.start()
                    }

                    Timer {
                        id: refreshTimer
                        interval: 300
                        onTriggered: {
                            console.log("开始刷新新闻...")
                            newsManager.refreshNews()
                            // 5秒后自动重置刷新状态（新闻获取通常在2-3秒内完成）
                            resetRefreshingTimer.start()
                        }
                    }

                    Timer {
                        id: resetRefreshingTimer
                        interval: 5000
                        onTriggered: {
                            console.log("重置刷新状态")
                            homePage.isRefreshing = false
                        }
                    }

                    ToolTip {
                        visible: refreshButton.hovered
                        text: qsTr("刷新新闻")
                    }
                }

                // 调试按钮 - 测试视频通知窗口
                RoundButton {
                    id: debugButton
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    flat: true
                    icon.name: "ic_fluent_bug_20_regular"
                    visible: typeof debugMode !== 'undefined' && debugMode

                    onClicked: {
                        console.log("调试：触发视频通知窗口")
                        // 通过主窗口创建通知窗口
                        if (typeof mainWindow !== 'undefined' && mainWindow.createVideoNotificationWindow) {
                            var notificationWindow = mainWindow.createVideoNotificationWindow()
                            if (notificationWindow) {
                                notificationWindow.newsTitle = "测试新闻标题"
                                notificationWindow.pid = "test123"
                                notificationWindow.options = {"rate": 1.0, "volume": 50}
                                notificationWindow.show()
                                notificationWindow.raise()
                                notificationWindow.requestActivate()
                            }
                        }
                    }

                    ToolTip {
                        visible: debugButton.hovered
                        text: qsTr("测试视频通知")
                    }
                }
            }

            // 第一行：大图区 + 2x2 网格 - 使用API数据
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: homePage.isCompact ? 280 : 320
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 16

                // 左侧大图区（沉浸式）- 使用API第一条新闻
                Rectangle {
                    id: mainCard
                    Layout.preferredWidth: homePage.isCompact ? parent.width : parent.width * 0.55
                    Layout.fillHeight: true
                    Layout.fillWidth: homePage.isCompact
                    radius: 8
                    visible: newsManager && newsManager.news ? newsManager.news.length > 0 : false

                    // 主卡片显示第一条非完整版新闻
                    // 如果第一条是完整版，则显示第二条；否则显示第一条
                    property var mainNewsItem: {
                        if (!newsManager || !newsManager.news || newsManager.news.length === 0) return null
                        var firstNews = newsManager.news[0]
                        if (firstNews.isFullVersion && newsManager.news.length > 1) {
                            return newsManager.news[1]  // 第一条是完整版，显示第二条
                        }
                        return firstNews  // 显示第一条
                    }

                    Image {
                        id: newsImage
                        anchors.fill: parent
                        source: mainCard.mainNewsItem ? mainCard.mainNewsItem.image : ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: newsImage.width
                                height: newsImage.height
                                radius: 8
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.6; color: "transparent" }
                            GradientStop { position: 1.0; color: Utils.colors.maskColor }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Utils.colors.textColor
                        opacity: mainCardMouseArea.containsMouse ? 0.15 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 16
                        spacing: 4

                        Text {
                            text: mainCard.mainNewsItem ? mainCard.mainNewsItem.title : ""
                            font.pixelSize: 14
                            color: "#CCCCCC"
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: mainCard.mainNewsItem ? (mainCard.mainNewsItem.summary.length > 40 ? mainCard.mainNewsItem.summary.substring(0, 40) + "..." : mainCard.mainNewsItem.summary) : ""
                            font.pixelSize: 16
                            font.bold: true
                            color: "white"
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: mainCardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            console.log("主卡片被点击，打开 Flyout")
                            mainFlyout.open()
                        }
                    }

                    Flyout {
                        id: mainFlyout
                        parent: mainCard
                        width: 400
                        position: Position.Bottom

                        RowLayout {
                            spacing: 12
                            width: parent.width

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 100
                                radius: 8
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: mainCard.mainNewsItem ? mainCard.mainNewsItem.image : ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: mainCard.mainNewsItem ? mainCard.mainNewsItem.title : ""
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Utils.colors.textColor
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: mainCard.mainNewsItem ? mainCard.mainNewsItem.summary : ""
                                    font.pixelSize: 12
                                    color: Utils.colors.textSecondaryColor
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        buttonBox: [
                            Button {
                                text: qsTr("关闭")
                                onClicked: mainFlyout.close()
                            },
                            Button {
                                text: qsTr("播放")
                                highlighted: true
                                onClicked: {
                                    console.log("播放按钮被点击")
                                    var newsItem = mainCard.mainNewsItem
                                    console.log("新闻项:", newsItem ? "存在" : "不存在")
                                    if (newsItem) {
                                        console.log("视频ID:", newsItem.videoId)
                                        if (newsItem.videoId) {
                                            videoManager.parseVideo(newsItem.videoId, newsItem.title)
                                        } else {
                                            console.log("没有视频ID")
                                        }
                                    }
                                    mainFlyout.close()
                                }
                            }
                        ]
                    }
                }

                // 右侧 2x2 网格 - 使用API第2-5条新闻
                GridLayout {
                    Layout.fillWidth: !homePage.isCompact
                    Layout.fillHeight: true
                    Layout.preferredWidth: homePage.isCompact ? parent.width : parent.width * 0.45
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 12
                    visible: !homePage.isCompact && newsManager && newsManager.news ? newsManager.news.length > 1 : false

                    Repeater {
                        model: newsManager && newsManager.news ? Math.min(4, Math.max(0, newsManager.news.length - 1)) : 0

                        delegate: Rectangle {
                            id: gridCard
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8

                            // 动态计算新闻索引
                            // 如果第一条是完整版：卡片0显示完整版，卡片1-3显示新闻2-4
                            // 如果第一条不是完整版：卡片0显示新闻1（第二条），卡片1-3显示新闻2-4
                            property var newsItem: {
                                if (!newsManager || !newsManager.news) return null
                                var firstNews = newsManager.news[0]
                                var hasFullVersion = firstNews && firstNews.isFullVersion
                                
                                // 调试日志 - 只在index=0时打印一次
                                if (index === 0) {
                                    console.log("新闻总数:", newsManager.news.length)
                                    console.log("第一条新闻标题:", firstNews ? firstNews.title : "null")
                                    console.log("第一条是否完整版:", hasFullVersion)
                                    console.log("第一条isFullVersion值:", firstNews ? firstNews.isFullVersion : "null")
                                    // 打印前3条新闻的标题
                                    for (var i = 0; i < Math.min(3, newsManager.news.length); i++) {
                                        var news = newsManager.news[i]
                                        console.log("[" + i + "] " + (news ? news.title : "null") + " (完整版:" + (news ? news.isFullVersion : "null") + ")")
                                    }
                                }
                                
                                // 计算实际的新闻索引
                                // 有完整版时：主卡片显示news[1]，小卡片从news[0]开始
                                // 无完整版时：主卡片显示news[0]，小卡片从news[1]开始
                                var startIndex = hasFullVersion ? 0 : 1
                                var newsIndex = startIndex + index
                                
                                return newsManager.news.length > newsIndex ? newsManager.news[newsIndex] : null
                            }

                            Image {
                                id: gridNewsImage
                                anchors.fill: parent
                                source: newsItem ? newsItem.image : ""
                                fillMode: Image.PreserveAspectCrop
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: gridNewsImage.width
                                        height: gridNewsImage.height
                                        radius: 8
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.6; color: "transparent" }
                                    GradientStop { position: 1.0; color: Utils.colors.maskColor }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Utils.colors.textColor
                                opacity: gridMouseArea.containsMouse ? 0.2 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                spacing: 2

                                // 完整版显示特殊标识
                                Rectangle {
                                    visible: newsItem ? newsItem.isFullVersion : false
                                    color: Utils.colors.primaryColor
                                    radius: 3
                                    Layout.preferredWidth: fullVersionLabel.implicitWidth + 8
                                    Layout.preferredHeight: 16
                                    
                                    Text {
                                        id: fullVersionLabel
                                        anchors.centerIn: parent
                                        text: "完整版"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: Utils.colors.backgroundColor
                                    }
                                }

                                Text {
                                    text: newsItem ? (newsItem.title.length > 20 ? newsItem.title.substring(0, 20) + "..." : newsItem.title) : ""
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "white"
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // 普通新闻显示副标题，完整版显示时长
                                Text {
                                    text: {
                                        if (!newsItem) return ""
                                        if (newsItem.isFullVersion) {
                                            // 完整版显示时长
                                            return newsItem.length ? "时长: " + newsItem.length : "完整版节目"
                                        } else {
                                            // 普通新闻显示摘要
                                            return newsItem.summary.length > 20 ? newsItem.summary.substring(0, 20) + "..." : newsItem.summary
                                        }
                                    }
                                    font.pixelSize: 10
                                    color: newsItem && newsItem.isFullVersion ? Utils.colors.primaryColor : Utils.colors.textSecondaryColor
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: gridMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: gridFlyout.open()
                            }

                            Flyout {
                                id: gridFlyout
                                parent: parent
                                width: 360
                                position: Position.Top

                                RowLayout {
                                    spacing: 10
                                    width: parent.width

                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 85
                                        radius: 6
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: newsItem ? newsItem.image : ""
                                            fillMode: Image.PreserveAspectCrop
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        // 完整版显示标识
                                        Rectangle {
                                            visible: newsItem ? newsItem.isFullVersion : false
                                            color: Utils.colors.primaryColor
                                            radius: 3
                                            Layout.preferredWidth: flyoutFullVersionLabel.implicitWidth + 10
                                            Layout.preferredHeight: 20
                                            
                                            Text {
                                                id: flyoutFullVersionLabel
                                                anchors.centerIn: parent
                                                text: "完整版"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Utils.colors.backgroundColor
                                            }
                                        }

                                        Text {
                                            text: newsItem ? newsItem.title : ""
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Utils.colors.textColor
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: {
                                                if (!newsItem) return ""
                                                if (newsItem.isFullVersion) {
                                                    return "时长: " + (newsItem.length ? newsItem.length : "未知") + "\n本期节目的完整视频，包含所有新闻报道。"
                                                }
                                                return newsItem.summary
                                            }
                                            font.pixelSize: 11
                                            color: Utils.colors.textSecondaryColor
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 4
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                buttonBox: [
                                Button {
                                    text: qsTr("关闭")
                                    onClicked: gridFlyout.close()
                                },
                                Button {
                                    text: qsTr("播放")
                                    highlighted: true
                                    onClicked: {
                                        if (newsItem && newsItem.videoId) {
                                            videoManager.parseVideo(newsItem.videoId, newsItem.title)
                                        }
                                        gridFlyout.close()
                                    }
                                }
                            ]
                            }
                        }
                    }
                }
            }

            // 紧凑模式下的完整版卡片 + 其他新闻（只在屏幕较窄时显示）
            // 4张卡片等宽等高并排显示
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 12
                visible: homePage.isCompact && newsManager && newsManager.news && newsManager.news.length > 0 && newsManager.news[0].isFullVersion

                // 完整版卡片（第1张）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8

                    property var newsItem: newsManager && newsManager.news && newsManager.news.length > 0 ? newsManager.news[0] : null

                    Image {
                        id: compactCard1Image
                        anchors.fill: parent
                        source: parent.newsItem ? parent.newsItem.image : ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: compactCard1Image.width
                                height: compactCard1Image.height
                                radius: 8
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.6; color: "transparent" }
                            GradientStop { position: 1.0; color: Utils.colors.maskColor }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Utils.colors.textColor
                        opacity: compactCard1MouseArea.containsMouse ? 0.15 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    // 完整版标签
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 6
                        color: Utils.colors.primaryColor
                        radius: 3
                        width: compactCard1Label.implicitWidth + 8
                        height: 18
                        visible: parent.newsItem && parent.newsItem.isFullVersion

                        Text {
                            id: compactCard1Label
                            anchors.centerIn: parent
                            text: "完整版"
                            font.pixelSize: 9
                            font.bold: true
                            color: Utils.colors.backgroundColor
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        spacing: 2

                        Text {
                            text: parent.parent.newsItem ? (parent.parent.newsItem.title.length > 18 ? parent.parent.newsItem.title.substring(0, 18) + "..." : parent.parent.newsItem.title) : ""
                            font.pixelSize: 10
                            font.bold: true
                            color: "white"
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                                text: parent.parent.newsItem && parent.parent.newsItem.isFullVersion ? (parent.parent.newsItem.length ? "时长: " + parent.parent.newsItem.length : "完整版") : (parent.parent.newsItem ? (parent.parent.newsItem.summary.length > 20 ? parent.parent.newsItem.summary.substring(0, 20) + "..." : parent.parent.newsItem.summary) : "")
                                font.pixelSize: 9
                                color: parent.parent.newsItem && parent.parent.newsItem.isFullVersion ? Utils.colors.primaryColor : Utils.colors.textSecondaryColor
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                    }

                    MouseArea {
                        id: compactCard1MouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var item = parent.newsItem
                            console.log("紧凑模式卡片1被点击，新闻项:", item ? item.title : "null")
                            compactCard1Flyout.currentNewsItem = item
                            compactCard1Flyout.open()
                        }
                    }

                    Flyout {
                        id: compactCard1Flyout
                        parent: compactCard1MouseArea
                        width: 340
                        position: Position.Top
                        
                        property var currentNewsItem: null
                        
                        onOpened: {
                            console.log("紧凑模式卡片1 Flyout 已打开，当前新闻项:", currentNewsItem ? currentNewsItem.title : "null")
                        }

                        RowLayout {
                            spacing: 10
                            width: parent.width

                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 85
                                radius: 6
                                clip: true
                                color: Utils.colors.controlColor

                                Image {
                                    anchors.fill: parent
                                    source: compactCard1Flyout.currentNewsItem && compactCard1Flyout.currentNewsItem.image ? compactCard1Flyout.currentNewsItem.image : ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 85
                                spacing: 4

                                Rectangle {
                                    visible: compactCard1Flyout.currentNewsItem && compactCard1Flyout.currentNewsItem.isFullVersion
                                    color: Utils.colors.primaryColor
                                    radius: 3
                                    Layout.preferredWidth: compactCard1FlyoutLabel.implicitWidth + 10
                                    Layout.preferredHeight: 20

                                    Text {
                                        id: compactCard1FlyoutLabel
                                        anchors.centerIn: parent
                                        text: "完整版"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: Utils.colors.backgroundColor
                                    }
                                }

                                Text {
                                    text: compactCard1Flyout.currentNewsItem && compactCard1Flyout.currentNewsItem.title ? compactCard1Flyout.currentNewsItem.title : "无标题"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Utils.colors.textColor
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: compactCard1Flyout.currentNewsItem ? (compactCard1Flyout.currentNewsItem.isFullVersion ? "时长: " + (compactCard1Flyout.currentNewsItem.length ? compactCard1Flyout.currentNewsItem.length : "未知") + "\n本期节目的完整视频，包含所有新闻报道。" : compactCard1Flyout.currentNewsItem.summary) : ""
                                    font.pixelSize: 11
                                    color: Utils.colors.textSecondaryColor
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        buttonBox: [
                            Button {
                                text: qsTr("关闭")
                                onClicked: compactCard1Flyout.close()
                            },
                            Button {
                                text: qsTr("播放")
                                highlighted: true
                                onClicked: {
                                    var item = compactCard1Flyout.currentNewsItem
                                    console.log("播放按钮被点击，新闻项:", item ? item.title : "null")
                                    if (item && item.videoId) {
                                        videoManager.parseVideo(item.videoId, item.title)
                                    } else {
                                        console.log("没有视频ID，无法播放")
                                    }
                                    compactCard1Flyout.close()
                                }
                            }
                        ]
                    }
                }

                // 其他新闻卡片（第2-4张）
                Repeater {
                    model: newsManager && newsManager.news ? Math.min(3, Math.max(0, newsManager.news.length - 1)) : 0

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8

                        property var newsItem: newsManager && newsManager.news && newsManager.news.length > index + 1 ? newsManager.news[index + 1] : null

                        Image {
                            id: compactCardImage
                            anchors.fill: parent
                            source: parent.newsItem ? parent.newsItem.image : ""
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: compactCardImage.width
                                    height: compactCardImage.height
                                    radius: 8
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.6; color: "transparent" }
                                GradientStop { position: 1.0; color: Utils.colors.maskColor }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Utils.colors.textColor
                            opacity: compactCardMouseArea.containsMouse ? 0.15 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            spacing: 2

                            Text {
                                text: parent.parent.newsItem ? (parent.parent.newsItem.title.length > 18 ? parent.parent.newsItem.title.substring(0, 18) + "..." : parent.parent.newsItem.title) : ""
                                font.pixelSize: 10
                                font.bold: true
                                color: "white"
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: parent.parent.newsItem ? (parent.parent.newsItem.summary.length > 20 ? parent.parent.newsItem.summary.substring(0, 20) + "..." : parent.parent.newsItem.summary) : ""
                                font.pixelSize: 9
                                color: "#CCCCCC"
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: compactCardMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("紧凑模式小卡片被点击，新闻项:", newsItem ? newsItem.title : "null")
                                compactCardFlyout.currentNewsItem = newsItem
                                compactCardFlyout.open()
                            }
                        }

                        Flyout {
                            id: compactCardFlyout
                            parent: compactCardMouseArea
                            width: 340
                            position: Position.Top
                            
                            property var currentNewsItem: null
                            
                            onOpened: {
                                console.log("紧凑模式 Flyout 已打开，当前新闻项:", currentNewsItem ? currentNewsItem.title : "null")
                            }

                            RowLayout {
                                spacing: 10
                                width: parent.width

                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: 85
                                    radius: 6
                                    clip: true
                                    color: Utils.colors.controlColor

                                    Image {
                                        anchors.fill: parent
                                        source: compactCardFlyout.currentNewsItem && compactCardFlyout.currentNewsItem.image ? compactCardFlyout.currentNewsItem.image : ""
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 85
                                    spacing: 4

                                    Text {
                                        text: compactCardFlyout.currentNewsItem && compactCardFlyout.currentNewsItem.title ? compactCardFlyout.currentNewsItem.title : "无标题"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: Utils.colors.textColor
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: compactCardFlyout.currentNewsItem && compactCardFlyout.currentNewsItem.summary ? compactCardFlyout.currentNewsItem.summary : ""
                                        font.pixelSize: 11
                                        color: Utils.colors.textSecondaryColor
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            buttonBox: [
                                Button {
                                    text: qsTr("关闭")
                                    onClicked: compactCardFlyout.close()
                                },
                                Button {
                                    text: qsTr("播放")
                                    highlighted: true
                                    onClicked: {
                                        var item = compactCardFlyout.currentNewsItem
                                        console.log("播放按钮被点击，新闻项:", item ? item.title : "null")
                                        if (item && item.videoId) {
                                            videoManager.parseVideo(item.videoId, item.title)
                                        } else {
                                            console.log("没有视频ID，无法播放")
                                        }
                                        compactCardFlyout.close()
                                    }
                                }
                            ]
                        }
                    }
                }
            }

            // 间距项 - 在紧凑模式下添加一些空间
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: homePage.isCompact ? 16 : 0
                visible: homePage.isCompact
            }

            // 第三行：底部卡片 - 使用API第6-9条新闻
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: homePage.isCompact ? 400 : 200
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                columns: homePage.isCompact ? 2 : 4
                rowSpacing: 12
                columnSpacing: 12
                visible: newsManager && newsManager.news ? newsManager.news.length > 5 : false

                Repeater {
                    model: newsManager && newsManager.news ? Math.min(4, Math.max(0, newsManager.news.length - 5)) : 0

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Utils.colors.controlColor
                        radius: 8

                        property var newsItem: newsManager && newsManager.news ? newsManager.news[index + 5] : null

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Utils.colors.textColor
                            opacity: bottomCardMouseArea.containsMouse ? 0.1 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 4

                                Image {
                                    id: bottomCardImage
                                    anchors.fill: parent
                                    source: newsItem ? newsItem.image : ""
                                    fillMode: Image.PreserveAspectCrop
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: bottomCardImage.width
                                            height: bottomCardImage.height
                                            radius: 4
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: newsItem ? (newsItem.title.length > 15 ? newsItem.title.substring(0, 15) + "..." : newsItem.title) : ""
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Utils.colors.textColor
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: newsItem ? (newsItem.summary.length > 25 ? newsItem.summary.substring(0, 25) + "..." : newsItem.summary) : ""
                                    font.pixelSize: 11
                                    color: Utils.colors.textSecondaryColor
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            id: bottomCardMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("底部卡片被点击，新闻项:", newsItem ? newsItem.title : "null")
                                bottomFlyout.currentNewsItem = newsItem
                                bottomFlyout.open()
                            }
                        }

                        Flyout {
                            id: bottomFlyout
                            parent: bottomCardMouseArea
                            width: 360
                            position: Position.Top
                            
                            property var currentNewsItem: null
                            
                            onOpened: {
                                console.log("底部卡片 Flyout 已打开，当前新闻项:", currentNewsItem ? currentNewsItem.title : "null")
                            }

                            RowLayout {
                                spacing: 10
                                width: parent.width

                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: 85
                                    radius: 6
                                    clip: true
                                    color: Utils.colors.controlColor

                                    Image {
                                        anchors.fill: parent
                                        source: bottomFlyout.currentNewsItem && bottomFlyout.currentNewsItem.image ? bottomFlyout.currentNewsItem.image : ""
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 85
                                    spacing: 4

                                    Text {
                                        text: bottomFlyout.currentNewsItem && bottomFlyout.currentNewsItem.title ? bottomFlyout.currentNewsItem.title : "无标题"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: Utils.colors.textColor
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: bottomFlyout.currentNewsItem && bottomFlyout.currentNewsItem.summary ? bottomFlyout.currentNewsItem.summary : ""
                                        font.pixelSize: 11
                                        color: Utils.colors.textSecondaryColor
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            buttonBox: [
                                Button {
                                    text: qsTr("关闭")
                                    onClicked: bottomFlyout.close()
                                },
                                Button {
                                    text: qsTr("播放")
                                    highlighted: true
                                    onClicked: {
                                        var item = bottomFlyout.currentNewsItem
                                        console.log("播放按钮被点击，新闻项:", item ? item.title : "null")
                                        if (item && item.videoId) {
                                            videoManager.parseVideo(item.videoId, item.title)
                                        } else {
                                            console.log("没有视频ID，无法播放")
                                        }
                                        bottomFlyout.close()
                                    }
                                }
                            ]
                        }
                    }
                }
            }

            // 更多新闻区域
            Text {
                text: qsTr("更多新闻")
                font.pixelSize: 18
                font.bold: true
                color: Utils.colors.textColor
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 16
                visible: newsManager && newsManager.news ? newsManager.news.length > 9 : false
            }

            // 更多新闻网格 - 使用API第10条以后的新闻
            GridLayout {
                id: newsGrid
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                columns: {
                    var minCardWidth = 260
                    var availableWidth = homePage.width - 32
                    var cols = Math.floor(availableWidth / minCardWidth)
                    return Math.max(1, Math.min(cols, 4))
                }
                rowSpacing: 12
                columnSpacing: 12
                visible: newsManager && newsManager.news ? newsManager.news.length > 9 : false

                Repeater {
                    model: newsManager && newsManager.news ? Math.max(0, newsManager.news.length - 9) : 0

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        color: Utils.colors.controlColor
                        radius: 8

                        property var newsItem: newsManager && newsManager.news ? newsManager.news[index + 9] : null

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Utils.colors.textColor
                            opacity: newsCardMouseArea.containsMouse ? 0.1 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 4

                                Image {
                                    id: newsCardImage
                                    anchors.fill: parent
                                    source: newsItem ? newsItem.image : ""
                                    fillMode: Image.PreserveAspectCrop
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: newsCardImage.width
                                            height: newsCardImage.height
                                            radius: 4
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: newsItem ? (newsItem.title.length > 18 ? newsItem.title.substring(0, 18) + "..." : newsItem.title) : ""
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Utils.colors.textColor
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: newsItem ? (newsItem.summary.length > 30 ? newsItem.summary.substring(0, 30) + "..." : newsItem.summary) : ""
                                    font.pixelSize: 11
                                    color: Utils.colors.textSecondaryColor
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            id: newsCardMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("小卡片被点击，新闻项:", newsItem ? newsItem.title : "null")
                                moreNewsFlyout.currentNewsItem = newsItem
                                moreNewsFlyout.open()
                            }
                        }

                        Flyout {
                            id: moreNewsFlyout
                            parent: newsCardMouseArea
                            width: 360
                            position: Position.Top
                            
                            property var currentNewsItem: null
                            
                            onOpened: {
                                console.log("Flyout 已打开，当前新闻项:", currentNewsItem ? currentNewsItem.title : "null")
                            }

                            RowLayout {
                                spacing: 10
                                width: parent.width

                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: 85
                                    radius: 6
                                    clip: true
                                    color: Utils.colors.controlColor

                                    Image {
                                        anchors.fill: parent
                                        source: moreNewsFlyout.currentNewsItem && moreNewsFlyout.currentNewsItem.image ? moreNewsFlyout.currentNewsItem.image : ""
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 85
                                    spacing: 4

                                    Text {
                                        text: moreNewsFlyout.currentNewsItem && moreNewsFlyout.currentNewsItem.title ? moreNewsFlyout.currentNewsItem.title : "无标题"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: Utils.colors.textColor
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: moreNewsFlyout.currentNewsItem && moreNewsFlyout.currentNewsItem.summary ? moreNewsFlyout.currentNewsItem.summary : ""
                                        font.pixelSize: 11
                                        color: Utils.colors.textSecondaryColor
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            buttonBox: [
                                Button {
                                    text: qsTr("关闭")
                                    onClicked: moreNewsFlyout.close()
                                },
                                Button {
                                    text: qsTr("播放")
                                    highlighted: true
                                    onClicked: {
                                        console.log("播放按钮被点击")
                                        var item = moreNewsFlyout.currentNewsItem
                                        console.log("当前新闻项:", item ? item.title : "null")
                                        if (item && item.videoId) {
                                            videoManager.parseVideo(item.videoId, item.title)
                                        } else {
                                            console.log("没有视频ID，无法播放")
                                        }
                                        moreNewsFlyout.close()
                                    }
                                }
                            ]
                        }
                    }
                }
            }

            // 底部填充
            Item {
                height: 16
            }
        }
    }


}
