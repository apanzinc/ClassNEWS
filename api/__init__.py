"""
API 模块

提供 HTTP API 接口供外部调用。
"""

from .plugin_api import plugin_bp

__all__ = ['plugin_bp']
