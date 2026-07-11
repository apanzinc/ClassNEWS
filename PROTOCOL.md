# ClassNEWS 协议文档

## 1. 浏览器协议 (classnews://)

### 1.1 协议注册

ClassNEWS 会在启动时自动注册 `classnews://` 协议到 Windows 注册表，允许浏览器和其他应用直接调用 ClassNEWS 播放视频。

### 1.2 协议格式（新架构）

```
classnews://play?plugin=PLUGIN_ID&action=ACTION&title=TITLE
```

### 1.3 支持的参数

| 参数 | 类型 | 必需 | 描述 | 默认值 |
|------|------|------|------|--------|
| `plugin` | 整数 | 是 | 插件 ID | - |
| `action` | 字符串 | 否 | 动作类型（透传给插件） | "play" |
| `title` | 字符串 | 否 | 视频标题 | "视频" |

**播放控制参数（软件处理，不传给插件）：**

| 参数 | 类型 | 必需 | 描述 | 默认值 |
|------|------|------|------|--------|
| `rate` | 数字 | 否 | 播放倍率 | 系统设置 |
| `volume` | 数字 | 否 | 音量 (0-100) | 系统设置 |
| `time` | 数字 | 否 | 开始时间 (秒) | 系统设置 |
| `fullscreen` | 布尔值 | 否 | 是否全屏 | 系统设置 |

### 1.4 插件 Action（透传）

插件自己决定如何处理 action，常见值：

| Action | 描述 |
|--------|------|
| `today` | 播放当天的完整版新闻 |
| `latest` | 播放最新的新闻 |
| `play` | 播放指定新闻（需要额外参数如 `id`） |

### 1.5 协议示例

#### 1.5.1 播放当天新闻（插件 ID=1）
```
classnews://play?plugin=1&action=today
```

#### 1.5.2 带参数播放
```
classnews://play?plugin=1&action=today&title=朝闻天下&rate=1.5&volume=60&fullscreen=true
```

#### 1.5.3 测试协议
```
classnews://test
```

#### 1.5.4 关闭播放器
```
classnews://close
```

### 1.6 优先级规则

- **协议参数优先**：如果协议中明确指定了参数，则使用协议值
- **系统设置兜底**：如果协议中未指定参数，则使用系统设置的默认值
- **插件自主**：action 和额外参数透传给插件，插件自己决定如何处理

### 1.7 数据流

```
classnews://play?plugin=1&action=today&volume=80
        │
        ▼
  ProtocolManager.parseProtocolUrl()
        │  提取: plugin=1, action=today, volume=80
        ▼
  软件处理播放控制参数 (volume/fullscreen/rate/time)
        │
        ▼
  路由到插件1 → plugin.handle_protocol_request("today", {})
        │
        ▼
  插件返回: {id, title, type, url, isFullVersion, ...}
        │
        ▼
  软件用返回的 url 播放，id 用于断点续播
```

## 2. 本地 API 服务器

### 2.1 服务器信息

- **地址**：`http://localhost:45678`
- **端口**：45678（不常用端口，减少冲突）
- **CORS**：支持跨域访问
- **访问限制**：仅本地访问（127.0.0.1）

### 2.2 API 端点

#### 2.2.1 获取所有新闻
```
GET /api/news
```

**返回格式**：
```json
[
    {
        "id": "b85050028c86464ab8f42447351e6687",
        "title": "朝闻天下 20260418 08:00",
        "type": "video",
        "isFullVersion": true,
        "duration": "00:53:09",
        "publishTime": "2026-04-18 08:00:00",
        "summary": "今日新闻摘要..."
    }
]
```

#### 2.2.2 获取完整版新闻
```
GET /api/news/full
```

**返回格式**：只包含 `isFullVersion: true` 的新闻

#### 2.2.3 获取普通新闻
```
GET /api/news/normal
```

**返回格式**：只包含 `isFullVersion: false` 的新闻

#### 2.2.4 获取服务器状态
```
GET /api/status
```

**返回格式**：
```json
{
    "status": "running",
    "news_count": 50,
    "full_news_count": 1,
    "api_version": "1.0"
}
```

### 2.3 数据更新

- **初始更新**：服务器启动时自动获取新闻数据
- **定期更新**：每 5 分钟自动更新一次新闻数据
- **实时性**：数据与 ClassNEWS 应用保持同步

### 2.4 使用示例

#### 2.4.1 浏览器访问
```
http://localhost:45678/api/news
```

