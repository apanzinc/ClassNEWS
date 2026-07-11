"""
新闻源插件模板
用于快速创建新的新闻源插件
"""

from typing import List, Dict, Optional, Callable

from core.plugin_interface import (
    PluginBase, PluginInfo, NewsItem, NewsCategory, FetchResult
)


class TemplateNewsPlugin(PluginBase):
    """
    模板新闻插件
    
    使用此模板创建新的新闻源插件：
    1. 复制整个 template 目录
    2. 修改类名和 ID
    3. 实现各个方法
    4. 更新 config.json
    """
    
    def __init__(self):
        super().__init__()
        
        self._info = PluginInfo(
            id=1000,
            name="新闻源模板",
            version="1.0.0",
            author="ClassNEWS",
            description="用于创建新插件的模板，默认禁用",
            icon="",
            enabled=False,
        )
        
        self._config = {
            "api_url": "https://api.example.com/news",
            "api_key": "",
            "timeout": 15,
            "page_size": 20,
        }
    
    async def fetch_news(
        self,
        category: Optional[NewsCategory] = None,
        count: int = 20,
        cursor: Optional[str] = None
    ) -> FetchResult:
        items: List[NewsItem] = []
        return FetchResult(
            items=items,
            has_more=False,
            next_cursor=None,
            total=len(items)
        )
    
    async def get_news_detail(self, news_id: str) -> Optional[NewsItem]:
        return None
    
    async def play_news(
        self,
        news_id: str,
        on_progress: Optional[Callable[[int, int], None]] = None
    ) -> bool:
        return True
    
    async def search_news(
        self,
        keyword: str,
        count: int = 20
    ) -> List[NewsItem]:
        return await super().search_news(keyword, count)
    
    def health_check(self) -> bool:
        return True


plugin_class = TemplateNewsPlugin