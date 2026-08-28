"""
本地 API 服务器

基于 Flask 提供插件系统的 HTTP API（/api/v1/plugins ...），
供外部工具/浏览器扩展调用。

由 main.py 在启动时调用 start_server()，退出场景可调用 stop_server()。
"""

import threading
from typing import List, Dict, Any

from flask import Flask, jsonify
from flask_cors import CORS

from api import plugin_bp

HOST = "127.0.0.1"
PORT = 45678

_app: Flask = None
_server_thread: threading.Thread = None
_server = None  # werkzeug 服务器实例，用于停止
_running = False

# 新闻数据缓存（供 HTTP API 查询，由主程序定期刷新）
_news_data: List[Dict[str, Any]] = []


def _create_app() -> Flask:
    """创建 Flask 应用并注册路由"""
    app = Flask(__name__)
    CORS(app)
    app.register_blueprint(plugin_bp)

    @app.route("/api/v1/health", methods=["GET"])
    def health():
        return jsonify({"code": 0, "message": "ok", "data": {"status": "up"}})

    @app.route("/api/v1/news", methods=["GET"])
    def get_news():
        """获取主程序缓存的新闻列表"""
        return jsonify({"code": 0, "message": "ok", "data": _news_data})

    return app


def start_server(host: str = HOST, port: int = PORT) -> bool:
    """启动本地 API 服务器（非阻塞，后台线程运行）"""
    global _app, _server_thread, _server, _running

    if _running:
        return True

    try:
        from werkzeug.serving import make_server

        _app = _create_app()
        _server = make_server(host, port, _app, threaded=True)
        server = _server

        def _serve():
            try:
                server.serve_forever()
            except Exception as e:
                print(f"本地 API 服务器异常退出: {e}")
            finally:
                global _running
                _running = False

        _server_thread = threading.Thread(target=_serve, daemon=True, name="LocalAPIServer")
        _server_thread.start()
        _running = True
        print(f"本地 API 服务器已启动: http://{host}:{port}")
        return True
    except OSError as e:
        print(f"本地 API 服务器启动失败（端口 {port} 可能被占用）: {e}")
        _running = False
        return False
    except Exception as e:
        print(f"本地 API 服务器启动失败: {e}")
        _running = False
        return False


def stop_server() -> bool:
    """停止本地 API 服务器"""
    global _running, _server_thread, _server

    if not _running or _server_thread is None:
        return True

    try:
        if _server is not None:
            _server.shutdown()
        _server_thread.join(timeout=3)
        _running = False
        _server_thread = None
        _server = None
        print("本地 API 服务器已停止")
        return True
    except Exception as e:
        print(f"停止本地 API 服务器失败: {e}")
        return False


def set_news_data(news: List[Dict[str, Any]]) -> None:
    """更新新闻数据缓存（由主程序定期调用）"""
    global _news_data
    _news_data = news or []


def is_running() -> bool:
    return _running


if __name__ == "__main__":
    start_server()
    try:
        while True:
            threading.Event().wait(3600)
    except KeyboardInterrupt:
        stop_server()