#### 2.4.2 JavaScript 调用
```javascript
fetch('http://localhost:45678/api/news')
    .then(response => response.json())
    .then(data => {
        console.log('新闻数据:', data);
        // 处理新闻数据
    });
```

#### 2.4.3 Python 调用
```python
import requests

response = requests.get('http://localhost:45678/api/news')
news = response.json()
print(f'获取到 {len(news)} 条新闻')
```

## 3. 第三方集成

### 3.1 播放视频

第三方应用可以通过以下方式调用 ClassNEWS 播放视频：

1. **使用浏览器协议**（推荐）：
   ```
   classnews://play?plugin=1&action=today&fullscreen=true
   ```

2. **使用本地 API** 获取新闻，然后使用浏览器协议播放：
   ```python
   # 1. 获取新闻列表
   response = requests.get('http://localhost:45678/api/news/full')
   full_news = response.json()
   
   # 2. 获取第一个完整版新闻
   if full_news:
       news = full_news[0]
       news_id = news['id']
       title = news['title']
       
       # 3. 调用浏览器协议播放（通过插件获取播放地址）
       import webbrowser
       webbrowser.open(f'classnews://play?plugin=1&action=play&id={news_id}&title={title}&fullscreen=true')
   ```

### 3.2 获取新闻数据

第三方应用可以通过本地 API 获取新闻数据，用于显示或分析：

```javascript
// 获取当天的完整版新闻
fetch('http://localhost:45678/api/news/full')
    .then(response => response.json())
    .then(full_news => {
        if (full_news.length > 0) {
            const today_news = full_news[0];
            console.log('当天完整版新闻:', today_news.title);
            console.log('时长:', today_news.duration);
        }
    });
```

## 4. 错误处理

### 4.1 浏览器协议错误

- **缺少 plugin**：协议 URL 缺少 `plugin` 参数时，会返回错误
- **插件不存在**：当插件 ID 不存在或已禁用时，会显示错误提示
- **网络错误**：当网络连接失败时，会显示系统通知

### 4.2 本地 API 错误

- **服务器未启动**：返回 404 错误
- **数据获取失败**：返回空数组
- **格式错误**：返回 JSON 解析错误

## 5. 安全考虑

1. **本地访问限制**：API 服务器只监听 127.0.0.1，外部无法访问
2. **CORS 配置**：支持跨域访问，方便前端应用调用
3. **无敏感信息**：API 只返回公开的新闻数据，不包含用户隐私信息
4. **请求频率**：内部应用每 5 分钟更新一次，避免频繁请求

## 6. 故障排除

### 6.1 协议注册失败

- **原因**：权限不足或注册表被锁定
- **解决**：以管理员身份运行 ClassNEWS

### 6.2 本地服务器启动失败

- **原因**：端口 45678 被占用
- **解决**：检查并关闭占用该端口的应用

### 6.3 API 无响应

- **原因**：ClassNEWS 未运行或服务器未启动
- **解决**：启动 ClassNEWS 应用

## 7. 内部通信协议安全边界

### 7.1 安全原则

ClassNEWS 内部通信遵循以下安全原则：

1. **禁止外部 HTTP 通信**：内部组件之间禁止使用 HTTP 等网络协议进行通信
2. **进程内通信优先**：所有内部通信应通过 Qt 信号槽机制、函数调用或共享内存实现
3. **数据完整性保护**：内部通信数据应进行校验，防止篡改
4. **权限隔离**：内置插件与用户插件应有明确的权限边界

### 7.2 内部通信方式

| 通信场景 | 推荐方式 | 说明 |
|----------|----------|------|
| Python ↔ QML | Qt 信号槽 + Property | 通过 PySide6 的信号槽机制实现双向通信 |
| 插件 ↔ 主程序 | PluginManager API | 通过 `core/plugin_manager.py` 提供的接口调用 |
| 后台线程 ↔ 主线程 | QThread + Signal | 使用 Qt 线程机制，避免直接共享状态 |
| 本地 API ↔ 主程序 | 共享内存 + 线程安全访问 | 通过 `get_plugin_manager()` 全局单例访问 |

### 7.3 禁止的通信方式

- ❌ **HTTP/TCP 本地回环**：禁止使用 `http://localhost:xxx` 进行内部通信
- ❌ **文件共享**：禁止通过临时文件传递数据（除配置文件外）
- ❌ **命令行调用**：禁止通过 subprocess 调用自身或子进程

