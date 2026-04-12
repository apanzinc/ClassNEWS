import sys
import traceback
import json
import socket
import platform
import os
import io
from pathlib import Path
from datetime import datetime
from PySide6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
from PySide6.QtGui import QIcon, QAction
from PySide6.QtCore import Qt, QTimer, QObject, Signal, Slot, Property, QThread, QEvent, qInstallMessageHandler, QtMsgType, QMessageLogContext
import ctypes

# 设置环境变量，解决 Windows 控制台编码问题
if sys.platform == "win32":
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    
    # 强制设置标准输出和标准错误输出的编码为 UTF-8 (Python 3.7+)
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except AttributeError:
        # Python 3.7 以下版本使用回退方案
        try:
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
            sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')
        except (AttributeError, ValueError) as e:
            print(f"编码设置失败：{e}")
    
    # 尝试使用 ctypes 直接设置控制台代码页为 UTF-8
    try:
        kernel32 = ctypes.windll.kernel32
        # 设置控制台输出代码页为 UTF-8 (65001)
        kernel32.SetConsoleOutputCP(65001)
        # 设置控制台输入代码页为 UTF-8
        kernel32.SetConsoleCP(65001)
    except OSError as e:
        print(f"控制台编码设置失败：{e}")

# 先打印启动横幅（ASCII 艺术字）
from logger import print_startup_banner
print_startup_banner()

# Qt 消息处理器 - 处理 Qt/QML 的日志输出
def qt_message_handler(msg_type, context, message):
    """Qt 消息处理器，用于正确处理编码"""
    try:
        # 统一使用 UTF-8 输出，自动处理编码问题
        if message.startswith("qml:"):
            print(message, flush=True)
        else:
            print(f"Qt: {message}", file=sys.stderr, flush=True)
    except UnicodeEncodeError:
        # 编码失败时使用替换字符
        safe_msg = message.encode('utf-8', errors='replace').decode('utf-8', errors='replace')
        if message.startswith("qml:"):
            print(safe_msg, flush=True)
        else:
            print(f"Qt: {safe_msg}", file=sys.stderr, flush=True)

# 导入 plyer（在横幅之后）
notification = None
try:
    from plyer import notification
    print("plyer.notification 导入成功")
except ImportError:
    print("plyer 未安装，系统通知功能不可用")
except Exception as e:
    print(f"导入 plyer 失败：{e}")

# 在导入 RinUI 之前，设置正确的路径（用于 PyInstaller 打包环境）
def setup_rinui_path():
    """设置 RinUI 路径，确保在打包环境下能正确找到资源"""
    if hasattr(sys, '_MEIPASS'):
        # PyInstaller 打包环境
        base_path = Path(sys._MEIPASS)
        # 尝试多个可能的路径（onedir 模式）
        possible_paths = [
            base_path / '_internal' / 'RinUI',  # 在 _internal 目录 (onedir 模式)
            base_path / 'RinUI',  # 直接在根目录
        ]
        for rinui_path in possible_paths:
            if rinui_path.exists():
                # 直接修改 RinUI 的 config 模块中的路径
                import RinUI.core.config as rinui_config
                rinui_config.RINUI_PATH = rinui_path
                print(f"RinUI 资源路径已设置: {rinui_path}")
                return
        print(f"警告: 未找到 RinUI 目录，尝试路径: {possible_paths}")

# 先应用 RinUI 配置补丁，修复 JSON 解析错误
try:
    import patch_rinui_config
    print("[成功] RinUI 配置补丁已加载")
except Exception as e:
    print(f"[警告] RinUI 配置补丁加载失败：{e}，使用原始配置")

# 先导入 RinUI 的 config 模块并设置路径
import RinUI.core.config
setup_rinui_path()

from RinUI import RinUIWindow  # 使用 RinUIWindow 来正确初始化
from news_api import fetch_news
from logger import init_logger, get_logger, LogCategory
from download_manager import DownloadManager

r"""
                            _ooOoo_
                           o8888888o
                           88" . "88
                           (| -_- |)
                           O\  =  /O
                        ____/`---'\____
                      .'  \|     |//  `.
                     /  \|||  :  |||//  \
                    /  _||||| -:- |||||-  \
                    |   | \\  -  /// |   |
                    | \_|  ''\---/''  |   |
                    \  .-\__  `-`  ___/-. /
                  ___`. .'  /--.--\  `. . __
               ."" '<  `.___\_<|>_/___.'  >'"".
              | | :  `- \`.;`\ _ /`;.`/ - ` : | |
              \  \ `-.   \_ __\ /__ _/   .-` /  /
         ======`-.____`-.___\_____/___.-`____.-'======
                            `=---='
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                  佛祖保佑       永无BUG
         """


def load_build_info():
    """加载编译信息"""
    build_info_path = Path(__file__).parent / "build_info.json"
    default_info = {
        "version": "v0.1.0-dev",
        "buildDate": datetime.now().strftime("%Y-%m-%d"),
        "buildTime": datetime.now().strftime("%H:%M:%S"),
        "buildNumber": "1",
        "gitCommit": "unknown",
        "gitBranch": "main",
        "compiler": f"Python {platform.python_version()}",
        "qtVersion": "6.x",
        "platform": platform.system(),
        "architecture": platform.machine(),
        "releaseType": "development",
        "appName": "ClassNEWS",
        "appId": "ClassNEWS.App.1.0",
        "copyright": "Copyright 2026 ClassNEWS Team",
        "license": "GPL-3.0"
    }
    
    if build_info_path.exists():
        try:
            with open(build_info_path, 'r', encoding='utf-8') as f:
                loaded_info = json.load(f)
                # 合并默认值和加载的值
                default_info.update(loaded_info)
                print(f"编译信息已加载: {build_info_path}")
        except Exception as e:
            print(f"加载编译信息失败: {e}")
    else:
        print(f"编译信息文件不存在，使用默认值: {build_info_path}")
    
    return default_info


class SystemInfoWorker(QThread):
    """在后台线程中获取系统信息（包括公网IP）"""
    info_ready = Signal(dict)
    
    def run(self):
        """异步获取系统信息"""
        # 加载编译信息
        build_info = load_build_info()
        
        # 获取公网 IP（在后台线程中执行，不阻塞主线程）
        public_ip = "Unknown"
        try:
            import urllib.request
            import json
            # 使用 ipify API 获取公网 IP
            with urllib.request.urlopen("https://api.ipify.org?format=json", timeout=3) as response:
                data = json.loads(response.read().decode())
                public_ip = data.get("ip", "Unknown")
        except:
            try:
                # 备用方案
                with urllib.request.urlopen("https://httpbin.org/ip", timeout=3) as response:
                    data = json.loads(response.read().decode())
                    public_ip = data.get("origin", "Unknown")
            except:
                pass
        
        # 获取系统版本
        system = platform.system()
        version = platform.version()
        release = platform.release()
        
        if system == "Windows":
            os_version = f"Windows {release}"
        elif system == "Darwin":
            os_version = f"macOS {release}"
        else:
            os_version = f"{system} {release}"
        
        # 从 buildDate 提取年份
        build_date = build_info.get("buildDate", datetime.now().strftime("%Y-%m-%d"))
        build_year = build_date.split("-")[0] if "-" in str(build_date) else str(datetime.now().year)
        current_year = str(datetime.now().year)
        year_range = build_year if build_year == current_year else f"{build_year}-{current_year}"
        
        # 获取编译者信息
        builder = build_info.get("builder", {})
        builder_name = builder.get("name", "Unknown")
        builder_email = builder.get("email", "unknown")
        
        # 获取本地 IP
        local_ip = "Unknown"
        try:
            import socket
            # 获取本机主机名
            hostname = socket.gethostname()
            # 获取本地 IP
            local_ip = socket.gethostbyname(hostname)
        except:
            pass
        
        # 合并编译信息和系统信息
        system_info = {
            "ip": public_ip,
            "publicIP": public_ip,
            "localIP": local_ip,
            "os": os_version,
            "version": build_info.get("version", "v0.1.0-dev"),
            "buildDate": build_date,
            "buildTime": build_info.get("buildTime", "unknown"),
            "buildYear": build_year,
            "yearRange": year_range,
            "buildNumber": build_info.get("buildNumber", "1"),
            "gitCommit": build_info.get("gitCommit", "unknown"),
            "gitBranch": build_info.get("gitBranch", "main"),
            "compiler": build_info.get("compiler", f"Python {platform.python_version()}"),
            "qtVersion": build_info.get("qtVersion", "6.x"),
            "platform": build_info.get("platform", platform.system()),
            "architecture": build_info.get("architecture", platform.machine()),
            "releaseType": build_info.get("releaseType", "development"),
            "appName": build_info.get("appName", "ClassNEWS"),
            "appId": build_info.get("appId", "ClassNEWS.App.1.0"),
            "copyright": build_info.get("copyright", "Copyright 2026 ClassNEWS Team"),
            "license": build_info.get("license", "GPL-3.0"),
            "builder": builder_name,
            "builderName": builder_name,
            "builderEmail": builder_email
        }
        
        self.info_ready.emit(system_info)


