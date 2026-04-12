# ClassNEWS 编译脚本使用说明

## 📋 概述

`build.py` 是一个自动化的编译信息更新脚本，用于：
- 自动获取当前 Git 提交信息
- 自动获取当前 Git 分支
- 自动设置编译日期和时间
- 自动递增构建号
- 更新 `build_info.json` 文件

## 🚀 使用方法

### 方式一：直接运行脚本

在命令行中执行：

```bash
python build.py
```

### 方式二：在编译前运行

每次编译或打包项目之前，先运行此脚本：

```bash
# Windows PowerShell / CMD
python build.py
python main.py

# 或者打包时
python build.py
pyinstaller your_spec_file.spec
```

## 📊 自动更新的信息

脚本会自动更新以下信息：

| 字段 | 说明 | 来源 |
|------|------|------|
| `buildDate` | 编译日期 | 当前系统日期（YYYY-MM-DD） |
| `buildTime` | 编译时间 | 当前系统时间（HH:MM:SS） |
| `gitCommit` | Git 提交 hash | `git rev-parse --short HEAD` |
| `gitBranch` | Git 分支名称 | `git rev-parse --abbrev-ref HEAD` |
| `buildNumber` | 构建号 | 自动递增（每次运行 +1） |
| `platform` | 操作系统平台 | `platform.system()` |
| `architecture` | 系统架构 | `platform.machine()` |
| `compiler` | Python 版本 | `platform.python_version()` |

## 📝 输出示例

运行脚本后，会看到类似以下的输出：

```
============================================================
✨ 编译信息已更新
============================================================
📅 编译日期：2026-04-12 16:35:39
🔖 Git 提交：3f230e3
🌿 Git 分支：main
💻 平台：Windows (AMD64)
🐍 Python 版本：3.12.9
🔢 构建号：2
============================================================
文件已更新：C:\Users\apanz\Desktop\ClassNEWS\build_info.json
============================================================
```

## ⚠️ 注意事项

1. **Git 环境**：
   - 脚本需要在 Git 仓库中运行才能获取 Git 信息
   - 如果不在 Git 仓库中，`gitCommit` 和 `gitBranch` 会显示为 "unknown"

2. **构建号递增**：
   - 每次运行脚本，`buildNumber` 会自动 +1
   - 如果需要重置构建号，可以手动编辑 `build_info.json`

3. **手动修改**：
   - 编译日期、Git 信息等会在每次运行时自动更新
   - 版本号、编译者信息等需要手动在 `build_info.json` 中修改

## 🔧 高级用法

### 在 CI/CD 中使用

在 GitHub Actions 或其他 CI/CD 流程中：

```yaml
- name: Update build info
  run: python build.py

- name: Build application
  run: pyinstaller ClassNEWS.spec
```

### 自定义编译者信息

编辑 `build_info.json` 中的 `builder` 字段：

```json
{
    "builder": {
        "name": "你的名字",
        "email": "your.email@example.com"
    }
}
```

## 📁 相关文件

- `build.py` - 编译信息更新脚本
- `build_info.json` - 编译信息配置文件
- `main.py` - 主程序（会读取 build_info.json）

## 💡 提示

在软件的"关于"页面中，会显示以下编译信息：
- 编译人（可点击发送邮件）
- 编译日期
- Git 提交
- Git 分支

所有信息都来自 `build_info.json` 文件。
