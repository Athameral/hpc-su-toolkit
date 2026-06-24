#!/usr/bin/env bash
# ============================================================
# bootstrap.sh — HPC SU Toolkit 一键初始化
# ============================================================
# 用法:
#   # 推荐：clone 到 $HOME/<你的缩写>/ 下（如 ~/alice/），然后：
#   bash bootstrap.sh
#
#   # 指定本地静态工具 zip：
#   bash bootstrap.sh -f ./static_tools.zip
#
#   # 指定远程 URL：
#   bash bootstrap.sh -u https://example.com/static_tools.zip
#
#   # 自定义路径：
#   export HPC_SU_HOME=/custom/path
#   bash /custom/path/bootstrap.sh

set -euo pipefail

# --- 静态工具 zip 默认下载地址 ---
# 可在此处修改，或通过 -u 参数 / HPC_SU_TOOLS_URL 环境变量覆盖
DEFAULT_TOOLS_URL="${HPC_SU_TOOLS_URL:-}"

# --- 自动推断 HPC_SU_HOME ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${HPC_SU_HOME:-}" ]; then
    export HPC_SU_HOME="$SCRIPT_DIR"
fi

# --- 参数解析 ---
TOOLS_ZIP=""
TOOLS_URL="$DEFAULT_TOOLS_URL"

print_usage() {
    echo "用法: $0 [-f tools.zip] [-u url] [-h]"
    echo ""
    echo "选项:"
    echo "  -f PATH    从本地 zip 文件解压静态工具到 00_static_tools/"
    echo "  -u URL     从指定 URL 下载静态工具 zip 并解压"
    echo "  -h         显示此帮助"
    echo ""
    echo "环境变量:"
    echo "  HPC_SU_HOME         工具包根目录 (默认: 脚本所在目录)"
    echo "  HPC_SU_TOOLS_URL     静态工具 zip 的默认下载地址"
    exit 0
}

while getopts "f:u:h" opt; do
    case ${opt} in
        f) TOOLS_ZIP="${OPTARG}" ;;
        u) TOOLS_URL="${OPTARG}" ;;
        h) print_usage ;;
        \?) echo "无效选项: -${OPTARG}" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

echo "============================================"
echo " HPC SU Toolkit — 初始化"
echo "============================================"
echo ""
echo "HPC_SU_HOME = $HPC_SU_HOME"
echo ""

# === 1. 设置脚本可执行权限 ===
echo "[1/4] 设置脚本可执行权限..."
chmod +x "$HPC_SU_HOME/01_scripts/"*.sh 2>/dev/null || true
chmod +x "$HPC_SU_HOME/scripts/"*.sh 2>/dev/null || true
echo "  完成。"

# === 2. 解压 / 下载静态工具 ===
echo "[2/4] 安装静态工具..."

TOOLS_DIR="$HPC_SU_HOME/00_static_tools"
mkdir -p "$TOOLS_DIR"

extract_zip() {
    local zip="$1"
    echo "  解压 $zip → $TOOLS_DIR ..."
    if command -v unzip &>/dev/null; then
        unzip -o "$zip" -d "$TOOLS_DIR"
    elif command -v python3 &>/dev/null; then
        python3 -c "
import zipfile, sys
with zipfile.ZipFile('$zip', 'r') as z:
    z.extractall('$TOOLS_DIR')
print('解压完成')
"
    elif command -v python &>/dev/null; then
        python -c "
import zipfile, sys
with zipfile.ZipFile('$zip', 'r') as z:
    z.extractall('$TOOLS_DIR')
print('解压完成')
"
    else
        echo "  错误: 未找到 unzip / python3 / python，无法解压 zip 文件。" >&2
        exit 1
    fi
    # 确保二进制可执行
    find "$TOOLS_DIR" -type f -exec chmod +x {} + 2>/dev/null || true
    echo "  解压完成。"
}

if [ -n "$TOOLS_ZIP" ]; then
    # 用户指定了本地 zip
    if [ ! -f "$TOOLS_ZIP" ]; then
        echo "  错误: 文件不存在: $TOOLS_ZIP" >&2
        exit 1
    fi
    extract_zip "$(realpath "$TOOLS_ZIP")"
elif [ -n "$TOOLS_URL" ]; then
    # 从 URL 下载
    echo "  从 $TOOLS_URL 下载静态工具..."
    TMP_ZIP="$(mktemp -t tools.XXXXXX.zip)"
    if command -v curl &>/dev/null; then
        curl -fSL --progress-bar -o "$TMP_ZIP" "$TOOLS_URL"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$TMP_ZIP" "$TOOLS_URL"
    else
        echo "  错误: 未找到 curl 或 wget，无法下载。" >&2
        rm -f "$TMP_ZIP"
        exit 1
    fi
    extract_zip "$TMP_ZIP"
    rm -f "$TMP_ZIP"
else
    # 无 zip 提供，检查是否已有工具
    echo "  未提供静态工具 zip（使用 -f 或 -u），检查已有工具..."
    if [ -f "$TOOLS_DIR/micromamba" ]; then
        echo "  检测到已有工具，跳过。"
    else
        echo "  ⚠ 未找到静态工具。请执行以下任一操作:"
        echo "    $0 -f /path/to/static_tools.zip"
        echo "    $0 -u https://your-server/static_tools.zip"
        echo "  或手动将二进制文件放入 $TOOLS_DIR/"
    fi
fi

# === 3. 创建 bashrc_local.sh ===
echo "[3/4] 设置本地配置..."
if [ ! -f "$HPC_SU_HOME/02_configs/bashrc_local.sh" ]; then
    cp "$HPC_SU_HOME/02_configs/bashrc_local.sh.example" "$HPC_SU_HOME/02_configs/bashrc_local.sh"
    echo "  已创建 02_configs/bashrc_local.sh（从 .example 复制）"
    echo "  请根据需要编辑此文件。"
else
    echo "  bashrc_local.sh 已存在，跳过。"
fi

# === 4. 添加到 ~/.bashrc ===
echo "[4/4] 配置 ~/.bashrc..."
BASHRC_LINE="source $HPC_SU_HOME/02_configs/bashrc_entry.sh  # HPC SU Toolkit"
if [ -f "$HOME/.bashrc" ]; then
    if grep -qF "HPC SU Toolkit" "$HOME/.bashrc" 2>/dev/null; then
        echo "  ~/.bashrc 已包含入口，跳过。"
    else
        echo "" >> "$HOME/.bashrc"
        echo "$BASHRC_LINE" >> "$HOME/.bashrc"
        echo "  已添加 source 命令到 ~/.bashrc。"
    fi
else
    echo "$BASHRC_LINE" > "$HOME/.bashrc"
    echo "  已创建 ~/.bashrc。"
fi

# === 创建运行时目录 ===
mkdir -p "$HPC_SU_HOME/sblogs"

echo ""
echo "============================================"
echo " 初始化完成！"
echo "============================================"
echo ""
echo "下一步:"
echo "  1. 重新登录或执行: source ~/.bashrc"
echo "  2. 编辑本地配置: $HPC_SU_HOME/02_configs/bashrc_local.sh"
echo ""
echo "快速测试:"
echo "  apply_gpu          # 申请交互式 GPU 节点"
echo "  apply_gpu -c ./envs/my.squashfs  # 带 SquashFS 环境"
