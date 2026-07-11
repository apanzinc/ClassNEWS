# ClassNEWS 插件系统 API 参考

> 版本: v1.0.0  
> 日期: 2026-05-02

---

## 一、插件接口 (INewsSource)

所有新闻源插件必须继承 `INewsSource` 并实现以下方法：

```python
from core.plugin_interface import INewsSource, PluginInfo, NewsItem, NewsCategory, FetchResult

class MyPlugin(INewsSource):
    def __init__(self):
        super().__init__()
        self._info = PluginInfo(
            id=1001,                    # 唯一 ID (1000+ 给用户插件)
            name="我的新闻源",
            version="1.0.0",
            author="作者名",
            description="插件描述"
        )
    
    async def fetch_news(self, category=None, count=20, cursor=None) -> FetchResult:
        """获取新闻列表"""
        pass
    
    async def get_news_detail(self, news_id: str) -> NewsItem:
        """获取新闻详情"""
        pass
    
    async def play_news(self, news_id: str, on_progress=None) -> bool:
        """播放新闻（语音播报）"""
        pass
```

### 生命周期钩子 (可选)

```python
def on_load(self):
    """插件加载时调用，用于初始化"""
    pass

def on_unload(self):
    """插件卸载时调用，用于清理资源"""
    pass
```

---

## 二、PluginManager

### 2.1 QML 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `plugins` | list | 插件列表 |

### 2.2 QML 方法

#### setPluginEnabled(pluginId, enabled)
启用/禁用插件。

```qml
pluginManager.setPluginEnabled(1001, false)  // 禁用插件
```

#### uninstallPlugin(pluginId)
卸载用户插件（内置插件不支持）。

```qml
pluginManager.uninstallPlugin(1001)
```

#### importPlugin()
打开文件对话框，导入插件。

```qml
var conflicts = pluginManager.importPlugin()
if (conflicts.length > 0) {
    // 存在冲突插件
}
```

#### exportPlugin(pluginId)
导出用户插件为 `.cnplugin` 文件。

```qml
var path = pluginManager.exportPlugin(1001)
if (path) {
    // 导出成功，path 为文件路径
}
```

#### reloadPlugin(pluginId)
重载用户插件（先卸载再加载）。

```qml
pluginManager.reloadPlugin(1001)
```

#### openPluginFolder(pluginId)
打开插件目录。

```qml
pluginManager.openPluginFolder(1001)  // 打开指定插件目录
pluginManager.openPluginFolder(0)     // 打开用户插件根目录
```

#### getAPIVersion()
获取当前 API 版本。

```qml
var version = pluginManager.getAPIVersion()  // "1.0.0"
```

#### isPluginCompatible(pluginId)
检查插件是否与当前 API 版本兼容。

```qml
var ok = pluginManager.isPluginCompatible(1001)
```

### 2.3 QML 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `pluginListChanged` | - | 插件列表变化 |
| `pluginImportSucceeded` | - | 插件导入成功 |
| `pluginImportFailed` | msg | 插件导入失败 |
| `pluginReloadSucceeded` | pluginId | 插件重载成功 |
| `pluginReloadFailed` | pluginId, msg | 插件重载失败 |
| `pluginExportSucceeded` | filePath | 插件导出成功 |

### 2.4 Python 方法 (内部使用)

```python
# 加载
pm.load_all_plugins()                    # 加载所有插件
pm.get_plugin(plugin_id)                  # 获取单个插件
pm.get_all_plugins(enabled_only=True)     # 获取所有插件

# 查询
pm.get_plugin_type(plugin_id)            # 获取插件类型
pm.is_builtin_plugin(plugin_id)           # 是否内置插件
pm.get_user_plugins_dir()                 # 用户插件目录
pm.get_builtin_plugins_dir()              # 内置插件目录

# 异步 API
await pm.fetch_news(plugin_id, category, count, cursor)
await pm.get_news_detail(plugin_id, news_id)
await pm.play_news(plugin_id, news_id)
await pm.search_news(plugin_id, keyword, count)

# 同步 API (Flask 使用)
pm.fetch_news_sync(plugin_id, ...)
pm.get_news_detail_sync(plugin_id, news_id)
pm.play_news_sync(plugin_id, news_id)
pm.search_news_sync(plugin_id, keyword, count)
```