def get_system_info_sync():
    """同步获取系统信息（不包含公网IP，用于快速启动）"""
    # 加载编译信息
    build_info = load_build_info()
    
    # 获取系统版本
    system = platform.system()
    version = platform.version()
    release = platform.release()
    
    if system == "Windows":
        os_version = f"Windows {release}"
    elif system == "Darwin":
        os_version = f"macOS {release}"
    else:
        os_version = f"{system} {release}"
    
    # 从 buildDate 提取年份
    build_date = build_info.get("buildDate", datetime.now().strftime("%Y-%m-%d"))
    build_year = build_date.split("-")[0] if "-" in str(build_date) else str(datetime.now().year)
    current_year = str(datetime.now().year)
    year_range = build_year if build_year == current_year else f"{build_year}-{current_year}"
    
    # 获取编译者信息
    builder = build_info.get("builder", {})
    builder_name = builder.get("name", "Unknown")
    builder_email = builder.get("email", "unknown")
    
    # 返回基本信息（不包含公网 IP）
    return {
        "ip": "Loading...",  # 异步获取中
        "publicIP": "Loading...",  # 异步获取中
        "localIP": "Unknown",  # 本地 IP
        "os": os_version,
        "version": build_info.get("version", "v0.1.0-dev"),
        "buildDate": build_date,
        "buildTime": build_info.get("buildTime", "unknown"),
        "buildYear": build_year,
        "yearRange": year_range,
        "buildNumber": build_info.get("buildNumber", "1"),
        "gitCommit": build_info.get("gitCommit", "unknown"),
        "gitBranch": build_info.get("gitBranch", "main"),
        "compiler": build_info.get("compiler", f"Python {platform.python_version()}"),
        "qtVersion": build_info.get("qtVersion", "6.x"),
        "platform": build_info.get("platform", platform.system()),
        "architecture": build_info.get("architecture", platform.machine()),
        "releaseType": build_info.get("releaseType", "development"),
        "appName": build_info.get("appName", "ClassNEWS"),
        "appId": build_info.get("appId", "ClassNEWS.App.1.0"),
        "copyright": build_info.get("copyright", "Copyright 2026 ClassNEWS Team"),
        "license": build_info.get("license", "GPL-3.0"),
        "builder": builder_name,
        "builderName": builder_name,
        "builderEmail": builder_email
    }

class NewsWorker(QThread):
    """在后台线程中获取新闻"""
    news_fetched = Signal(list)
    
    def run(self):
        try:
            news = fetch_news()
            self.news_fetched.emit(news)
        except Exception as e:
            print(f"获取新闻失败: {e}")
            self.news_fetched.emit([])


class NewsManager(QObject):
    """新闻管理器，用于在 Python 和 QML 之间传递新闻数据"""
    newsChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._news = []
        self._worker = None

    @Property(list, notify=newsChanged)
    def news(self):
        return self._news

    @news.setter
    def news(self, value):
        if self._news != value:
            self._news = value
            self.newsChanged.emit()

    @Slot()
    def refreshNews(self):
        """刷新新闻数据"""
        print("正在获取最新新闻...")
        self._worker = NewsWorker()
        self._worker.news_fetched.connect(self._on_news_fetched)
        self._worker.start()

    @Slot()
    def shuffleNews(self):
        """随机打乱新闻顺序，但保持完整版新闻在第一位"""
        import random
        if self._news and len(self._news) > 1:
            # 分离完整版新闻和普通新闻
            full_version_news = [n for n in self._news if n.get('isFullVersion', False)]
            normal_news = [n for n in self._news if not n.get('isFullVersion', False)]
            # 打乱普通新闻顺序
            random.shuffle(normal_news)
            # 合并：完整版新闻在前，然后是打乱后的普通新闻
            news_list = full_version_news + normal_news
            self.news = news_list
            print(f"新闻已打乱顺序，共 {len(news_list)} 条（完整版 {len(full_version_news)} 条）")

    @Slot(result=dict)
    def getTodayFullVersionNews(self):
        """获取当天的完整版新闻（如朝闻天下）"""
        if not self._news:
            print("新闻列表为空，无法获取完整版新闻")
            return {}
        
        # 查找完整版新闻
        full_version_news = [n for n in self._news if n.get('isFullVersion', False)]
        if full_version_news:
            # 返回第一个完整版新闻（通常是最新的）
            news = full_version_news[0]
            print(f"获取到当天完整版新闻: {news.get('title', 'Unknown')}")
            # 使用 videoId 作为 pid（因为新闻数据中使用的是 videoId 字段）
            video_id = news.get('videoId', '')
            return {
                'pid': video_id,
                'title': news.get('title', '完整版新闻'),
                'isFullVersion': True
            }
        else:
            print("未找到完整版新闻")
            return {}

    def _on_news_fetched(self, news):
        """新闻获取完成回调"""
        print(f"获取到 {len(news)} 条新闻")
        # 自动打乱顺序，但保持完整版新闻在第一位
        if news and len(news) > 1:
            import random
            # 分离完整版新闻和普通新闻
            full_version_news = [n for n in news if n.get('isFullVersion', False)]
            normal_news = [n for n in news if not n.get('isFullVersion', False)]
            # 打乱普通新闻顺序
            random.shuffle(normal_news)
            # 合并：完整版新闻在前，然后是打乱后的普通新闻
            news_list = full_version_news + normal_news
            self.news = news_list
            print(f"新闻已自动打乱顺序，共 {len(news_list)} 条（完整版 {len(full_version_news)} 条）")
        else:
            self.news = news
        if self._worker:
            self._worker.deleteLater()
            self._worker = None


