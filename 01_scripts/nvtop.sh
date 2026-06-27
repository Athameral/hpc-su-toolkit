# 自推断 HPC_SU_HOME（本脚本在 01_scripts/ 下）
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HPC_SU_HOME="${HPC_SU_HOME:-$(cd "$_SCRIPT_DIR/.." && pwd)}"

# Try common terminfo locations
if [ -d /usr/share/terminfo ]; then
    export TERMINFO=/usr/share/terminfo
elif [ -d /usr/share/lib/terminfo ]; then
    export TERMINFO=/usr/share/lib/terminfo
fi

exec "$HPC_SU_HOME/00_static_tools/nvtop" "$@"

