import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtMultimedia
import RinUI

FluentWindow {
    id: audioPlayerWindow
    title: qsTr("音频播放器")
    width: 480
    height: 360
    minimumWidth: 400
    minimumHeight: 320
    visible: true
    titleBarHeight: 48

    icon: Qt.resolvedUrl("../assets/video.png")

    // 虚拟导航项，确保 NavigationView 正确初始化
    navigationItems: [
        {
            title: qsTr("音频"),
            page: "",
            icon: "ic_fluent_speaker_20_regular"
        }
    ]

    color: Utils.colors.backgroundColor

    // 主窗口引用
    property var mainWindow: null

    // 关闭时发出信号
    signal windowClosed()

    onClosing: {
        console.log("音频播放器窗口正在关闭，停止播放")
        audioPlayer.stop()
        audioPlayerWindow.windowClosed()
    }

    // 播放状态属性
    property url audioSource: ""
    property string audioTitle: qsTr("音频播放")
    property bool isPlaying: false

    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {
            id: audioOutput
            volume: volumeSlider.value / 100
        }
        onPlaybackStateChanged: function(state) {
            audioPlayerWindow.isPlaying = (state === MediaPlayer.PlayingState)
        }
        onMediaStatusChanged: function(status) {
            // 播放结束自动停止并归零
            if (status === MediaPlayer.EndOfMedia) {
                audioPlayer.position = 0
            }
        }
        onErrorOccurred: function(error, errorString) {
            console.error("音频播放错误:", errorString)
        }
    }

    // 加载音频
    function loadAudio(source, title, options) {
        options = options || {}
        console.log("========== 加载音频 ==========")
        console.log("  title:", title)
        console.log("  source:", source)
        audioPlayerWindow.audioSource = source
        audioPlayerWindow.audioTitle = title || qsTr("音频播放")
        audioPlayer.source = source
        audioPlayer.play()
    }

    // 时间格式化：毫秒 -> mm:ss
    function formatTime(ms) {
        var totalSeconds = Math.floor(ms / 1000)
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 封面占位：圆形渐变 + 音符图标
            Rectangle {
                anchors.centerIn: parent
                width: 120
                height: 120
                radius: 60
                color: Utils.colors.layerColor

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.pixelSize: 56
                    font.family: "FluentSystemIcons"
                    color: Utils.colors.textSecondaryColor
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: audioPlayerWindow.audioTitle
            font.pixelSize: 16
            font.bold: true
            color: Utils.colors.textColor
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }

        // 进度条
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: formatTime(audioPlayer.position)
                font.pixelSize: 12
                color: Utils.colors.textSecondaryColor
            }

            Slider {
                id: progressSlider
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, audioPlayer.duration)
                value: audioPlayer.position
                enabled: audioPlayer.duration > 0
                onMoved: function(value) {
                    audioPlayer.position = value
                }
            }

            Text {
                text: formatTime(audioPlayer.duration)
                font.pixelSize: 12
                color: Utils.colors.textSecondaryColor
            }
        }

        // 控制栏
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24

            Button {
                display: AbstractButton.IconOnly
                icon.name: "ic_fluent_previous_20_regular"
                onClicked: {
                    audioPlayer.position = 0
                }
            }

            Button {
                display: AbstractButton.IconOnly
                highlighted: true
                icon.name: audioPlayerWindow.isPlaying
                           ? "ic_fluent_pause_20_regular"
                           : "ic_fluent_play_20_regular"
                onClicked: {
                    if (audioPlayerWindow.isPlaying) {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                }
            }

            // 音量
            RowLayout {
                spacing: 4
                Text {
                    text: ""
                    font.pixelSize: 16
                    font.family: "FluentSystemIcons"
                    color: Utils.colors.textSecondaryColor
                }
                Slider {
                    id: volumeSlider
                    from: 0
                    to: 100
                    value: 80
                    Layout.preferredWidth: 100
                }
            }
        }
    }
}
