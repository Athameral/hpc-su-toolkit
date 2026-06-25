# ============================================================
# bashrc_entry.sh — 入口脚本
# ============================================================
# 推荐用法：将本仓库 clone 到 $HOME/<你的缩写>/ 下（如 ~/alice/），
# 登录后手动 source 即可（多人共用账号，不修改 ~/.bashrc）：
#   source ~/alice/02_configs/bashrc_entry.sh
#
# 多用户共享同一账号时，每人 clone 到自己目录即可互相隔离。

# --- 自动推断 HPC_SU_HOME ---
# 如果用户未设置 HPC_SU_HOME，从本脚本所在位置向上推断
if [ -z "${HPC_SU_HOME:-}" ]; then
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _INFERRED_HOME="$(cd "$_SCRIPT_DIR/.." && pwd)"
    if [ -f "$_INFERRED_HOME/02_configs/bashrc_base.sh" ]; then
        export HPC_SU_HOME="$_INFERRED_HOME"
    fi
fi

# 加载基础配置
source "$HPC_SU_HOME/02_configs/bashrc_base.sh"
