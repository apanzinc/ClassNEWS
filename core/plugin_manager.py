"""
插件管理器
负责插件的加载、注册、管理和生命周期

插件分为两类：
- 内置插件：打包在软件内，只能禁用，不能卸载
- 用户插件：用户目录，可禁用、可卸载

QML 暴露接口（继承 QObject）：
- plugins: list — 插件列表（每次返回新列表，QML 直接赋值监听变化）
- pluginListChanged: signal — 列表变化时触发
- setPluginEnabled(pluginId, enabled): bool
- uninstallPlugin(pluginId): bool
- importPlugin(): List[int] — 打开文件对话框，返回冲突插件列表或空
- openPluginFolder(pluginId): bool — 打开指定插件目录或用户根目录
"""

import os
import sys
import json
import importlib
import importlib.util
import shutil
from typing import Dict, List, Optional, Any
from pathlib import Path
from dataclasses import dataclass
from enum import Enum
import asyncio
import logging

from PySide6.QtCore import QObject, Property as pyqtProperty, Signal as pyqtSignal, Slot as pyqtSlot, QUrl
from PySide6.QtGui import QDesktopServices
from .plugin_interface import INewsSource, PluginInfo, NewsItem, NewsCategory, FetchResult

logger = logging.getLogger(__name__)

# API 版本（ClassNEWS 插件接口版本）
__API_VERSION__ = "1.0.0"


def check_api_version(plugin_api_version: str) -> bool:
    """
    检查插件 API 版本兼容性
    
    参考 Class-Widgets-2 的实现，使用语义化版本检查
    plugin_api_version 可以是：
    - "*" 或空字符串：兼容所有版本
    - "1.0.0"：精确匹配
    - ">=1.0.0"：大于等于
    - ">=1.0.0,<2.0.0"：版本范围
    
    Args:
        plugin_api_version: 插件要求的 API 版本
        
    Returns:
        True 表示兼容，False 表示不兼容
    """
    if not plugin_api_version or plugin_api_version.strip() in ("*", ""):
        return True
    
    try:
        from packaging.specifiers import SpecifierSet
        from packaging.version import Version
        
        api_v = Version(__API_VERSION__)
        # 对于精确版本号，SpecifierSet 的行为需要特殊处理
        # "1.0.0" 应该匹配 "==1.0.0" 或 ">=1.0.0,<2.0.0"
        plugin_version = plugin_api_version.strip()
        
        # 如果是精确版本号（不含操作符），转换为 == 操作符
        if not any(op in plugin_version for op in (">=", "<=", ">", "<", "~", "^", "==")):
            plugin_version = f"=={plugin_version}"
        
        required_specs = SpecifierSet(plugin_version)
        return required_specs.contains(api_v)
    except ImportError:
        # packaging 未安装，使用简单版本检查
        logger.debug("packaging not installed, using simple version check")
        return _simple_version_check(plugin_api_version)
    except Exception as e:
        logger.debug(f"Version check failed: {e}")
        return False


def _simple_version_check(plugin_api_version: str) -> bool:
    """简单的版本检查（fallback）"""
    try:
        # 解析当前版本
        current_parts = tuple(int(x) for x in __API_VERSION__.split("."))
        
        # 去掉操作符
        version_str = plugin_api_version.lstrip(">=").lstrip("<=").lstrip(">").lstrip("<").lstrip("~").lstrip("^")
        required_parts = tuple(int(x) for x in version_str.split(".")[:3])
        
        # 默认检查主版本和次版本
        return current_parts[0] == required_parts[0] and current_parts[1] >= required_parts[1]
    except Exception:
        return False


class PluginType(Enum):
    BUILTIN = "builtin"
    USER = "user"


@dataclass
class PluginRecord:
    plugin_id: int
    name: str
    plugin_type: PluginType
    directory: str
    enabled: bool = True


