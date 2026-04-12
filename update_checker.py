"""
软件更新检查器 - 支持开机自动检查和系统通知
"""
import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any
from pathlib import Path
from PySide6.QtCore import QObject, Signal, Slot, QThread
from PySide6.QtWidgets import QSystemTrayIcon
import requests

logger = logging.getLogger(__name__)


class UpdateCheckWorker(QThread):
    """后台检查更新的工作线程"""
    result_ready = Signal(object)  # 发送检查结果
    error_occurred = Signal(str)   # 发送错误信息
    
    def __init__(self, current_version: str, github_api_url: str):
        super().__init__()
        self.current_version = current_version
        self.github_api_url = github_api_url
    
    def run(self):
        """在后台线程执行检查"""
        try:
            logger.info(f"检查更新，当前版本：{self.current_version}")
            
            # 配置代理（如果设置了环境变量）
            import os
            proxies = {}
            if os.environ.get('HTTP_PROXY'):
                proxies['http'] = os.environ.get('HTTP_PROXY')
            if os.environ.get('HTTPS_PROXY'):
                proxies['https'] = os.environ.get('HTTPS_PROXY')
            
            # 调用 GitHub API
            response = requests.get(self.github_api_url, timeout=10, proxies=proxies)
            response.raise_for_status()
            
            release_data = response.json()
            
            latest_version = release_data.get('tag_name', '')
            
            # 比较版本
            if self._isNewerVersion(latest_version, self.current_version):
                # 有新版本
                release_date = release_data.get('published_at', '')
                download_url = release_data.get('html_url', '')
                changelog = release_data.get('body', '')
                
                # 格式化日期
                try:
                    date_obj = datetime.fromisoformat(release_date.replace('Z', '+00:00'))
                    release_date_str = date_obj.strftime('%Y-%m-%d')
                except:
                    release_date_str = release_date
                
                logger.info(f"发现新版本：{latest_version}")
                self.result_ready.emit({
                    'has_update': True,
                    'version': latest_version,
                    'release_date': release_date_str,
                    'download_url': download_url,
                    'changelog': changelog
                })
            else:
                logger.info("已是最新版本")
                self.result_ready.emit({'has_update': False})
                
        except requests.exceptions.RequestException as e:
            error_msg = f"检查更新失败：{str(e)}"
            logger.error(error_msg)
            self.error_occurred.emit(error_msg)
        except Exception as e:
            error_msg = f"检查更新时发生错误：{str(e)}"
            logger.error(error_msg)
            self.error_occurred.emit(error_msg)
    
    def _isNewerVersion(self, latest: str, current: str) -> bool:
        """比较版本号，判断是否有新版本"""
        try:
            import re
            
            # 移除 'v' 前缀和空格
            latest_clean = latest.lstrip('v').strip()
            current_clean = current.lstrip('v').strip()
            
            # 提取数字部分（处理 "Beta1.0" 这种情况）
            # 从 "Beta1.0" 提取出 "1.0"
            latest_match = re.search(r'(\d+(?:\.\d+)*)', latest_clean)
            current_match = re.search(r'(\d+(?:\.\d+)*)', current_clean)
            
            if not latest_match or not current_match:
                logger.warning(f"无法解析版本号：latest={latest}, current={current}")
                return False
            
            latest_numeric = latest_match.group(1)
            current_numeric = current_match.group(1)
            
            # 解析版本号
            latest_parts = [int(x) for x in latest_numeric.split('.')]
            current_parts = [int(x) for x in current_numeric.split('.')]
            
            # 补齐长度
            while len(latest_parts) < len(current_parts):
                latest_parts.append(0)
            while len(current_parts) < len(latest_parts):
                current_parts.append(0)
            
            # 逐位比较
            for i in range(len(latest_parts)):
                if latest_parts[i] > current_parts[i]:
                    return True
                elif latest_parts[i] < current_parts[i]:
                    return False
            
            return False
            
        except Exception as e:
            logger.error(f"版本比较失败：{e}")
            return False