class ConfigManager(QObject):
    """配置管理器，用于保存和加载应用设置"""
    configChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._config_file = Path(__file__).parent / "config.json"
        self._config = self._load_config()
    
    def _load_config(self):
        """加载配置文件"""
        if self._config_file.exists():
            try:
                with open(self._config_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"加载配置文件失败: {e}")
        return {}
    
    def _save_config(self):
        """保存配置文件"""
        try:
            with open(self._config_file, 'w', encoding='utf-8') as f:
                json.dump(self._config, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"保存配置文件失败: {e}")
    
    @Property(bool)
    def useInternalPlayer(self):
        return self._config.get("use_internal_player", True)
    
    @useInternalPlayer.setter
    def useInternalPlayer(self, value):
        self._config["use_internal_player"] = value
        self._save_config()
        self.configChanged.emit()

    @Slot(str, result=int)
    def getVideoProgress(self, video_id):
        """获取视频上次播放位置（毫秒）"""
        progress_data = self._config.get("video_progress", {})
        return progress_data.get(video_id, 0)

    @Slot(str, int)
    def saveVideoProgress(self, video_id, position):
        """保存视频播放位置（毫秒）"""
        if "video_progress" not in self._config:
            self._config["video_progress"] = {}
        self._config["video_progress"][video_id] = position
        self._save_config()

    @Slot(str)
    def clearVideoProgress(self, video_id):
        """清除指定视频的播放进度"""
        if "video_progress" in self._config and video_id in self._config["video_progress"]:
            del self._config["video_progress"][video_id]
            self._save_config()

    @Slot(result=bool)
    def getAutoReplay(self):
        """获取自动重播设置"""
        return self._config.get("auto_replay", False)

    @Slot(bool)
    def setAutoReplay(self, value):
        """设置自动重播"""
        self._config["auto_replay"] = value
        self._save_config()
        self.configChanged.emit()

    @Property(bool)
    def showNotificationWindow(self):
        """是否显示唤醒倒计时窗口"""
        return self._config.get("show_notification_window", True)
    
    @showNotificationWindow.setter
    def showNotificationWindow(self, value):
        self._config["show_notification_window"] = value
        self._save_config()
        self.configChanged.emit()

    @Property(int)
    def notificationCountdownSeconds(self):
        """唤醒倒计时秒数"""
        return self._config.get("notification_countdown_seconds", 5)
    
    @notificationCountdownSeconds.setter
    def notificationCountdownSeconds(self, value):
        self._config["notification_countdown_seconds"] = max(1, min(60, value))
        self._save_config()
        self.configChanged.emit()

    @Property(int)
    def defaultVolume(self):
        """默认音量（0-100）"""
        return self._config.get("default_volume", 80)
    
    @defaultVolume.setter
    def defaultVolume(self, value):
        self._config["default_volume"] = max(0, min(100, value))
        self._save_config()
        self.configChanged.emit()

    @Property(float)
    def defaultPlaybackRate(self):
        """默认倍速"""
        return self._config.get("default_playback_rate", 1.0)
    
    @defaultPlaybackRate.setter
    def defaultPlaybackRate(self, value):
        self._config["default_playback_rate"] = value
        self._save_config()
        self.configChanged.emit()

    @Property(int)
    def defaultProgress(self):
        """默认进度（秒）"""
        return self._config.get("default_progress", 0)
    
    @defaultProgress.setter
    def defaultProgress(self, value):
        self._config["default_progress"] = max(0, value)
        self._save_config()
        self.configChanged.emit()

    @Property(bool)
    def autoContinue(self):
        """自动续播"""
        return self._config.get("auto_continue", True)
    
    @autoContinue.setter
    def autoContinue(self, value):
        self._config["auto_continue"] = value
        self._save_config()
        self.configChanged.emit()

    @Property(bool)
    def autoStart(self):
        """开机自动启动"""
        return self._config.get("auto_start", False)
    
    @autoStart.setter
    def autoStart(self, value):
        self._config["auto_start"] = value
        self._save_config()
        self.configChanged.emit()
        # 设置/取消 Windows 开机启动
        self._set_windows_startup(value)

    @Property(bool)
    def fullscreenPlayback(self):
        """全屏播放"""
        return self._config.get("fullscreen_playback", False)
    
    @fullscreenPlayback.setter
    def fullscreenPlayback(self, value):
        self._config["fullscreen_playback"] = value
        self._save_config()
        self.configChanged.emit()
    
    def _set_windows_startup(self, enable):
        """设置 Windows 开机启动"""
        import winreg
        import sys
        
        try:
            # 检查权限：尝试打开注册表项进行测试
            key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
            try:
                test_key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_READ)
                winreg.CloseKey(test_key)
            except PermissionError:
                print("错误：没有权限修改开机启动项，请以管理员身份运行程序")
                return False
            except FileNotFoundError:
                # 注册表项不存在是正常的，继续执行
                pass
            
            # 打开注册表项进行写入
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_WRITE)
            
            app_name = "ClassNEWS"
            
            if enable:
                # 获取当前可执行文件路径
                if hasattr(sys, '_MEIPASS'):
                    # PyInstaller 打包后的路径
                    exe_path = sys.executable
                else:
                    # 开发环境
                    exe_path = sys.executable
                
                # 添加 --background 参数，让程序在后台运行
                command = f'"{exe_path}" --background'
                winreg.SetValueEx(key, app_name, 0, winreg.REG_SZ, command)
                print(f"已添加到开机启动: {command}")
            else:
                # 删除注册表项
                try:
                    winreg.DeleteValue(key, app_name)
                    print("已取消开机启动")
                except FileNotFoundError:
                    pass
            
            winreg.CloseKey(key)
            return True
        except PermissionError:
            print("错误：没有权限修改开机启动项，请以管理员身份运行程序")
            return False
        except Exception as e:
            print(f"设置开机启动失败：{e}")
            return False

    @Slot()
    def clearAllData(self):
        """Clear all data: config files, logs, temp files, RinUI config, then force exit"""
        import shutil
        import tempfile
        import os
        
        # Get logger instance for detailed logging
        try:
            from logger import get_logger, LogCategory
            logger = get_logger()
        except:
            logger = None
        
        def log_event(level, message, details=None, error_code=None):
            """记录事件到日志"""
            if logger:
                if level == "info":
                    logger.info(LogCategory.DATA, "ConfigManager", message, details)
                elif level == "success":
                    logger.success(LogCategory.DATA, "ConfigManager", message, details)
                elif level == "warning":
                    logger.warning(LogCategory.DATA, "ConfigManager", message, details)
                elif level == "error":
                    logger.error(LogCategory.DATA, "ConfigManager", message, details)
            print(message)
        
        log_event("info", "=" * 60)
        log_event("info", "Starting data cleanup / 开始清除所有数据...", {
            "config_file": str(self._config_file),
            "config_exists": self._config_file.exists()
        })
        
        app_dir = Path(__file__).parent
        cleanup_results = {
            "config_deleted": False,
            "rinui_config_deleted": False,
            "logs_deleted": False,
            "temp_files_deleted": 0
        }
        
        # 1. Delete app config file
        try:
            if self._config_file.exists():
                self._config_file.unlink()
                cleanup_results["config_deleted"] = True
                log_event("success", f"✓ App config deleted / 应用配置文件已删除: {self._config_file}")
            else:
                log_event("warning", f"! App config not found / 应用配置文件不存在: {self._config_file}")
        except Exception as e:
            log_event("error", f"✗ Failed to delete app config / 删除应用配置文件失败: {e}", error_code="CLEAR_001")
        
        # 2. Delete RinUI config file
        try:
            rinui_config = app_dir / "RinUI" / "config" / "rin_ui.json"
            if rinui_config.exists():
                rinui_config.unlink()
                cleanup_results["rinui_config_deleted"] = True
                log_event("success", f"✓ RinUI config deleted / RinUI 配置文件已删除: {rinui_config}")
            else:
                log_event("warning", f"! RinUI config not found / RinUI 配置文件不存在: {rinui_config}")
        except Exception as e:
            log_event("error", f"✗ Failed to delete RinUI config / 删除 RinUI 配置文件失败: {e}", error_code="CLEAR_002")
        
        # 3. Delete logs directory (skip logging to avoid file not found error)
        try:
            logs_dir = app_dir / "logs"
            if logs_dir.exists():
                shutil.rmtree(logs_dir)
                cleanup_results["logs_deleted"] = True
                print(f"✓ Logs directory deleted / 日志目录已删除: {logs_dir}")
            else:
                print(f"! Logs directory not found / 日志目录不存在: {logs_dir}")
        except Exception as e:
            print(f"✗ Failed to delete logs / 删除日志目录失败: {e}")
        
        # 4. Delete temp files
        try:
            temp_dir = Path(tempfile.gettempdir())
            deleted_count = 0
            for temp_file in temp_dir.iterdir():
                if temp_file.is_file() and temp_file.suffix in ['.m3u8', '.m3u', '.mp4', '.tmp']:
                    try:
                        temp_file.unlink()
                        deleted_count += 1
                    except:
                        pass
            cleanup_results["temp_files_deleted"] = deleted_count
            log_event("success", f"✓ Temp files cleaned / 临时文件已清理: {deleted_count} files")
        except Exception as e:
            log_event("error", f"✗ Failed to clean temp files / 清理临时文件失败: {e}", error_code="CLEAR_004")
        
        # 5. Clear config memory
        self._config = {}
        log_event("success", "✓ Config memory cleared / 配置内存已清空")
        
        log_event("info", "=" * 60)
        log_event("success", "All data cleared successfully / 所有数据已清除完成", cleanup_results)
        log_event("info", "Application will exit now / 应用即将退出...")
        
        # 6. 正常退出应用（允许 Python 清理资源）
        from PySide6.QtWidgets import QApplication
        app = QApplication.instance()
        if app:
            app.quit()
        else:
            sys.exit(0)


