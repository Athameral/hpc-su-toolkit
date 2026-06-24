#!/bin/bash
_HPC_SU_HOME="${HPC_SU_HOME:-$HOME/hpc-su-toolkit}"

JOB_NAME="hpc_su_vscode_remote"
CPUS="${VSC_SLURM_CPUS:-4}"
MEM="${VSC_SLURM_MEM:-16G}"
LOG_TIME=$(date "+%Y-%m-%d_%H-%M-%S")

# 确保 slogs 目录存在
mkdir -p "$_HPC_SU_HOME/sblogs"

# 1. 异步启动任务 (使用 --parsable 获取 JOBID)
JOB_ID=$(sbatch \
    --job-name="$JOB_NAME" \
    --cpus-per-task="$CPUS" \
    --mem="$MEM" \
    --parsable \
    --wrap="sleep infinity" \
    --output="$_HPC_SU_HOME/sblogs/${LOG_TIME}.out")

echo "Got job id: $JOB_ID" >&2

# 2. 定义清理逻辑 (这是解决孤儿进程的关键)
# 当这个 ProxyCommand 脚本因为 SSH 断开被杀掉时，强制干掉 Slurm 任务
cleanup() {
    scancel $JOB_ID >/dev/null 2>&1
}
trap cleanup EXIT INT TERM

# 3. 轮询获取节点名 (Poll)
while :; do
    NODE=$(squeue -j $JOB_ID -h -t RUNNING -o "%N")
    [ -n "$NODE" ] && break
    sleep 1
done

# 4. 执行转发
nc $NODE 22

