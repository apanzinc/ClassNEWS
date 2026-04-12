import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import RinUI

// 视频播放提示对话框 - 使用 RinUI Dialog，符合 Fluent 2 设计规范
Dialog {
    id: dialog
    modal: true
    title: qsTr("即将播放新闻")
    width: 420
    height: 200
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose  // 禁止点击外部关闭

    // 自定义属性
    property string newsTitle: ""
    property int countdownSeconds: 5
    property string pid: ""
    property var options: null

    // 信号
    signal playNow()
    signal delayOneMinute()
    signal dialogClosed()

    // 倒计时定时器
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: dialog.visible
        onTriggered: {
            if (countdownSeconds > 1) {
                countdownSeconds--
            } else {
                countdownTimer.stop()
                dialog.playNow()
                dialog.close()
            }
        }
    }

    // 打开时重置倒计时
    onOpened: {
        countdownSeconds = 5
    }

    // 关闭处理
    onClosed: {
        countdownTimer.stop()
        dialog.dialogClosed()
    }

    // 内容区域
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 提示文本
        Text {
            Layout.fillWidth: true
            text: qsTr("新闻《%1》将在 %2 秒后自动播放").arg(newsTitle).arg(countdownSeconds)
            font.pixelSize: 14
            color: Utils.colors.textColor
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        // 进度条 - 显示倒计时进度
        ProgressBar {
            Layout.fillWidth: true
            from: 0
            to: 5
            value: 5 - countdownSeconds
        }

        // 弹性空间
        Item {
            Layout.fillHeight: true
        }
    }

    // 自定义按钮区域
    footer: RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignRight
        spacing: 8

        // 延后一分钟按钮
        Button {
            text: qsTr("延后一分钟")
            flat: true
            onClicked: {
                countdownTimer.stop()
                dialog.delayOneMinute()
                dialog.close()
            }
        }

        // 立即播放按钮
        Button {
            text: qsTr("立即播放")
            highlighted: true
            onClicked: {
                countdownTimer.stop()
                dialog.playNow()
                dialog.close()
            }
        }
    }
}
