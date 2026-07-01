# ============================================================
# bashrc_base.sh — HPC SU Toolkit 基础配置（进入版本控制）
# ============================================================
# 所有路径通过 HPC_SU_HOME 统一管理，不再硬编码用户目录。
# HPC_SU_HOME 由 bashrc_entry.sh 自动推断，或用户手动设置。

# respect the system-wide bash configuration
source /etc/bashrc 2>/dev/null || true

# === 推断实际用户 ===
# 共享账号下 $USER 对所有人都一样，因此从目录名推断。
# 约定：每人 clone 到 $HOME/<你的缩写>/，如 ~/alice/。
# 如果 clone 到更深的位置（如 ~/lxz/hpc-su-toolkit/），
# 自动取 $HOME 下的第一级目录名。
# ACTUAL_USER 会作为 SLURM 作业名等场景的默认标识。
# 可在 bashrc_local.sh 中覆盖: export ACTUAL_USER=your_name
if [ -z "${ACTUAL_USER:-}" ]; then
    if [[ "$HPC_SU_HOME" == "$HOME/"* ]]; then
        _rel="${HPC_SU_HOME#$HOME/}"
        export ACTUAL_USER="${_rel%%/*}"
        unset _rel
    else
        export ACTUAL_USER="$(basename "$HPC_SU_HOME")"
    fi
fi

# === micromamba (static binary) ===
if [ -x "$HPC_SU_HOME/00_static_tools/micromamba" ]; then
    export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/.conda}"
    eval "$("$HPC_SU_HOME/00_static_tools/micromamba" shell hook --shell bash)"
    export PYTHONNOUSERSITE=1  # avoid loading .local/lib/python*/site-packages
fi

# === uv (static binary) ===
if [ -x "$HPC_SU_HOME/00_static_tools/uv-x86_64-unknown-linux-musl/uv" ]; then
    alias uv="$HPC_SU_HOME/00_static_tools/uv-x86_64-unknown-linux-musl/uv"
    alias uvx="$HPC_SU_HOME/00_static_tools/uv-x86_64-unknown-linux-musl/uvx"
    export UV_TOOL_DIR="$HPC_SU_HOME/.uv/tools"
    export UV_TOOL_BIN_DIR="$HPC_SU_HOME/.uv/bin"
    export UV_PYTHON_INSTALL_DIR="$HPC_SU_HOME/.uv/python"
    eval "$(uv generate-shell-completion bash 2>/dev/null)" || true
    PATH="$UV_TOOL_BIN_DIR:$PATH"
fi

# === nvtop (static binary) ===
alias nvtop="$HPC_SU_HOME/01_scripts/nvtop.sh"

# === squashfs tools (static binaries) ===
alias squashfuse="$HPC_SU_HOME/00_static_tools/squashfuse_ll-musl-mimalloc-x86_64"
alias mksquashfs="$HPC_SU_HOME/00_static_tools/mksquashfs-x86_64"
alias unsquashfs="$HPC_SU_HOME/00_static_tools/unsquashfs-x86_64"

# === 便捷别名 ===
alias apply_gpu="$HPC_SU_HOME/01_scripts/apply_gpu.sh"
alias auto_release="$HPC_SU_HOME/01_scripts/autorelease.sh"

# === SquashFS 环境自动激活 ===
if [ -n "${SQFS_MNT_DIR-}" ] && [ -f "$SQFS_MNT_DIR/bin/activate" ]; then
    source "$SQFS_MNT_DIR/bin/activate"
fi

# === 加载用户本地覆盖 (如果存在) ===
if [ -f "$HPC_SU_HOME/02_configs/bashrc_local.sh" ]; then
    source "$HPC_SU_HOME/02_configs/bashrc_local.sh"
fi