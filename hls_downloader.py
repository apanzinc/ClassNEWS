"""
HLS 视频下载器 - 纯 Python 实现，无需 ffmpeg
"""
import os
import re
import requests
from urllib.parse import urljoin, urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import tempfile
import shutil


class HLSDownloader:
    """HLS (m3u8) 视频下载器"""

    def __init__(self, progress_callback=None):
        self.progress_callback = progress_callback
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Referer": "https://tv.cctv.com/",
        })
        self._cancelled = False

    def download(self, m3u8_url, output_path):
        """
        下载 HLS 视频

        Args:
            m3u8_url: m3u8 播放列表 URL
            output_path: 输出文件路径

        Returns:
            bool: 是否成功
        """
        try:
            # 1. 下载并解析 m3u8 文件
            playlist_content = self._download_playlist(m3u8_url)
            if not playlist_content:
                raise Exception("无法下载播放列表")

            # 2. 检查是否是主播放列表（包含多个码率）
            variant_url = self._select_variant(playlist_content, m3u8_url)
            if variant_url:
                # 递归下载选中的码率
                return self.download(variant_url, output_path)

            # 3. 获取所有片段 URL
            segments = self._parse_segments(playlist_content, m3u8_url)
            if not segments:
                raise Exception("未找到视频片段")

            total_segments = len(segments)
            print(f"找到 {total_segments} 个视频片段")

            # 4. 创建临时目录
            temp_dir = tempfile.mkdtemp()

            try:
                # 5. 下载所有片段
                segment_files = []
                for i, segment_url in enumerate(segments):
                    if self._cancelled:
                        return False

                    segment_file = os.path.join(temp_dir, f"segment_{i:06d}.ts")
                    self._download_segment(segment_url, segment_file)
                    segment_files.append(segment_file)

                    # 更新进度
                    if self.progress_callback:
                        progress = int((i + 1) / total_segments * 100)
                        self.progress_callback(progress, i + 1, total_segments)

                # 6. 合并所有片段
                self._merge_segments(segment_files, output_path)

                return True

            finally:
                # 7. 清理临时目录
                shutil.rmtree(temp_dir, ignore_errors=True)

        except Exception as e:
            print(f"下载失败: {e}")
            return False

    def _download_playlist(self, url):
        """下载播放列表"""
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            return response.text
        except Exception as e:
            print(f"下载播放列表失败: {e}")
            return None

    def _select_variant(self, playlist_content, base_url):
        """
        从主播放列表中选择最佳码率
        返回选中的 variant URL
        """
        # 查找所有 variant
        variants = []
        lines = playlist_content.split('\n')

        for i, line in enumerate(lines):
            if line.startswith('#EXT-X-STREAM-INF:'):
                # 解析带宽
                bandwidth_match = re.search(r'BANDWIDTH=(\d+)', line)
                bandwidth = int(bandwidth_match.group(1)) if bandwidth_match else 0

                # 获取下一个行的 URL
                if i + 1 < len(lines):
                    variant_url = lines[i + 1].strip()
                    if variant_url and not variant_url.startswith('#'):
                        # 转换为绝对 URL
                        if not variant_url.startswith('http'):
                            variant_url = urljoin(base_url, variant_url)
                        variants.append((bandwidth, variant_url))

        if not variants:
            return None

        # 选择最高码率
        variants.sort(reverse=True)
        print(f"选择码率: {variants[0][0] / 1000:.0f} kbps")
        return variants[0][1]

    def _parse_segments(self, playlist_content, base_url):
        """解析所有片段 URL"""
        segments = []
        lines = playlist_content.split('\n')

        for line in lines:
            line = line.strip()
            # 跳过注释和空行
            if not line or line.startswith('#'):
                continue

            # 这是一个片段 URL
            if not line.startswith('http'):
                line = urljoin(base_url, line)
            segments.append(line)

        return segments

    def _download_segment(self, url, output_file):
        """下载单个片段"""
        try:
            response = self.session.get(url, timeout=30, stream=True)
            response.raise_for_status()

            with open(output_file, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if self._cancelled:
                        return
                    if chunk:
                        f.write(chunk)
        except Exception as e:
            print(f"下载片段失败 {url}: {e}")
            raise

    def _merge_segments(self, segment_files, output_path):
        """合并所有片段为最终视频"""
        print(f"合并 {len(segment_files)} 个片段...")

        # 确保输出目录存在
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        # 直接拼接所有片段（TS 格式支持直接拼接）
        with open(output_path, 'wb') as outfile:
            for segment_file in segment_files:
                with open(segment_file, 'rb') as infile:
                    shutil.copyfileobj(infile, outfile)

        print(f"视频已保存: {output_path}")

    def cancel(self):
        """取消下载"""
        self._cancelled = True


if __name__ == "__main__":
    # 测试
    def progress_callback(progress, current, total):
        print(f"进度: {progress}% ({current}/{total})")

    downloader = HLSDownloader(progress_callback)

    # 测试 URL（替换为实际的 m3u8 URL）
    test_url = "https://example.com/video.m3u8"
    output = "test_output.mp4"

    success = downloader.download(test_url, output)
    print(f"下载{'成功' if success else '失败'}")
