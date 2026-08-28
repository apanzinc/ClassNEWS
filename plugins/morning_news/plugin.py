"""
官方新闻插件 - ID: 1
ClassNEWS 内置央视新闻源
"""

import re
import json
import time
import hashlib
import uuid
import requests
from pathlib import Path
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Optional, Callable, Any

from core.plugin_interface import (
    PluginBase, PluginInfo, NewsItem, NewsCategory, FetchResult
)


class OfficialNewsPlugin(PluginBase):
    """
    官方新闻插件
    
    提供央视新闻联播的获取和播放功能。
    数据来源：央视新闻 API
    """
    
    def __init__(self):
        super().__init__()
        
        self._info = PluginInfo(
            id=1,
            name="朝闻天下",
            version="1.0.0",
            author="中国中央广播电视台",
            description="来自央视，横跨CCTV-1综合、CCTV-13新闻2个频道，囊括3档新闻。",
            icon="icon.png",
            enabled=True,
            homepage="https://news.cctv.com/",
            min_app_version="2.0.0"
        )
        
        self._config = {
            "api_url": "https://api.cntv.cn/NewVideo/getVideoListByColumn",
            "timeout": 15,
            "page_size": 50,
            "column_id": "TOPC1451558496100826",
            "sort": "desc",
            "mode": "2",
            "service_id": "tvcctv"
        }
        
        # 从外部配置文件补充配置
        self._load_config_from_file()
        
        # 缓存
        self._news_cache: List[NewsItem] = []
        self._cache_time: Optional[datetime] = None
        self._cache_ttl = 300  # 缓存5分钟
    
    def _load_config_from_file(self) -> None:
        """从外部配置文件加载配置（合并到现有配置）"""
        config_path = Path(__file__).parent / "config.json"
        if config_path.exists():
            try:
                with open(config_path, 'r', encoding='utf-8') as f:
                    external = json.load(f)
                    # 尝试从 news_api 节点加载
                    news_api = external.get("news_api", {})
                    if news_api:
                        self._config.update(news_api)
                    # 如果配置在根级别，也合并
                    for key, value in external.items():
                        if key not in ("plugin", "news_api"):
                            self._config[key] = value
            except Exception:
                pass
    
    def _is_cache_valid(self) -> bool:
        """检查缓存是否有效"""
        if not self._news_cache or not self._cache_time:
            return False
        elapsed = (datetime.now() - self._cache_time).total_seconds()
        return elapsed < self._cache_ttl
    
    def _fetch_page_sync(self, page: int, date: str) -> tuple:
        """同步获取单页新闻（内部使用）"""
        params = {
            "id": self._config["column_id"],
            "sort": self._config["sort"],
            "mode": self._config["mode"],
            "serviceId": self._config["service_id"],
            "n": str(self._config["page_size"]),
            "p": str(page),
            "bd": date,
        }
        
        try:
            response = requests.get(
                self._config["api_url"],
                params=params,
                timeout=self._config["timeout"]
            )
            response.raise_for_status()
            
            text = response.text
            if text.startswith("cb(") and text.endswith(")"):
                text = text[3:-1]
            
            data = json.loads(text)
            return data, None
        except Exception as e:
            return None, str(e)
    
    def _parse_raw_item(self, item: Dict) -> Optional[NewsItem]:
        """解析原始新闻数据为 NewsItem"""
        try:
            title = item.get("title", "").replace("[朝闻天下]", "").strip()
            brief = item.get("brief", "")
            video_id = item.get("guid", "")
            
            if not video_id:
                return None
            
            return NewsItem(
                id=video_id,
                title=title,
                type="video",
                summary=brief,
                url="",  # 视频地址需要额外解析
                source_name="央视新闻",
                publish_time=item.get("time"),
                image_url=item.get("image"),
                category=NewsCategory.GENERAL,
                content=None,
                is_full_version=item.get("_is_full", False)
            )
        except Exception:
            return None
    
    # ========== 央视视频解析相关方法 ==========
    
    def _generate_uid(self) -> str:
        """生成32位设备标识"""
        return uuid.uuid4().hex.upper()[:32]
    
    def _generate_vc(self, pid: str, tsp: int) -> str:
        """生成校验签名: MD5(pid + tsp)"""
        raw = f"{pid}{tsp}"
        return hashlib.md5(raw.encode()).hexdigest().upper()
    
    def _get_cctv_video(self, pid: str) -> dict:
        """
        获取央视视频播放地址
        
        Args:
            pid: 视频唯一标识
            
        Returns:
            {
                "success": bool,
                "title": str,
                "hls_url": str,
                "qualities": list,
                "raw_data": dict
            }
        """
        tsp = int(time.time())
        uid = self._generate_uid()
        vc = self._generate_vc(pid, tsp)
        
        url = "https://vdn.apps.cntv.cn/api/getHttpVideoInfo.do"
        params = {
            "pid": pid,
            "client": "flash",
            "im": "0",
            "tsp": tsp,
            "vn": "2049",
            "vc": vc,
            "uid": uid,
            "wlan": ""
        }
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Referer": "https://tv.cctv.com/",
            "Origin": "https://tv.cctv.com"
        }
        
        try:
            response = requests.get(url, params=params, headers=headers, timeout=15)
            data = response.json()
            
            if data.get("ack") != "yes":
                return {"success": False, "error": "API返回失败", "raw_data": data}
            
            video_data = data.get("video", {})
            title = data.get("title", "") or video_data.get("title", "")
            
            return {
                "success": True,
                "title": title,
                "hls_url": data.get("hls_url", ""),
                "raw_data": data
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _upgrade_hls_quality(self, hls_url: str, target: str = "4000") -> str:
        """尝试升级HLS清晰度"""
        # 注意：必须在同一个变量上链式替换，否则前几次替换会被覆盖
        url = hls_url
        url = url.replace("/main/", f"/{target}/")
        url = url.replace("/main.m3u8", f"/{target}.m3u8")
        url = url.replace("maxbr=2048", f"maxbr={target}")
        return url
    
    def _get_video_url(self, pid: str) -> Optional[str]:
        """
        获取视频播放地址（带高清升级）
        
        Args:
            pid: 视频ID
            
        Returns:
            视频播放地址，或 None（获取失败）
        """
        result = self._get_cctv_video(pid)
        if not result.get("success"):
            return None
        
        hls_url = result.get("hls_url", "")
        if not hls_url:
            return None
        
        # 尝试升级高清
        hd_url = self._upgrade_hls_quality(hls_url, "4000")
        try:
            r = requests.head(hd_url, timeout=5)
            if r.status_code == 200:
                return hd_url
        except:
            pass
        
        return hls_url
    
    # ========== 协议请求处理 ==========
    
    async def handle_protocol_request(self, action: str, params: Dict[str, Any]) -> Optional[NewsItem]:
        """
        处理协议请求
        
        支持的 action:
        - "today": 获取当天完整版新闻
        - "latest": 获取最新新闻
        - "play": 播放指定新闻（需要 params 中有 "id"）
        """
        if action == "today":
            return await self._handle_today_request()
        elif action == "latest":
            return await self._handle_latest_request()
        elif action == "play":
            news_id = params.get("id") or params.get("pid")
            if news_id:
                return await self._handle_play_request(news_id)
            return None
        else:
            # 未知 action，尝试获取最新
            return await self._handle_latest_request()
    
    async def _handle_today_request(self) -> Optional[NewsItem]:
        """处理 today 请求：获取当天完整版新闻"""
        # 获取新闻列表
        result = await self.fetch_news(count=20)
        
        # 查找完整版
        for item in result.items:
            if item.is_full_version:
                # 获取视频播放地址
                video_url = self._get_video_url(item.id)
                if video_url:
                    item.url = video_url
                    return item
        
        # 没找到完整版，返回第一条
        if result.items:
            item = result.items[0]
            video_url = self._get_video_url(item.id)
            if video_url:
                item.url = video_url
                return item
        
        return None
    
    async def _handle_latest_request(self) -> Optional[NewsItem]:
        """处理 latest 请求：获取最新新闻"""
        result = await self.fetch_news(count=1)
        if result.items:
            item = result.items[0]
            video_url = self._get_video_url(item.id)
            if video_url:
                item.url = video_url
                return item
        return None
    
    async def _handle_play_request(self, news_id: str) -> Optional[NewsItem]:
        """处理 play 请求：播放指定新闻"""
        item = await self.get_news_detail(news_id)
        if item:
            video_url = self._get_video_url(item.id)
            if video_url:
                item.url = video_url
                return item
        return None
    
    # ========== 标准插件接口实现 ==========
    
    async def fetch_news(
        self,
        category: Optional[NewsCategory] = None,
        count: int = 20,
        cursor: Optional[str] = None
    ) -> FetchResult:
        """
        获取新闻列表
        
        从央视 API 获取新闻，自动处理分页。
        """
        # 检查缓存
        if self._is_cache_valid() and not cursor:
            items = self._news_cache[:count]
            return FetchResult(
                items=items,
                has_more=len(self._news_cache) > count,
                next_cursor=str(count) if len(self._news_cache) > count else None,
                total=len(self._news_cache)
            )
        
        # 获取日期
        date = datetime.now().strftime("%Y%m%d")
        
        # 获取第一页
        data, error = self._fetch_page_sync(1, date)
        if error:
            return FetchResult(items=[], has_more=False)
        
        all_items: List[NewsItem] = []
        full_version = None
        
        if "data" in data and "list" in data["data"]:
            for idx, item in enumerate(data["data"]["list"]):
                brief = item.get("brief", "")
                length = item.get("length", "")
                title = item.get("title", "").replace("[朝闻天下]", "").strip()
                
                # 检测完整版
                is_full = self._is_full_version(brief, length, title)
                
                if is_full and not full_version:
                    item["_is_full"] = True   # 打标记
                    parsed = self._parse_raw_item(item)
                    if parsed:
                        full_version = parsed
                        all_items.insert(0, full_version)
                    continue
                
                # 跳过主要内容综合新闻
                if "本期节目主要内容" in brief or "本期主要内容" in brief:
                    continue
                
                parsed = self._parse_raw_item(item)
                if parsed:
                    all_items.append(parsed)
        
        total = data.get("data", {}).get("total", 0)
        
        # 更新缓存
        self._news_cache = all_items
        self._cache_time = datetime.now()
        
        # 计算分页
        start_idx = int(cursor) if cursor else 0
        page_items = all_items[start_idx:start_idx + count]
        
        return FetchResult(
            items=page_items,
            has_more=start_idx + count < len(all_items),
            next_cursor=str(start_idx + count) if start_idx + count < len(all_items) else None,
            total=len(all_items)
        )
    
    def _is_full_version(self, brief: str, length: str, title: str) -> bool:
        """判断是否为完整版"""
        has_main = "本期节目主要内容" in brief or "本期主要内容" in brief
        is_program_title = bool(re.match(r'《[^》]+》\s*\d{8}\s+\d{2}:\d{2}', title))
        
        is_long = False
        if length:
            try:
                parts = length.split(':')
                if len(parts) == 3 and int(parts[0]) >= 0:
                    is_long = int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2]) >= 1800
            except Exception:
                pass
        
        return has_main or (is_program_title and is_long)
    
    async def get_news_detail(self, news_id: str) -> Optional[NewsItem]:
        """获取新闻详情"""
        for item in self._news_cache:
            if item.id == news_id:
                return item
        
        # 缓存未命中，需要重新获取
        result = await self.fetch_news(count=100)
        for item in result.items:
            if item.id == news_id:
                return item
        
        return None
    
    async def play_news(
        self,
        news_id: str,
        on_progress: Optional[Callable[[int, int], None]] = None
    ) -> bool:
        """
        播放新闻（已弃用，新架构下由软件直接调用 handle_protocol_request）
        """
        # 新架构下，这个方法不再通过协议调用播放器
        # 保留此方法以兼容旧接口，但实际逻辑由 handle_protocol_request 处理
        print("play_news 已弃用，请使用 handle_protocol_request")
        return False
    
    async def search_news(
        self,
        keyword: str,
        count: int = 20
    ) -> List[NewsItem]:
        """搜索新闻"""
        result = await self.fetch_news(count=100)
        
        keyword_lower = keyword.lower()
        matches = [
            item for item in result.items
            if keyword_lower in item.title.lower()
            or keyword_lower in item.summary.lower()
        ]
        
        return matches[:count]
    
    def health_check(self) -> bool:
        """健康检查"""
        try:
            data, _ = self._fetch_page_sync(1, datetime.now().strftime("%Y%m%d"))
            return data is not None and "data" in data
        except Exception:
            return False


# 导出插件类（必须）
plugin_class = OfficialNewsPlugin
