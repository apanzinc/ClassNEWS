import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import RinUI

// 视频播放提示窗口 - 使用 FluentWindowBase（无导航栏）
FluentWindowBase {
    id: notificationWindow
    width: 420
    height: 200
    minimumWidth: 420
    minimumHeight: 200
    maximumWidth: 420
    maximumHeight: 200
    title: "ClassNEWS"
    visible: false
    titleBarHeight: 48  // 与主窗口一致

    // 禁用最大化按钮
    maximizeEnabled: false

    // 窗口背景色（与标题栏区分）
    color: Utils.colors.backgroundColor

    // 目标窗口 - 用于定位
    property var targetWindow: null

    // 自定义属性
    property string newsTitle: ""
    property int countdownSeconds: 5
    property string pid: ""
    property var options: null
    property bool isError: false
    property string errorMessage: ""

    // 信号
    signal playNow()
    signal delayOneMinute()
    signal windowClosed()
    signal retryPlay()

    // 显示时居中并启动倒计时
    onVisibleChanged: {
        if (visible) {
            // 居中显示在目标窗口上
            if (targetWindow) {
                x = targetWindow.x + (targetWindow.width - width) / 2
                y = targetWindow.y + (targetWindow.height - height) / 2
            }
            // 错误模式下不启动倒计时，其他模式都启动
            if (!isError) {
                countdownSeconds = 5
                countdownTimer.start()
            }
        } else {
            countdownTimer.stop()
        }
    }

    // 关闭处理
    onClosing: function(close) {
        countdownTimer.stop()
        notificationWindow.windowClosed()
    }

    // 内容区域背景（与标题栏颜色一致）
    Rectangle {
        anchors.fill: parent
        color: Utils.colors.backgroundColor

        // 倒计时定时器
        Timer {
            id: countdownTimer
            interval: 1000
            repeat: true
            onTriggered: {
                if (countdownSeconds > 1) {
                    countdownSeconds--
                } else {
                    countdownTimer.stop()
                    notificationWindow.playNow()
                    notificationWindow.close()
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // 标题行：包含标题文本
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // 标题文本
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: newsTitle
                        font.pixelSize: 14
                        font.bold: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        horizontalAlignment: Text.AlignLeft
                        color: Utils.colors.textColor
                    }

                    // 时长信息
                    Text {
                        text: notificationWindow.options && notificationWindow.options.duration ? 
                              qsTr("时长：%1").arg(notificationWindow.options.duration) : ""
                        font.pixelSize: 11
                        color: Utils.colors.textSecondaryColor
                    }
                }
            }

            // 副标题：倒计时提示
            Text {
                Layout.fillWidth: true
                text: notificationWindow.isError ?
                      qsTr("播放失败：%1").arg(notificationWindow.errorMessage) :
                      qsTr("将在 %1 秒后自动播放").arg(countdownSeconds)
                font.pixelSize: 12
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                horizontalAlignment: Text.AlignLeft
                color: notificationWindow.isError ? "#E81123" : Utils.colors.textColor
            }

            // 进度条（错误模式下不显示）
            ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: 5
                value: 5 - countdownSeconds
                visible: !notificationWindow.isError
            }

            // 弹性空间 - 确保按钮有足够空间
            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 8
            }

            // 按钮区域
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: notificationWindow.isError ? qsTr("关闭") : qsTr("延后一分钟")
                    flat: true
                    onClicked: {
                        countdownTimer.stop()
                        if (notificationWindow.isError) {
                            notificationWindow.close()
                        } else {
                            notificationWindow.delayOneMinute()
                            notificationWindow.close()
                        }
                    }
                }

                Button {
                    text: notificationWindow.isError ? qsTr("重试") : qsTr("立即播放")
                    highlighted: true
                    onClicked: {
                        countdownTimer.stop()
                        if (notificationWindow.isError) {
                            notificationWindow.retryPlay()
                        } else {
                            notificationWindow.playNow()
                        }
                        notificationWindow.close()
                    }
                }
            }
        }
    }
}
