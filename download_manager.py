import os
import json
import time
import requests
from pathlib import Path
from datetime import datetime
from PySide6.QtCore import QObject, Signal, Slot, QThread, Property
from PySide6.QtCore import Qt
from hls_downloader import HLSDownloader

# 尝试导入系统通知
try:
    from plyer import notification
    NOTIFICATION_AVAILABLE = True
except ImportError:
    NOTIFICATION_AVAILABLE = False
    print("plyer 未安装，系统通知功能不可用")


class DownloadWorker(QThread):
    """后台下载线程 - 使用纯 Python HLS 下载器"""
    progress_updated = Signal(str, int, int, float)  # download_id, downloaded_bytes, total_bytes, speed
    download_finished = Signal(str, str, bool, str)  # download_id, file_path, success, error_msg
    status_changed = Signal(str, str)  # download_id, status

    def __init__(self, download_id, video_url, title, save_path, parent=None):
        super().__init__(parent)
        self.download_id = download_id
        self.video_url = video_url
        self.title = title
        self.save_path = save_path
        self._is_cancelled = False
        self._status = "pending"
        self._hls_downloader = None
        self._total_segments = 0
        self._downloaded_segments = 0
        self._start_time = None

    def run(self):
        """执行下载"""
        try:
            self._status = "downloading"
            self.status_changed.emit(self.download_id, self._status)
            self._start_time = time.time()

            # 创建保存目录
            os.makedirs(os.path.dirname(self.save_path), exist_ok=True)

            # 检查是否是 HLS (m3u8) 格式
            if '.m3u8' in self.video_url.lower():
                # 使用纯 Python HLS 下载器
                self._download_hls()
            else:
                # 直接下载普通视频文件
                self._download_direct()

        except Exception as e:
            self._status = "error"
            self.status_changed.emit(self.download_id, self._status)
            # 删除未完成的文件
            if os.path.exists(self.save_path):
                os.remove(self.save_path)
            self.download_finished.emit(self.download_id, "", False, str(e))

    def _download_hls(self):
        """使用纯 Python HLS 下载器"""
        try:
            # 创建进度回调
            def progress_callback(progress, current, total):
                if self._is_cancelled:
                    return

                self._downloaded_segments = current
                self._total_segments = total

                # 计算下载速度
                elapsed = time.time() - self._start_time
                speed = current / elapsed if elapsed > 0 else 0

                # 估算文件大小 (假设每个片段平均 500KB)
                estimated_size = total * 500 * 1024
                downloaded = current * 500 * 1024

                self.progress_updated.emit(
                    self.download_id,
                    int(downloaded),
                    int(estimated_size),
                    speed
                )

            # 创建 HLS 下载器
            self._hls_downloader = HLSDownloader(progress_callback)

            # 执行下载
            success = self._hls_downloader.download(self.video_url, self.save_path)

            if self._is_cancelled:
                self._status = "cancelled"
                self.status_changed.emit(self.download_id, self._status)
                if os.path.exists(self.save_path):
                    os.remove(self.save_path)
                return

            if success:
                self._status = "completed"
                self.status_changed.emit(self.download_id, self._status)
                self.download_finished.emit(self.download_id, self.save_path, True, "")
            else:
                raise Exception("HLS 下载失败")

        except Exception as e:
            self._status = "error"
            self.status_changed.emit(self.download_id, self._status)
            if os.path.exists(self.save_path):
                os.remove(self.save_path)
            self.download_finished.emit(self.download_id, "", False, str(e))

    def _download_direct(self):
        """直接下载普通视频文件"""
        try:
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Referer": "https://tv.cctv.com/",
            }

            response = requests.get(self.video_url, headers=headers, stream=True, timeout=30)
            response.raise_for_status()

            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0
            start_time = time.time()
            last_update_time = start_time

            # 下载文件
            with open(self.save_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if self._is_cancelled:
                        self._status = "cancelled"
                        self.status_changed.emit(self.download_id, self._status)
                        if os.path.exists(self.save_path):
                            os.remove(self.save_path)
                        return

                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)

                        # 计算下载速度（每0.5秒更新一次）
                        current_time = time.time()
                        if current_time - last_update_time >= 0.5:
                            elapsed = current_time - start_time
                            speed = downloaded / elapsed if elapsed > 0 else 0
                            self.progress_updated.emit(
                                self.download_id,
                                downloaded,
                                total_size,
                                speed
                            )
                            last_update_time = current_time

            # 下载完成
            self._status = "completed"
            self.status_changed.emit(self.download_id, self._status)
            self.download_finished.emit(self.download_id, self.save_path, True, "")

        except Exception as e:
            self._status = "error"
            self.status_changed.emit(self.download_id, self._status)
            if os.path.exists(self.save_path):
                os.remove(self.save_path)
            self.download_finished.emit(self.download_id, "", False, str(e))

    def cancel(self):
        """取消下载"""
        self._is_cancelled = True
        if self._hls_downloader:
            try:
                self._hls_downloader.cancel()
            except Exception as e:
                print(f"取消下载器时出错：{e}")

    @property
    def status(self):
        return self._status