def _load_cwplugin_meta(plugin_dir: Path) -> Optional[dict]:
    """加载 cwplugin.json 元数据文件"""
    meta_file = plugin_dir / "cwplugin.json"
    if meta_file.exists():
        try:
            with open(meta_file, "r", encoding="utf-8") as f:
                meta = json.load(f)
                # 验证 meta 信息
                if not _validate_meta(meta, plugin_dir):
                    return None
                return meta
        except Exception as e:
            logger.warning(f"Failed to load cwplugin.json in {plugin_dir}: {e}")
    return None


def _validate_plugin_convention(plugin_dir: Path, plugin: INewsSource, meta: Optional[dict] = None) -> None:
    """插件命名与 ID 约定检查（仅告警，不阻塞加载）。"""
    dir_name = plugin_dir.name

    # 建议目录名使用英文 + 下划线/数字
    if not all(ch.isascii() for ch in dir_name):
        logger.warning(
            f"Plugin directory naming suggestion: '{dir_name}' contains non-ASCII chars, "
            f"recommended English name for better portability"
        )

    # 建议目录名包含插件 ID，便于快速定位与排障
    plugin_id_str = str(plugin.id)
    if plugin_id_str not in dir_name:
        logger.info(
            f"Plugin directory suggestion: '{dir_name}' does not include plugin ID {plugin.id}. "
            f"Recommended pattern like 'news_{plugin.id}'"
        )

    # 代码元信息与 cwplugin.json 的 ID 不一致时给出警告
    if meta and "id" in meta and meta.get("id") != plugin.id:
        logger.warning(
            f"Plugin ID mismatch in {plugin_dir}: plugin.py={plugin.id}, cwplugin.json={meta.get('id')}"
        )


def _validate_meta(meta: dict, plugin_dir: Path) -> bool:
    """
    验证插件 meta 信息
    
    参考 Class-Widgets-2 的实现，检查必填字段
    
    Args:
        meta: 插件元数据字典
        plugin_dir: 插件目录（用于日志）
        
    Returns:
        True 表示验证通过，False 表示验证失败
    """
    required_fields = ["id", "name", "version", "api_version", "author"]
    
    for field in required_fields:
        if field not in meta or not meta[field]:
            logger.warning(f"Plugin meta missing required field '{field}' in {plugin_dir}")
            return False
    
    # 检查 API 版本兼容性
    if not check_api_version(meta.get("api_version", "")):
        logger.warning(
            f"Plugin {meta.get('name', 'unknown')} API version "
            f"{meta.get('api_version')} is incompatible with current version {__API_VERSION__}"
        )
        # 不阻止加载，但会在 UI 中标记
    
    return True


def _plugin_to_dict(record: PluginRecord, meta: Optional[dict] = None, plugin: Optional[INewsSource] = None) -> dict:
    """将插件记录转为 QML 可用的 dict"""
    # 检查 API 版本兼容性
    api_version = meta.get("api_version", "") if meta else ""
    compatible = check_api_version(api_version) if api_version else True

    icon = ""
    icon_path = ""
    if plugin and plugin.info.icon:
        # 支持两种图标：Fluent 图标名，或插件目录下的图片路径（如 icon.png）
        raw_icon = plugin.info.icon
        candidate = Path(raw_icon)
        if not candidate.is_absolute():
            candidate = Path(record.directory) / raw_icon

        if candidate.exists() and candidate.is_file():
            icon_path = candidate.as_posix()
        else:
            icon = raw_icon

    return {
        "pluginId": record.plugin_id,
        "name": record.name,
        "type": record.plugin_type.value,  # "builtin" | "user"
        "enabled": record.enabled,
        "builtin": record.plugin_type == PluginType.BUILTIN,
        "directory": record.directory,
        "author": meta.get("author", "") if meta else "",
        "version": meta.get("version", "") if meta else "",
        "description": meta.get("description", "") if meta else "",
        "apiVersion": api_version,
        "compatible": compatible,  # 添加兼容性标记
        "icon": icon,
        "iconPath": icon_path,
    }


