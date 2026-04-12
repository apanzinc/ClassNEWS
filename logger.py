"""
ClassNEWS Logging System
A professional logging module with categorized levels, bilingual support,
and console monitoring capabilities.
"""

import json
import socket
import platform
import sys
import traceback
from pathlib import Path
from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any, Callable
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer


class LogLevel(Enum):
    """Log severity levels"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARN"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"
    SUCCESS = "SUCCESS"  # For successful operations


class LogCategory(Enum):
    """Log categories for better organization"""
    SYSTEM = "SYSTEM"      # System-level events
    NETWORK = "NETWORK"    # Network/API operations
    UI = "UI"              # User interface events
    VIDEO = "VIDEO"        # Video playback
    CONFIG = "CONFIG"      # Configuration changes
    DATA = "DATA"          # Data operations
    SECURITY = "SECURITY"  # Security-related
    PERFORMANCE = "PERF"   # Performance metrics


class LogEntry:
    """A single log entry with rich information"""
    
    # Level icons for visual distinction
    LEVEL_ICONS = {
        LogLevel.DEBUG: "🔍",
        LogLevel.INFO: "ℹ️",
        LogLevel.WARNING: "⚠️",
        LogLevel.ERROR: "❌",
        LogLevel.CRITICAL: "🚨",
        LogLevel.SUCCESS: "✅"
    }
    
    def __init__(self, 
                 timestamp: datetime, 
                 level: LogLevel, 
                 category: LogCategory,
                 component: str, 
                 message: str, 
                 details: Optional[Dict] = None,
                 error_code: Optional[str] = None):
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.component = component
        self.message = message
        self.details = details or {}
        self.error_code = error_code
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            "timestamp": self.timestamp.isoformat(),
            "level": self.level.value,
            "category": self.category.value,
            "component": self.component,
            "message": self.message,
            "details": self.details,
            "error_code": self.error_code
        }
    
    def format_console(self) -> str:
        """Format for console output with icons and colors"""
        icon = self.LEVEL_ICONS.get(self.level, "•")
        time_str = self.timestamp.strftime("%H:%M:%S.%f")[:-3]
        
        # Format: [ICON] [TIME] [CATEGORY] [LEVEL] Component: Message
        parts = [
            f"{icon}",
            f"[{time_str}]",
            f"[{self.category.value}]",
            f"[{self.level.value:8}]",
            f"{self.component:15}",
            f"{self.message}"
        ]
        
        result = " ".join(parts)
        
        # Add error code if present
        if self.error_code:
            result += f" [ErrorCode: {self.error_code}]"
        
        return result
    
    def format_file(self) -> str:
        """Format for file output (clean, parseable)"""
        time_str = self.timestamp.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        
        parts = [
            time_str,
            self.level.value,
            self.category.value,
            self.component,
            self.message
        ]
        
        result = " | ".join(parts)
        
        if self.error_code:
            result += f" | ErrorCode:{self.error_code}"
        
        if self.details:
            result += f" | Details:{json.dumps(self.details, ensure_ascii=False)}"
        
        return result
    
    def format_text(self) -> str:
        """Legacy format for compatibility"""
        return self.format_console()


class ConsoleMonitor(QObject):
    """Monitor and capture console output"""
    consoleOutput = Signal(str)  # Emits captured console lines
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._original_stdout = None
        self._original_stderr = None
        self._capture_enabled = False
    
    def start_capture(self):
        """Start capturing console output"""
        if not self._capture_enabled:
            self._original_stdout = sys.stdout
            self._original_stderr = sys.stderr
            sys.stdout = self._StdoutCapture(self._on_output)
            sys.stderr = self._StderrCapture(self._on_output)
            self._capture_enabled = True
    
    def stop_capture(self):
        """Stop capturing and restore original streams"""
        if self._capture_enabled:
            sys.stdout = self._original_stdout
            sys.stderr = self._original_stderr
            self._capture_enabled = False
    
    def _on_output(self, text: str, is_error: bool = False):
        """Handle captured output"""
        prefix = "[STDERR] " if is_error else "[STDOUT] "
        self.consoleOutput.emit(prefix + text)
        # Also write to original streams
        if is_error and self._original_stderr:
            self._original_stderr.write(text)
        elif self._original_stdout:
            self._original_stdout.write(text)
    
    class _StdoutCapture:
        """Custom stdout capture"""
        def __init__(self, callback: Callable[[str, bool], None]):
            self.callback = callback
        
        def write(self, text: str):
            if text.strip():
                self.callback(text, False)
        
        def flush(self):
            pass
    
    class _StderrCapture:
        """Custom stderr capture"""
        def __init__(self, callback: Callable[[str, bool], None]):
            self.callback = callback
        
        def write(self, text: str):
            if text.strip():
                self.callback(text, True)
        
        def flush(self):
            pass


class Logger(QObject):
    """
    Professional Logger with categorized logging, bilingual support,
    and console monitoring.
    """
    
    # Signals
    logAdded = Signal(str)           # Formatted log text for UI
    logEntryAdded = Signal(object)   # LogEntry object for detailed handling
    logCleared = Signal()
    errorOccurred = Signal(str, str) # (error_message, error_code)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Log storage
        self._logs: List[LogEntry] = []
        self._max_logs = 10000
        
        # Settings
        self._debug_mode = False
        self._show_details = False
        self._monitor_console = False
        
        # Paths
        self._log_dir = Path(__file__).parent / "logs"
        self._log_dir.mkdir(exist_ok=True)
        self._log_file = self._log_dir / f"app_{datetime.now().strftime('%Y%m%d')}.log"
        
        # Console monitor
        self._console_monitor = ConsoleMonitor(self)
        self._console_monitor.consoleOutput.connect(self._on_console_output)
        
        # Component filters (for reducing noise)
        self._filtered_components = {
            "MouseArea", "ToolTip", "HoverHandler", "ScrollBar"
        }
        
        # Write header
        self._write_header()
        
        # Log initialization
        self.info(LogCategory.SYSTEM, "Logger", "Logging system initialized", {
            "log_file": str(self._log_file),
            "max_logs": self._max_logs
        })
    
    def _write_header(self):
        """Write application startup header"""
        lines = []
        lines.append("=" * 80)
        lines.append(" ClassNEWS Application Log")
        lines.append("=" * 80)
        lines.append(f" Session Start: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append(f" Log File: {self._log_file.name}")
        lines.append("-" * 80)
        
        # System Information
        lines.append("")
        lines.append("【System Information / 系统信息】")
        lines.append(f"  OS: {platform.system()} {platform.release()} ({platform.machine()})")
        lines.append(f"  Host: {socket.gethostname()}")
        lines.append(f"  Python: {platform.python_version()}")
        lines.append(f"  Executable: {sys.executable}")
        
        # Try to load build info
        try:
            build_info_path = Path(__file__).parent / "build_info.json"
            if build_info_path.exists():
                with open(build_info_path, 'r', encoding='utf-8') as f:
                    build_info = json.load(f)
                lines.append("")
                lines.append("【Build Information / 构建信息】")
                lines.append(f"  Version: {build_info.get('version', 'unknown')}")
                lines.append(f"  Build Date: {build_info.get('buildDate', 'unknown')}")
                lines.append(f"  Build Number: {build_info.get('buildNumber', 'unknown')}")
                lines.append(f"  Git Commit: {build_info.get('gitCommit', 'unknown')}")
        except Exception as e:
            pass
        
        lines.append("")
        lines.append("=" * 80)
        lines.append(" Log Format: [ICON] [TIME] [CATEGORY] [LEVEL] Component: Message")
        lines.append("=" * 80)
        lines.append("")
        
        header = "\n".join(lines)
        
        # Write to file
        with open(self._log_file, 'w', encoding='utf-8') as f:
            f.write(header + "\n")
        
        # Print to console
        print(header)
    
    def log(self, 
            level: LogLevel, 
            category: LogCategory,
            component: str, 
            message: str, 
            details: Optional[Dict] = None,
            error_code: Optional[str] = None):
        """
        Main logging method
        
        Args:
            level: Severity level
            category: Log category
            component: Source component/module
            message: Log message (supports bilingual)
            details: Additional structured data
            error_code: Unique error identifier for tracking
        """
        # Filter out noisy components in non-debug mode
        if not self._debug_mode:
            if component in self._filtered_components:
                return
            if any(x in message.lower() for x in ["mouse", "hover", "clicked"]):
                return
        
        # Create entry
        entry = LogEntry(
            timestamp=datetime.now(),
            level=level,
            category=category,
            component=component,
            message=message,
            details=details,
            error_code=error_code
        )
        
        # Store in memory
        self._logs.append(entry)
        if len(self._logs) > self._max_logs:
            self._logs = self._logs[-self._max_logs:]
        
        # Format outputs
        console_text = entry.format_console()
        file_text = entry.format_file()
        
        # Write to file
        with open(self._log_file, 'a', encoding='utf-8') as f:
            f.write(file_text + "\n")
        
        # Print to console (handle encoding issues for Windows)
        try:
            # 尝试直接输出 UTF-8
            print(console_text, flush=True)
        except UnicodeEncodeError:
            # 如果失败，尝试替换无法编码的字符
            safe_text = console_text.encode('gbk', errors='replace').decode('gbk', errors='replace')
            print(safe_text, flush=True)
        except Exception as e:
            # 最后的回退方案：输出 ASCII 版本
            ascii_text = console_text.encode('ascii', errors='replace').decode('ascii', errors='replace')
            print(f"[LOG] {ascii_text}", flush=True)
        
        # Emit signals
        self.logAdded.emit(console_text)
        self.logEntryAdded.emit(entry)
        
        # Emit error signal for errors
        if level in (LogLevel.ERROR, LogLevel.CRITICAL):
            self.errorOccurred.emit(message, error_code or "UNKNOWN")
    
    # Convenience methods by level
    def debug(self, category: LogCategory, component: str, message: str, details: Optional[Dict] = None):
        """Debug level log"""
        if self._debug_mode:
            self.log(LogLevel.DEBUG, category, component, message, details)
    
    def info(self, category: LogCategory, component: str, message: str, details: Optional[Dict] = None):
        """Info level log"""
        self.log(LogLevel.INFO, category, component, message, details)
    
    def warning(self, category: LogCategory, component: str, message: str, details: Optional[Dict] = None, error_code: Optional[str] = None):
        """Warning level log"""
        self.log(LogLevel.WARNING, category, component, message, details, error_code)
    
    def error(self, category: LogCategory, component: str, message: str, details: Optional[Dict] = None, error_code: Optional[str] = None):
        """Error level log"""
        self.log(LogLevel.ERROR, category, component, message, details, error_code)
    
    def critical(self, category: LogCategory, component: str, message: str, details: Optional[Dict] = None, error_code: Optional[str] = None):
        """Critical level log"""
        self.log(LogLevel.CRITICAL, category, component, message, details, error_code)
    
    def success(self, category: LogCategory, component: str, message: str, details: Optional[Dict] = None):
        """Success level log for completed operations"""
        self.log(LogLevel.SUCCESS, category, component, message, details)
    
    # Exception logging
    def exception(self, category: LogCategory, component: str, message: str, error_code: Optional[str] = None):
        """Log an exception with full traceback"""
        exc_info = traceback.format_exc()
        self.error(category, component, f"{message}\n{exc_info}", error_code=error_code)
    
    # Console monitoring
    def _on_console_output(self, text: str):
        """Handle captured console output"""
        if self._monitor_console and text.strip():
            self.log(LogLevel.INFO, LogCategory.SYSTEM, "Console", text.strip())
    
    # QML Slots
    @Slot(str, str)
    def logInfo(self, component: str, message: str):
        """QML: Log info message"""
        self.info(LogCategory.UI, component, message)
    
    @Slot(str, str)
    def logWarning(self, component: str, message: str):
        """QML: Log warning message"""
        self.warning(LogCategory.UI, component, message)
    
    @Slot(str, str)
    def logError(self, component: str, message: str):
        """QML: Log error message"""
        self.error(LogCategory.UI, component, message)
    
    @Slot(result=str)
    def getLogs(self) -> str:
        """Get all logs as formatted text"""
        return "\n".join([log.format_console() for log in self._logs])
    
    @Slot(str, result=str)
    def getLogsByLevel(self, level: str) -> str:
        """Get logs filtered by level"""
        filtered = [log for log in self._logs if log.level.value == level]
        return "\n".join([log.format_console() for log in filtered])
    
    @Slot(str, result=str)
    def getLogsByCategory(self, category: str) -> str:
        """Get logs filtered by category"""
        filtered = [log for log in self._logs if log.category.value == category]
        return "\n".join([log.format_console() for log in filtered])
    
    @Slot()
    def clearLogs(self):
        """Clear all logs"""
        self._logs.clear()
        self.logCleared.emit()
        self.success(LogCategory.DATA, "Logger", "All logs cleared / 日志已清空")
    
    @Slot(result=str)
    def getLogFilePath(self) -> str:
        """Get current log file path"""
        return str(self._log_file)
    
    @Slot(result=str)
    def getLogDirPath(self) -> str:
        """Get log directory path"""
        return str(self._log_dir)
    
    # Properties
    @Property(bool, notify=logAdded)
    def debugMode(self) -> bool:
        return self._debug_mode
    
    @debugMode.setter
    def debugMode(self, value: bool):
        if self._debug_mode != value:
            self._debug_mode = value
            self.info(LogCategory.CONFIG, "Logger", f"Debug mode {'enabled' if value else 'disabled'} / 调试模式{'开启' if value else '关闭'}")
    
    @Property(bool, notify=logAdded)
    def showDetails(self) -> bool:
        return self._show_details
    
    @showDetails.setter
    def showDetails(self, value: bool):
        if self._show_details != value:
            self._show_details = value
            self.info(LogCategory.CONFIG, "Logger", f"Details display {'enabled' if value else 'disabled'}")

    @Property(bool, notify=logAdded)
    def showDebugDetails(self) -> bool:
        """显示详细日志（用于记录点击事件等）"""
        return self._show_details
    
    @showDebugDetails.setter
    def showDebugDetails(self, value: bool):
        """设置显示详细日志"""
        if self._show_details != value:
            self._show_details = value
            self.info(LogCategory.CONFIG, "Logger", f"Debug details {'enabled' if value else 'disabled'} / 详细日志{'开启' if value else '关闭'}")
    
    @Property(bool, notify=logAdded)
    def monitorConsole(self) -> bool:
        return self._monitor_console
    
    @monitorConsole.setter
    def monitorConsole(self, value: bool):
        if self._monitor_console != value:
            self._monitor_console = value
            if value:
                self._console_monitor.start_capture()
                self.info(LogCategory.CONFIG, "Logger", "Console monitoring enabled / 控制台监控已开启")
            else:
                self._console_monitor.stop_capture()
                self.info(LogCategory.CONFIG, "Logger", "Console monitoring disabled / 控制台监控已关闭")


# Global instance
_logger_instance: Optional[Logger] = None


def init_logger() -> Logger:
    """Initialize and return the global logger instance"""
    global _logger_instance
    if _logger_instance is None:
        _logger_instance = Logger()
    return _logger_instance


def get_logger() -> Logger:
    """Get the global logger instance (must call init_logger first)"""
    global _logger_instance
    if _logger_instance is None:
        raise RuntimeError("Logger not initialized. Call init_logger() first.")
    return _logger_instance


def print_startup_banner():
    """
    打印启动横幅
    在导入 RinUI 之前调用，使用纯文本方式
    """
    RESET = "\033[0m"
    
    # ASCII 艺术字（原始版本）
    banner = r"""
 $$$$$$\  $$\                               $$\   $$\ $$$$$$$$\ $$\      $$\  $$$$$$\  
