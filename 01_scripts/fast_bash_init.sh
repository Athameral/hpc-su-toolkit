#!/bin/bash
shopt -s expand_aliases
_HPC_SU_HOME="${HPC_SU_HOME:-$HOME/hpc-su-toolkit}"
source "$_HPC_SU_HOME/02_configs/bashrc_entry.sh"

while getopts ":c:" opt; do
    case ${opt} in
        c) SQFS="${OPTARG}" ;;
        \?) echo "Invalid option: -${OPTARG}" >&2
            exit 1
            ;;
    esac
done

if [ -n "${SQFS}" ]; then
    export SQFS_MNT_DIR="$(mktemp -d)"
    echo "Mounting ${SQFS} to ${SQFS_MNT_DIR}..."
    squashfuse "${SQFS}" "${SQFS_MNT_DIR}"
fi

cleanup() {
    if [ -n "${SQFS}" ] && [ -d "${SQFS_MNT_DIR}" ]; then
        # 尝试正常卸载
        if ! fusermount -u "${SQFS_MNT_DIR}" 2>/dev/null; then
            # 如果失败（设备忙），使用 lazy unmount
            echo "Normal unmount failed, trying lazy unmount..."
            fusermount -uz "${SQFS_MNT_DIR}" 2>/dev/null || true
        fi
        # 确认已卸载后再删除目录
        if ! mountpoint -q "${SQFS_MNT_DIR}" 2>/dev/null; then
            rm -rf "${SQFS_MNT_DIR}"
        else
            echo "Warning: ${SQFS_MNT_DIR} still mounted, skipping removal" >&2
        fi
    fi
}
trap cleanup EXIT INT TERM

bash --noprofile --rcfile "$_HPC_SU_HOME/02_configs/bashrc_entry.sh"