### 7.4 安全边界

```
┌─────────────────────────────────────────────────────────────┐
│                     ClassNEWS 进程                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    信号槽     ┌──────────────┐          │
│  │   QML 层     │◄─────────────►│   Python层   │          │
│  └──────────────┘                └──────┬───────┘          │
│                                         │                  │
│                              PluginManager API             │
│                                         │                  │
│                    ┌────────────────────┼───────────────────┐
│                    │                    │                   │
│         ┌──────────▼──────────┐ ┌───────▼────────┐         │
│         │   内置插件 (只读)    │ │ 用户插件(读写) │         │
│         │   • 禁止修改系统文件  │ │ • 可读写用户目录│         │
│         │   • 禁止网络请求     │ │ • 可发起网络请求│         │
│         │   • 可禁用不可卸载   │ │ • 可禁用可卸载  │         │
│         └─────────────────────┘ └────────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                    本地 API 服务器 (仅本地访问)              │
│                        127.0.0.1:45678                     │
└─────────────────────────────────────────────────────────────┘
```

### 7.5 插件权限分层

| 权限级别 | 内置插件 | 用户插件 |
|----------|----------|----------|
| 文件读取 | ✅ 全部 | ✅ 用户目录 |
| 文件写入 | ❌ | ✅ 用户目录 |
| 网络请求 | ❌ | ✅ |
| 系统调用 | ❌ | ❌ |
| 可卸载 | ❌ | ✅ |
| 可禁用 | ✅ | ✅ |

---

## 8. 插件系统 API 文档

### 8.1 API 概述

ClassNEWS 插件系统允许开发者扩展新闻数据源。插件通过实现 `INewsSource` 接口与主程序交互。

**API 版本**：`2.0.0`

### 8.2 核心接口

#### 8.2.1 INewsSource 接口

```python
from core import INewsSource, PluginInfo, NewsItem, NewsCategory, FetchResult

class MyNewsPlugin(INewsSource):
    def __init__(self):
        self._info = PluginInfo(
            id=1001,
            name="我的新闻插件",
            version="1.0.0",
            author="作者名",
            description="插件描述"
        )
    
    async def fetch_news(self, category=None, count=20, cursor=None):
        """获取新闻列表"""
        # 返回 FetchResult 对象
        pass
    
    async def get_news_detail(self, news_id):
        """获取新闻详情"""
        # 返回 NewsItem 或 None
        pass
    
    async def handle_protocol_request(self, action, params):
        """
        处理协议请求（新架构）
        
        Args:
            action: 动作类型（如 today/latest/play）
            params: 额外参数
            
        Returns:
            NewsItem 对象（必须包含 id, title, type, url）
        """
        pass
```

#### 8.2.2 数据结构

**NewsItem（新闻项）**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | str | ✅ | 新闻唯一ID |
| `title` | str | ✅ | 标题 |
| `type` | str | ✅ | 内容类型: video/audio/text |
| `summary` | str | ❌ | 摘要 |
| `content` | str | ❌ | 完整内容 |
| `url` | str | ✅ | 资源地址（视频/音频链接） |
| `source_name` | str | ❌ | 来源名称 |
| `publish_time` | str | ❌ | 发布时间 |
| `category` | NewsCategory | ❌ | 分类 |
| `image_url` | str | ❌ | 配图URL |
| `author` | str | ❌ | 作者 |
| `tags` | list | ❌ | 标签列表 |
| `is_full_version` | bool | ❌ | 是否完整版 |

**内容类型（type）**：

| 类型 | 说明 |
|------|------|
| `video` | 视频内容 |
| `audio` | 音频内容 |
| `text` | 文本/Markdown 内容 |

**NewsCategory（新闻分类）**：

| 枚举值 | 说明 |
|--------|------|
| `GENERAL` | 综合 |
| `POLITICS` | 时政 |
| `TECH` | 科技 |
| `ENTERTAINMENT` | 娱乐 |
| `SPORTS` | 体育 |
| `FINANCE` | 财经 |
| `SOCIETY` | 社会 |
| `EDUCATION` | 教育 |
| `OTHER` | 其他 |

**FetchResult（获取结果）**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `items` | list[NewsItem] | 新闻列表 |
| `has_more` | bool | 是否有更多 |
| `next_cursor` | str | 下一页游标 |
| `total` | int | 总条数 |

### 8.3 QML 层 API

