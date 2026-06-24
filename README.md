# HPC SU Toolkit

**超算共享账号便携式开发环境** — 多人共用同一账号的解决方案。

## 设计理念

在无 root、无法安装系统包、多人共用同一账号的超算平台上，将所有依赖打包为用户态自包含环境：

```
静态二进制 zip (micromamba/uv/squashfuse/nvtop...)
    ＋
SLURM 胶水脚本 (申请/释放/初始化)
    ＋
SquashFS 镜像 (完整的 Python/Conda 环境)
    ＝
    零依赖、可移植、可复现的开发环境
```

使用 SquashFS 而非直接安装 conda 环境：避免共享文件系统上数十万小文件的 IO 瓶颈，也使得环境可一键挂载/卸载。

## 推荐部署方式

**每个实际用户在自己的 `$HOME/<缩写>/` 下 clone 一份**，各自独立、互不干扰：

```
/home/shared_account/
├── alice/         # 用户 Alice
│   ├── 00_static_tools/
│   ├── 01_scripts/
│   ├── 02_configs/
│   └── ...
├── bob/           # 用户 Bob
│   └── ...
└── charlie/       # 用户 Charlie
    └── ...
```

## 目录结构

```
<你的缩写>/
├── bootstrap.sh                  # 一键初始化
├── .gitignore
├── 00_static_tools/              # 静态二进制 (从 zip 安装，不入库)
│   └── .gitkeep
├── 01_scripts/                   # SLURM 工作流脚本
│   ├── apply_gpu.sh              #   申请交互式 GPU 节点
│   ├── autorelease.sh            #   任务结束自动释放资源
│   ├── fast_bash_init.sh         #   快速初始化 bash 环境
│   ├── nvtop.sh                  #   GPU 监控 (静态 nvtop 包装)
│   └── vscode_slurm_connect.sh   #   VS Code Remote SSH 隧道
├── 02_configs/                   # Shell 配置文件
│   ├── bashrc_entry.sh           #   入口 (自动推断路径)
│   ├── bashrc_base.sh            #   基础配置 (版本控制)
│   └── bashrc_local.sh.example   #   本地覆盖模板
├── scripts/
│   └── build_sqfs.sh             #   从 micromamba 环境构建 SquashFS
└── docs/
    └── TIPS.md                   #   踩坑记录 & 技巧
```

## 快速开始

```bash
# 1. Clone 到你自己的目录 (例如 ~/alice/)
git clone <repo_url> ~/alice

# 2. 初始化 (含静态工具安装)
#  方式 A: 从本地 zip 解压
bash ~/alice/bootstrap.sh -f /path/to/static_tools.zip

#  方式 B: 从远程 URL 下载
bash ~/alice/bootstrap.sh -u https://your-server/static_tools.zip

# 3. 重新登录或手动加载
source ~/.bashrc
```

如果已经手动把静态工具放好了，直接 `bash ~/alice/bootstrap.sh`（会跳过工具安装）。

## 静态工具 zip

`00_static_tools/` 中的二进制文件不入 Git 仓库。通过一个 zip 包分发：

```bash
# 制作 zip (在已有工具的机器上):
cd ~/alice
zip -r static_tools.zip 00_static_tools/

# 分发给其他人:
bash ~/bob/bootstrap.sh -f ~/alice/static_tools.zip   # 直接从别人目录读
# 或放到一个共享 HTTP 地址后:
bash ~/bob/bootstrap.sh -u https://files.example.com/static_tools.zip
```

### 设置默认下载地址

编辑 `bootstrap.sh` 顶部的 `DEFAULT_TOOLS_URL`，或设置环境变量：

```bash
export HPC_SU_TOOLS_URL="https://your-server/static_tools.zip"
bash ~/ls/bootstrap.sh
```

## 典型用法

### 申请交互式 GPU

```bash
# 交互式问答模式 (推荐)
apply_gpu

# 命令行模式
apply_gpu 2 2 4 28 a100        # N=2节点 n=2task g=4卡 c=28核 a100

# 带 SquashFS 环境
apply_gpu -c ./envs/pytorch.squashfs
```

### 自动释放

在申请的 GPU 节点内：

```bash
auto_release python train.py    # 训练完成后自动释放节点
```

### VS Code Remote 连接

在本地 `~/.ssh/config` 中添加：

```
Host hpc-gpu
    HostName login-node.example.com
    User shared_account
    ProxyCommand bash /home/shared_account/alice/01_scripts/vscode_slurm_connect.sh
```

### 构建 SquashFS 环境

参考[conda-pack](https://conda.github.io/conda-pack/)、[SquashFS](https://conda.github.io/conda-pack/squashfs.html)以及[squashfuse](https://github.com/vasi/squashfuse)项目。

## 配置

编辑 `02_configs/bashrc_local.sh`（不入版本控制，每人独立）：

```bash
# 自定义 micromamba 根目录
export MAMBA_ROOT_PREFIX=/share/home/shared_account/.conda

# 自定义 VS Code 连接参数
export VSC_SLURM_CPUS=8
export VSC_SLURM_MEM=32G
```

## 新增用户只需三步

```bash
git clone <repo_url> ~/<你的缩写>
bash ~/<你的缩写>/bootstrap.sh -f /path/to/static_tools.zip
source ~/.bashrc
```

每人的 `HPC_SU_HOME` 自动指向自己的 clone 目录，环境天然隔离。

## License

MIT
