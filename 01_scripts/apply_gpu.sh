#!/usr/bin/env bash
set -euo pipefail

print_usage() {
    echo "Usage: $0 [-c SQFS_PATH] [N_nodes] [n_tasks] [g_gpus_per_node] [c_cpus_per_task] [gpu_type] [server]"
}

# 先解析 -c 选项（必须在位置参数之前），然后 shift 掉，剩下的才是位置参数
SQFS_PATH=""
while getopts ":c:h" opt; do
    case ${opt} in
        c) SQFS_PATH="${OPTARG}" ;;
        h) print_usage; exit 0 ;;
        \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ "$#" -le 2 ]; then
    ACTUAL_USER="${ACTUAL_USER:-$(basename "$_HPC_SU_HOME")}"
    read -rp "作业名称 [默认 $ACTUAL_USER]: " job_name
    job_name=${job_name:-$ACTUAL_USER}
    read -rp "GPU 类型 (例如 l40) [默认 l40]: " name
    name=${name:-l40}
    read -rp "每个节点显卡数 g [默认 1]: " g
    g=${g:-1}
    read -rp "每个 task 使用的 CPU 数 c [默认 7*g]: " c
    if [ -z "$c" ]; then
        c=$((7 * g))
    fi
    read -rp "节点数 N [默认 1]: " N
    N=${N:-1}
    read -rp "task 数 n [默认 1]: " n
    n=${n:-1}
    read -rp "是否指定 server？(y/N): " use_server
    if [[ "$use_server" =~ ^[Yy] ]]; then
        read -rp "server 名称: " server_name
        server="-w $server_name"
    else
        server=""
    fi
else
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        print_usage
        exit 0
    fi
    ACTUAL_USER="${ACTUAL_USER:-$(basename "$_HPC_SU_HOME")}"
    job_name="$ACTUAL_USER"
    N=${1:-1}
    n=${2:-1}
    g=${3:-1}
    c=${4:-}
    if [ -z "$c" ]; then
        c=$((7 * g))
    fi
    name=${5:-l40}
    if [ -n "${6:-}" ]; then
        server="-w ${6}"
    else
        server=""
    fi
fi

echo "作业名 ${job_name}"
echo "正在申请 ${N} 个节点，每节点 ${g} 张 ${name^^}；每个 task 使用 ${c} 个 CPU；task 数 ${n}。"
_HPC_SU_HOME="${HPC_SU_HOME:-$HOME/hpc-su-toolkit}"
if [ -n "${SQFS_PATH}" ]; then
    srun -p ${name^^} -N ${N} -n ${n} -J ${job_name} $server --gres=gpu:${name}:${g} --cpus-per-task=${c} --pty \
     "$_HPC_SU_HOME/01_scripts/fast_bash_init.sh" \
     -c "$SQFS_PATH"
else
    srun -p ${name^^} -N ${N} -n ${n} -J ${job_name} $server --gres=gpu:${name}:${g} --cpus-per-task=${c} --pty \
     "$_HPC_SU_HOME/01_scripts/fast_bash_init.sh"
fi
