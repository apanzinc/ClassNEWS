import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import RinUI

// 视频播放提示窗口 - 使用 FluentWindowBase（无导航栏）
FluentWindowBase {
    id: notificationWindow
    width: 400
    height: 220
    minimumWidth: 400
    minimumHeight: 220
    maximumWidth: 400
    maximumHeight: 220
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
            anchors.margins: 20
            spacing: 12

            // 大标题：新闻名称（居左），限制最多显示20个字符
            Text {
                Layout.fillWidth: true
                text: {
                    var maxLength = 20;
                    if (newsTitle.length > maxLength) {
                        return newsTitle.substring(0, maxLength) + "...";
                    }
                    return newsTitle;
                }
                font.pixelSize: 20
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft  // 居左
                color: Utils.colors.textColor
            }

            // 副标题：倒计时提示（居左）
            Text {
                Layout.fillWidth: true
                text: notificationWindow.isError ?
                      qsTr("播放失败: %1").arg(notificationWindow.errorMessage) :
                      qsTr("将在 %1 秒后自动播放").arg(countdownSeconds)
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft  // 居左
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

            // 弹性空间
            Item {
                Layout.fillHeight: true
            }

            // 按钮区域
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 8

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
