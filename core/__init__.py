"""
核心模块

包含插件化架构的核心组件：
- plugin_interface: 插件接口定义
- plugin_manager: 插件管理器
"""

from typing import Optional

from .plugin_interface import (
    INewsSource,
    PluginBase,
    PluginInfo,
    NewsItem,
    NewsCategory,
    FetchResult,
)

from .plugin_manager import PluginManager

# ── 全局单例（解决 API 与主程序状态不一致问题） ──────────────────────────────
# PluginManager 继承 QObject，在 Qt 主线程创建后可在 Flask 线程中安全访问
_plugin_manager_singleton: Optional[PluginManager] = None


def get_plugin_manager() -> PluginManager:
    """获取 PluginManager 全局单例（延迟初始化）"""
    global _plugin_manager_singleton
    if _plugin_manager_singleton is None:
        _plugin_manager_singleton = PluginManager()
        _plugin_manager_singleton.load_all_plugins()
    return _plugin_manager_singleton


def init_plugin_manager() -> PluginManager:
    """初始化 PluginManager 并加载所有插件（供主程序调用）"""
    global _plugin_manager_singleton
    if _plugin_manager_singleton is None:
        _plugin_manager_singleton = PluginManager()
        count = _plugin_manager_singleton.load_all_plugins()
        print(f"[插件系统] 加载完成，共 {count} 个插件")
        for plugin in _plugin_manager_singleton.get_all_plugins(enabled_only=False):
            status = "[ON]" if plugin.info.enabled else "[OFF]"
            print(f"  {status} {plugin.name} (ID: {plugin.id})")
    return _plugin_manager_singleton


__all__ = [
    'INewsSource',
    'PluginBase',
    'PluginInfo',
    'NewsItem',
    'NewsCategory',
    'FetchResult',
    'PluginManager',
]
