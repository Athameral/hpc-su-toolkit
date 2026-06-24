_HPC_SU_HOME="${HPC_SU_HOME:-$HOME/hpc-su-toolkit}"

# Try common terminfo locations
if [ -d /usr/share/terminfo ]; then
    export TERMINFO=/usr/share/terminfo
elif [ -d /usr/share/lib/terminfo ]; then
    export TERMINFO=/usr/share/lib/terminfo
fi

exec "$_HPC_SU_HOME/00_static_tools/nvtop" "$@"

