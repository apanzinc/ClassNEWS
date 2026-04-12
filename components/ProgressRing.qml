import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Controls.Basic
import RinUI

// 微软 Fluent Design 风格的圆形进度环
// 支持三种状态：运行（蓝色）、暂停（黄色）、错误（红色）
QQC.ProgressBar {
    id: root
    
    // 定义三种状态
    enum State {
        Running,  // 运行中（蓝色）
        Paused,   // 暂停（黄色）
        Error     // 错误（红色）
    }
    
    // 核心属性
    property int size: 56           // 圆环尺寸
    property real strokeWidth: 4    // 圆环线条宽度
    property color ringColor: Utils.colors.primaryColor  // 主色调（蓝色）- 公开属性
    property color backgroundColor: "transparent"  // 背景色
    property int state: ProgressRing.State.Running  // 当前状态
    
    // 内部属性
    property real radius: (Math.min(width, height) - strokeWidth) / 2  // 自动计算半径
    property color _ringColor: {
        // 根据状态切换颜色（优先级高于 ringColor）
        if (state === ProgressRing.State.Paused) {
            return "#FFC107"  // 黄色 - 暂停/缓冲
        } else if (state === ProgressRing.State.Error) {
            return "#E81123"  // 红色 - 错误
        } else {
            return ringColor  // 使用 ringColor 属性（蓝色 - 运行中）
        }
    }
    
    // 进度值（0-1）
    property real _progress: indeterminate ? 0 : value
    
    // 尺寸设置
    width: size
    height: size
    from: 0
    to: 1
    value: 0
    
    // 不定模式（无限旋转）
    property bool indeterminate: true
    
    // 背景圆环
    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: size / 2
    }
    
    // 使用 Canvas 绘制圆环
    Canvas {
        id: ringCanvas
        anchors.fill: parent
        antialiasing: true
        smooth: true
        
        // 旋转动画（用于不定模式）
        property real rotationAngle: 0
        
        SequentialAnimation on rotationAngle {
            running: root.indeterminate && root.state === ProgressRing.State.Running
            loops: Animation.Infinite
            
            PropertyAnimation {
                from: 0
                to: 450
                duration: 666
                easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                from: 450
                to: 1080
                duration: 666
                easing.type: Easing.InOutQuad
            }
        }
        
        // 进度变化动画
        Behavior on _progress {
            NumberAnimation {
                duration: Utils.appearance.animationSpeed || 300
                easing.type: Easing.InOutQuad
            }
        }
        
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            var centerX = width / 2
            var centerY = height / 2
            var currentRadius = root.radius
            var currentLineWidth = root.strokeWidth
            
            // 计算起始和结束角度
            var startAngle = -Math.PI / 2  // 从顶部开始
            var sweepAngle = 0
            
            if (root.indeterminate) {
                // 不定模式：显示 75% 圆弧并旋转
                sweepAngle = 2 * Math.PI * 0.75
                startAngle = ringCanvas.rotationAngle * Math.PI / 180 - Math.PI / 2
            } else {
                // 定值模式：根据进度显示
                sweepAngle = 2 * Math.PI * _progress
            }
            
            // 绘制背景圆环（灰色/透明）
            ctx.beginPath()
            ctx.arc(centerX, centerY, currentRadius, 0, 2 * Math.PI)
            ctx.strokeStyle = Qt.ringa(_ringColor.r, _ringColor.g, _ringColor.b, 0.15)
            ctx.lineWidth = currentLineWidth
            ctx.lineCap = "round"
            ctx.stroke()
            
            // 绘制前景进度圆环（彩色）
            if (sweepAngle > 0) {
                ctx.beginPath()
                var endAngle = startAngle + sweepAngle
                
                if (root.indeterminate) {
                    // 不定模式：绘制圆弧
                    ctx.arc(centerX, centerY, currentRadius, startAngle, endAngle)
                } else {
                    // 定值模式：从顶部开始绘制
                    ctx.arc(centerX, centerY, currentRadius, -Math.PI / 2, -Math.PI / 2 + sweepAngle)
                }
                
                ctx.strokeStyle = _ringColor
                ctx.lineWidth = currentLineWidth
                ctx.lineCap = "round"
                ctx.stroke()
            }
        }
    }
    
    // 状态变化时的动画
    Behavior on _ringColor {
        ColorAnimation {
            duration: Utils.appearance.animationSpeed || 300
            easing.type: Easing.InOutQuad
        }
    }
}
