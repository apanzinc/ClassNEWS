import QtQuick
import QtQuick.Controls
import RinUI

// 微软 Fluent Design 风格的圆形进度环
Rectangle {
    id: root
    color: "transparent"
    visible: running

    property bool running: true
    property int size: 64
    property color ringColor: Utils.colors.primaryColor

    width: size
    height: size

    // 旋转的圆环
    Canvas {
        id: ringCanvas
        anchors.fill: parent
        antialiasing: true
        smooth: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var centerX = width / 2
            var centerY = height / 2
            var radius = (Math.min(width, height) - 4) / 2
            var lineWidth = 4

            // 绘制背景圆环（浅色）
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
            ctx.strokeStyle = Qt.rgba(root.ringColor.r, root.ringColor.g, root.ringColor.b, 0.15)
            ctx.lineWidth = lineWidth
            ctx.lineCap = "round"
            ctx.stroke()

            // 绘制进度弧（75%圆弧）
            ctx.beginPath()
            var startAngle = -Math.PI / 2
            var endAngle = startAngle + (2 * Math.PI * 0.75)
            ctx.arc(centerX, centerY, radius, startAngle, endAngle)
            ctx.strokeStyle = root.ringColor
            ctx.lineWidth = lineWidth
            ctx.lineCap = "round"
            ctx.stroke()
        }

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
            running: root.running
        }
    }
}
