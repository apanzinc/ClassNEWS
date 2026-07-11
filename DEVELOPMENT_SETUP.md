# ClassNEWS 跨平台开发环境搭建指南

## 项目概述

ClassNEWS 现已支持 **Windows**、**macOS** 和 **Linux** 三大平台！

## 环境要求

- **Python**: 3.10 或更高版本
- **操作系统**: Windows 10/11、macOS 10.15+、Ubuntu 20.04+

---

## 启动方式（统一入口）

所有平台都使用 **main.py** 作为唯一入口：

```bash
python main.py
```

---

## 各平台环境搭建

### Windows

#### 1. 安装 Python
1. 访问 https://www.python.org/downloads/
2. 下载 Python 3.10+ 版本
3. 安装时勾选 **"Add Python to PATH"**

#### 2. 安装依赖
```bash
pip install -r requirements.txt
```

#### 3. 启动项目
```bash
python main.py
```

---

### macOS

#### 1. 安装 Homebrew (如果未安装)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. 安装 Python
```bash
brew install python@3.12
```

#### 3. 安装依赖
```bash
pip3 install -r requirements.txt
```

#### 4. 启动项目
```bash
python3 main.py
```

---

### Linux (Ubuntu/Debian)

#### 1. 安装系统依赖
```bash
sudo apt-get update
sudo apt-get install -y \
    python3 python3-pip \
    libegl1 libgl1-mesa-glx \
    libglib2.0-0 libfontconfig1 \
    libx11-6 libxcb1 libxkbcommon-x11-0 \
    libdbus-1-3 libxcb-xinerama0 \
    libxcb-xkb1 libxkbcommon0 \
    libxcb-icccm4 libxcb-image0 \
    libxcb-keysyms1 libxcb-randr0 \
    libxcb-render-util0 libxcb-shape0 \
    libxcb-xfixes0 libxcb-util1
```

#### 2. 安装 Python 依赖
```bash
pip3 install -r requirements.txt
```

#### 3. 启动项目
```bash
python3 main.py
```

---

## 项目结构

```
ClassNEWS/
├── main.py                 # 主程序入口
├── start.py               # 跨平台启动器
├── start_windows.bat      # Windows 启动脚本
├── requirements.txt       # Python 依赖
├── main.qml              # QML 主界面
├── pages/                # QML 页面
├── components/           # QML 组件
├── plugins/              # 新闻插件
├── assets/               # 资源文件
└── docs/                 # 文档
```

---

## 双端适配修改说明

### 已完成的适配工作

1. **平台检测**
   - 添加了 `IS_WINDOWS`、`IS_MACOS`、`IS_LINUX` 常量
   - 条件导入 Windows 特定的 `ctypes` 模块

2. **Windows 特定功能**
   - 开机启动 (仅 Windows 支持)
   - 协议注册 (仅 Windows 支持)
   - 任务栏图标设置 (仅 Windows 支持)
   - 窗口圆角 (仅 Windows 11 支持)
   - 窗口事件过滤器 (仅 Windows 支持)

3. **视频播放**
   - Windows: 使用 ShellExecute 和系统播放器
   - macOS: 使用 `open` 命令
   - Linux: 使用 `xdg-open` 命令

4. **编码处理**
   - Windows: 设置控制台 UTF-8 编码
   - macOS/Linux: 使用默认 UTF-8 编码

---

## 常见问题

### Q: 提示缺少 Qt 平台插件
**A**: 安装 Qt 平台插件
```bash
# Ubuntu/Debian
sudo apt-get install qtbase5-dev

# macOS
brew install qt@6
```

### Q: 提示缺少 libEGL.so.1
**A**: 安装 EGL 库
```bash
# Ubuntu/Debian
sudo apt-get install libegl1

# CentOS/RHEL
sudo yum install mesa-libEGL
```

### Q: macOS 上界面显示异常
**A**: 设置环境变量
```bash
export QT_MAC_WANTS_LAYER=1
python3 start.py
```

---

## 开发建议

1. **代码提交**: 提交信息请使用中英文双语
2. **测试**: 在修改后请在目标平台测试
3. **兼容性**: 避免使用平台特定 API，如需使用请添加平台判断

---

## 技术支持

如有问题，请提交 Issue 到项目仓库。
