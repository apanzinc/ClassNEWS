"""
新闻源插件接口定义
ClassNEWS 插件化架构核心
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Optional, Callable, Any
from dataclasses import dataclass, field, asdict
from enum import Enum
import json
import os


class NewsCategory(Enum):
    """新闻分类枚举"""
    GENERAL = "general"        # 综合
    POLITICS = "politics"      # 时政
    TECH = "tech"              # 科技
    ENTERTAINMENT = "ent"      # 娱乐
    SPORTS = "sports"          # 体育
    FINANCE = "finance"        # 财经
    SOCIETY = "society"         # 社会
    EDUCATION = "education"    # 教育
    OTHER = "other"            # 其他


@dataclass
class NewsItem:
    """单条新闻数据结构"""
    id: str                          # 新闻唯一ID
    title: str                       # 标题
    type: str = "text"               # 内容类型: video/audio/text
    summary: str = ""                # 摘要
    content: Optional[str] = None    # 完整内容（可选）
    url: str = ""                    # 资源地址（视频/音频链接或原文链接）
    source_name: str = ""            # 来源名称
    publish_time: Optional[str] = None  # 发布时间
    category: Optional[NewsCategory] = None  # 分类
    image_url: Optional[str] = None  # 配图URL
    author: Optional[str] = None     # 作者
    tags: List[str] = field(default_factory=list)  # 标签
    is_full_version: bool = False    # 是否为完整版节目
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典（JSON序列化用）"""
        d = asdict(self)
        if self.category:
            d['category'] = self.category.value
        return d
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'NewsItem':
        """从字典创建"""
        if data.get('category') and isinstance(data['category'], str):
            try:
                data['category'] = NewsCategory(data['category'])
            except ValueError:
                data['category'] = None
        return cls(**{k: v for k, v in data.items() if k in cls.__annotations__})


@dataclass
class PluginInfo:
    """插件元信息"""
    id: int                          # 数字ID（全局唯一）
    name: str                        # 插件名称
    version: str = "1.0.0"          # 版本号
    author: str = "Unknown"         # 作者
    description: str = ""            # 描述
    icon: Optional[str] = None       # 图标路径
    enabled: bool = True             # 是否启用
    homepage: Optional[str] = None   # 插件主页
    min_app_version: Optional[str] = None  # 最低支持版本
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass  
class FetchResult:
    """获取新闻结果"""
    items: List[NewsItem] = field(default_factory=list)
    has_more: bool = False
    next_cursor: Optional[str] = None
    total: int = 0  # 总条数（可选）
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "items": [item.to_dict() for item in self.items],
            "has_more": self.has_more,
            "next_cursor": self.next_cursor,
            "total": self.total
        }


