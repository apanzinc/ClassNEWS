# ClassNEWS Git 信息设置快速指南

## 问题说明

如果您看到 Git 提交和 Git 分支显示为 `unknown`，说明脚本无法自动获取 Git 信息。

## 原因分析

有以下几种可能：

1. **当前目录不是 Git 仓库**
   - 项目没有初始化 Git
   - 或者在不包含 `.git` 文件夹的目录中运行

2. **未安装 Git**
   - 系统没有安装 Git 命令
   - Git 没有添加到系统 PATH

3. **在沙盒/受限环境中运行**
   - 某些 IDE 或容器环境可能限制了 Git 访问

## 解决方案

### 方案一：在 Git 仓库中运行（推荐）

确保您在 ClassNEWS 项目根目录（包含 `.git` 文件夹）中运行脚本：

```bash
# 确认在 Git 仓库中
git status

# 如果在 Git 仓库中，会显示当前分支和文件状态
# 然后运行编译脚本
python build.py
```

### 方案二：手动设置 Git 信息

编辑 `build_info.json` 文件，手动设置 Git 信息：

```json
{
    "version": "v2.0.0",
    "buildNumber": "3",
    "gitCommit": "3f230e3",
    "gitBranch": "main",
    "releaseType": "Beta",
    "buildDate": "2026-04-12",
    "buildTime": "16:41:41",
    ...
}
```

**如何获取 Git 信息：**

```bash
# 获取当前 Git 提交 hash（短版本）
git rev-parse --short HEAD

# 获取当前 Git 分支名称
git rev-parse --abbrev-ref HEAD
```

将输出结果复制到 `build_info.json` 中即可。

### 方案三：安装 Git

如果系统没有 Git，请下载安装：

- **Windows**: https://git-scm.com/download/win
- **macOS**: https://git-scm.com/download/mac
- **Linux**: 使用包管理器安装（如 `sudo apt install git`）

安装完成后，重启终端并运行：

```bash
git --version  # 确认安装成功
python build.py
```

## 验证结果

运行脚本后，检查输出：

✅ **成功**：
```
🔖 Git 提交：3f230e3
🌿 Git 分支：main
```

❌ **失败**：
```
⚠️  警告：当前目录不是 Git 仓库，将使用 'unknown' 作为 Git 信息
   请在 Git 仓库中运行此脚本，或者手动编辑 build_info.json 设置 Git 信息
```

## 编译信息在软件中的显示

设置完成后，打开 ClassNEWS 软件，在 **关于 → 编译信息** 中可以看到：

- 编译人：apanzinc（可点击发送邮件）
- 编译日期：2026-04-12
- Git 提交：3f230e3
- Git 分支：main

## 常见问题

**Q: 为什么每次运行构建号都会增加？**
A: 这是正常行为，每次编译都会自动递增构建号，方便追踪版本。

**Q: 可以固定构建号吗？**
A: 可以手动编辑 `build_info.json`，修改 `buildNumber` 字段。

**Q: Git 信息对软件运行有影响吗？**
A: 没有影响，Git 信息仅用于显示和追踪，不影响软件功能。

## 自动化建议

如果您使用 CI/CD（如 GitHub Actions），可以在工作流中自动运行：

```yaml
- name: Update build info
  run: python build.py
  
- name: Build application
  run: pyinstaller ClassNEWS.spec
```

CI/CD 环境通常会自动提供 Git 信息。
