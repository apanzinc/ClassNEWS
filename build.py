#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ClassNEWS 自动编译脚本
自动获取 Git 信息、系统信息，并更新 build_info.json
"""

import json
import subprocess
import platform
import os
from pathlib import Path
from datetime import datetime

def get_git_info():
    """获取 Git 信息"""
    git_info = {
        "commit": "unknown",
        "branch": "unknown"
    }
    
    # 检查是否在 Git 仓库中
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode != 0:
            print("⚠️  警告：当前目录不是 Git 仓库，将使用 'unknown' 作为 Git 信息")
            print("   请在 Git 仓库中运行此脚本，或者手动编辑 build_info.json 设置 Git 信息")
            return git_info
    except FileNotFoundError:
        print("⚠️  警告：未找到 Git 命令，请确保已安装 Git")
        print("   下载地址：https://git-scm.com/downloads")
        return git_info
    except Exception as e:
        print(f"⚠️  警告：检查 Git 环境失败：{e}")
        return git_info
    
    try:
        # 获取 Git commit hash（短版本）
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            git_info["commit"] = result.stdout.strip()
        
        # 获取 Git 分支名称
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            git_info["branch"] = result.stdout.strip()
    except Exception as e:
        print(f"⚠️  警告：获取 Git 详细信息失败：{e}")
    
    return git_info

def update_build_info():
    """更新 build_info.json 文件"""
    # 获取项目根目录
    script_dir = Path(__file__).parent.resolve()
    build_info_path = script_dir / "build_info.json"
    
    # 读取现有的 build_info.json
    if build_info_path.exists():
        with open(build_info_path, "r", encoding="utf-8") as f:
            build_info = json.load(f)
    else:
        build_info = {}
    
    # 获取 Git 信息
    git_info = get_git_info()
    
    # 获取当前日期和时间
    now = datetime.now()
    build_date = now.strftime("%Y-%m-%d")
    build_time = now.strftime("%H:%M:%S")
    
    # 获取系统信息
    system = platform.system()
    machine = platform.machine()
    python_version = platform.python_version()
    
    # 更新构建信息
    build_info["buildDate"] = build_date
    build_info["buildTime"] = build_time
    build_info["gitCommit"] = git_info["commit"]
    build_info["gitBranch"] = git_info["branch"]
    build_info["platform"] = system
    build_info["architecture"] = machine
    build_info["compiler"] = f"Python {python_version}"
    
    # 自动递增构建号
    if "buildNumber" in build_info:
        try:
            build_info["buildNumber"] = str(int(build_info["buildNumber"]) + 1)
        except ValueError:
            build_info["buildNumber"] = "1"
    else:
        build_info["buildNumber"] = "1"
    
    # 写回文件
    with open(build_info_path, "w", encoding="utf-8") as f:
        json.dump(build_info, f, indent=4, ensure_ascii=False)
    
    print("=" * 60)
    print("✨ 编译信息已更新")
    print("=" * 60)
    print(f"📅 编译日期：{build_date} {build_time}")
    print(f"🔖 Git 提交：{git_info['commit']}")
    print(f"🌿 Git 分支：{git_info['branch']}")
    print(f"💻 平台：{system} ({machine})")
    print(f"🐍 Python 版本：{python_version}")
    print(f"🔢 构建号：{build_info['buildNumber']}")
    print("=" * 60)
    print(f"文件已更新：{build_info_path}")
    print("=" * 60)
    
    # 如果 Git 信息是 unknown，提供手动设置提示
    if git_info["commit"] == "unknown" or git_info["branch"] == "unknown":
        print("\n💡 提示：Git 信息未自动获取到，可以手动编辑 build_info.json")
        print("   示例：")
        print('   "gitCommit": "3f230e3",')
        print('   "gitBranch": "main"')
        print("\n   或者在 Git 仓库中运行此脚本以自动获取\n")
    else:
        print()

if __name__ == "__main__":
    update_build_info()