class VideoManager(QObject):
    """视频管理器，用于解析和播放视频"""
    videoParsed = Signal(str, str, dict)  # 信号：视频URL, 视频标题, 播放选项
    parseError = Signal(str)  # 信号：错误信息

    def __init__(self, config_manager=None, parent=None):
        super().__init__(parent)
        self._video_worker = None
        self._program_worker = None
        self._config_manager = config_manager
        self._toast_notifier = None
        self._notification = None
        # 初始化 Windows 系统通知
        self._init_toast_notifier()

    def _init_toast_notifier(self):
        """初始化系统通知"""
        try:
            if notification:
                self._notification = notification
                print("系统通知已初始化")
            else:
                print("系统通知不可用: notification 未导入")
        except Exception as e:
            print(f"初始化系统通知失败: {e}")

    @Slot(str, str)
    def showSystemNotification(self, title, message):
        """显示系统通知"""
        try:
            if self._notification:
                self._notification.notify(
                    title=title,
                    message=message,
                    app_name="ClassNEWS",
                    timeout=5
                )
                print(f"系统通知已发送: {title} - {message}")
            else:
                print(f"系统通知不可用: {title} - {message}")
        except Exception as e:
            print(f"显示系统通知失败: {e}")
        self._pending_options = {}  # 存储待处理的播放选项

    @Property(bool)
    def useInternalPlayer(self):
        if self._config_manager:
            return self._config_manager.useInternalPlayer
        return True

    @useInternalPlayer.setter
    def useInternalPlayer(self, value):
        if self._config_manager:
            self._config_manager.useInternalPlayer = value

    @Slot(str, str)
    def parseVideo(self, pid, title):
        """解析视频（兼容旧版本，无选项）"""
        self.parseVideoWithOptions(pid, title, {})

    @Slot(str, str, dict)
    def parseVideoWithOptions(self, pid, title, options=None):
        """解析视频（带播放选项）"""
        options = options or {}
        print(f"正在解析视频: {pid}, 标题: {title}, 选项: {options}")
        self._pending_options = options
        self._video_worker = VideoParseWorker(pid, title)
        self._video_worker.video_parsed.connect(self._on_video_parsed)
        self._video_worker.parse_error.connect(self._on_parse_error)
        self._video_worker.start()

    @Slot(str)
    def playProgramByName(self, program_name):
        """通过节目名称搜索并播放视频"""
        print(f"正在搜索节目: {program_name}")
        self._program_worker = ProgramSearchWorker(program_name)
        self._program_worker.video_parsed.connect(self._on_program_video_parsed)
        self._program_worker.parse_error.connect(self._on_program_parse_error)
        self._program_worker.start()

    def _on_video_parsed(self, video_url, title):
        """视频解析完成"""
        print(f"视频解析完成: {title}, 选项: {self._pending_options}")
        self.videoParsed.emit(video_url, title, self._pending_options)
        self._pending_options = {}
        if self._video_worker:
            self._video_worker.deleteLater()
            self._video_worker = None

    def _on_parse_error(self, error_msg):
        """视频解析错误"""
        print(f"视频解析失败: {error_msg}")
        self.parseError.emit(error_msg)
        self._pending_options = {}
        if self._video_worker:
            self._video_worker.deleteLater()
            self._video_worker = None

    def _on_program_video_parsed(self, video_url, title):
        """节目搜索并解析完成"""
        print(f"节目视频解析完成: {title}")
        self.videoParsed.emit(video_url, title, {})
        if self._program_worker:
            self._program_worker.deleteLater()
            self._program_worker = None

    def _on_program_parse_error(self, error_msg):
        """节目搜索或解析错误"""
        print(f"节目搜索失败: {error_msg}")
        self.parseError.emit(error_msg)
        if self._program_worker:
            self._program_worker.deleteLater()
            self._program_worker = None

    def _get_file_extension(self, video_url):
        """根据 URL 获取文件扩展名"""
        from pathlib import Path
        from urllib.parse import urlparse
        
        # 解析 URL
        parsed = urlparse(video_url)
        path = parsed.path
        
        # 获取扩展名
        ext = Path(path).suffix.lower()
        
        # 检查 URL 中是否包含特定格式的参数
        url_lower = video_url.lower()
        if '.mp4' in url_lower:
            return '.mp4'
        elif '.m3u8' in url_lower:
            return '.m3u8'
        elif '.m3u' in url_lower:
            return '.m3u'
        elif '.mpd' in url_lower:
            return '.mpd'
        
        # 如果没有扩展名或者是常见的流媒体格式，默认使用 .m3u 播放列表
        # 这样可以支持大多数播放器播放网络视频
        if not ext or ext in ['.m3u8', '.m3u', '.ts', '.mpd']:
            return '.m3u'
        
        # 返回扩展名
        return ext

    def _sanitize_filename(self, filename):
        """清理文件名，移除非法字符"""
        import re
        # 移除或替换 Windows 文件名中的非法字符
        invalid_chars = '<>:"/\\|?*'
        for char in invalid_chars:
            filename = filename.replace(char, '_')
        # 限制长度
        if len(filename) > 100:
            filename = filename[:100]
        return filename.strip()

    def _cleanup_old_temp_files(self):
        """清理旧的临时文件（超过1天的）"""
        import tempfile
        from datetime import datetime, timedelta
        
        try:
            temp_dir = Path(tempfile.gettempdir())
            current_time = datetime.now()
            
            # 查找 ClassNEWS 相关的临时文件（标题_ClassNEWS_video 格式）
            for temp_file in temp_dir.glob("*_ClassNEWS_video*"):
                try:
                    # 获取文件修改时间
                    file_stat = temp_file.stat()
                    file_mtime = datetime.fromtimestamp(file_stat.st_mtime)
                    
                    # 如果文件超过1天，删除它
                    if current_time - file_mtime > timedelta(days=1):
                        temp_file.unlink()
                        print(f"已删除旧临时文件: {temp_file}")
                except Exception as e:
                    print(f"删除临时文件失败 {temp_file}: {e}")
        except Exception as e:
            print(f"清理临时文件失败: {e}")

    @Slot(str, str, result=bool)
    def openWithExternalPlayer(self, video_url, title):
        """使用系统默认播放器打开视频"""
        import subprocess
        import platform
        import os
        import tempfile
        from pathlib import Path
        import requests

        try:
            # 先清理旧临时文件
            self._cleanup_old_temp_files()
            
            # 检查视频 URL 是否可访问
            print(f"检查视频链接: {video_url}")
            try:
                # 发送 HEAD 请求检查链接
                response = requests.head(video_url, timeout=10, allow_redirects=True)
                content_type = response.headers.get('Content-Type', '')
                print(f"视频链接状态: {response.status_code}, Content-Type: {content_type}")
                
                # 检查是否是常见的视频格式
                supported_types = ['video/', 'application/vnd.apple.mpegurl', 'application/x-mpegurl']
                is_video = any(t in content_type for t in supported_types)
                
                if response.status_code != 200 and response.status_code != 206:
                    print(f"警告: 视频链接返回状态码 {response.status_code}")
                    # 不阻止播放，但记录警告
                    
            except Exception as e:
                print(f"检查视频链接失败: {e}")
                # 网络检查失败不阻止播放
            
            system = platform.system()
            if system == "Windows":
                # Windows: 根据视频格式创建临时文件
                
                # 获取文件扩展名
                file_ext = self._get_file_extension(video_url)
                
                # 使用标题创建文件名（清理非法字符），新闻标题在前
                safe_title = self._sanitize_filename(title)
                temp_dir = Path(tempfile.gettempdir())
                temp_file = Path(temp_dir) / f"{safe_title}_ClassNEWS_video{file_ext}"
                
                # 根据文件类型处理
                # 对于所有网络视频，都使用 .m3u 播放列表格式
                # 这是最通用的方式，支持大多数播放器
                temp_file = temp_file.with_suffix('.m3u')
                
                # 创建标准的 M3U 播放列表格式
                # 使用 #EXTM3U 头部和 #EXTINF 标签提高兼容性
                m3u_content = f"""#EXTM3U
#EXTINF:-1,{title}
{video_url}
#EXT-X-ENDLIST
"""
                temp_file.write_text(m3u_content, encoding='utf-8')
                print(f"创建播放列表: {temp_file}")
                print(f"播放列表内容:\n{m3u_content}")
                
                # 使用 ShellExecute 打开临时文件
                import ctypes
                shell32 = ctypes.windll.shell32
                
                result = shell32.ShellExecuteW(
                    None,
                    "open",
                    str(temp_file),
                    None,
                    None,
                    1
                )
                
                if result > 32:
                    print(f"已使用系统默认播放器打开: {title}")
                else:
                    # 如果 ShellExecute 失败，尝试直接使用已知的播放器
                    player_paths = [
                        Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WindowsApps" / "Microsoft.ZuneVideo_8wekyb3d8bbwe" / "Video.UI.exe",
                        Path(os.environ.get("ProgramFiles", "C:\\Program Files")) / "PotPlayer" / "PotPlayerMini64.exe",
                        Path(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)")) / "PotPlayer" / "PotPlayerMini.exe",
                        Path(os.environ.get("ProgramFiles", "C:\\Program Files")) / "VideoLAN" / "VLC" / "vlc.exe",
                        Path(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)")) / "VideoLAN" / "VLC" / "vlc.exe",
                    ]
                    
                    player_found = None
                    for player_path in player_paths:
                        if player_path.exists():
                            player_found = str(player_path)
                            break
                    
                    if player_found:
                        # 尝试使用播放列表文件
                        try:
                            subprocess.Popen([player_found, str(temp_file)])
                            print(f"已使用 {player_found} 打开: {title}")
                        except Exception as e:
                            print(f"使用播放列表失败，尝试直接打开URL: {e}")
                            # 如果播放列表失败，尝试直接打开 URL
                            subprocess.Popen([player_found, video_url])
                            print(f"已使用 {player_found} 直接打开URL: {title}")
                    else:
                        # 如果没有找到特定播放器，尝试直接用 URL 打开
                        result = shell32.ShellExecuteW(
                            None,
                            "open",
                            video_url,
                            None,
                            None,
                            1
                        )
                        if result <= 32:
                            raise Exception("未找到可用的视频播放器")
                    
            elif system == "Darwin":
                # macOS: 使用 open 命令
                subprocess.Popen(["open", video_url])
            else:
                # Linux: 使用 xdg-open
                subprocess.Popen(["xdg-open", video_url])
            print(f"已使用系统播放器打开: {title}")
            return True
        except Exception as e:
            error_msg = f"打开系统播放器失败: {e}"
            print(error_msg)
            self.parseError.emit(error_msg)
            return False