class INewsSource(ABC):
    """
    新闻源插件接口
    
    所有新闻源插件必须实现此接口。
    插件应放在 plugins/{plugin_name}/ 目录下，
    并在 core/plugin_manager.py 中注册。
    
    实现步骤：
    1. 继承 INewsSource
    2. 在 __init__ 中初始化 PluginInfo
    3. 实现所有抽象方法
    4. 导出 plugin_class = YourPluginClass
    """
    
    def __init__(self):
        self._info: Optional[PluginInfo] = None
        self._config: Dict[str, Any] = {}
    
    def on_load(self) -> None:
        """
        插件加载时调用（生命周期钩子）
        
        在此方法中执行初始化操作，如：
        - 创建网络连接
        - 加载配置文件
        - 初始化缓存
        
        如果初始化失败，应抛出异常
        """
        pass
    
    def on_unload(self) -> None:
        """
        插件卸载/禁用时调用（生命周期钩子）
        
        在此方法中执行清理操作，如：
        - 关闭网络连接
        - 保存配置
        - 清理缓存
        - 释放资源
        """
        pass
    
    @property
    def info(self) -> PluginInfo:
        """返回插件元信息"""
        if self._info is None:
            raise NotImplementedError("插件必须设置 info 属性")
        return self._info
    
    @property
    def config(self) -> Dict[str, Any]:
        """返回插件配置"""
        return self._config
    
    @config.setter
    def config(self, value: Dict[str, Any]):
        """设置插件配置"""
        self._config = value
    
    @property
    def id(self) -> int:
        """快捷属性：获取插件ID"""
        return self.info.id
    
    @property
    def name(self) -> str:
        """快捷属性：获取插件名称"""
        return self.info.name
    
    @abstractmethod
    async def fetch_news(
        self,
        category: Optional[NewsCategory] = None,
        count: int = 20,
        cursor: Optional[str] = None
    ) -> FetchResult:
        """
        获取新闻列表
        
        Args:
            category: 新闻分类，None表示全部
            count: 获取条数，默认20
            cursor: 分页游标，用于翻页
            
        Returns:
            FetchResult 对象，包含:
            - items: 新闻列表
            - has_more: 是否有更多
            - next_cursor: 下一页游标
            - total: 总条数（可选）
        """
        pass
    
    @abstractmethod
    async def get_news_detail(self, news_id: str) -> Optional[NewsItem]:
        """
        获取新闻详情
        
        Args:
            news_id: 新闻ID（来自fetch_news返回的item.id）
            
        Returns:
            NewsItem 或 None（未找到）
        """
        pass
    
    @abstractmethod
    async def play_news(
        self,
        news_id: str,
        on_progress: Optional[Callable[[int, int], None]] = None
    ) -> bool:
        """
        播放新闻（语音播报）
        
        此方法应调用 TTS 服务将新闻内容转换为语音播放。
        
        Args:
            news_id: 新闻ID
            on_progress: 进度回调函数，参数为 (current, total)
                        current: 当前播放位置（字符或秒）
                        total: 总长度
            
        Returns:
            是否播放成功
        """
        pass
    
    async def search_news(
        self,
        keyword: str,
        count: int = 20
    ) -> List[NewsItem]:
        """
        搜索新闻
        
        Args:
            keyword: 搜索关键词
            count: 返回条数，默认20
            
        Returns:
            匹配的 NewsItem 列表
        """
        # 默认实现：获取所有新闻然后在本地过滤
        result = await self.fetch_news(count=count * 2)
        keyword_lower = keyword.lower()
        matches = [
            item for item in result.items
            if keyword_lower in item.title.lower() 
            or keyword_lower in item.summary.lower()
        ]
        return matches[:count]
    
    def health_check(self) -> bool:
        """
        健康检查
        
        检查新闻源是否可用。
        可选实现，默认返回True。
        
        Returns:
            True 表示正常，False 表示不可用
        """
        return True
    
    async def handle_protocol_request(self, action: str, params: Dict[str, Any]) -> Optional[NewsItem]:
        """
        处理协议请求
        
        当通过 classnews:// 协议调用时，软件会路由到对应插件的此方法。
        插件自己决定如何处理 action 和参数，返回可直接播放/展示的数据。
        
        Args:
            action: 动作类型（如 today/latest/play 等），由软件透传
            params: 额外参数字典
            
        Returns:
            NewsItem 对象（必须包含 id, title, type, url），或 None（处理失败）
            
        示例:
            action="today" -> 返回当天完整版新闻
            action="play" + params{"id": "xxx"} -> 返回指定新闻的播放数据
        """
        # 默认实现：尝试从 fetch_news 获取第一条
        try:
            result = await self.fetch_news(count=1)
            if result.items:
                return result.items[0]
            return None
        except Exception:
            return None
    
    def load_config(self, config_path: str) -> bool:
        """
        加载配置文件
        
        Args:
            config_path: 配置文件路径
            
        Returns:
            是否加载成功
        """
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r', encoding='utf-8') as f:
                    self._config = json.load(f)
                return True
            except (json.JSONDecodeError, IOError):
                return False
        return False
    
    def save_config(self, config_path: str) -> bool:
        """
        保存配置文件
        
        Args:
            config_path: 配置文件路径
            
        Returns:
            是否保存成功
        """
        try:
            os.makedirs(os.path.dirname(config_path), exist_ok=True)
            with open(config_path, 'w', encoding='utf-8') as f:
                json.dump(self._config, f, ensure_ascii=False, indent=2)
            return True
        except (IOError, OSError):
            return False


class PluginBase(INewsSource):
    """
    插件基类
    
    提供常用功能的默认实现，
    新插件可以直接继承此类。
    """
    
    def __init__(self):
        super().__init__()
        self._http_session = None
    
    async def _http_get(
        self,
        url: str,
        params: Optional[Dict] = None,
        headers: Optional[Dict] = None,
        timeout: int = 10
    ) -> Optional[Dict]:
        """
        HTTP GET 请求（异步）
        
        Args:
            url: 请求URL
            params: 查询参数
            headers: 请求头
            timeout: 超时秒数
            
        Returns:
            JSON响应或None
        """
        try:
            import aiohttp
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    url, 
                    params=params, 
                    headers=headers, 
                    timeout=aiohttp.ClientTimeout(total=timeout)
                ) as resp:
                    if resp.status == 200:
                        return await resp.json()
                    return None
        except Exception:
            return None
    
    async def _http_post(
        self,
        url: str,
        data: Optional[Dict] = None,
        headers: Optional[Dict] = None,
        timeout: int = 10
    ) -> Optional[Dict]:
        """
        HTTP POST 请求（异步）
        
        Args:
            url: 请求URL
            data: 请求数据
            headers: 请求头
            timeout: 超时秒数
            
        Returns:
            JSON响应或None
        """
        try:
            import aiohttp
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    url, 
                    json=data,
                    headers=headers, 
                    timeout=aiohttp.ClientTimeout(total=timeout)
                ) as resp:
                    if resp.status == 200:
                        return await resp.json()
                    return None
        except Exception:
            return None