class UpdateChecker(QObject):
    """软件更新检查器 - 支持开机自动检查和系统通知"""
    
    # 信号
    updateAvailable = Signal(str, str, str, str)  # version, releaseDate, downloadUrl, changelog
    noUpdate = Signal()
    checkFailed = Signal(str)  # error message
    
    def __init__(self, current_version: str, config_manager=None):
        super().__init__()
        self.current_version = current_version
        self.github_api_url = "https://api.github.com/repos/apanzinc/ClassNEWS/releases/latest"
        self.latest_release = None
        self._worker = None
        self._config_manager = config_manager
        self._skipped_versions = set()  # 用户选择跳过的版本
        
        # 加载跳过的版本
        self._load_skipped_versions()
    
    def _load_skipped_versions(self):
        """加载用户选择跳过的版本"""
        if self._config_manager:
            skipped = self._config_manager.get("skipped_versions", [])
            self._skipped_versions = set(skipped)
    
    def _save_skipped_versions(self):
        """保存跳过的版本"""
        if self._config_manager:
            self._config_manager.set("skipped_versions", list(self._skipped_versions))
    
    @Slot()
    def checkForUpdates(self, show_notification=True):
        """
        异步检查更新（不阻塞 UI）
        
        Args:
            show_notification: 是否显示系统通知（默认 True）
        """
        if self._worker and self._worker.isRunning():
            logger.info("检查更新正在进行中，跳过")
            return
        
        # 创建工作线程
        self._worker = UpdateCheckWorker(self.current_version, self.github_api_url)
        self._worker.result_ready.connect(lambda result: self._on_result_ready(result, show_notification))
        self._worker.error_occurred.connect(self._on_error_occurred)
        self._worker.start()
        logger.info(f"已启动后台检查更新线程（通知：{show_notification}）")
    
    def checkForUpdatesInBackground(self):
        """后台静默检查更新（开机启动时使用，不显示通知）"""
        self.checkForUpdates(show_notification=False)
    
    def _on_result_ready(self, result, show_notification=True):
        """处理检查结果"""
        if result.get('has_update'):
            version = result['version']
            
            # 检查用户是否选择跳过此版本
            if version in self._skipped_versions:
                logger.info(f"用户已选择跳过版本 {version}，不显示通知")
                self.noUpdate.emit()
                return
            
            self.latest_release = result
            
            # 如果有系统托盘且需要显示通知
            if show_notification and QSystemTrayIcon.isSystemTrayAvailable():
                self._show_system_notification(result)
            
            # 发射信号通知 UI 更新
            self.updateAvailable.emit(
                result['version'],
                result['release_date'],
                result['download_url'],
                result['changelog']
            )
        else:
            self.noUpdate.emit()
    
    def _show_system_notification(self, result):
        """显示系统通知"""
        try:
            version = result['version']
            download_url = result['download_url']
            
            # 创建系统托盘图标（如果还没有）
            tray_icon = QSystemTrayIcon(self)
            tray_icon.setIcon(self.style().standardIcon(self.style().SP_ComputerIcon))
            tray_icon.show()
            
            # 显示通知
            tray_icon.showMessage(
                "ClassNEWS 发现新版本",
                f"最新版本：{version}\n点击前往下载",
                QSystemTrayIcon.Information,
                5000  # 显示 5 秒
            )
            
            # 点击通知时打开下载链接
            tray_icon.messageClicked.connect(lambda: self._open_download_url(download_url))
            
            logger.info(f"已显示系统通知：新版本 {version}")
            
        except Exception as e:
            logger.error(f"显示系统通知失败：{e}")
    
    def _open_download_url(self, url):
        """打开下载链接"""
        try:
            import webbrowser
            webbrowser.open(url)
            logger.info(f"已打开下载链接：{url}")
        except Exception as e:
            logger.error(f"打开下载链接失败：{e}")
    
    def skipThisVersion(self, version):
        """用户选择跳过此版本（不再提示）"""
        self._skipped_versions.add(version)
        self._save_skipped_versions()
        logger.info(f"用户选择跳过版本：{version}")
    
    def resetSkippedVersions(self):
        """重置所有跳过的版本"""
        self._skipped_versions.clear()
        self._save_skipped_versions()
        logger.info("已重置所有跳过的版本")
    
    def _on_error_occurred(self, error_msg):
        """处理错误"""
        self.checkFailed.emit(error_msg)
    
    def getLatestVersion(self) -> Optional[str]:
        """获取最新版本号"""
        if self.latest_release and isinstance(self.latest_release, dict):
            return self.latest_release.get('version')
        return None
    
    def getDownloadUrl(self) -> Optional[str]:
        """获取下载链接"""
        if self.latest_release and isinstance(self.latest_release, dict):
            return self.latest_release.get('download_url')
        return None