$$  __$$\ $$ |                              $$$\  $$ |$$  _____|$$ | $\  $$ |$$  __$$\ 
$$ /  \__|$$ | $$$$$$\   $$$$$$$\  $$$$$$$\ $$$$\ $$ |$$ |      $$ |$$$\ $$ |$$ /  \__| 
$$ |      $$ | \____$$\ $$  _____|$$  _____|$$ $$\$$ |$$$$$\    $$ $$ $$\$$ |\$$$$$$\  
$$ |      $$ | $$$$$$$ |\$$$$$$\  \$$$$$$\  $$ \$$$$ |$$  __|   $$$$  _$$$$ | \____$$\ 
$$ |  $$\ $$ |$$  __$$ | \____$$\  \____$$\ $$ |\$$$ |$$ |      $$$  / \$$$ |$$\   $$ | 
\$$$$$$  |$$ |\$$$$$$$ |$$$$$$$  |$$$$$$$  |$$ | \$$ |$$$$$$$$\ $$  /   \$$ |\$$$$$$  | 
 \______/ \__| \_______|\_______/ \_______/ \__|  \__|\________|\__/     \__| \______/ 
                                                                                        
"""
    
    # 获取软件信息
    try:
        from pathlib import Path
        import json
        
        # 读取版本信息
        build_info_path = Path(__file__).parent / "build_info.json"
        version = "v1.0.0"
        build_number = "1"
        
        if build_info_path.exists():
            with open(build_info_path, 'r', encoding='utf-8') as f:
                build_info = json.load(f)
                version = build_info.get("version", "v1.0.0")
                build_number = build_info.get("buildNumber", "1")  # 修复：使用驼峰命名
    except:
        version = "v1.0.0"
        build_number = "1"
    
    # 打印 ASCII 艺术字（使用亮红色 #F5525D 的近似 ANSI 颜色）
    try:
        print("\033[38;2;245;82;93m" + banner + RESET, flush=True)
    except:
        print(banner, flush=True)
    
    # 打印软件信息
    try:
        print("\033[38;2;245;82;93m" + "=" * 80 + RESET, flush=True)
        print(f"\033[38;2;245;82;93m软件名称：ClassNEWS\033[0m", flush=True)
        print(f"\033[38;2;245;82;93m开发者：apanzinc\033[0m", flush=True)
        print(f"\033[38;2;245;82;93m版本：{version} (Build {build_number})\033[0m", flush=True)
        print("\033[38;2;245;82;93m" + "=" * 80 + RESET, flush=True)
    except:
        print("=" * 80, flush=True)
        print(f"软件名称：ClassNEWS", flush=True)
        print(f"开发者：apanzinc", flush=True)
        print(f"版本：{version} (Build {build_number})", flush=True)
        print("=" * 80, flush=True)
    print()
