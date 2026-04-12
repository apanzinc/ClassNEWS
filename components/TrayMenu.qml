import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import RinUI

Window {
    id: trayMenuWindow
    
    // 窗口属性 - 不使用透明背景
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "#FFFFFF"  // 使用白色背景，不透明
    width: 200
    height: contentLayout.implicitHeight + 16
    
    // 属性
    property var trayManager: null
    property bool isDarkTheme: ThemeManager.get_theme() === "Dark"
    
    // 信号
    signal showWindowRequested()
    signal quitRequested()
    
    // 根据主题更新窗口颜色
    onIsDarkThemeChanged: {
        color = isDarkTheme ? "#2D2D2D" : "#FFFFFF"
    }
    
    // 初始化颜色
    Component.onCompleted: {
        color = isDarkTheme ? "#2D2D2D" : "#FFFFFF"
    }
    
    // 主题颜色
    QtObject {
        id: colors
        property color backgroundColor: isDarkTheme ? "#2D2D2D" : "#FFFFFF"
        property color borderColor: isDarkTheme ? "#3D3D3D" : "#E5E5E5"
        property color textColor: isDarkTheme ? "#FFFFFF" : "#1A1A1A"
        property color textSecondaryColor: isDarkTheme ? "#A0A0A0" : "#666666"
        property color hoverColor: isDarkTheme ? "#3D3D3D" : "#F5F5F5"
        property color accentColor: "#0078D4"
    }
    
    // 边框和圆角
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 8
        border.color: colors.borderColor
        border.width: 1
        
        // 内容
        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            
            // 标题
            Text {
                Layout.fillWidth: true
                text: "ClassNEWS"
                font.pixelSize: 14
                font.bold: true
                color: colors.textColor
                horizontalAlignment: Text.AlignHCenter
                topPadding: 4
                bottomPadding: 8
            }
            
            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: colors.borderColor
            }
            
            // 显示主界面按钮
            TrayMenuItem {
                Layout.fillWidth: true
                text: "显示主界面"
                iconName: "ic_fluent_home_20_regular"
                textColor: colors.textColor
                hoverColor: colors.hoverColor
                onClicked: {
                    showWindowRequested()
                    trayMenuWindow.close()
                }
            }
            
            // 设置按钮
            TrayMenuItem {
                Layout.fillWidth: true
                text: "设置"
                iconName: "ic_fluent_settings_20_regular"
                textColor: colors.textColor
                hoverColor: colors.hoverColor
                onClicked: {
                    showWindowRequested()
                    // 发送信号通知主窗口切换到设置页面
                    if (trayManager !== null) {
                        trayManager.navigateToSettings()
                    }
                    trayMenuWindow.close()
                }
            }
            
            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                height: 1
                color: colors.borderColor
            }
            
            // 退出按钮
            TrayMenuItem {
                Layout.fillWidth: true
                text: "退出"
                iconName: "ic_fluent_sign_out_20_regular"
                textColor: "#E74C3C"
                hoverColor: isDarkTheme ? "#3D2D2D" : "#FDF2F2"
                onClicked: {
                    quitRequested()
                    trayMenuWindow.close()
                }
            }
        }
    }
    
    // 显示菜单
    function showAt(x, y) {
        trayMenuWindow.x = x - width / 2
        trayMenuWindow.y = y - height - 8
        trayMenuWindow.show()
        trayMenuWindow.raise()
        trayMenuWindow.requestActivate()
    }
}
