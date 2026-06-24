#!/bin/bash

# 获取父进程（即那个 srun 产生的交互式 bash）的 PID
PARENT_PID=$PPID

cleanup() {
    echo -e "\n[Ctrl+C] 任务中断，保留会话。"
    # 仅仅退出脚本自己，不碰父进程
    exit 1
}

# 捕获 SIGINT
trap cleanup SIGINT

# 执行任务
"$@"

EXIT_CODE=$?

# 如果任务正常跑完，没有触发上面的 cleanup exit
echo "任务完成，退出码 $EXIT_CODE 正在关闭 Slurm 终端..."

# 渐进式终止父进程：SIGTERM → SIGINT → SIGKILL
for signal in TERM INT KILL; do
    wait_sec=5
    echo -n "  发送 SIG${signal} (PID $PARENT_PID)，倒计时 ${wait_sec}s: "
    for ((i = wait_sec; i > 0; i--)); do
        printf "%d " "$i"
        sleep 1
    done
    echo ""
    kill "-${signal}" "$PARENT_PID" 2>/dev/null || true
    sleep 0.5
    if ! kill -0 "$PARENT_PID" 2>/dev/null; then
        echo "  父进程已终止。"
        break
    fi
done