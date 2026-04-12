from PySide6.QtCore import QAbstractNativeEventFilter


class CustomWindowEventFilter(QAbstractNativeEventFilter):
    """自定义窗口事件过滤器 - 用于处理 Windows 窗口消息"""
    
    def __init__(self, windows=None, parent=None):
        super().__init__(parent)
        self.windows = windows or []
        self.hwnds = {}
    
    def _init_window_handle(self, window):
        """初始化窗口句柄"""
        try:
            hwnd = int(window.winId())
            self.hwnds[window] = hwnd
        except Exception as e:
            print(f"初始化窗口句柄失败: {e}")
    
    def nativeEventFilter(self, event_type, message):
        """处理原生事件"""
        return False, 0
