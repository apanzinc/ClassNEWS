#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ClassNEWS PyInstaller 打包脚本
生成可执行的 .exe 文件
"""

import subprocess
import sys
import shutil
import os
from pathlib import Path

# 设置控制台编码为 UTF-8
if sys.platform == "win32":
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except:
        pass

def create_spec_file():
    """创建 PyInstaller spec 文件"""
    spec_content = """# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[
        # 添加 QtMultimedia 的二进制文件
    ],
    datas=[
        ('main.qml', '.'),
        ('build_info.json', '.'),
        ('api_config.json', '.'),
        ('CtrlBtn.qml', '.'),
        ('FluentWindowBase.qml', '.'),
        ('TitleBar.qml', '.'),
        ('components', 'components'),
        ('pages', 'pages'),
        ('assets', 'assets'),
        ('RinUI', 'RinUI'),
        ('plugins', 'plugins'),  # 内置插件目录
    ],
    hiddenimports=[
        'PySide6',
        'PySide6.QtCore',
        'PySide6.QtGui',
        'PySide6.QtQuick',
        'PySide6.QtQml',
        'PySide6.QtWidgets',
        'PySide6.QtMultimedia',
        'PySide6.QtMultimedia.QMediaPlayer',
        'PySide6.QtMultimedia.QAudioOutput',
        'RinUI',
        'RinUI.core',
        'RinUI.components',
        'requests',
        'plyer',
        'plyer.platforms.win.notification',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# 正式版本配置
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='ClassNEWS',
    debug=False,  # 关闭调试模式
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,  # 启用 UPX 压缩，减小体积
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # 不显示控制台窗口
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='assets/logo.ico',
)
"""
    return spec_content

def build():
    """执行打包"""
    print("=" * 60)
    print("🔨 ClassNEWS 打包工具")
    print("=" * 60)
    
    # 检查依赖
    print("\n📦 检查依赖...")
    try:
        import PyInstaller
        print(f"   ✓ PyInstaller {PyInstaller.__version__}")
    except ImportError:
        print("   ❌ PyInstaller 未安装")
        print("\n💡 正在安装 PyInstaller...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
        print("   ✓ PyInstaller 安装完成")
    
    # 更新 build_info.json
    print("\n📝 更新编译信息...")
    try:
        subprocess.run([sys.executable, "build.py"], check=True)
    except Exception as e:
        print(f"   ⚠️  更新 build_info.json 失败：{e}")
        print("   继续打包...")
    
    # 创建 spec 文件
    spec_path = Path("ClassNEWS.spec")
    print(f"\n📄 创建打包配置文件...")
    spec_path.write_text(create_spec_file(), encoding="utf-8")
    print(f"   ✓ {spec_path}")
    
    # 清理旧的构建文件
    print("\n🧹 清理旧的构建文件...")
    build_dir = Path("build")
    dist_dir = Path("dist")
    
    if build_dir.exists():
        try:
            shutil.rmtree(build_dir)
            print("   ✓ 删除 build 目录")
        except Exception as e:
            print(f"   ⚠️  删除 build 目录失败：{e}")
    
    if dist_dir.exists():
        try:
            # 尝试多次删除，避免文件被占用
            import time
            for i in range(3):
                try:
                    shutil.rmtree(dist_dir)
                    print("   ✓ 删除 dist 目录")
                    break
                except PermissionError:
                    time.sleep(1)
            else:
                print(f"   ⚠️  删除 dist 目录失败，请手动删除后重试")
        except Exception as e:
            print(f"   ⚠️  删除 dist 目录失败：{e}")
    
    # 执行打包
    print("\n🚀 开始打包...")
    print("   这可能需要几分钟时间，请耐心等待...\n")
    
    try:
        subprocess.check_call([
            sys.executable,
            "-m",
            "PyInstaller",
            "ClassNEWS.spec",
            "--clean"
        ])
        
        print("\n" + "=" * 60)
        print("✨ 打包完成！")
        print("=" * 60)
        
        # 检查输出文件
        exe_path = dist_dir / "ClassNEWS_Debug.exe"
        if exe_path.exists():
            file_size = exe_path.stat().st_size
            print(f"\n📦 输出文件：{exe_path}")
            print(f"📊 文件大小：{file_size / 1024 / 1024:.2f} MB")
            print("\n💡 提示：")
            print("   - 可执行文件位于 dist/ClassNEWS_Debug.exe")
            print("   - 这是多文件版本（onedir），所有依赖都在 exe 中")
            print("   - 运行时不需要 Python 环境")
        else:
            print("\n❌ 打包失败：未找到输出文件")
            
    except subprocess.CalledProcessError as e:
        print(f"\n❌ 打包失败：{e}")
        print("\n💡 可能的解决方案：")
        print("   1. 确保所有依赖已安装：pip install -r requirements.txt")
        print("   2. 检查是否有语法错误：python main.py")
        print("   3. 查看详细日志：build/ClassNEWS/warn-*.txt")
        sys.exit(1)

if __name__ == "__main__":
    build()
