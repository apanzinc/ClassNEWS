import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import RinUI

FluentPage {
    id: root
    title: qsTr("插件")

    // 插件详情弹窗
    Dialog {
        id: pluginDetailDialog
        title: detailPlugin ? detailPlugin.name : ""
        standardButtons: Dialog.Ok
        modal: true
        anchors.centerIn: parent

        ColumnLayout {
            spacing: 12

            GridLayout {
                columns: 2
                columnSpacing: 16
                rowSpacing: 8

                Text { text: qsTr("插件ID:"); font.bold: true }
                Text { text: detailPlugin ? detailPlugin.pluginId : "" }

                Text { text: qsTr("版本:"); font.bold: true }
                Text { text: detailPlugin ? (detailPlugin.version || "未知") : "" }

                Text { text: qsTr("作者:"); font.bold: true }
                Text { text: detailPlugin ? (detailPlugin.author || "未知") : "" }

                Text { text: qsTr("类型:"); font.bold: true }
                Text { text: detailPlugin ? (detailPlugin.builtin ? qsTr("内置") : qsTr("用户")) : "" }

                Text { text: qsTr("API版本:"); font.bold: true }
                Text { text: detailPlugin ? (detailPlugin.apiVersion || "未知") : "" }

                Text { text: qsTr("兼容性:"); font.bold: true }
                Text {
                    text: detailPlugin ? (detailPlugin.compatible === false ? qsTr("不兼容") : qsTr("兼容")) : ""
                    color: detailPlugin && detailPlugin.compatible === false ? Colors.proxy.systemErrorColor : Colors.proxy.textColor
                }
            }

            Text {
                text: qsTr("描述:")
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: detailPlugin ? (detailPlugin.description || qsTr("无描述")) : ""
                wrapMode: Text.WordWrap
                color: Colors.proxy.textSecondaryColor
            }

            Text {
                text: qsTr("目录:")
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: detailPlugin ? detailPlugin.directory : ""
                wrapMode: Text.WrapAnywhere
                font.pointSize: 9
                color: Colors.proxy.textSecondaryColor
            }
        }
    }

    property var detailPlugin: null

    InfoBar {
        Layout.fillWidth: true
        title: qsTr("警告")
        text: qsTr("插件系统仍在开发中，部分功能可能不稳定。")
        severity: Severity.Warning
    }

    // 插件统计信息
    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Text {
            text: qsTr("共 %1 个插件").arg(pluginManager ? pluginManager.plugins.length : 0)
            color: Colors.proxy.textSecondaryColor
            font.pointSize: 12
        }

        Text {
            text: qsTr("已启用 %1").arg(pluginManager ? pluginManager.plugins.filter(p => p.enabled).length : 0)
            color: Colors.proxy.textSecondaryColor
            font.pointSize: 12
        }

        Text {
            text: qsTr("用户插件 %1").arg(pluginManager ? pluginManager.plugins.filter(p => !p.builtin).length : 0)
            color: Colors.proxy.textSecondaryColor
            font.pointSize: 12
        }
    }

    function uninstallPlugin(pluginId) {
        if (pluginManager.uninstallPlugin(pluginId)) {
            showInfoBar(qsTr("卸载成功"), qsTr("插件已卸载，重启后生效。"), Severity.Success, 5000)
        } else {
            showInfoBar(qsTr("卸载失败"), qsTr("无法卸载插件，请稍后重试。"), Severity.Error, 5000)
        }
    }

    function showInfoBar(title, message, severity, duration) {
        if (root.Window.window && root.Window.window.showInfoBar) {
            root.Window.window.showInfoBar(title, message, severity, duration || 3000, true)
        }
    }

    function showPluginDetail(plugin) {
        detailPlugin = plugin
        pluginDetailDialog.open()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            typography: Typography.BodyStrong
            text: qsTr("您的插件")
            color: Colors.proxy.textColor
        }

        SettingCard {
            Layout.fillWidth: true
            title: qsTr("获取插件")
            description: qsTr("在「插件广场」(网页)中查找和安装插件")

            Hyperlink {
                text: qsTr("前往「插件广场」")
                enabled: false
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            TextField {
                Layout.maximumWidth: 300
                Layout.fillWidth: true
                id: searchField
                placeholderText: qsTr("搜索插件")
            }

            Item { Layout.fillWidth: true }

            Connections {
                target: pluginManager

                function onPluginListChanged() {
                    // 列表已更新
                }
            }

            // 导入状态反馈
            Connections {
                target: pluginManager

                function onPluginImportSucceeded() {
                    showInfoBar(qsTr("导入成功"), qsTr("插件导入成功。"), Severity.Success, 5000)
                }

                function onPluginImportFailed(msg) {
                    showInfoBar(qsTr("导入失败"), qsTr("插件导入失败：") + msg, Severity.Error, 5000)
                }

                function onPluginReloadSucceeded(pluginId) {
                    showInfoBar(qsTr("重载成功"), qsTr("插件已重新加载。"), Severity.Success, 3000)
                }

                function onPluginReloadFailed(pluginId, errorMsg) {
                    showInfoBar(qsTr("重载失败"), qsTr("无法重载插件：") + errorMsg, Severity.Error, 5000)
                }

                function onPluginExportSucceeded(filePath) {
                    showInfoBar(qsTr("导出成功"), qsTr("插件已导出至：") + filePath, Severity.Success, 5000)
                }
            }

            Button {
                icon.name: "ic_fluent_add_20_regular"
                text: qsTr("导入")
                onClicked: {
                    var conflicts = pluginManager.importPlugin()
                    if (conflicts && conflicts.length > 0) {
                        showInfoBar(qsTr("插件冲突"), qsTr("该插件与现有插件冲突，请先卸载冲突插件。"), Severity.Warning, 5000)
                    } else {
                        showInfoBar(qsTr("导入成功"), qsTr("插件导入成功。"), Severity.Success, 3000)
                    }
                }
            }
        }

        Segmented {
            id: segmented
            Layout.fillWidth: true

            SegmentedItem {
                text: qsTr("全部")
            }
            SegmentedItem {
                text: qsTr("已启用")
            }
            SegmentedItem {
                text: qsTr("已禁用")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: pluginManager ? pluginManager.plugins.filter(function(plugin) {
                    // 关键字搜索
                    var kw = searchField.text.trim().toLowerCase()
                    if (kw !== "") {
                        if (
                            plugin.name.toLowerCase().indexOf(kw) === -1 &&
                            (plugin.author || "").toLowerCase().indexOf(kw) === -1 &&
                            (plugin.description || "").toLowerCase().indexOf(kw) === -1
                        ) {
                            return false
                        }
                    }

                    // 启用/禁用过滤
                    if (segmented.currentIndex === 1 && !plugin.enabled) return false
                    if (segmented.currentIndex === 2 && plugin.enabled) return false

                    return true
                }) : []

                delegate: Clip {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 70
                    id: frame

                    TapHandler {
                        onTapped: showPluginDetail(modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            color: "transparent"
                            radius: 8
                            clip: true
                            width: 48
                            height: 48
                            border.width: 0

                            Image {
                                id: pluginImage
                                anchors.fill: parent
                                source: modelData.iconPath ? ("file:///" + modelData.iconPath) : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: source !== ""
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: pluginImage.width
                                        height: pluginImage.height
                                        radius: 8
                                    }
                                }
                            }

                            Icon {
                                id: pluginIcon
                                name: modelData.icon || "ic_fluent_puzzle_piece_20_regular"
                                anchors.fill: parent
                                size: modelData.icon ? 48 : 32
                                opacity: modelData.icon ? 1 : 0.5
                                color: Colors.proxy.textSecondaryColor
                                visible: !(modelData.iconPath && modelData.iconPath !== "")
                            }
                        }

                        ColumnLayout {
                            RowLayout {
                                Layout.fillWidth: true
                                InfoBadge {
                                    visible: modelData.builtin
                                    text: qsTr("内置")
                                    severity: Severity.Info
                                    solid: false
                                }
                                InfoBadge {
                                    visible: modelData.compatible === false
                                    text: qsTr("不兼容")
                                    severity: Severity.Warning
                                    solid: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                    color: modelData.compatible === false ? Colors.proxy.textSecondaryColor : Colors.proxy.textColor
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.author || (modelData.builtin ? qsTr("内置插件") : qsTr("用户插件"))
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                typography: Typography.Caption
                                color: Colors.proxy.textSecondaryColor
                            }
                        }

                        // 右侧区域
                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 18

                            // 兼容警告图标
                            Item {
                                visible: modelData.compatible === false
                                width: 24
                                height: 24

                                Icon {
                                    id: compatibilityIcon
                                    size: 24
                                    color: Colors.proxy.systemCriticalColor
                                    name: "ic_fluent_warning_20_filled"
                                    anchors.fill: parent
                                    opacity: compatibilityHoverHandler.hovered ? 0.8 : 1

                                    HoverHandler {
                                        id: compatibilityHoverHandler
                                    }

                                    TapHandler {
                                        onTapped: compatibilityFlyout.open()
                                    }
                                }

                                Flyout {
                                    id: compatibilityFlyout
                                    text: qsTr("此插件需要 API 版本 %1，但当前版本为 %2。\n不兼容的插件可能会导致意外问题。").arg(modelData.apiVersion || "?").arg(pluginManager ? pluginManager.getAPIVersion() : "?")
                                }
                            }

                            // 启用/禁用
                            Switch {
                                text: !checked ? qsTr("已禁用") : qsTr("已启用")
                                checked: modelData.enabled
                                onToggled: {
                                    if (pluginManager) {
                                        pluginManager.setPluginEnabled(modelData.pluginId, checked)
                                    }
                                }
                            }

                            ToolButton {
                                flat: true
                                icon.name: "ic_fluent_more_horizontal_20_regular"
                                onClicked: actionMenu.open()

                                Menu {
                                    id: actionMenu

                                    MenuItem {
                                        icon.name: "ic_fluent_folder_open_20_regular"
                                        text: Qt.platform.os === "osx" ? qsTr("访达") : qsTr("文件资源管理器")
                                        enabled: !modelData.builtin
                                        onTriggered: {
                                            if (!pluginManager.openPluginFolder(modelData.pluginId)) {
                                                showInfoBar(qsTr("打开失败"), qsTr("无法打开插件文件夹。"), Severity.Error, 5000)
                                            }
                                        }
                                    }

                                    MenuItem {
                                        icon.name: "ic_fluent_arrow_sync_20_regular"
                                        text: qsTr("重载")
                                        enabled: !modelData.builtin
                                        onTriggered: {
                                            pluginManager.reloadPlugin(modelData.pluginId)
                                        }
                                    }

                                    MenuItem {
                                        icon.name: "ic_fluent_share_20_regular"
                                        text: qsTr("导出插件")
                                        enabled: !modelData.builtin
                                        onTriggered: {
                                            var path = pluginManager.exportPlugin(modelData.pluginId)
                                            if (!path) {
                                                showInfoBar(qsTr("导出失败"), qsTr("无法导出插件。"), Severity.Error, 5000)
                                            }
                                        }
                                    }

                                    MenuSeparator { }

                                    MenuItem {
                                        icon.name: "ic_fluent_delete_20_regular"
                                        text: qsTr("卸载")
                                        enabled: !modelData.builtin
                                        onTriggered: {
                                            uninstallPlugin(modelData.pluginId)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
