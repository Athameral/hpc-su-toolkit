#!/usr/bin/env bash
# ============================================================
# build_sqfs.sh — 从 micromamba 环境构建 SquashFS 镜像
# ============================================================
# 用法:
#   bash scripts/build_sqfs.sh my_env_name                    # 从 named env 构建
#   bash scripts/build_sqfs.sh /path/to/env                   # 从 prefix 构建
#   bash scripts/build_sqfs.sh my_env_name -o out.squashfs    # 指定输出路径
#
# 前提: micromamba 已在 PATH 中（source bashrc_entry.sh 后即可）

set -euo pipefail

HPC_SU_HOME="${HPC_SU_HOME:-$HOME/hpc-su-toolkit}"

print_usage() {
    echo "用法: $0 <env_name_or_prefix> [-o output.squashfs] [-c zstd|lz4|lzo|xz]"
    echo ""
    echo "示例:"
    echo "  $0 pytorch_env"
    echo "  $0 pytorch_env -o ./envs/pytorch.squashfs -c zstd"
    exit 1
}

if [ "$#" -lt 1 ]; then
    print_usage
fi

ENV_SPEC="$1"
shift

OUTPUT=""
COMPRESSION="zstd"

while getopts "o:c:h" opt; do
    case ${opt} in
        o) OUTPUT="${OPTARG}" ;;
        c) COMPRESSION="${OPTARG}" ;;
        h) print_usage ;;
        \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    esac
done

# 解析环境路径
if [ -d "$ENV_SPEC" ]; then
    ENV_DIR="$ENV_SPEC"
else
    # 尝试用 micromamba 查找
    ENV_DIR=$(micromamba env list 2>/dev/null | grep "^[[:space:]]*${ENV_SPEC}[[:space:]]" | awk '{print $NF}' || true)
    if [ -z "$ENV_DIR" ]; then
        echo "错误: 找不到环境 '$ENV_SPEC'" >&2
        echo "请确保 micromamba 已初始化（source bashrc_entry.sh）。" >&2
        exit 1
    fi
fi

if [ ! -d "$ENV_DIR" ]; then
    echo "错误: 目录不存在: $ENV_DIR" >&2
    exit 1
fi

# 默认输出路径
if [ -z "$OUTPUT" ]; then
    ENV_BASENAME="$(basename "$ENV_DIR")"
    OUTPUT="./${ENV_BASENAME}.squashfs"
fi

echo "=== 构建 SquashFS 镜像 ==="
echo "源环境:   $ENV_DIR"
echo "输出文件: $OUTPUT"
echo "压缩算法: $COMPRESSION"
echo "环境大小: $(du -sh "$ENV_DIR" | cut -f1)"
echo ""

read -rp "确认开始？(y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy] ]]; then
    echo "已取消。"
    exit 0
fi

# 构建
echo "正在打包..."
mksquashfs "$ENV_DIR" "$OUTPUT" -comp "$COMPRESSION" -noappend

echo ""
echo "=== 构建完成 ==="
echo "镜像: $OUTPUT ($(du -sh "$OUTPUT" | cut -f1))"
echo ""
echo "使用方法:"
echo "  apply_gpu -c $(realpath "$OUTPUT")"
