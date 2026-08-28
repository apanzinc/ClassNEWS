"""
插件 API 路由 (Flask 版本)
提供新闻源插件的 HTTP API 接口
"""

from flask import Blueprint, jsonify, request
from core import get_plugin_manager
from core.plugin_interface import NewsCategory


plugin_bp = Blueprint('plugins', __name__, url_prefix='/api/v1/plugins')


# 统一响应
def ok_response(data=None, message="ok"):
    return jsonify({"code": 0, "message": message, "data": data})


def err_response(code=1, message="error", status=400):
    return jsonify({"code": code, "message": message}), status


# ===== 插件列表 =====

@plugin_bp.route('', methods=['GET'])
def get_all_plugins():
    """获取所有新闻源"""
    manager = get_plugin_manager()
    plugins = manager.get_all_plugins(enabled_only=False)
    
    data = [
        {
            "id": p.info.id,
            "name": p.info.name,
            "version": p.info.version,
            "author": p.info.author,
            "description": p.info.description,
            "icon": p.info.icon,
            "enabled": p.info.enabled,
            "homepage": p.info.homepage,
        }
        for p in plugins
    ]
    return ok_response(data)


# ===== 获取新闻列表 =====

@plugin_bp.route('/<int:plugin_id>/news', methods=['GET'])
def get_plugin_news(plugin_id):
    """获取指定插件的新闻列表"""
    category_str = request.args.get('category')
    count = int(request.args.get('count', 20))
    cursor = request.args.get('cursor')
    
    category = None
    if category_str:
        try:
            category = NewsCategory(category_str)
        except ValueError:
            return err_response(400, f"无效的分类: {category_str}")
    
    manager = get_plugin_manager()
    result = manager.fetch_news_sync(plugin_id, category, count, cursor)
    
    if result is None:
        return err_response(404, f"插件 {plugin_id} 不存在或已禁用")
    
    return ok_response(result.to_dict())


# ===== 获取新闻详情 =====

@plugin_bp.route('/<int:plugin_id>/news/<news_id>', methods=['GET'])
def get_news_detail(plugin_id, news_id):
    """获取新闻详情"""
    manager = get_plugin_manager()
    news = manager.get_news_detail_sync(plugin_id, news_id)
    
    if news is None:
        return err_response(404, "新闻未找到")
    
    return ok_response(news.to_dict())


# ===== 播放新闻 =====

@plugin_bp.route('/<int:plugin_id>/news/<news_id>/play', methods=['POST'])
def play_news(plugin_id, news_id):
    """播放新闻（异步）"""
    manager = get_plugin_manager()
    success = manager.play_news_sync(plugin_id, news_id)
    
    if not success:
        return err_response(500, "播放失败")
    
    return ok_response({"playing": True})


# ===== 搜索新闻 =====

@plugin_bp.route('/<int:plugin_id>/search', methods=['GET'])
def search_news(plugin_id):
    """搜索新闻"""
    keyword = request.args.get('q') or request.args.get('keyword', '')
    count = int(request.args.get('count', 20))
    
    if not keyword:
        return err_response(400, "请提供搜索关键词")
    
    manager = get_plugin_manager()
    results = manager.search_news_sync(plugin_id, keyword, count)
    
    return ok_response([r.to_dict() for r in results])


# ===== 插件状态 =====

@plugin_bp.route('/<int:plugin_id>/status', methods=['PUT', 'PATCH'])
def update_plugin_status(plugin_id):
    """启用/禁用插件"""
    body = request.get_json(silent=True) or {}
    enabled = body.get('enabled', True)
    
    manager = get_plugin_manager()
    success = manager.setPluginEnabled(plugin_id, enabled)
    
    if not success:
        return err_response(404, f"插件 {plugin_id} 不存在")
    
    return ok_response(message=f"插件已{'启用' if enabled else '禁用'}")


# ===== 插件配置 =====

@plugin_bp.route('/<int:plugin_id>/config', methods=['GET'])
def get_plugin_config(plugin_id):
    """获取插件配置"""
    manager = get_plugin_manager()
    plugin = manager.get_plugin(plugin_id)
    
    if plugin is None:
        return err_response(404, f"插件 {plugin_id} 不存在")
    
    return ok_response(plugin.config)


@plugin_bp.route('/<int:plugin_id>/config', methods=['PUT', 'PATCH'])
def update_plugin_config(plugin_id):
    """更新插件配置"""
    body = request.get_json(silent=True) or {}
    
    manager = get_plugin_manager()
    plugin = manager.get_plugin(plugin_id)
    
    if plugin is None:
        return err_response(404, f"插件 {plugin_id} 不存在")
    
    plugin.config.update(body)
    return ok_response(message="配置已更新")


# ===== 健康检查 =====

@plugin_bp.route('/<int:plugin_id>/health', methods=['GET'])
def health_check(plugin_id):
    """检查插件健康状态"""
    manager = get_plugin_manager()
    plugin = manager.get_plugin(plugin_id)
    
    if plugin is None:
        return err_response(404, f"插件 {plugin_id} 不存在")
    
    healthy = plugin.health_check()
    return ok_response({"healthy": healthy})