class VideoParseWorker(QThread):
    """在后台线程中解析视频"""
    video_parsed = Signal(str, str)  # video_url, title
    parse_error = Signal(str)  # error message

    def __init__(self, pid, title, parent=None):
        super().__init__(parent)
        self.pid = pid
        self.title = title

    def run(self):
        try:
            from cctv_video import get_cctv_video, upgrade_hls_quality
            import requests

            result = get_cctv_video(self.pid)

            if result["success"]:
                hls_url = result["hls_url"]

                # 尝试升级高清
                hd_url = upgrade_hls_quality(hls_url, "4000")

                # 验证高清是否可用
                try:
                    r = requests.head(hd_url, timeout=5)
                    if r.status_code == 200:
                        video_url = hd_url
                    else:
                        video_url = hls_url
                except:
                    video_url = hls_url

                self.video_parsed.emit(video_url, self.title)
            else:
                self.parse_error.emit(result.get("error", "未知错误"))
        except Exception as e:
            print(f"解析视频失败: {e}")
            self.parse_error.emit(str(e))


class ProgramSearchWorker(QThread):
    """在后台线程中搜索节目并解析视频"""
    video_parsed = Signal(str, str)  # video_url, title
    parse_error = Signal(str)  # error message

    def __init__(self, program_name, parent=None):
        super().__init__(parent)
        self.program_name = program_name

    def run(self):
        try:
            from cctv_video import get_video_by_program_name

            result = get_video_by_program_name(self.program_name)

            if result["success"]:
                hls_url = result.get("hls_url", "")
                title = result.get("title", self.program_name)

                if hls_url:
                    self.video_parsed.emit(hls_url, title)
                else:
                    self.parse_error.emit("未找到视频播放地址")
            else:
                error_msg = result.get("error", "未知错误")
                suggestions = result.get("suggestions", [])
                if suggestions:
                    error_msg += f"\n\n您可以尝试以下节目:\n" + "\n".join([f"• {s}" for s in suggestions])
                self.parse_error.emit(error_msg)
        except Exception as e:
            print(f"搜索节目失败: {e}")
            self.parse_error.emit(str(e))


class WindowManager(QObject):
    """窗口管理器，用于管理动态创建的窗口"""
    
    def __init__(self, win_event_filter=None, parent=None):
        super().__init__(parent)
        self._win_event_filter = win_event_filter
    
    @Slot(QObject)
    def registerWindow(self, window):
        """注册动态创建的窗口到 WinEventFilter"""
        if self._win_event_filter and window:
            try:
                # 将窗口添加到 WinEventFilter 的窗口列表中
                if hasattr(self._win_event_filter, 'windows'):
                    self._win_event_filter.windows.append(window)
                    print(f"窗口已添加到 WinEventFilter 列表: {window}")

                    # 无论窗口是否可见，都连接 visibleChanged 信号
                    # 这样窗口显示时会自动初始化
                    try:
                        window.visibleChanged.connect(
                            lambda visible, w=window: self._on_visible_changed(visible, w)
                        )
                        print(f"已连接 visibleChanged 信号")
                    except Exception as e2:
                        print(f"连接信号失败: {e2}")

                    # 如果窗口已经可见，立即初始化
                    if window.isVisible():
                        print(f"窗口已可见，立即初始化")
                        self._win_event_filter._init_window_handle(window)

                    # 设置 Windows 11 圆角
                    self._set_window_round_corners(window)
                    
                    # 设置窗口图标
                    self._set_window_icon(window)
            except Exception as e:
                print(f"注册窗口失败: {e}")

    def _set_window_round_corners(self, window):
        """设置窗口圆角（Windows 11）"""
        try:
            import ctypes
            from ctypes import wintypes

            hwnd = int(window.winId())
            if hwnd == 0:
                return

            # DWMWA_WINDOW_CORNER_PREFERENCE = 33
            # DWMWCP_ROUND = 2
            DWMWA_WINDOW_CORNER_PREFERENCE = 33
            DWMWCP_ROUND = 2

            # 设置圆角偏好
            ctypes.windll.dwmapi.DwmSetWindowAttribute(
                hwnd,
                DWMWA_WINDOW_CORNER_PREFERENCE,
                ctypes.byref(ctypes.c_int(DWMWCP_ROUND)),
                ctypes.sizeof(ctypes.c_int)
            )
            print(f"窗口圆角已设置: {hwnd}")
        except Exception as e:
            print(f"设置窗口圆角失败: {e}")

    def _set_window_icon(self, window):
        """设置窗口图标（使用 Windows API）"""
        try:
            from pathlib import Path
            import ctypes
            from ctypes import wintypes
            
            icon_path = Path(__file__).parent / "assets" / "logo.ico"
            if not icon_path.exists():
                print(f"窗口图标文件不存在: {icon_path}")
                return
            
            # 获取窗口句柄
            hwnd = int(window.winId())
            
            # 加载图标
            hicon = ctypes.windll.user32.LoadImageW(
                None, str(icon_path), 1, 0, 0,
                0x00000010 | 0x00002000  # LR_LOADFROMFILE | LR_DEFAULTSIZE
            )
            
            if hicon:
                # 设置窗口图标
                WM_SETICON = 0x80
                ICON_BIG = 1
                ICON_SMALL = 0
                ctypes.windll.user32.SendMessageW(hwnd, WM_SETICON, ICON_SMALL, hicon)
                ctypes.windll.user32.SendMessageW(hwnd, WM_SETICON, ICON_BIG, hicon)
                print(f"窗口图标已设置: {icon_path}")
            else:
                print(f"加载图标失败: {icon_path}")
        except Exception as e:
            print(f"设置窗口图标失败: {e}")

    def _on_visible_changed(self, visible, window):
        """窗口可见性改变时的回调"""
        if visible and self._win_event_filter:
            if window not in self._win_event_filter.hwnds:
                self._win_event_filter._init_window_handle(window)


def set_windows_app_id(app_id: str):
    """设置 Windows 应用程序 ID，用于任务栏图标显示"""
    try:
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(app_id)
        print(f"Windows App ID 已设置: {app_id}")
    except Exception as e:
        print(f"设置 Windows App ID 失败: {e}")


def refresh_taskbar_icon():
    """刷新 Windows 任务栏图标"""
    try:
        import ctypes
        HWND_BROADCAST = 0xFFFF
        WM_SETTINGCHANGE = 0x1A
        SMTO_ABORTIFHUNG = 0x0002
        ctypes.windll.user32.SendMessageTimeoutW(
            HWND_BROADCAST, WM_SETTINGCHANGE, 0, 0,
            SMTO_ABORTIFHUNG, 5000, None
        )
        print("任务栏图标已刷新")
    except Exception as e:
        print(f"刷新任务栏图标失败: {e}")


def set_taskbar_icon(hwnd: int, icon_path: str):
    """直接设置 Windows 任务栏图标"""
    try:
        import ctypes
        from ctypes import wintypes

        # 加载图标
        hicon = ctypes.windll.user32.LoadImageW(
            None, str(icon_path), 1, 0, 0,
            0x00000010 | 0x00002000  # LR_LOADFROMFILE | LR_DEFAULTSIZE
        )
        if hicon:
            WM_SETICON = 0x80
            ICON_BIG = 1
            ICON_SMALL = 0
            ctypes.windll.user32.SendMessageW(hwnd, WM_SETICON, ICON_SMALL, hicon)
            ctypes.windll.user32.SendMessageW(hwnd, WM_SETICON, ICON_BIG, hicon)
            print(f"任务栏图标已直接设置: {icon_path}")
            return True
        else:
            print(f"加载图标失败: {icon_path}")
            return False
    except Exception as e:
        print(f"设置任务栏图标失败: {e}")
        return False


