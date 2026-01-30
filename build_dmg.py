import os
import subprocess
import shutil
import sys

# 配置路径
BASE_DIR = "/Users/mac/ai-house"
PROJECT_DIR = os.path.join(BASE_DIR, "ImessageBot")
PACK_DIR = os.path.join(BASE_DIR, "ImessageBot_Pack")
BUILD_DIR = os.path.join(PROJECT_DIR, "build")
APP_PATH = os.path.join(BUILD_DIR, "Build/Products/Debug/ImessageBot.app")
README_PATH = os.path.join(PROJECT_DIR, "README_安装必读.txt")
DMG_PATH = os.path.join(PROJECT_DIR, "ImessageBot.dmg")

def run_command(command, cwd=None):
    """运行终端命令并打印输出"""
    print(f"正在执行: {command}")
    try:
        process = subprocess.Popen(
            command,
            shell=True,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        for line in process.stdout:
            print(line, end="")
        process.wait()
        if process.returncode != 0:
            print(f"命令执行失败，退出码: {process.returncode}")
            sys.exit(1)
    except Exception as e:
        print(f"执行出错: {str(e)}")
        sys.exit(1)

def main():
    # 1. 清理旧的打包目录和旧的 DMG
    print("=== 步骤 1: 清理旧文件 ===")
    if os.path.exists(PACK_DIR):
        shutil.rmtree(PACK_DIR)
    if os.path.exists(DMG_PATH):
        os.remove(DMG_PATH)
    
    # 2. 使用 xcodebuild 构建项目 (确保 App 是最新的)
    print("\n=== 步骤 2: 构建 Xcode 项目 ===")
    build_cmd = (
        f"xcodebuild -project {PROJECT_DIR}/ImessageBot.xcodeproj "
        f"-scheme ImessageBot -configuration Debug "
        f"-derivedDataPath {BUILD_DIR} build"
    )
    run_command(build_cmd)

    # 3. 准备打包目录
    print("\n=== 步骤 3: 准备打包资源 ===")
    os.makedirs(PACK_DIR, exist_ok=True)
    
    # 检查构建出的 App 是否存在
    if not os.path.exists(APP_PATH):
        print(f"错误: 找不到构建成功的 App 文件: {APP_PATH}")
        sys.exit(1)
        
    # 复制 App 和 README
    run_command(f"cp -R '{APP_PATH}' '{PACK_DIR}/'")
    run_command(f"cp '{README_PATH}' '{PACK_DIR}/'")

    # 4. 使用 create-dmg 生成 DMG
    print("\n=== 步骤 4: 生成 DMG 安装包 ===")
    dmg_cmd = (
        f"create-dmg "
        f"--volname \"ImessageBot 安装包\" "
        f"--window-pos 200 120 "
        f"--window-size 600 400 "
        f"--icon-size 100 "
        f"--icon \"ImessageBot.app\" 150 150 "
        f"--hide-extension \"ImessageBot.app\" "
        f"--app-drop-link 450 150 "
        f"--icon \"README_安装必读.txt\" 300 280 "
        f"\"{DMG_PATH}\" "
        f"\"{PACK_DIR}/\""
    )
    run_command(dmg_cmd)

    # 5. 最后清理
    print("\n=== 步骤 5: 最终清理 ===")
    if os.path.exists(PACK_DIR):
        shutil.rmtree(PACK_DIR)
    
    # 清理构建目录
    if os.path.exists(BUILD_DIR):
        print(f"正在清理构建目录: {BUILD_DIR}")
        shutil.rmtree(BUILD_DIR)

    print(f"\n✅ 打包完成！DMG 文件位于: {DMG_PATH}")

if __name__ == "__main__":
    main()