class PluginManager(QObject):
    """插件管理器 — 继承 QObject，直接暴露给 QML
    实例由 main.py 的 get_plugin_manager() 管理（lazy init）
    """

    # === QML 信号 ===
    pluginListChanged = pyqtSignal()
    pluginImportSucceeded = pyqtSignal()      # 插件导入成功
    pluginImportFailed = pyqtSignal(str)      # 插件导入失败，参数为错误信息
    pluginReloadSucceeded = pyqtSignal(int)   # 插件重载成功，参数为 plugin_id
    pluginReloadFailed = pyqtSignal(int, str)  # 插件重载失败，参数为 plugin_id 和错误信息
    pluginExportSucceeded = pyqtSignal(str)   # 插件导出成功，参数为文件路径

    # === QML 属性 ===
    @pyqtProperty("QVariantList", notify=pluginListChanged)
    def plugins(self) -> List[dict]:
        """插件列表，供 QML 直接绑定"""
        result = []
        print(f"[DEBUG] plugins 属性被访问，_plugin_records 数量: {len(self._plugin_records)}")
        for record in self._plugin_records.values():
            meta = self._plugin_meta_cache.get(record.plugin_id)
            plugin = self._plugins.get(record.plugin_id)
            result.append(_plugin_to_dict(record, meta, plugin))
        print(f"[DEBUG] 返回插件列表数量: {len(result)}")
        return result

    def __init__(self):
        super().__init__()
        self._init_directories()
        self._init_state()
        self._plugin_meta_cache: Dict[int, Optional[dict]] = {}
        logger.info("PluginManager initialized")
        logger.info(f"  Builtin dir: {self._builtin_dir}")
        logger.info(f"  User dir: {self._user_dir}")

    # ── 目录与状态 ────────────────────────────────────────────────────────

    def _init_directories(self):
        self._base_dir = Path(__file__).parent.parent
        self._builtin_dir = self._base_dir / "plugins"
        self._user_dir = self._get_user_plugins_dir()
        self._ensure_user_dir_exists()

    def _get_user_plugins_dir(self) -> Path:
        if getattr(sys, "frozen", False):
            base = Path(sys.executable).parent
        else:
            base = self._base_dir

        if sys.platform == "win32":
            return Path(os.environ.get("APPDATA", base)) / "ClassNEWS" / "plugins"
        elif sys.platform == "darwin":
            return Path.home() / "Library" / "Application Support" / "ClassNEWS" / "plugins"
        else:
            return Path.home() / ".classnews" / "plugins"

    def _ensure_user_dir_exists(self):
        try:
            self._user_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            logger.error(f"Failed to create user plugins dir: {e}")

    def _init_state(self):
        self._plugins: Dict[int, INewsSource] = {}
        self._plugin_records: Dict[int, PluginRecord] = {}
        self._state_file = self._user_dir / "plugin_states.json"
        self._load_plugin_states()

    def _load_plugin_states(self):
        if self._state_file.exists():
            try:
                with open(self._state_file, "r", encoding="utf-8") as f:
                    states = json.load(f)
                    self._plugin_states = states.get("states", {})
            except Exception as e:
                logger.error(f"Failed to load plugin states: {e}")
                self._plugin_states = {}
        else:
            self._plugin_states = {}

    def _save_plugin_states(self):
        try:
            self._state_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self._state_file, "w", encoding="utf-8") as f:
                json.dump({"states": self._plugin_states}, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"Failed to save plugin states: {e}")

    # ── 加载 ───────────────────────────────────────────────────────────────

    def load_all_plugins(self) -> int:
        self._load_plugins_from_dir(self._builtin_dir, PluginType.BUILTIN, allow_delete=False)
        self._load_plugins_from_dir(self._user_dir, PluginType.USER, allow_delete=True)
        count = len(self._plugins)
        logger.info(f"Loaded {count} plugins")
        
        # 如果所有插件都被禁用，自动启用官方新闻插件
        all_disabled = all(not p.info.enabled for p in self._plugins.values())
        if all_disabled and 1 in self._plugins:
            logger.info("所有插件都被禁用，自动启用官方新闻插件")
            self._plugins[1]._info.enabled = True
            record = self._plugin_records.get(1)
            if record:
                record.enabled = True
        
        self.pluginListChanged.emit()
        return count

    def _load_plugins_from_dir(
        self, plugins_dir: Path, plugin_type: PluginType, allow_delete: bool = False
    ) -> int:
        count = 0
        if not plugins_dir.exists():
            return 0

        for plugin_dir in plugins_dir.iterdir():
            if not plugin_dir.is_dir() or plugin_dir.name.startswith(("_", ".")):
                continue
            try:
                if self._load_single_plugin(plugin_dir, plugin_type):
                    count += 1
            except Exception as e:
                logger.error(f"Failed to load plugin {plugin_dir}: {e}")
        return count

    def _load_single_plugin(self, plugin_dir: Path, plugin_type: PluginType) -> bool:
        plugin_name = plugin_dir.name
        plugin_file = plugin_dir / "plugin.py"

        if not plugin_file.exists():
            return False

        try:
            spec = importlib.util.spec_from_file_location(
                f"plugins.{plugin_type.value}.{plugin_name}", plugin_file
            )
            if spec is None or spec.loader is None:
                return False

            module = importlib.util.module_from_spec(spec)
            sys.modules[f"plugins.{plugin_type.value}.{plugin_name}"] = module
            spec.loader.exec_module(module)

            if not hasattr(module, "plugin_class"):
                logger.warning(f"Plugin missing plugin_class: {plugin_name}")
                return False

            plugin_class = module.plugin_class
            if not issubclass(plugin_class, INewsSource):
                logger.warning(f"Plugin must inherit INewsSource: {plugin_name}")
                return False

            plugin = plugin_class()
            plugin_id = plugin.id
            
            if plugin_id in self._plugins:
                logger.warning(f"Plugin ID conflict: {plugin_id}")
                return False
            
            # 调用 on_load 生命周期钩子
            try:
                plugin.on_load()
            except Exception as e:
                logger.error(f"Plugin {plugin_name} on_load() failed: {e}")
                return False
            
            # 缓存 cwplugin.json 元数据
            meta = _load_cwplugin_meta(plugin_dir)
            if meta:
                self._plugin_meta_cache[plugin_id] = meta

            # 约定检查（仅日志提示）
            _validate_plugin_convention(plugin_dir, plugin, meta)

            # 记录元数据
            record = PluginRecord(
                plugin_id=plugin_id,
                name=plugin.name,
                plugin_type=plugin_type,
                directory=str(plugin_dir),
                enabled=True,
            )

            # 应用持久化状态
            saved_state = self._plugin_states.get(str(plugin_id))
            if saved_state is not None:
                plugin._info.enabled = saved_state
                record.enabled = saved_state

            self._plugin_records[plugin_id] = record
            self._plugins[plugin_id] = plugin
            logger.info(
                f"Loaded plugin: {plugin.name} (ID: {plugin_id}, type: {plugin_type.value})"
            )
            return True

        except Exception as e:
            logger.error(f"Error loading plugin {plugin_name}: {e}")
            return False

    # ── QML 槽函数 ─────────────────────────────────────────────────────────

    @pyqtSlot(int, bool, result=bool)
    def setPluginEnabled(self, plugin_id: int, enabled: bool) -> bool:
        """启用/禁用插件"""
        plugin = self._plugins.get(plugin_id)
        if plugin is None:
            return False

        plugin._info.enabled = enabled
        self._plugin_states[str(plugin_id)] = enabled
        self._save_plugin_states()

        record = self._plugin_records.get(plugin_id)
        if record:
            record.enabled = enabled

        self.pluginListChanged.emit()
        return True

    @pyqtSlot(int, result=bool)
    def uninstallPlugin(self, plugin_id: int) -> bool:
        """卸载用户插件，返回是否成功"""
        record = self._plugin_records.get(plugin_id)
        if not record:
            return False

        if record.plugin_type == PluginType.BUILTIN:
            logger.warning(f"Cannot uninstall builtin plugin: {plugin_id}")
            return False

        try:
            # 调用 on_unload 生命周期钩子
            if plugin_id in self._plugins:
                try:
                    self._plugins[plugin_id].on_unload()
                except Exception as e:
                    logger.warning(f"Error in plugin {plugin_id} on_unload(): {e}")
                del self._plugins[plugin_id]
            
            if plugin_id in self._plugin_records:
                del self._plugin_records[plugin_id]
            if plugin_id in self._plugin_meta_cache:
                del self._plugin_meta_cache[plugin_id]

            if str(plugin_id) in self._plugin_states:
                del self._plugin_states[str(plugin_id)]
                self._save_plugin_states()

            plugin_dir = Path(record.directory)
            if plugin_dir.exists():
                shutil.rmtree(plugin_dir)

            logger.info(f"Uninstalled plugin: {plugin_id}")
            self.pluginListChanged.emit()
            return True

        except Exception as e:
            logger.error(f"Failed to uninstall plugin {plugin_id}: {e}")
            return False

    @pyqtSlot(result="QVariantList")
    def importPlugin(self) -> List[int]:
        """
        打开文件对话框让用户选择插件文件，返回冲突的插件ID列表。
        空列表表示安装成功无冲突。
        """
        from PySide6.QtWidgets import QFileDialog

        file_path, _ = QFileDialog.getOpenFileName(
            None,
            "选择插件",
            "",
            "插件文件 (*.zip *.cnplugin);;所有文件 (*.*)",
        )

        if not file_path:
            return []

        conflicts = self._install_plugin(file_path)
        self.pluginListChanged.emit()
        return conflicts

    def _install_plugin(self, source_path: str) -> List[int]:
        """安装插件，返回冲突的插件ID列表"""
        import zipfile

        source = Path(source_path)
        if not source.exists():
            return []

        conflicts = []
        try:
            temp_dir = self._user_dir / "_temp_install"
            temp_dir.mkdir(parents=True, exist_ok=True)

            if source.suffix.lower() in [".zip", ".cnplugin"]:
                with zipfile.ZipFile(source, "r") as zf:
                    zf.extractall(temp_dir)
            else:
                if source.is_dir():
                    for item in source.iterdir():
                        shutil.copy2(item, temp_dir / item.name)

            plugin_file = None
            plugin_name = None
            for item in temp_dir.rglob("plugin.py"):
                plugin_file = item
                plugin_name = item.parent.name
                break

            if not plugin_file:
                shutil.rmtree(temp_dir, ignore_errors=True)
                return []

            # 检查冲突
            spec = importlib.util.spec_from_file_location("test_plugin", plugin_file)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            plugin_class = module.plugin_class
            test_plugin = plugin_class()
            plugin_id = test_plugin.id

            if plugin_id in self._plugins:
                conflicts.append(plugin_id)

            target_dir = self._user_dir / plugin_name
            if target_dir.exists():
                shutil.rmtree(target_dir)
            shutil.move(str(temp_dir), str(target_dir))

            if self._load_single_plugin(target_dir, PluginType.USER):
                self.pluginImportSucceeded.emit()
            else:
                self.pluginImportFailed.emit("插件加载失败")

        except Exception as e:
            logger.error(f"Failed to install plugin: {e}")
            self.pluginImportFailed.emit(str(e))
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

        return conflicts

    @pyqtSlot(int, result=bool)
    def openPluginFolder(self, plugin_id: int) -> bool:
        """打开指定插件的目录，或用户插件根目录"""
        if plugin_id:
            record = self._plugin_records.get(plugin_id)
            if record and record.directory:
                folder = Path(record.directory)
                if folder.exists():
                    QDesktopServices.openUrl(QUrl.fromLocalFile(str(folder)))
                    logger.info(f"Opened plugin folder: {folder}")
                    return True
                logger.warning(f"Plugin folder does not exist: {folder}")
                return False

        # 打开用户插件根目录
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(self._user_dir)))
        return True

    @pyqtSlot(int, result=str)
    def exportPlugin(self, plugin_id: int) -> str:
        """
        导出用户插件为压缩包（.cnplugin）
        返回保存的文件路径，失败返回空字符串
        """
        record = self._plugin_records.get(plugin_id)
        if not record:
            return ""
        
        if record.plugin_type == PluginType.BUILTIN:
            logger.warning(f"Cannot export builtin plugin: {plugin_id}")
            return ""
        
        import zipfile
        from PySide6.QtWidgets import QFileDialog
        
        source_dir = Path(record.directory)
        if not source_dir.exists():
            return ""
        
        # 默认文件名：插件名_version.cnplugin
        meta = self._plugin_meta_cache.get(plugin_id, {})
        version = meta.get("version", "1.0.0")
        default_name = f"{record.name}_{version}.cnplugin"
        
        file_path, _ = QFileDialog.getSaveFileName(
            None,
            "导出插件",
            default_name,
            "插件文件 (*.cnplugin);;ZIP文件 (*.zip)"
        )
        
        if not file_path:
            return ""
        
        try:
            with zipfile.ZipFile(file_path, "w", zipfile.ZIP_DEFLATED) as zf:
                for src_file in source_dir.rglob("*"):
                    if src_file.is_file():
                        arcname = src_file.relative_to(source_dir)
                        zf.write(src_file, arcname)
            
            logger.info(f"Exported plugin {plugin_id} to {file_path}")
            self.pluginExportSucceeded.emit(file_path)
            return file_path
        except Exception as e:
            logger.error(f"Failed to export plugin: {e}")
            return ""

    @pyqtSlot(result=str)
    def getAPIVersion(self) -> str:
        """获取当前插件 API 版本"""
        return __API_VERSION__

    @pyqtSlot(int, result=bool)
    def isPluginCompatible(self, plugin_id: int) -> bool:
        """检查指定插件是否与当前 API 版本兼容"""
        meta = self._plugin_meta_cache.get(plugin_id)
        if not meta:
            return True  # 没有 meta 信息，默认兼容
        return check_api_version(meta.get("api_version", ""))

    # ── 内部查询 ────────────────────────────────────────────────────────────

    def get_plugin(self, plugin_id: int) -> Optional[INewsSource]:
        return self._plugins.get(plugin_id)

    def get_all_plugins(self, enabled_only: bool = True) -> List[INewsSource]:
        print(f"[DEBUG] get_all_plugins: _plugins 数量={len(self._plugins)}, enabled_only={enabled_only}")
        if enabled_only:
            enabled_plugins = [p for p in self._plugins.values() if p.info.enabled]
            print(f"[DEBUG] 启用的插件数量={len(enabled_plugins)}")
            for p in self._plugins.values():
                print(f"[DEBUG] 插件: {p.name} (ID:{p.id}), enabled={p.info.enabled}")
            return enabled_plugins
        return list(self._plugins.values())

    def get_plugin_type(self, plugin_id: int) -> Optional[PluginType]:
        record = self._plugin_records.get(plugin_id)
        return record.plugin_type if record else None

    def is_builtin_plugin(self, plugin_id: int) -> bool:
        record = self._plugin_records.get(plugin_id)
        return record.plugin_type == PluginType.BUILTIN if record else False

    def get_user_plugins_dir(self) -> str:
        return str(self._user_dir)

    def get_builtin_plugins_dir(self) -> str:
        return str(self._builtin_dir)

    @pyqtSlot(int, result=bool)
    def reloadPlugin(self, plugin_id: int) -> bool:
        """
        重载用户插件（先卸载再重新加载，用于热更新）
        注意：内置插件不支持重载
        """
        record = self._plugin_records.get(plugin_id)
        if not record or record.plugin_type == PluginType.BUILTIN:
            self.pluginReloadFailed.emit(plugin_id, "内置插件不支持重载")
            return False
        try:
            plugin_dir = Path(record.directory)
            if not plugin_dir.exists():
                self.pluginReloadFailed.emit(plugin_id, "插件目录不存在")
                return False
            
            # 调用旧的 on_unload
            if plugin_id in self._plugins:
                try:
                    self._plugins[plugin_id].on_unload()
                except Exception as e:
                    logger.warning(f"on_unload error during reload: {e}")
                del self._plugins[plugin_id]
            
            if plugin_id in self._plugin_records:
                del self._plugin_records[plugin_id]
            
            # 重新加载
            success = self._load_single_plugin(plugin_dir, PluginType.USER)
            self.pluginListChanged.emit()
            
            if success:
                self.pluginReloadSucceeded.emit(plugin_id)
            else:
                self.pluginReloadFailed.emit(plugin_id, "插件加载失败")
            return success
        except Exception as e:
            logger.error(f"Failed to reload plugin {plugin_id}: {e}")
            self.pluginReloadFailed.emit(plugin_id, str(e))
            return False

    # ── 插件功能代理 ────────────────────────────────────────────────────────

    async def fetch_news(
        self,
        plugin_id: int,
        category: Optional[NewsCategory] = None,
        count: int = 20,
        cursor: Optional[str] = None,
    ) -> Optional[FetchResult]:
        plugin = self._plugins.get(plugin_id)
        if plugin is None or not plugin.info.enabled:
            return None
        try:
            return await plugin.fetch_news(category, count, cursor)
        except Exception as e:
            logger.error(f"Error fetching news from plugin {plugin_id}: {e}")
            return None

    async def get_news_detail(self, plugin_id: int, news_id: str) -> Optional[NewsItem]:
        plugin = self._plugins.get(plugin_id)
        if plugin is None or not plugin.info.enabled:
            return None
        try:
            return await plugin.get_news_detail(news_id)
        except Exception as e:
            logger.error(f"Error getting news detail: {e}")
            return None

    async def play_news(self, plugin_id: int, news_id: str) -> bool:
        plugin = self._plugins.get(plugin_id)
        if plugin is None or not plugin.info.enabled:
            return False
        try:
            return await plugin.play_news(news_id)
        except Exception as e:
            logger.error(f"Error playing news: {e}")
            return False

    async def search_news(
        self, plugin_id: int, keyword: str, count: int = 20
    ) -> List[NewsItem]:
        plugin = self._plugins.get(plugin_id)
        if plugin is None or not plugin.info.enabled:
            return []
        try:
            return await plugin.search_news(keyword, count)
        except Exception as e:
            logger.error(f"Error searching news: {e}")
            return []

    # 同步包装（Flask / 兼容）
    def fetch_news_sync(
        self,
        plugin_id: int,
        category: Optional[NewsCategory] = None,
        count: int = 20,
        cursor: Optional[str] = None,
    ) -> Optional[FetchResult]:
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                return loop.run_until_complete(
                    self.fetch_news(plugin_id, category, count, cursor)
                )
            finally:
                loop.close()
        except Exception as e:
            logger.error(f"Sync fetch error: {e}")
            return None

    def get_news_detail_sync(self, plugin_id: int, news_id: str) -> Optional[NewsItem]:
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                return loop.run_until_complete(self.get_news_detail(plugin_id, news_id))
            finally:
                loop.close()
        except Exception as e:
            logger.error(f"Sync detail error: {e}")
            return None

    def play_news_sync(self, plugin_id: int, news_id: str) -> bool:
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                return loop.run_until_complete(self.play_news(plugin_id, news_id))
            finally:
                loop.close()
        except Exception as e:
            logger.error(f"Sync play error: {e}")
            return False

    def search_news_sync(
        self, plugin_id: int, keyword: str, count: int = 20
    ) -> List[NewsItem]:
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                return loop.run_until_complete(self.search_news(plugin_id, keyword, count))
            finally:
                loop.close()
        except Exception as e:
            logger.error(f"Sync search error: {e}")
            return []