---

## 三、cwplugin.json 格式

插件元数据文件，位于插件目录下：

```json
{
    "id": 1001,
    "name": "我的新闻源",
    "version": "1.0.0",
    "api_version": "1.0.0",
    "author": "作者名",
    "description": "这是一个示例插件"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | int | ✅ | 插件唯一 ID |
| name | string | ✅ | 插件名称 |
| version | string | ✅ | 版本号 (语义化) |
| api_version | string | ✅ | 要求的 API 版本 |
| author | string | ✅ | 作者 |
| description | string | ❌ | 描述 |

---

## 四、插件数据结构

### 插件列表项 (QML)

```javascript
{
    pluginId: 1001,           // 插件 ID
    name: "我的新闻源",        // 名称
    type: "user",            // "builtin" 或 "user"
    enabled: true,            // 是否启用
    builtin: false,           // 是否内置
    directory: "...",        // 目录路径
    author: "作者",          // 作者
    version: "1.0.0",        // 版本
    description: "...",       // 描述
    apiVersion: "1.0.0",     // API 版本
    compatible: true          // 是否兼容
}
```

---

## 五、NewsItem 数据结构

```python
@dataclass
class NewsItem:
    id: str                          # 新闻唯一ID
    title: str                       # 标题
    summary: str = ""                # 摘要
    content: Optional[str] = None    # 完整内容
    url: str = ""                    # 原文链接
    source_name: str = ""            # 来源名称
    publish_time: Optional[str] = None  # 发布时间
    category: Optional[NewsCategory] = None  # 分类
    image_url: Optional[str] = None  # 配图URL
    author: Optional[str] = None     # 作者
    tags: List[str] = field(default_factory=list)  # 标签
    is_full_version: bool = False    # 是否为完整版节目
```

---

## 六、NewsCategory 枚举

```python
class NewsCategory(Enum):
    GENERAL = "general"        # 综合
    POLITICS = "politics"       # 时政
    TECH = "tech"               # 科技
    ENTERTAINMENT = "ent"       # 娱乐
    SPORTS = "sports"           # 体育
    FINANCE = "finance"         # 财经
    SOCIETY = "society"         # 社会
    EDUCATION = "education"     # 教育
    OTHER = "other"             # 其他
```

---

## 七、插件 ID 分配

| ID 范围 | 用途 | 说明 |
|--------|------|------|
| 1-99 | 内置官方插件 | 官方维护的新闻源 |
| 100-999 | 预留 | 扩展插件 |
| 1000+ | 用户插件 | 用户自定义插件 |

---

## 八、示例：完整插件代码

```python
# plugins/my_plugin/plugin.py
from core.plugin_interface import (
    INewsSource, PluginInfo, NewsItem, FetchResult, NewsCategory
)

class MyNewsPlugin(INewsSource):
    def __init__(self):
        super().__init__()
        self._info = PluginInfo(
            id=1001,
            name="我的新闻源",
            version="1.0.0",
            author="作者",
            description="这是一个示例插件"
        )
    
    def on_load(self):
        """插件加载时调用"""
        print("插件加载成功")
    
    def on_unload(self):
        """插件卸载时调用"""
        print("插件卸载")
    
    async def fetch_news(self, category=None, count=20, cursor=None):
        # 获取新闻逻辑
        items = [
            NewsItem(
                id="1",
                title="新闻标题",
                summary="新闻摘要",
                source_name="我的新闻源"
            )
        ]
        return FetchResult(items=items, has_more=False, total=1)
    
    async def get_news_detail(self, news_id: str):
        return NewsItem(
            id=news_id,
            title="新闻详情",
            content="完整内容...",
            source_name="我的新闻源"
        )
    
    async def play_news(self, news_id: str, on_progress=None):
        # 播放逻辑
        return True

# 导出插件类
plugin_class = MyNewsPlugin
```

---

*本文档由 AI 生成，最后更新: 2026-05-02*
