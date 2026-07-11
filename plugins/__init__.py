"""
新闻源插件包

所有新闻源插件都放在此目录下。
每个插件是一个独立的子目录，包含：
- plugin.py: 主插件类
- config.json: 默认配置
- README.md: 插件说明
"""

from core.plugin_manager import PluginManager
from core.plugin_interface import INewsSource, PluginInfo, NewsItem, NewsCategory

__all__ = ['PluginManager', 'INewsSource', 'PluginInfo', 'NewsItem', 'NewsCategory']
