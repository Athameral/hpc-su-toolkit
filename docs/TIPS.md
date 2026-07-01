# TIPS — 踩坑记录 & 性能调优

## SquashFS

### 为什么用 SquashFS？

共享文件系统（NFS/Lustre/GPFS）上，一个 conda 环境动辄 10 万+ 小文件。
`import torch` 等操作会产生大量 `stat()` / `open()` 调用，严重拖慢启动速度。
SquashFS 将所有文件压缩进单个镜像，通过 FUSE 挂载，消除了小文件 IO 开销，速度更快。
单 SquashFS 环境速度优势在训练任务大量import时尤为明显。

### 压缩算法选择

| 算法 | 压缩率 | 速度 | 适合场景 |
|------|--------|------|----------|
| zstd | 中 | 快 | 推荐，平衡性好 |
| lz4  | 低 | 极快 | 对加载速度敏感 |
| xz   | 高 | 慢 | 存储空间紧张 |
| lzo  | 低 | 快 | 兼容性考虑 |

### 挂载注意事项

- 挂载点需要用 `mktemp -d` 创建，避免多用户冲突。
- `fast_bash_init.sh` 中已实现 `trap ... EXIT` 自动卸载。`autorelease.sh` 使用渐进式信号 (TERM→INT→KILL) 终止父进程，给 trap 足够的清理时间。
  如果遇到残留挂载，手动：`fusermount -uz /tmp/tmp.XXXXXX`
- 部分超算限制 FUSE，可尝试 `squashfuse -o allow_other`。

### pre-built 环境技巧

如果团队共用同一个 base 环境，可以提前构建好 `.squashfs` 放在共享目录：
- 避免每人重复构建
- 确保环境一致性
- 多个 compute node 同时挂载同一文件是安全的（只读）

## SLURM

### srun 交互式申请的坑

- `--pty` 在某些集群上需要配合 `--overcommit` 才能获得伪终端。
- 如果 `srun` 卡住不返回，通常是因为没有可用资源（`squeue` 查看排队状态）。
- `apply_gpu.sh` 中的分区名 (`l40`) 是示例，可能和你的集群分区名不同，用位置参数覆盖。

### 孤儿进程

- `vscode_slurm_connect.sh` 使用 `trap cleanup EXIT INT TERM` 防止 SSH 断开后 Slurm job 继续运行。
- 如果网络波动导致 SSH 断开，job 会自动 `scancel`。
- 如果想保留 job 手动调试，在断开前 `touch ~/keep_job` 可做条件判断。

### 环境变量传递

`srun` 默认传递当前 shell 的大部分环境变量，但 `HPC_SU_HOME` 可能不被传递。
`apply_gpu.sh` 中通过 `fast_bash_init.sh` 间接引用路径，避免依赖 srun 的环境变量传递行为。

## micromamba

### 静态二进制 vs 完整 conda

- micromamba 是 mamba 的 C++ 重写 + 静态编译版，无 Python 依赖，~10MB。
- 直接放在 `00_static_tools/` 即可，不需要 root。
- 兼容 conda-forge 的所有包。

## 静态工具 zip

### 如何制作

```bash
# 在有完整工具的机器上:
cd ~/alice
zip -r static_tools.zip 00_static_tools/
```

### 如何分发

```bash
# 方式 A: 直接读别人的目录
bash ~/bob/bootstrap.sh -f ~/alice/static_tools.zip

# 方式 B: 放到 HTTP 服务器 (用 Python 一行起)
cd ~/alice && python3 -m http.server 8888
bash ~/bob/bootstrap.sh -u http://login-node:8888/static_tools.zip

# 方式 C: 用 lrz/sz 传到本地再传回来
```

## 多用户隔离

### 推荐目录布局

```
/home/shared_account/
├── alice/            # Alice 的工具包
├── bob/              # Bob 的工具包
└── charlie/          # Charlie 的工具包
```

每人 clone 到自己的缩写目录下，`HPC_SU_HOME` 自动指向自己的目录。

### MAMBA_ROOT_PREFIX

如果共享账号，每个用户设置不同的 `MAMBA_ROOT_PREFIX`，避免 env 互相覆盖。
在各自 `bashrc_local.sh` 中覆盖即可：

```bash
# alice 的 bashrc_local.sh
export MAMBA_ROOT_PREFIX=/share/home/shared_account/.conda_alice

# bob 的 bashrc_local.sh
export MAMBA_ROOT_PREFIX=/share/home/shared_account/.conda_bob
```

## uv

- 静态编译版本，同样可在无 root 环境使用。
- `PYTHONNOUSERSITE=1` 避免加载 `.local/lib/` 中的用户级 site-packages（常见的依赖冲突源）。

## 调试

### Script 找不到文件

```bash
echo $HPC_SU_HOME       # 确认指向正确
ls $HPC_SU_HOME/01_scripts/   # 确认脚本存在
```

### SquashFS 挂载失败

```bash
# 检查 squashfuse 是否存在且可执行
which squashfuse
squashfuse --version

# 手动测试挂载
mkdir -p /tmp/test_mnt
squashfuse /path/to/env.squashfs /tmp/test_mnt
ls /tmp/test_mnt
fusermount -u /tmp/test_mnt
```

### 环境未加载

```bash
# 手动加载 (多人共用账号，不修改 ~/.bashrc)
source ~/alice/02_configs/bashrc_entry.sh    # 改成你自己的目录

# 确认变量
echo $HPC_SU_HOME
echo $ACTUAL_USER
```