class ProtocolManager(QObject):
    """协议管理器，用于注册和处理 classnews:// 协议"""

    protocolTriggered = Signal(str, str, dict)  # pid, title, options
    protocolNewsReady = Signal(str, str, dict)  # 获取到新闻后通知QML显示确认窗口: pid, title, options
    closePlayerRequested = Signal()  # 关闭播放器请求
    closeMainWindowRequested = Signal()  # 关闭主窗口请求
    testResultReady = Signal(str)  # 测试结果就绪（JSON字符串）

    def __init__(self, video_manager=None, news_manager=None, config_manager=None, parent=None):
        super().__init__(parent)
        self._video_manager = video_manager
        self._news_manager = news_manager
        self._config_manager = config_manager
        self._protocol_name = "classnews"
        self._app_path = Path(sys.executable if getattr(sys, 'frozen', False) else __file__).parent
        
        # 确定正确的可执行文件路径
        if getattr(sys, 'frozen', False):
            # 打包后的可执行文件
            self._exe_path = sys.executable
        else:
            # 开发环境 - 尝试找到正确的 Python 解释器和脚本路径
            # 检查是否存在打包后的 exe 文件
            exe_path = Path(__file__).parent / "ClassNEWS.exe"
            if exe_path.exists():
                self._exe_path = str(exe_path)
            else:
                # 使用 Python 脚本方式
                self._exe_path = str(Path(__file__).parent / "main.py")
    
    def _get_app_name(self):
        """获取应用程序显示名称"""
        return "ClassNEWS"
    
    @Slot(result=bool)
    def registerProtocol(self):
        """注册 classnews:// 协议到 Windows 注册表"""
        try:
            import winreg
            
            # 创建协议键
            protocol_key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, f"Software\\Classes\\{self._protocol_name}")
            winreg.SetValue(protocol_key, "", winreg.REG_SZ, f"URL:{self._get_app_name()} Protocol")
            winreg.SetValueEx(protocol_key, "URL Protocol", 0, winreg.REG_SZ, "")
            
            # 添加 FriendlyTypeName
            winreg.SetValueEx(protocol_key, "FriendlyTypeName", 0, winreg.REG_SZ, f"{self._get_app_name()} Video")
            
            # 创建 DefaultIcon 键
            icon_key = winreg.CreateKey(protocol_key, "DefaultIcon")
            icon_path = Path(__file__).parent / "assets" / "logo.ico"
            winreg.SetValue(icon_key, "", winreg.REG_SZ, str(icon_path) if icon_path.exists() else self._exe_path)
            
            # 创建 shell\\open\\command 键
            command_key = winreg.CreateKey(protocol_key, "shell\\open\\command")
            
            # 检查是否是 exe 文件
            if self._exe_path.endswith('.exe'):
                # 直接使用可执行文件
                command = f'"{self._exe_path}" --protocol "%1"'
            else:
                # Python 脚本方式
                python_exe = sys.executable
                command = f'"{python_exe}" "{self._exe_path}" --protocol "%1"'
            
            winreg.SetValue(command_key, "", winreg.REG_SZ, command)
            
            print(f"协议注册命令: {command}")
            
            # 关闭键
            winreg.CloseKey(command_key)
            winreg.CloseKey(icon_key)
            winreg.CloseKey(protocol_key)
            
            print(f"协议 {self._protocol_name}:// 已注册")
            return True
        except Exception as e:
            print(f"注册协议失败: {e}")
            return False
    
    @Slot(result=bool)
    def unregisterProtocol(self):
        """从 Windows 注册表中移除 classnews:// 协议"""
        try:
            import winreg
            
            # 删除协议键
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, f"Software\\Classes\\{self._protocol_name}\\shell\\open\\command")
            except WindowsError:
                pass
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, f"Software\\Classes\\{self._protocol_name}\\shell\\open")
            except WindowsError:
                pass
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, f"Software\\Classes\\{self._protocol_name}\\shell")
            except WindowsError:
                pass
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, f"Software\\Classes\\{self._protocol_name}\\DefaultIcon")
            except WindowsError:
                pass
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, f"Software\\Classes\\{self._protocol_name}")
            except WindowsError:
                pass
            
            print(f"协议 {self._protocol_name}:// 已取消注册")
            return True
        except Exception as e:
            print(f"取消注册协议失败: {e}")
            return False
    
    @Slot(result=bool)
    def isProtocolRegistered(self):
        """检查协议是否已注册"""
        try:
            import winreg
            try:
                key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, f"Software\\Classes\\{self._protocol_name}")
                winreg.CloseKey(key)
                return True
            except WindowsError:
                return False
        except Exception as e:
            print(f"检查协议注册状态失败: {e}")
            return False
    
    def parseProtocolUrl(self, url):
        """解析协议 URL，提取参数

        支持的参数：
        - pid: 视频 ID（必需）
        - title: 视频标题（可选）
        - rate: 播放倍率，如 1.0, 1.5, 2.0（可选，默认 1.0）
        - volume: 音量，0-100（可选，默认 50）
        - time: 开始时间（秒）（可选，默认 0）
        - fullscreen: 是否全屏播放，true/false（可选，默认 false）
        """
        from urllib.parse import urlparse, parse_qs

        try:
            # 解析 URL
            parsed = urlparse(url)

            # 检查协议名称
            if parsed.scheme != self._protocol_name:
                return None

            # 解析查询参数
            params = parse_qs(parsed.query)

            # 提取 action（处理 path 如 /play/ 或 play/ 或 /play）
            action = "play"  # 默认动作
            # 优先从 netloc 获取 action（如 classnews://close）
            if parsed.netloc and parsed.netloc not in ["play", "close", "test"]:
                # netloc 不是已知的 action，可能是带 path 的格式
                if parsed.path:
                    path_clean = parsed.path.strip("/")
                    if path_clean:
                        action = path_clean
            elif parsed.netloc in ["play", "close", "test"]:
                # classnews://close 这种格式
                action = parsed.netloc
            elif parsed.path:
                # 移除前后的斜杠，如 /play/ -> play
                path_clean = parsed.path.strip("/")
                if path_clean:
                    action = path_clean

            # 提取参数
            result = {
                "action": action,
                "pid": params.get("pid", [""])[0],
                "title": params.get("title", [""])[0] or "视频",
                # 可选参数
                "rate": float(params.get("rate", ["1.0"])[0]) if params.get("rate") else 1.0,
                "volume": int(params.get("volume", ["50"])[0]) if params.get("volume") else 50,
                "time": int(params.get("time", ["0"])[0]) if params.get("time") else 0,
                "fullscreen": params.get("fullscreen", ["false"])[0].lower() == "true",
            }

            # 验证参数范围
            result["rate"] = max(0.5, min(3.0, result["rate"]))  # 限制倍率 0.5-3.0
            result["volume"] = max(0, min(100, result["volume"]))  # 限制音量 0-100
            result["time"] = max(0, result["time"])  # 时间不能为负

            return result
        except Exception as e:
            print(f"解析协议 URL 失败: {e}")
            return None
    
    def handleProtocolUrl(self, url):
        """处理协议 URL"""
        params = self.parseProtocolUrl(url)
        if not params:
            return False

        action = params.get("action", "play")

        # 处理不同动作
        if action == "test":
            # 测试协议，返回版本号和状态
            print("处理测试协议请求")
            build_info = load_build_info()
            test_result = {
                "status": "ok",
                "version": build_info.get("version", "unknown"),
                "buildDate": build_info.get("buildDate", "unknown"),
                "buildNumber": build_info.get("buildNumber", "unknown"),
                "platform": platform.system(),
                "pythonVersion": platform.python_version(),
                "timestamp": datetime.now().isoformat()
            }
            print(f"测试协议响应: {test_result}")
            self.testResultReady.emit(json.dumps(test_result, ensure_ascii=False, indent=2))
            return True
        
        elif action == "close":
            # 关闭视频播放器和主窗口（但不退出软件）
            print("处理关闭请求")
            self.closePlayerRequested.emit()
            self.closeMainWindowRequested.emit()
            return True
        
        elif action == "play":
            # 播放视频
            pid = params.get("pid")
            title = params.get("title", "视频")

            if not pid:
                print("协议 URL 缺少 pid 参数")
                return False

            # 提取可选参数
            options = {
                "pid": pid,
                "rate": params.get("rate", 1.0),
                "volume": params.get("volume", 50),
                "time": params.get("time", 0),
                "fullscreen": params.get("fullscreen", False)  # 已经是布尔值
            }

            # 打印调试信息
            print(f"协议参数解析结果：fullscreen={options['fullscreen']}, 类型={type(options['fullscreen'])}")

            # 如果协议 URL 中没有指定 fullscreen 参数（值为 None 或 False），检查配置管理器的设置
            if params.get("fullscreen") is None and self._config_manager and self._config_manager.fullscreenPlayback:
                options["fullscreen"] = True
                print("配置管理器：协议调用时全屏播放已启用")
                print(f"最终 options: {options}")

            # 如果 pid 是 "today" 或 "latest"，先获取当天的完整版新闻
            if pid.lower() in ["today", "latest", "zhaowentianxia", "朝闻天下"]:
                print(f"检测到特殊 pid: {pid}，尝试获取当天完整版新闻")
                if self._news_manager:
                    today_news = self._news_manager.getTodayFullVersionNews()
                    # 检查 today_news 是否是有效的字典且包含非空的 pid
                    if today_news and isinstance(today_news, dict):
                        news_pid = today_news.get('pid')
                        if news_pid:
                            pid = news_pid
                            title = today_news.get('title', title)
                            options['pid'] = pid  # 更新options中的pid
                            print(f"获取到当天新闻: {title} ({pid})")
                            # 发送信号给QML显示确认窗口，让用户确认是否播放
                            self.protocolNewsReady.emit(pid, title, options)
                            return True
                        else:
                            print(f"获取到的新闻没有有效的 pid: {today_news}")
                            return False
                    else:
                        print(f"未获取到当天新闻或返回格式错误: {today_news}")
                        return False
                else:
                    print("NewsManager 未初始化，无法获取当天新闻")
                    return False
            else:
                # 普通pid，直接触发播放（需要获取新闻标题）
                print(f"处理协议请求: pid={pid}, title={title}, options={options}")
                # 触发信号，让 QML 显示提示对话框
                self.protocolTriggered.emit(pid, title, options)
                return True
        
        else:
            print(f"未知的协议动作: {action}")
            return False