class DownloadManager(QObject):
    """下载管理器 - 管理所有视频下载任务"""

    # 信号
    download_added = Signal(str, str, str)  # download_id, title, status
    download_progress = Signal(str, int, int, float)  # download_id, downloaded, total, speed
    download_completed = Signal(str, str)  # download_id, file_path
    download_error = Signal(str, str)  # download_id, error_msg
    download_status_changed = Signal(str, str)  # download_id, status
    download_list_changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._downloads = {}  # download_id -> download_info
        self._workers = {}    # download_id -> DownloadWorker
        self._download_dir = self._get_default_download_dir()

        # 确保下载目录存在
        os.makedirs(self._download_dir, exist_ok=True)

    def _send_notification(self, title, message, timeout=5):
        """发送系统通知"""
        try:
            if NOTIFICATION_AVAILABLE:
                notification.notify(
                    title=title,
                    message=message,
                    app_name="ClassNEWS",
                    timeout=timeout
                )
                print(f"系统通知已发送: {title} - {message}")
            else:
                print(f"系统通知不可用: {title} - {message}")
        except Exception as e:
            print(f"发送系统通知失败: {e}")

    def _get_default_download_dir(self):
        """获取默认下载目录"""
        # 使用用户下载文件夹
        download_path = Path.home() / "Downloads" / "ClassNEWS"
        return str(download_path)

    @Slot(str, str, str, result=str)
    def startDownload(self, video_url, title, video_id=""):
        """
        开始下载视频（使用默认路径）

        Args:
            video_url: 视频URL
            title: 视频标题
            video_id: 视频ID（可选）

        Returns:
            download_id: 下载任务ID
        """
        # 生成下载ID
        download_id = f"dl_{int(time.time() * 1000)}_{hash(video_url) % 10000}"

        # 清理文件名
        safe_title = self._sanitize_filename(title) or "video"
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{safe_title}_{timestamp}.mp4"
        save_path = os.path.join(self._download_dir, filename)

        return self._startDownloadInternal(download_id, video_url, title, video_id, save_path)

    @Slot(str, str, str, str, result=str)
    def startDownloadWithPath(self, video_url, title, video_id, save_path):
        """
        开始下载视频（使用指定路径）

        Args:
            video_url: 视频URL
            title: 视频标题
            video_id: 视频ID
            save_path: 保存路径

        Returns:
            download_id: 下载任务ID
        """
        # 生成下载ID
        download_id = f"dl_{int(time.time() * 1000)}_{hash(video_url) % 10000}"

        return self._startDownloadInternal(download_id, video_url, title, video_id, save_path)

    def _startDownloadInternal(self, download_id, video_url, title, video_id, save_path):
        """内部开始下载方法"""
        # 确保保存目录存在
        os.makedirs(os.path.dirname(save_path), exist_ok=True)

        # 创建下载信息
        download_info = {
            "id": download_id,
            "title": title,
            "video_url": video_url,
            "video_id": video_id,
            "save_path": save_path,
            "filename": os.path.basename(save_path),
            "status": "pending",
            "progress": 0,
            "downloaded_bytes": 0,
            "total_bytes": 0,
            "speed": 0,
            "created_at": datetime.now().isoformat(),
            "completed_at": None
        }

        self._downloads[download_id] = download_info

        # 创建并启动下载线程
        worker = DownloadWorker(download_id, video_url, title, save_path)
        worker.progress_updated.connect(self._on_progress_updated)
        worker.download_finished.connect(self._on_download_finished)
        worker.status_changed.connect(self._on_status_changed)
        worker.finished.connect(lambda: self._cleanup_worker(download_id))

        self._workers[download_id] = worker
        worker.start()

        # 发送信号
        self.download_added.emit(download_id, title, "downloading")
        self.download_list_changed.emit()

        # 发送系统通知
        self._send_notification(
            "ClassNEWS - 开始下载",
            f"正在下载: {title}"
        )

        print(f"开始下载: {title} -> {save_path}")
        return download_id

    @Slot(str)
    def cancelDownload(self, download_id):
        """取消下载"""
        if download_id in self._workers:
            worker = self._workers[download_id]
            worker.cancel()
            print(f"取消下载: {download_id}")

    @Slot(str)
    def removeDownload(self, download_id):
        """移除下载记录"""
        if download_id in self._downloads:
            # 如果正在下载，先取消
            if download_id in self._workers:
                self.cancelDownload(download_id)

            del self._downloads[download_id]
            self.download_list_changed.emit()
            print(f"移除下载记录: {download_id}")

    @Slot(result=list)
    def getDownloadList(self):
        """获取下载列表"""
        return list(self._downloads.values())

    @Slot(str, result=dict)
    def getDownloadInfo(self, download_id):
        """获取单个下载信息"""
        return self._downloads.get(download_id, {})

    @Slot(result=str)
    def getDownloadDirectory(self):
        """获取下载目录"""
        return self._download_dir

    @Slot(str)
    def setDownloadDirectory(self, path):
        """设置下载目录"""
        self._download_dir = path
        os.makedirs(self._download_dir, exist_ok=True)

    @Slot(str, result=bool)
    def openDownloadFolder(self, download_id=""):
        """打开下载文件夹"""
        try:
            if download_id and download_id in self._downloads:
                path = self._downloads[download_id]["save_path"]
                folder = os.path.dirname(path)
            else:
                folder = self._download_dir

            if os.path.exists(folder):
                os.startfile(folder)
                return True
        except Exception as e:
            print(f"打开下载文件夹失败: {e}")
        return False

    @Slot(str, result=bool)
    def openFolder(self, path):
        """打开指定文件夹"""
        try:
            if path and os.path.exists(path):
                folder = os.path.dirname(path)
                if os.path.exists(folder):
                    os.startfile(folder)
                    return True
        except Exception as e:
            print(f"打开文件夹失败: {e}")
        return False

    def _on_progress_updated(self, download_id, downloaded, total, speed):
        """进度更新回调"""
        if download_id in self._downloads:
            self._downloads[download_id]["downloaded_bytes"] = downloaded
            self._downloads[download_id]["total_bytes"] = total
            self._downloads[download_id]["speed"] = speed

            # 计算进度百分比
            if total > 0:
                progress = int((downloaded / total) * 100)
            else:
                progress = 0
            self._downloads[download_id]["progress"] = progress

            self.download_progress.emit(download_id, downloaded, total, speed)

    def _on_download_finished(self, download_id, file_path, success, error_msg):
        """下载完成回调"""
        if download_id in self._downloads:
            self._downloads[download_id]["completed_at"] = datetime.now().isoformat()
            title = self._downloads[download_id].get('title', '未知视频')

            if success:
                self.download_completed.emit(download_id, file_path)
                print(f"下载完成: {file_path}")
                # 发送下载完成通知
                self._send_notification(
                    "ClassNEWS - 下载完成",
                    f"视频已下载: {title}"
                )
            else:
                self.download_error.emit(download_id, error_msg)
                print(f"下载失败: {error_msg}")
                # 发送下载失败通知
                self._send_notification(
                    "ClassNEWS - 下载失败",
                    f"下载失败: {title}\n{error_msg[:50]}"
                )

            self.download_list_changed.emit()

    def _on_status_changed(self, download_id, status):
        """状态变更回调"""
        if download_id in self._downloads:
            self._downloads[download_id]["status"] = status
            self.download_status_changed.emit(download_id, status)
            self.download_list_changed.emit()

    def _cleanup_worker(self, download_id):
        """清理工作线程"""
        if download_id in self._workers:
            worker = self._workers[download_id]
            worker.deleteLater()
            del self._workers[download_id]

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

    @Slot(int, result=str)
    def formatFileSize(self, size_bytes):
        """格式化文件大小"""
        try:
            # 确保是数字类型
            size_bytes = int(size_bytes)
            if size_bytes == 0:
                return "0 B"
            size_names = ["B", "KB", "MB", "GB", "TB"]
            import math
            i = int(math.floor(math.log(size_bytes, 1024)))
            p = math.pow(1024, i)
            s = round(size_bytes / p, 2)
            return f"{s} {size_names[i]}"
        except (ValueError, TypeError):
            return "0 B"

    @Slot(float, result=str)
    def formatSpeed(self, bytes_per_second):
        """格式化下载速度"""
        try:
            return self.formatFileSize(int(bytes_per_second)) + "/s"
        except (ValueError, TypeError):
            return "0 B/s"