#### 8.3.1 PluginManager 暴露接口

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `plugins` | list | 插件列表（QML 属性） |
| `setPluginEnabled(pluginId, enabled)` | bool | 启用/禁用插件 |
| `uninstallPlugin(pluginId)` | bool | 卸载用户插件 |
| `importPlugin()` | list[int] | 导入插件，返回冲突ID列表 |
| `openPluginFolder(pluginId)` | bool | 打开插件目录 |
| `exportPlugin(pluginId)` | str | 导出插件为 .cnplugin |
| `reloadPlugin(pluginId)` | bool | 重载用户插件 |
| `getAPIVersion()` | str | 获取 API 版本 |
| `isPluginCompatible(pluginId)` | bool | 检查兼容性 |

#### 8.3.2 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `pluginListChanged` | - | 插件列表变化 |
| `pluginImportSucceeded` | - | 导入成功 |
| `pluginImportFailed` | error: str | 导入失败 |
| `pluginReloadSucceeded` | pluginId: int | 重载成功 |
| `pluginReloadFailed` | pluginId: int, error: str | 重载失败 |
| `pluginExportSucceeded` | path: str | 导出成功 |

### 8.4 插件生命周期

```
加载 (on_load) → 运行 → 卸载/禁用 (on_unload)
      │              │                │
      ▼              ▼                ▼
   初始化         fetch_news       资源清理
   网络连接       get_news_detail   保存配置
   加载配置       handle_protocol_request
```

### 8.5 插件文件结构

```
plugins/
└── my_plugin/
    ├── plugin.py           # 插件主文件
    ├── cwplugin.json       # 元数据文件
    └── icon.png            # 插件图标（可选）
```

**cwplugin.json 示例**：

```json
{
    "id": 1001,
    "name": "我的新闻插件",
    "version": "1.0.0",
    "api_version": ">=2.0.0",
    "author": "作者名",
    "description": "插件描述",
    "homepage": "https://example.com"
}
```

---

## 9. 数据源自定义边界

### 9.1 插件类型定义

#### 9.1.1 内置插件（Builtin）

- **位置**：`plugins/` 目录（程序安装目录）
- **权限**：只读，禁止网络请求
- **生命周期**：随程序启动加载，可禁用但不可卸载
- **用途**：官方数据源、核心功能扩展

#### 9.1.2 用户插件（User）

- **位置**：用户目录（如 `%APPDATA%\ClassNEWS\plugins`）
- **权限**：可读写用户目录，可发起网络请求
- **生命周期**：可安装、禁用、卸载、重载
- **用途**：第三方数据源、自定义功能

### 9.2 权限边界矩阵

| 操作 | 内置插件 | 用户插件 |
|------|----------|----------|
| 读取配置文件 | ✅ | ✅ |
| 写入配置文件 | ❌ | ✅ (用户目录) |
| 发起网络请求 | ❌ | ✅ |
| 修改系统文件 | ❌ | ❌ |
| 执行系统命令 | ❌ | ❌ |
| 访问用户数据 | ✅ | ✅ |
| 卸载 | ❌ | ✅ |
| 禁用 | ✅ | ✅ |
| 重载 | ❌ | ✅ |

### 9.3 安全限制

1. **网络请求限制**：内置插件禁止发起网络请求，防止数据泄露
2. **文件系统限制**：用户插件只能读写用户目录，禁止访问系统目录
3. **权限隔离**：插件无法获取系统管理员权限
4. **API 版本检查**：插件必须声明兼容的 API 版本

### 9.4 插件开发规范

1. **ID 唯一性**：插件 ID 必须全局唯一（建议使用 1000+）
2. **API 版本声明**：必须在 `cwplugin.json` 中声明 `api_version`
3. **异常处理**：所有方法应妥善处理异常，避免导致主程序崩溃
4. **资源清理**：在 `on_unload` 中释放资源
5. **协议处理**：实现 `handle_protocol_request` 以支持浏览器协议调用

---

## 10. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2026-04-18 | 初始版本，支持浏览器协议和本地 API |
| 1.1 | 2026-05-08 | 添加内部通信协议安全边界、插件系统 API、数据源边界文档 |
| 2.0 | 2026-05-16 | **重大更新**：改为多插件架构，协议支持 plugin 参数路由，插件返回带 type 和 url 的数据 |

---

**注意**：本地 API 服务器与浏览器协议共用一个开关，当 ClassNEWS 启动时自动启动，关闭时自动停止。