class TrayManager(QObject):
    """系统托盘管理器"""
    
    navigateToSettingsRequested = Signal()
    
    def __init__(self, window, icon_path, parent=None):
        super().__init__(parent)
        self.window = window
        self.icon_path = icon_path
        self.tray_icon = None
        self.setup_tray()
    
    def setup_tray(self):
        """设置系统托盘图标"""
        if not QSystemTrayIcon.isSystemTrayAvailable():
            print("系统不支持托盘图标")
            return
        
        # 创建托盘图标
        app_icon = QIcon(str(self.icon_path))
        self.tray_icon = QSystemTrayIcon(app_icon, self)
        self.tray_icon.setToolTip("ClassNEWS")
        
        # 创建标准右键菜单
        self.create_context_menu()
        
        # 点击托盘图标显示主窗口
        self.tray_icon.activated.connect(self.on_tray_activated)
        
        self.tray_icon.show()
        print("系统托盘图标已创建")
    
    def create_context_menu(self):
        """创建标准右键菜单"""
        menu = QMenu()
        
        # 显示主窗口
        show_action = QAction("显示主窗口", self)
        show_action.triggered.connect(self.show_window)
        menu.addAction(show_action)
        
        menu.addSeparator()
        
        # 退出
        quit_action = QAction("退出", self)
        quit_action.triggered.connect(self.quitApplication)
        menu.addAction(quit_action)
        
        self.tray_icon.setContextMenu(menu)
    
    def on_tray_activated(self, reason):
        """托盘图标被激活时的处理"""
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            # 单击左键 - 显示主窗口
            self.show_window()
        # 右键点击会自动显示 setContextMenu 设置的菜单
    
    def show_window(self):
        """显示主窗口"""
        if self.window:
            self.window.show()
            self.window.raise_()
            self.window.requestActivate()
    
    @Slot()
    def navigateToSettings(self):
        """导航到设置页面"""
        self.show_window()
        self.navigateToSettingsRequested.emit()
    
    @Slot(str, str)
    def showTrayMessage(self, title, message):
        """显示托盘消息"""
        if self.tray_icon:
            self.tray_icon.showMessage(title, message, QSystemTrayIcon.MessageIcon.Information, 2000)
    
    @Slot(result=bool)
    def isTrayIconAvailable(self):
        """检查托盘图标是否可用"""
        return self.tray_icon is not None
    
    @Slot()
    def quitApplication(self):
        """退出应用程序"""
        if self.tray_icon:
            self.tray_icon.hide()
        QApplication.quit()


def main():
    # 解析命令行参数
    protocol_url = None
    background_mode = "--background" in sys.argv
    
    if "--protocol" in sys.argv:
        protocol_index = sys.argv.index("--protocol")
        if protocol_index + 1 < len(sys.argv):
            protocol_url = sys.argv[protocol_index + 1]
            print(f"收到协议 URL: {protocol_url}")
    
    if background_mode:
        print("后台模式启动，不显示主窗口")

    # 设置 Windows 应用程序 ID（必须在创建 QApplication 之前）
    if sys.platform == "win32":
        set_windows_app_id("ClassNEWS.App.1.0")

    # 检查是否已有实例在运行（单实例）
    from PySide6.QtNetwork import QLocalSocket, QLocalServer
    socket = QLocalSocket()
    socket.connectToServer("ClassNEWS_SingleInstance")
    if socket.waitForConnected(500):
        # 已有实例在运行
        print("ClassNEWS 已在运行...")
        
        # 如果有协议 URL，发送给现有实例
        if protocol_url:
            socket.write(f"PROTOCOL:{protocol_url}".encode())
            print(f"发送协议 URL 到现有实例: {protocol_url}")
        else:
            socket.write(b"SHOW_WINDOW")
            print("发送激活窗口请求到现有实例")
        
        socket.flush()
        socket.waitForBytesWritten(500)
        socket.disconnectFromServer()
        sys.exit(0)
    
    # 创建本地服务器以监听新实例
    local_server = QLocalServer()
    local_server.listen("ClassNEWS_SingleInstance")

    # 创建 QApplication
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)  # 关闭最后一个窗口时不退出应用
    
    # 安装 Qt 消息处理器（处理 qml: 输出的编码问题）
    qInstallMessageHandler(qt_message_handler)

    # 初始化日志系统（在设置图标之前，记录启动信息）
    logger = init_logger()
    
    # 设置应用程序图标
    icon_path = Path(__file__).parent / "assets" / "logo.ico"
    if icon_path.exists():
        app_icon = QIcon(str(icon_path))
        app.setWindowIcon(app_icon)
        logger.success(LogCategory.SYSTEM, "Main", f"Application icon set / 应用程序图标已设置: {icon_path}")
    else:
        logger.warning(LogCategory.SYSTEM, "Main", f"Icon file not found / 图标文件不存在: {icon_path}", error_code="ICON_001")

    try:
        # 创建新闻管理器
        news_manager = NewsManager()
        logger.success(LogCategory.DATA, "Main", "News manager created / 新闻管理器已创建")
        
        # 快速获取系统信息（不包含公网IP，避免阻塞启动）
        system_info = get_system_info_sync()
        logger.info(LogCategory.SYSTEM, "Main", f"System info loaded / 系统信息已加载: {system_info.get('os', 'unknown')}")
        
        # 在后台线程中异步获取完整的系统信息（包括公网IP）
        system_info_worker = SystemInfoWorker()
        def on_system_info_ready(info):
            # 更新 systemInfo 上下文属性
            window.engine.rootContext().setContextProperty("systemInfo", info)
            logger.info(LogCategory.SYSTEM, "Main", f"System info updated with IP / 系统信息已更新: {info.get('ip', 'unknown')}")
        system_info_worker.info_ready.connect(on_system_info_ready)
        system_info_worker.start()
        
        # 创建窗口管理器，用于管理动态创建的窗口
        window_manager = WindowManager(None)  # 先创建，后面再设置 win_event_filter
        logger.success(LogCategory.UI, "Main", "Window manager created / 窗口管理器已创建")
        
        # 创建配置管理器
        config_manager = ConfigManager()
        logger.success(LogCategory.CONFIG, "Main", "Config manager created / 配置管理器已创建")
        
        # 创建视频管理器（在加载QML之前创建）
        video_manager = VideoManager(config_manager)
        logger.success(LogCategory.VIDEO, "Main", "Video manager created / 视频管理器已创建")

        # 创建协议管理器
        protocol_manager = ProtocolManager(video_manager, news_manager, config_manager)
        logger.success(LogCategory.SYSTEM, "Main", "Protocol manager created / 协议管理器已创建")

        # 创建下载管理器
        download_manager = DownloadManager()
        logger.success(LogCategory.VIDEO, "Main", "Download manager created / 下载管理器已创建")

        # 先创建 RinUIWindow 对象（不加载 QML）
        window = RinUIWindow(None)
        logger.success(LogCategory.UI, "Main", "RinUIWindow created / RinUIWindow 已创建")

        # 在加载 QML 之前设置上下文属性
        window.engine.rootContext().setContextProperty("newsManager", news_manager)
        window.engine.rootContext().setContextProperty("systemInfo", system_info)
        window.engine.rootContext().setContextProperty("windowManager", window_manager)
        window.engine.rootContext().setContextProperty("videoManager", video_manager)
        window.engine.rootContext().setContextProperty("configManager", config_manager)
        window.engine.rootContext().setContextProperty("appLogger", logger)
        window.engine.rootContext().setContextProperty("protocolManager", protocol_manager)
        window.engine.rootContext().setContextProperty("downloadManager", download_manager)
        
        # 设置调试模式（非打包环境为调试模式）
        debug_mode = not hasattr(sys, '_MEIPASS')
        window.engine.rootContext().setContextProperty("debugMode", debug_mode)
        print(f"调试模式: {debug_mode}")
        
        # 获取脚本所在目录（开发环境下使用脚本目录，打包环境下使用 MEIPASS）
        if hasattr(sys, '_MEIPASS'):
            base_dir = Path(sys._MEIPASS)
        else:
            # 开发环境：使用脚本所在目录
            base_dir = Path(__file__).parent.resolve()
        
        # 设置项目基础路径，供 QML 使用（使用 file:/// 协议，避免 Network error）
        project_base_path = "file:///" + str(base_dir).replace('\\', '/')
        window.engine.rootContext().setContextProperty("projectBasePath", project_base_path)
        print(f"项目基础路径: {project_base_path}")
        
        logger.success(LogCategory.SYSTEM, "Main", "Context properties set / 上下文属性已设置")

        # 现在加载 QML 文件
        qml_path = base_dir / "main.qml"
        window.load(str(qml_path))

        # 从 RinUIWindow 获取 win_event_filter 并设置给 window_manager
        win_event_filter = getattr(window, 'win_event_filter', None)
        logger.debug(LogCategory.SYSTEM, "Main", f"WinEventFilter retrieved: {win_event_filter}")
        
        # 替换为自定义窗口事件过滤器，修复标题栏拖动问题
        if win_event_filter and sys.platform == "win32":
            from custom_window_filter import CustomWindowEventFilter
            
            # 移除旧的过滤器
            app.removeNativeEventFilter(win_event_filter)
            
            # 创建并安装新的过滤器
            custom_filter = CustomWindowEventFilter(window.windows)
            app.installNativeEventFilter(custom_filter)
            
            # 更新引用
            window.win_event_filter = custom_filter
            win_event_filter = custom_filter
            logger.success(LogCategory.SYSTEM, "Main", "Custom window event filter installed / 自定义窗口事件过滤器已安装")
        
        window_manager._win_event_filter = win_event_filter

        # 创建系统托盘管理器
        tray_manager = TrayManager(window, icon_path)
        logger.success(LogCategory.UI, "Main", "Tray manager created / 系统托盘管理器已创建")

        # 在 QML 中处理关闭事件
        window.engine.rootContext().setContextProperty("trayManager", tray_manager)

        # 处理新实例的连接请求（单实例）
        def on_new_connection():
            """当有新实例尝试启动时"""
            client_socket = local_server.nextPendingConnection()
            if client_socket:
                client_socket.waitForReadyRead(500)
                data = client_socket.readAll().data()
                if data == b"SHOW_WINDOW":
                    logger.info(LogCategory.SYSTEM, "Main", "Received activate window request / 收到激活窗口请求")
                    # 显示并激活主窗口（强制到前台）
                    _force_activate_window(window)
                elif data.startswith(b"PROTOCOL:"):
                    # 处理协议 URL
                    protocol_url = data[9:].decode('utf-8')
                    logger.info(LogCategory.SYSTEM, "Main", f"Received protocol URL / 收到协议 URL: {protocol_url}")
                    # 处理协议 URL（不显示主界面，直接播放视频）
                    protocol_manager.handleProtocolUrl(protocol_url)
                client_socket.disconnectFromServer()
        
        def _force_activate_window(win):
            """强制激活窗口到前台"""
            # Windows 特定：使用 Windows API 强制前台
            if sys.platform == "win32":
                try:
                    import ctypes
                    hwnd = int(win.winId())
                    
                    # 检查窗口是否最小化 (WS_MINIMIZE = 0x20000000)
                    GWL_STYLE = -16
                    WS_MINIMIZE = 0x20000000
                    style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_STYLE)
                    is_minimized = (style & WS_MINIMIZE) != 0
                    
                    if is_minimized:
                        # 如果窗口最小化，恢复它 (SW_RESTORE = 9)
                        ctypes.windll.user32.ShowWindow(hwnd, 9)
                    else:
                        # 否则正常显示 (SW_SHOW = 5)
                        ctypes.windll.user32.ShowWindow(hwnd, 5)
                    
                    # 强制设置前台窗口
                    ctypes.windll.user32.SetForegroundWindow(hwnd)
                    print(f"Windows API: 窗口已强制激活到前台")
                except Exception as e:
                    print(f"Windows API 激活窗口失败: {e}")
            
            # 使用 Qt 方法（备用）
            try:
                win.show()
                win.raise_()
                win.requestActivate()
            except Exception as e:
                print(f"Qt 激活窗口失败: {e}")
        
        local_server.newConnection.connect(on_new_connection)
        logger.success(LogCategory.SECURITY, "Main", "Single instance server started / 单实例服务器已启动")

        # 连接视频解析信号到播放器 - 在QML中处理
        # 信号会通过 videoManager.videoParsed 自动传递到 QML

        # 延迟获取新闻，等待窗口完全显示后再加载（提升启动速度）
        QTimer.singleShot(2000, news_manager.refreshNews)
        logger.info(LogCategory.DATA, "Main", "News fetch scheduled after window shown / 新闻获取已调度（窗口显示后）")

        # 处理启动时传入的协议 URL
        if protocol_url:
            # 如果是通过协议启动，隐藏主窗口，只显示视频通知窗口
            window.hide()
            logger.info(LogCategory.SYSTEM, "Main", "Main window hidden for protocol startup / 协议启动时隐藏主窗口")
            
            # 定义协议处理函数，在新闻加载完成后执行
            def handle_protocol_after_news_loaded():
                logger.info(LogCategory.SYSTEM, "Main", f"Processing startup protocol URL after news loaded / 新闻加载完成后处理协议: {protocol_url}")
                protocol_manager.handleProtocolUrl(protocol_url)
            
            # 连接新闻加载完成信号
            news_manager.newsChanged.connect(handle_protocol_after_news_loaded)
            logger.info(LogCategory.SYSTEM, "Main", f"Startup protocol URL will be processed after news loaded / 启动协议 URL 将在新闻加载后处理: {protocol_url}")
        elif background_mode:
            # 后台模式启动，不显示主窗口，只在系统托盘运行
            window.hide()
            logger.info(LogCategory.SYSTEM, "Main", "Background mode: main window hidden / 后台模式：主窗口已隐藏")

        # 获取窗口句柄并设置任务栏图标
        if sys.platform == "win32" and icon_path.exists():
            # 延迟一点确保窗口已经创建
            QTimer.singleShot(100, lambda: set_taskbar_icon(int(window.winId()), str(icon_path)))
            # 再次刷新确保生效
            QTimer.singleShot(500, refresh_taskbar_icon)
            logger.info(LogCategory.UI, "Main", "Taskbar icon setup scheduled / 任务栏图标设置已调度")

        logger.success(LogCategory.SYSTEM, "Main", "Application startup completed / 应用程序启动完成")

    except Exception as e:
        logger.exception(LogCategory.SYSTEM, "Main", f"Failed to load RinUI window / 加载 RinUI 窗口失败: {e}", error_code="STARTUP_001")
        traceback.print_exc()
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
