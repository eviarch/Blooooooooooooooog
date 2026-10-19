---
title: Strata 与 Project Maya 安装、构建及局域网部署指南
date: 2026-10-16 00:58:50
tags: ["AI", "Instruction"]
categories: ["AI", "Instruction", "Learning", "Part-time Study"]
thumbnail: "/post_images/Strata与ProjectMaya安装构建及局域网部署指南/huggingface_logo.svg"
---

> **文档目的**：在同一台 Ubuntu 服务器上，以统一的环境隔离原则安装、构建和部署 Strata 与 Project Maya，包含原理说明、逐步操作、模型目录配置、服务监听、API Key、安全注意事项和故障排查。
>
> **适用环境（以部署记录为准）**：Ubuntu 18.04 x86_64；NVIDIA RTX 4090 24G x8张 GPU 服务器；NVIDIA 驱动记录为 530.41.03；CUDA Toolkit 12.0.1；独立 GCC/G++ 11.4.0 环境。
>
> **重要说明**：各项目的启动参数会随版本变化，执行前必须检查当前仓库的帮助信息。文档明确区分历史记录、示例命令和需要在服务器上实际验证的行为。

## 目录

- [第一部分：整体架构与共同原则](#第一部分整体架构与共同原则)
  - [1.1 目录规划](#11-目录规划)
  - [1.2 共同技术原理](#12-共同技术原理)
  - [1.3 两个项目不能混用的内容](#13-两个项目不能混用的内容)
- [第二部分：Project Maya 安装与局域网服务部署指南（Ubuntu）](#第二部分project-maya-安装与局域网服务部署指南ubuntu)
  - [1. 当前环境与目标](#1-当前环境与目标)
  - [2. 安装原理](#2-安装原理)
  - [3. 安装前检查](#3-安装前检查)
  - [4. 安装脚本的准备与使用](#4-安装脚本的准备与使用)
  - [5. 如何选择 API Key 与 GGUF 目录](#5-如何选择-api-key-与-gguf-目录)
  - [6. 验证服务是否启动](#6-验证服务是否启动)
  - [7. 常见问题](#7-常见问题)
  - [8. 日常使用速查](#8-日常使用速查)
  - [9. 部署完成的判断标准](#9-部署完成的判断标准)
- [第三部分：Strata 安装与部署指南](#第三部分strata-安装与部署指南)
  - [1. Strata 部署目标与总体原理](#1-strata-部署目标与总体原理)
  - [2. 服务器环境与目录](#2-服务器环境与目录)
  - [3. 第一步：检查项目与基础环境](#3-第一步检查项目与基础环境)
  - [4. 第二步：为 Strata 设置隔离工具链](#4-第二步为-strata-设置隔离工具链)
  - [5. 第三步：查看当前版本支持的安装参数](#5-第三步查看当前版本支持的安装参数)
  - [6. 第四步：准备模型目录与模型文件](#6-第四步准备模型目录与模型文件)
  - [7. 第五步：检查构建结果与 CMake 缓存](#7-第五步检查构建结果与-cmake-缓存)
  - [8. 第六步：本机启动与 API 验证](#8-第六步本机启动与-api-验证)
  - [9. 第七步：开放局域网访问](#9-第七步开放局域网访问)
  - [10. Strata 常见问题](#10-strata-常见问题)
  - [11. Strata 部署验收清单](#11-strata-部署验收清单)
- [第四部分：两个项目共存时的维护原则](#第四部分两个项目共存时的维护原则)
  - [1. 保持项目环境隔离](#1-保持项目环境隔离)
  - [2. 不要默认两个服务使用同一端口](#2-不要默认两个服务使用同一端口)
  - [3. 日志、密钥和模型数据](#3-日志密钥和模型数据)
- [第五部分：统一部署验收清单](#第五部分统一部署验收清单)
  - [Project Maya](#project-maya)
  - [Strata](#strata)
  - [服务器安全与资源](#服务器安全与资源)

# 第一部分：整体架构与共同原则

### 1.1 目录规划

后文命令都使用 `/mnt/data/ProjectMoE`。这里只保留部署时需要区分的目录：共享编译工具链、两个项目各自的代码与 Python 环境、以及与仓库分开存放的模型数据。编译器环境内部文件、仓库自带源码、备份、缓存和一次性安装包不列入。CUDA Toolkit 在 `/usr/local/cuda-12.0.1`，不在这个根目录下。

```text
/mnt/data/ProjectMoE/                  # 两个项目的统一根目录
├── gcc11-env/                          # 独立 GCC/G++ 11.4.0；Maya 与 Strata 共用，不替换系统编译器
├── mamba-root/                         # Micromamba 根目录，对应 MAMBA_ROOT_PREFIX
├── tools/bin/micromamba                # Micromamba 可执行文件，用于进入 gcc11-env
├── project-maya/                       # Maya 源码与运行目录
│   ├── .venv/                          # Maya 自己的 Python 环境，不要与 Strata 混用
│   ├── maya.sh                         # Maya 的安装与启动入口
│   ├── build-maya-gcc11.sh             # 本指南使用的 GCC 11 包装脚本
│   └── logs/                           # 包装脚本写出的安装日志
├── Maya-data/
│   └── models/                         # 建议存放 Maya 的 GGUF；实际路径通过 --gguf-dir 传入
├── Strata/                             # Strata 源码与运行目录
│   ├── .venv/                          # Strata 自己的 Python 环境
│   ├── setup.py                        # 安装与构建入口，参数以当前 --help 为准
│   └── build-cuda12/                   # CUDA 构建目录；检查编译器时看其中的 CMake 缓存
└── Strata-data/
    └── models/                         # Strata 模型文件，与源码仓库分开存放
```

### 1.2 共同技术原理

| 层级        | 方案                                 | 原因                                   |
| ----------- | ------------------------------------ | -------------------------------------- |
| Python 依赖 | 每个项目使用自己的 `.venv`           | 避免 Python 包版本相互污染             |
| C/C++ 编译  | 使用独立 GCC/G++ 11.4.0              | 避免依赖 Ubuntu 18.04 较旧的系统编译器 |
| CUDA 编译   | 显式指定 CUDA 12.0.1 的 `nvcc`       | 避免构建时误选其他 Toolkit             |
| 构建缓存    | 检查各自的 CMake 缓存                | 避免旧缓存继续使用错误编译器           |
| 模型文件    | 放在独立数据目录，按模型实际要求指定 | 便于管理和避免误删                     |
| 服务监听    | 本机验证后，再按需设置 `0.0.0.0`     | 控制网络暴露范围                       |
| 认证        | 为可远程访问的 API 设置强 API Key    | 降低未授权调用风险                     |

### 1.3 两个项目不能混用的内容

- 不要将 Maya 的 `.venv` 与 Strata 的 `.venv` 合并或互相安装依赖。
- 两个项目可以引用同一套 GCC 11 工具链，但应分别检查各自的构建缓存和参数。
- 不要因为某个项目构建失败就修改系统默认 GCC、覆盖 `/usr/local/cuda` 软链接或升级驱动。
- 不要把 Strata 的 `setup.py` 参数套用到 Maya，也不要把 Maya 的 `maya.sh` 参数套用到 Strata。
- 模型格式、模型目录、下载源和 API 路径都以各项目当前版本为准。
- 在构建、下载或加载模型前运行 `nvidia-smi`；不要擅自终止已有 GPU 任务。

# 第二部分：Project Maya 安装与局域网服务部署指南（Ubuntu）

## 1. 当前环境与目标

已知环境：

- 操作系统：Ubuntu 18.04
- GPU：8 × NVIDIA RTX 4090，每张 24 GB 显存
- NVIDIA 驱动：530.41.03
- CUDA Toolkit：12.0.1，`nvcc` 位于 `/usr/local/cuda-12.0.1/bin/nvcc`
- 独立 GCC/G++：11.4.0，位于 `/mnt/data/ProjectMoE/gcc11-env/bin/`
- Maya 项目：`/mnt/data/ProjectMoE/project-maya`
- Maya Python 虚拟环境：`/mnt/data/ProjectMoE/project-maya/.venv`
- 计划服务地址：`0.0.0.0:8080`

目标是：使用独立 GCC 11 和指定 CUDA Toolkit 检查并构建 Maya，按需选择模型与 GGUF 目录，并使用 API Key 在局域网内访问服务。

## 2. 安装原理

### 2.1 为什么使用独立 GCC 11

Ubuntu 18.04 自带的系统编译器可能较旧。此前 Maya 的检查结果显示系统 `g++` 为 7.5.0，而独立环境中已有 GCC/G++ 11.4.0。

脚本通过环境变量将编译器明确指向独立环境：

- `CC`：C 编译器
- `CXX`：C++ 编译器
- `CUDAHOSTCXX`：CUDA 编译时使用的主机 C++ 编译器

这样做的目的是让构建系统优先使用 GCC 11，而不是系统 `g++`。它不会修改系统默认编译器，也不会通过 `update-alternatives` 更改全局配置。

### 2.2 CUDA Toolkit、驱动和 GPU 架构的区别

- **NVIDIA 驱动**负责让操作系统与 GPU 通信。
- **CUDA Toolkit / `nvcc`**提供 CUDA 编译工具。
- **GPU 架构参数**决定编译产物针对哪些 GPU 架构。RTX 4090 属于 `sm_89` 架构。

脚本指定 `/usr/local/cuda-12.0.1/bin/nvcc`，并把 GCC 11 的 `g++` 传给 Maya 的 `--host-compiler` 参数。此前已经成功完成了最小 C++ 编译/链接和一个 `sm_89` CUDA 文件编译；这只证明基本工具链可用，**不代表 Maya 的完整项目一定能构建成功**。

### 2.3 Python 虚拟环境的作用

Maya 的 Python 环境位于项目的 `.venv`。它将 Python 包与系统 Python、Strata 的环境隔离，降低依赖版本相互影响的风险。运行脚本时会把 `.venv/bin` 放入 `PATH`。

### 2.4 `--setup`、模型下载与服务启动

Maya 命令行帮助提供了 `--setup`、`--check`、`--download-model`、`--model`、`--gguf-dir`、`--host`、`--port` 和 `--api-key` 等参数。

- `--check`：执行环境检查。
- `--setup`：执行 Maya 的安装/构建配置流程。
- `--download-model`：显式请求下载模型。
- `--model`：选择 Maya 支持的模型标识。
- `--gguf-dir`：指定 GGUF 模型目录。
- `--host` / `--port`：指定监听地址和端口。
- `--api-key`：配置 API 访问密钥。

本指南的包装脚本**不会默认添加** `--download-model`。如需下载模型，必须明确传入该参数。模型文件来源、下载行为和所需磁盘空间应以当前 Maya 版本的帮助信息及项目文档为准。

### 2.5 `0.0.0.0` 的含义与安全性

- `127.0.0.1`：通常只接受服务器本机的回环访问。
- `0.0.0.0`：让服务监听所有 IPv4 网络接口，局域网内其他设备才有机会连接。

`0.0.0.0` **不是客户端要访问的地址**。客户端应使用服务器的实际局域网 IP，例如 `http://192.168.1.20:8080`。启用网络监听后应设置强 API Key，并只向可信网络开放端口；不要未经防火墙和访问控制就直接暴露到公网。

## 3. 安装前检查

### 第 1 步：登录服务器并进入项目目录

```bash
ssh usr@你的服务器地址
cd /mnt/data/ProjectMoE/project-maya
```

### 第 2 步：确认项目和脚本存在

```bash
pwd
ls -l ./maya.sh
./maya.sh --help
```

帮助信息应列出当前版本实际支持的参数。如果 `maya.sh` 不存在或帮助输出与本文不同，先检查仓库目录和版本，不要盲目继续。

### 第 3 步：确认 GCC 11 与 CUDA 路径

```bash
/mnt/data/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc --version
/mnt/data/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++ --version
/usr/local/cuda-12.0.1/bin/nvcc --version
```

应能看到 GCC/G++ 11.4.0 和 CUDA 12.0。若路径不存在，先修复工具链路径；不要为此直接更改系统 GCC 或 CUDA 软链接。

### 第 4 步：检查 GPU 与当前占用

```bash
nvidia-smi
```

确认 GPU 可见，并检查显存占用、GPU 利用率及运行中的进程。此前服务器上曾有 `./demo` 进程占用多张 GPU；运行重型构建或加载模型前务必重新检查。**不要为了安装 Maya 擅自终止其他用户或任务的 GPU 进程。**

### 第 5 步：检查 Maya 环境（推荐先做）

将 `build-maya-gcc11.sh` 放在 Maya 项目目录后：

```bash
cd /mnt/data/ProjectMoE/project-maya
chmod +x ./build-maya-gcc11.sh
./build-maya-gcc11.sh --check
```

包装脚本会使用指定的 GCC 11、CUDA `nvcc` 和主机编译器运行 Maya 的 `--check`。检查通过只代表前置环境检查通过，不等于安装已完成。

## 4. 安装脚本的准备与使用

### 第 1 步：把脚本放到服务器

如果脚本在本地电脑当前目录，可以从本地终端上传：

```bash
scp build-maya-gcc11.sh -p ssh端口 usr@你的服务器地址:/mnt/data/ProjectMoE/project-maya/
```

然后在服务器上执行：

```bash
cd /mnt/data/ProjectMoE/project-maya
chmod +x build-maya-gcc11.sh
```

### 第 2 步：理解脚本默认配置

脚本默认配置如下：

| 配置          | 默认值                                   |
| ------------- | ---------------------------------------- |
| Maya 项目目录 | `/mnt/data/ProjectMoE/project-maya`      |
| GCC 环境      | `/mnt/data/ProjectMoE/gcc11-env`         |
| CUDA Toolkit  | `/usr/local/cuda-12.0.1`                 |
| GPU           | `0,1,2,3,4,5,6,7`                        |
| 服务监听地址  | `0.0.0.0`                                |
| 服务端口      | `8080`                                   |
| 日志目录      | `/mnt/data/ProjectMoE/project-maya/logs` |
| Python 包索引 | 阿里云 PyPI 镜像（仅影响 pip 包安装）    |

脚本不会主动杀死 GPU 进程，不会更改系统编译器或驱动，也不会默认强制下载模型。

### 第 3 步：先查看帮助与检查环境

```bash
./build-maya-gcc11.sh --help
./build-maya-gcc11.sh --check
```

`--help` 会转交给 Maya 自己的帮助命令。`--check` 只执行环境检查，不要求输入 API Key，也不启动服务。

### 第 4 步：启动安装流程

```bash
./build-maya-gcc11.sh
```

正常安装运行时，脚本会提示输入 API Key 和可选 GGUF 目录。

- **API Key**：输入时不回显；不能为空。
- **GGUF 目录**：输入已存在的目录绝对路径。直接回车表示不传 `--gguf-dir`，由 Maya 使用自身默认配置。
- **模型下载**：默认不添加 `--download-model`。若需要下载，先确认当前 Maya 版本支持的模型和下载方式，再显式添加对应参数。

脚本会将安装输出保存到 `logs/maya-setup-gcc11-时间戳.log`。如果命令失败，按终端提示查看最后 100 行日志：

```bash
tail -n 100 /mnt/data/ProjectMoE/project-maya/logs/你的日志文件名.log
```

**注意：** 当前包装脚本会把 `--setup`、`--host 0.0.0.0`、`--port 8080`、`--api-key` 及可选的 `--gguf-dir` 传给 `maya.sh`。Maya 的 `--setup` 在当前版本中是否会在同一流程里完成构建并启动服务，需要以实际日志和该版本文档为准。若它只完成安装而没有启动服务，不要直接假设服务已运行。

## 5. 如何选择 API Key 与 GGUF 目录

### 方式 A：交互式输入（推荐）

```bash
./build-maya-gcc11.sh
```

按提示输入 API Key。然后输入 GGUF 模型目录；如果想使用 Maya 默认目录，直接按回车。

### 方式 B：使用环境变量

```bash
export MAYA_API_KEY='替换为你自己生成的强随机密钥'
export MAYA_GGUF_DIR='/实际存在的/GGUF/目录'
export MAYA_HOST='0.0.0.0'
export MAYA_PORT='8080'

./build-maya-gcc11.sh
```

如果不想指定自定义 GGUF 目录，可以取消该变量：

```bash
unset MAYA_GGUF_DIR
```

安全提示：环境变量可能被同一账户下的调试工具、进程信息或 shell 配置间接暴露。不要把真实密钥提交到 Git、写进公开脚本或粘贴到公开日志中。交互输入可避免终端回显，但仍应保护服务器账户和日志访问权限。

### 方式 C：指定模型（仅在确认需要时）

先检查支持的模型：

```bash
./maya.sh --help
```

如果确认要使用某个支持的模型，例如帮助中列出的 `Maya-S-v2-IQ2_XXS`，可按该版本的参数规则显式指定：

```bash
./build-maya-gcc11.sh --model Maya-S-v2-IQ2_XXS
```

只有明确希望触发下载时才添加 `--download-model`：

```bash
./build-maya-gcc11.sh --model Maya-S-v2-IQ2_XXS --download-model
```

上面是参数使用示例，不代表已验证模型下载源、文件完整性、模型所需显存或当前服务器可用空间。下载前应先阅读该版本文档并检查磁盘与 GPU 资源。

## 6. 验证服务是否启动

### 第 1 步：检查监听端口

```bash
ss -lntp | grep ':8080'
```

如果服务成功监听所有 IPv4 接口，通常会看到类似 `0.0.0.0:8080` 的监听项。若没有输出，服务可能没有启动、启动失败，或使用了其他端口；先查看 Maya 日志。

### 第 2 步：在服务器本机测试

```bash
curl -i http://127.0.0.1:8080/
```

不同 Maya 版本的根路径可能不提供网页或健康检查端点，因此 `404` 并不必然代表服务进程没启动。应根据 Maya 文档找到正确的健康检查或 API 路径。对需要认证的 API 请求，应按该版本要求传递 API Key。

### 第 3 步：取得服务器局域网 IP

```bash
hostname -I
```

从输出中选择与客户端电脑处于同一局域网的服务器地址。不要把 `0.0.0.0` 当成访问地址。

### 第 4 步：从另一台电脑访问

浏览器或客户端使用：

```text
http://服务器局域网IP:8080
```

例如（仅为格式示例）：

```text
http://192.168.1.20:8080
```

如果使用 API 客户端，请根据 Maya 当前版本的 API 文档配置认证头或参数。不要把 API Key 放进公开分享的 URL。

### 第 5 步：如果无法访问，按顺序排查

1. 在服务器执行 `ss -lntp | grep ':8080'`，确认端口确实在监听。
2. 查看 Maya 日志，确认服务没有在启动后退出。
3. 确认客户端使用的是服务器局域网 IP，而不是 `0.0.0.0` 或 `127.0.0.1`。
4. 检查 Ubuntu 防火墙、上游防火墙、路由器 ACL、VLAN 或无线客户端隔离。
5. 检查 Maya 是否要求特定 API 路径或认证头。
6. 不要为排障而直接关闭全部防火墙，也不要将服务无保护地暴露到公网。

## 7. 常见问题

### 问题：检查仍显示系统 `g++` 7.5

先通过包装脚本运行：

```bash
./build-maya-gcc11.sh --check
```

查看 Maya 检查输出是否识别了 `--host-compiler` 指定的 GCC 11。构建系统可能缓存先前的编译器选择；若日志仍显示旧编译器，应先检查 Maya 构建目录和该版本的 CMake 配置方式，再决定是否清理或重建。不要直接删除未知目录。

### 问题：提示找不到 GCC、CUDA 或 Maya 脚本

逐项确认以下文件存在且可执行：

```bash
ls -l /mnt/data/ProjectMoE/project-maya/maya.sh
ls -l /mnt/data/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc
ls -l /mnt/data/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++
ls -l /usr/local/cuda-12.0.1/bin/nvcc
```

若项目实际安装在其他位置，可在脚本中修改默认路径，或设置相应环境变量 `MAYA_ROOT`、`MAYA_GCC_ENV`、`MAYA_CUDA_HOME`。

### 问题：GGUF 目录输入后报错

脚本会检查目录是否存在，但目录存在不代表其中的模型文件一定符合 Maya 的要求。确认文件格式、命名、分片完整性以及该 Maya 版本的目录约定。

### 问题：API Key 输入后仍然无法调用 API

API Key 必须与服务端实际配置一致。还要确认客户端采用的认证方式、请求路径和 API 格式符合当前 Maya 版本文档。不要把密钥贴进公共日志或问题帖。

### 问题：显存不足或服务启动很慢

先运行 `nvidia-smi` 检查其他进程、显存占用和 GPU 利用率。多 GPU 推理的显存分配、上下文长度、并发数和模型量化都会影响资源需求。不要未经确认就终止正在运行的任务。

## 8. 日常使用速查

```bash
# 进入项目目录
cd /mnt/data/ProjectMoE/project-maya

# 查看 Maya 支持的参数
./maya.sh --help

# 检查环境（不会要求输入 API Key）
./build-maya-gcc11.sh --check

# 运行安装/构建流程并按提示输入 API Key 与 GGUF 目录
./build-maya-gcc11.sh

# 显式选择模型（以当前 --help 支持的名称为准）
./build-maya-gcc11.sh --model Maya-S-v2-IQ2_XXS

# 显式请求模型下载（确认下载源与资源需求后再执行）
./build-maya-gcc11.sh --model Maya-S-v2-IQ2_XXS --download-model

# 查看 GPU 状态
nvidia-smi

# 查看服务监听
ss -lntp | grep ':8080'

# 查看最新日志文件列表
ls -lt /mnt/data/ProjectMoE/project-maya/logs/
```

## 9. 部署完成的判断标准

逐项确认：

- [ ] `./maya.sh --help` 能正常运行，参数与当前版本一致。
- [ ] `./build-maya-gcc11.sh --check` 通过。
- [ ] 日志表明构建过程使用了预期的 GCC 11 与 CUDA Toolkit，而不是意外回退到系统编译器。
- [ ] 所需模型文件已准备好，且 GGUF 路径与 Maya 配置一致。
- [ ] 服务进程实际运行，`ss` 能看到预期监听端口。
- [ ] 本机请求可到达正确的 API 路径。
- [ ] 另一台局域网电脑能够访问，并且 API Key 认证按预期生效。
- [ ] 服务只开放给可信网络，日志和密钥受到保护。

完成这些检查后，才可以认为 Maya 已完成从工具链准备、构建、模型配置到局域网 API 访问的整套部署。

# 第三部分：Strata 安装与部署指南

## 1. Strata 部署目标与总体原理

本部分基于用户提供的《Strata 环境依赖隔离与工具链配置记录》，并结合此前对 Strata 的部署上下文整理。文档中明确标注了需要以当前仓库 `--help` 或日志再次核实的步骤，避免把历史命令当作所有版本都适用的固定接口。

Strata 部署分为五个层面：

1. **Python 运行环境**：使用 Strata 仓库自己的 `.venv` 安装 Python 依赖。
2. **C/C++ 编译工具链**：通过独立 Micromamba 环境 `gcc11-env` 使用 GCC/G++ 11.4.0，不替换系统编译器。
3. **CUDA 编译工具链**：显式指定 `/usr/local/cuda-12.0.1/bin/nvcc`。
4. **模型文件**：将模型文件存放在独立的数据目录中；模型来源、模型家族、量化格式和目录参数以当前版本帮助为准。
5. **服务部署**：先在服务器本机验证模型和 API，再按需要绑定 `0.0.0.0` 并配置 API Key，以允许可信局域网客户端访问。

Python 虚拟环境与 GCC 环境各自解决不同问题：`.venv` 管理 Python 包，`gcc11-env` 提供编译器和构建工具。二者不是同一个环境。该方案也不能隔离 Linux 内核、glibc、系统头文件或 NVIDIA 驱动。

## 2. 服务器环境与目录

已记录的环境如下，执行前请重新检查：

| 项目               | 路径或版本                                  |
| ------------------ | ------------------------------------------- |
| 操作系统           | Ubuntu 18.04 x86_64                         |
| Strata 仓库        | `/mnt/data/ProjectMoE/Strata`               |
| Strata 数据目录    | `/mnt/data/ProjectMoE/Strata-data`          |
| Strata Python 环境 | `/mnt/data/ProjectMoE/Strata/.venv`         |
| 独立 GCC 环境      | `/mnt/data/ProjectMoE/gcc11-env`            |
| Micromamba         | `/mnt/data/ProjectMoE/tools/bin/micromamba` |
| Micromamba 根目录  | `/mnt/data/ProjectMoE/mamba-root`           |
| CUDA Toolkit       | `/usr/local/cuda-12.0.1`                    |
| CUDA 编译器        | `/usr/local/cuda-12.0.1/bin/nvcc`           |
| Python 版本记录    | 3.12.15                                     |
| GCC/G++ 版本记录   | 11.4.0                                      |
| 构建工具记录       | CMake 4.4.4、Ninja                          |

典型目录结构：

```text
/mnt/data/ProjectMoE/
├── Strata/
│   ├── .venv/                 # Strata 的 Python 依赖
│   ├── setup.py               # 安装/构建入口（需按当前版本确认）
│   └── build-cuda12/          # 若存在，为 CUDA 构建目录
├── Strata-data/
│   └── models/                # 模型数据
├── gcc11-env/                 # 独立 GCC 11 工具链
├── mamba-root/                # Micromamba 环境管理目录
└── tools/bin/micromamba
```

## 3. 第一步：检查项目与基础环境

### 3.1 登录并进入 Strata 仓库

```bash
ssh usr@你的服务器地址
cd /mnt/data/ProjectMoE/Strata
pwd
ls -la
```

### 3.2 检查 Python 虚拟环境

```bash
cd /mnt/data/ProjectMoE/Strata

test -x .venv/bin/python && .venv/bin/python --version
.venv/bin/python -m pip --version
.venv/bin/python -c 'import sys; print(sys.executable); print(sys.prefix)'
```

确认解释器指向 `/mnt/data/ProjectMoE/Strata/.venv`，而不是系统 Python 或 Maya 的 `.venv`。

安装 Python 包时，优先使用项目自己的解释器：

```bash
/mnt/data/ProjectMoE/Strata/.venv/bin/python -m pip install 包名
```

不要把 Strata 的 Python 依赖安装到 `gcc11-env`，也不要把 Maya 和 Strata 的 Python 虚拟环境混用。

### 3.3 检查 Micromamba 与 GCC 11

```bash
export MAMBA_EXE="/mnt/data/ProjectMoE/tools/bin/micromamba"
export MAMBA_ROOT_PREFIX="/mnt/data/ProjectMoE/mamba-root"
export ENV_PREFIX="/mnt/data/ProjectMoE/gcc11-env"

test -x "$MAMBA_EXE" && echo "Micromamba OK"
test -d "$ENV_PREFIX" && echo "GCC 11 environment OK"

"$MAMBA_EXE" run -p "$ENV_PREFIX" gcc --version
"$MAMBA_EXE" run -p "$ENV_PREFIX" g++ --version
"$MAMBA_EXE" run -p "$ENV_PREFIX" cmake --version
"$MAMBA_EXE" run -p "$ENV_PREFIX" ninja --version
```

此前构建流程使用的编译器路径为：

```bash
/mnt/data/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc
/mnt/data/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++
```

检查实际文件：

```bash
test -x "$ENV_PREFIX/bin/x86_64-conda-linux-gnu-gcc" && echo "GCC wrapper OK"
test -x "$ENV_PREFIX/bin/x86_64-conda-linux-gnu-g++" && echo "G++ wrapper OK"
```

如果文件不存在，先查看 `$ENV_PREFIX/bin` 中的实际文件名，不要直接假定路径正确。

### 3.4 检查 CUDA、驱动和 GPU 负载

```bash
export CUDA_HOME="/usr/local/cuda-12.0.1"
test -x "$CUDA_HOME/bin/nvcc" && echo "CUDA nvcc OK"
"$CUDA_HOME/bin/nvcc" --version
nvidia-smi
```

`nvcc --version` 检查的是 CUDA Toolkit 编译器；`nvidia-smi` 检查驱动、GPU 和资源占用。二者不能互相替代。

在编译、下载大型模型或启动推理前，重新检查显存和进程。此前服务器曾有 `./demo` 进程占用多张 GPU；不要为了部署 Strata 擅自终止其他任务。

## 4. 第二步：为 Strata 设置隔离工具链

在当前 shell 中执行以下命令：

```bash
cd /mnt/data/ProjectMoE/Strata

export MAMBA_EXE="/mnt/data/ProjectMoE/tools/bin/micromamba"
export MAMBA_ROOT_PREFIX="/mnt/data/ProjectMoE/mamba-root"
export ENV_PREFIX="/mnt/data/ProjectMoE/gcc11-env"
export CUDA_HOME="/usr/local/cuda-12.0.1"

export CC="$ENV_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
export CXX="$ENV_PREFIX/bin/x86_64-conda-linux-gnu-g++"
export CUDAHOSTCXX="$CXX"
export STRATA_NVCC="$CUDA_HOME/bin/nvcc"
export STRATA_CUDA=12
export PATH="$ENV_PREFIX/bin:$CUDA_HOME/bin:$PATH"
```

验证当前选择：

```bash
printf 'CC=%s\nCXX=%s\nCUDAHOSTCXX=%s\nCUDA_HOME=%s\nSTRATA_NVCC=%s\n' \
  "$CC" "$CXX" "$CUDAHOSTCXX" "$CUDA_HOME" "$STRATA_NVCC"

"$CC" --version | head -n 1
"$CXX" --version | head -n 1
"$CUDA_HOME/bin/nvcc" --version
```

这些环境变量应在构建命令所在的同一个 shell 中设置，或写入你自己的构建脚本。`STRATA_NVCC` 和 `STRATA_CUDA` 是项目侧变量，只有 Strata 的脚本读取它们时才会生效。已有 CMake 缓存也可能保留旧编译器路径，因此还要检查构建缓存。

## 5. 第三步：查看当前版本支持的安装参数

先确认仓库当前版本实际支持的参数：

```bash
cd /mnt/data/ProjectMoE/Strata
.venv/bin/python setup.py --help
```

若当前仓库使用不同的入口或参数，应以仓库 README、脚本帮助和当前版本代码为准，不要直接照搬旧命令。

历史构建命令曾使用以下参数组合：

- `--setup`：执行项目配置流程。
- `--source modelscope`：选择脚本支持的 ModelScope 来源。
- `--family unsloth`：指定模型系列。
- `--gguf-dir`：指定模型文件目录。
- `--cuda 12`：指定 CUDA 主版本。
- `--build`：执行构建。
- `--no-start`：构建后不自动启动服务。

参数名称和语义可能随版本变化；运行前必须确认 `setup.py --help` 仍列出这些选项。

## 6. 第四步：准备模型目录与模型文件

### 6.1 模型文件与推理程序分开管理

建议将仓库和模型数据分开：

- 程序代码：`/mnt/data/ProjectMoE/Strata`
- 模型数据：`/mnt/data/ProjectMoE/Strata-data/models/`

这样更新或重新构建程序时，不必把模型文件放进源码仓库。模型下载前应核对模型名称、量化版本、分片数量、总磁盘空间和显存需求。

### 6.2 检查已有模型文件

```bash
find /mnt/data/ProjectMoE/Strata-data/models -maxdepth 3 -type f \
  \( -name '*.gguf' -o -name '*.safetensors' \) -printf '%p\n' 2>/dev/null
```

如果模型是多分片 GGUF，检查所有分片是否齐全，文件名和分片序号是否连续。目录存在不等于模型文件完整，也不保证模型格式与当前 Strata 版本兼容。

### 6.3 历史命令示例：ModelScope + UD-Q4_K_XL

此前记录过的构建命令结构如下。它是**历史配置示例**，执行前请先运行 `setup.py --help` 核对当前参数，并确认模型路径真实存在：

```bash
ROOT="/mnt/data/ProjectMoE/Strata"
ENV_PREFIX="/mnt/data/ProjectMoE/gcc11-env"
CUDA_HOME="/usr/local/cuda-12.0.1"

export CC="$ENV_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
export CXX="$ENV_PREFIX/bin/x86_64-conda-linux-gnu-g++"
export CUDAHOSTCXX="$CXX"
export STRATA_NVCC="$CUDA_HOME/bin/nvcc"
export STRATA_CUDA=12
export CUDA_HOME
export PATH="$ENV_PREFIX/bin:$CUDA_HOME/bin:$PATH"

"/mnt/data/ProjectMoE/tools/bin/micromamba" run -p "$ENV_PREFIX" \
  "$ROOT/.venv/bin/python" "$ROOT/setup.py" \
  --setup \
  --source modelscope \
  --family unsloth \
  --gguf-dir "/mnt/data/ProjectMoE/Strata-data/models/unsloth-UD-Q4_K_XL/" \
  --cuda 12 \
  --build \
  --no-start
```

该命令中的 `--gguf-dir` 必须改成模型实际所在的目录。`--source modelscope` 只在当前脚本支持此参数且下载流程确实使用该来源时才有效；它不等于所有依赖都从国内源下载。若模型已下载完成，确认当前版本是否允许跳过下载步骤，再决定是否执行完整 setup。

## 7. 第五步：检查构建结果与 CMake 缓存

### 7.1 检查构建目录中的编译器路径

```bash
grep -E '^(CMAKE_C_COMPILER|CMAKE_CXX_COMPILER|CMAKE_CUDA_COMPILER|CMAKE_CUDA_HOST_COMPILER):' \
  /mnt/data/ProjectMoE/Strata/build-cuda12/CMakeCache.txt 2>/dev/null
```

检查输出是否指向预期 GCC 11 工具链和 CUDA Toolkit。如果构建目录不存在，说明尚未生成该缓存，不能把“没有输出”当成成功。

### 7.2 为什么设置了 GCC 11 仍可能使用系统 GCC

CMake 首次配置时可能将编译器路径写入 `CMakeCache.txt`。如果之前配置时用的是 `/usr/bin/g++`，后续仅设置 `CXX` 不一定会覆盖已有缓存。

发现旧路径时：

1. 备份对应的 Strata 构建目录或缓存文件。
2. 检查当前版本构建脚本支持的重建选项。
3. 只清理或重新配置 Strata 自己的构建目录。
4. 重新构建后再次检查缓存。
5. 确认工具链选择正确后，再启动服务。

不要未经确认删除整个仓库、模型数据目录或其他项目的构建目录。

## 8. 第六步：本机启动与 API 验证

此前部署上下文中，Strata 已经完成过模型部署，并有在本机回环地址运行的记录。若当前仍是这种状态，先在服务器本机验证，不要直接开放网络端口。

### 8.1 检查 Strata 当前运行状态

```bash
nvidia-smi
ps -ef | grep -E '[S]trata|[s]etup.py|[l]lama|[s]erver'
ss -lntp
```

根据实际进程和监听端口判断服务是否已经运行。不要仅凭进程名称猜测 API 端点。

### 8.2 检查当前版本启动参数

查看仓库提供的启动脚本和帮助信息：

```bash
cd /mnt/data/ProjectMoE/Strata
ls -la
```

对实际使用的入口脚本运行其帮助命令。此前的部署讨论提到过 `START-HERE.bat --setup --host 0.0.0.0 --api-key <secret>` 这一类 Windows 启动说明；但在 Ubuntu 服务器上不能假设 `.bat` 文件可以原生执行，也不能直接将 Windows 示例命令当作 Linux 命令。应先确认仓库是否提供 Linux 对应脚本，以及当前版本支持的 `--host`、`--port`、`--api-key` 等参数。

### 8.3 先验证本机回环

如果通过 `ss -lntp` 确认服务监听在某个端口，例如 `8080`，可先按当前 API 文档提供的路径进行本机测试：

```bash
curl -i http://127.0.0.1:端口/实际API路径
```

将 `端口` 和 `/实际API路径` 替换成当前配置。根路径返回 `404` 并不必然意味着服务未运行；应使用该版本文档规定的健康检查或 API 路径。需要认证的接口应按当前版本要求传递 API Key。

## 9. 第七步：开放局域网访问

### 9.1 原理

- `127.0.0.1`：只接受本机回环访问。
- `0.0.0.0`：监听所有 IPv4 网络接口，使其他设备有机会访问。
- 客户端应连接服务器的实际局域网 IP，而不是连接 `0.0.0.0`。

**不要在尚未确认认证机制有效时就开放服务。** 先准备强随机 API Key，再按当前 Strata 版本支持的参数或配置文件设置监听地址和密钥。

### 9.2 确认启动入口支持的参数

先在 Linux 服务器上检查实际启动脚本的帮助。只有帮助信息明确支持时，才使用相应参数，例如：

```text
--host 0.0.0.0
--port 8080
--api-key 你的强随机密钥
```

这只是常见参数形式的示意，不是可直接执行的完整命令。必须将它们加到当前版本真实的 Linux 启动入口上；若版本通过配置文件或环境变量设置服务，则按项目文档配置。

### 9.3 检查监听状态

服务启动后：

```bash
ss -lntp | grep ':8080'
```

如果服务使用其他端口，应替换 `8080`。若只显示 `127.0.0.1:端口`，说明仍然只监听本机；若显示 `0.0.0.0:端口`，则已监听所有 IPv4 接口。

### 9.4 获取服务器局域网 IP

```bash
hostname -I
```

从输出中选择与客户端电脑处于同一网络的地址。在另一台电脑上使用：

```text
http://服务器局域网IP:端口
```

例如 `http://192.168.1.20:8080` 仅为格式示例，不能直接假定它是你的服务器地址。

### 9.5 网络访问失败时的排查顺序

1. 在服务器上用 `ss -lntp` 确认端口正在监听。
2. 查看 Strata 日志，确认进程没有启动后退出。
3. 确认客户端使用真实局域网 IP，而不是 `127.0.0.1` 或 `0.0.0.0`。
4. 检查 Ubuntu 防火墙、上游防火墙、路由器 ACL、VLAN 或无线客户端隔离。
5. 检查客户端的 API 路径、请求格式与认证头是否符合当前版本要求。
6. 不要为了排障直接关闭全部防火墙，也不要将未受保护的推理 API 暴露到公网。

## 10. Strata 常见问题

### Python 依赖报错

确认使用 `/mnt/data/ProjectMoE/Strata/.venv/bin/python`，不要混用系统 Python 或 Maya 的 `.venv`。根据错误定位缺失包或版本冲突，再在 Strata 的虚拟环境内处理。

### 构建仍使用系统 GCC

检查 `CC`、`CXX`、`CUDAHOSTCXX` 的值，并检查 `build-cuda12/CMakeCache.txt`。已有缓存可能保存旧编译器路径。

### CUDA 编译失败

确认 `nvcc` 来自 `/usr/local/cuda-12.0.1/bin/nvcc`，确认主机编译器路径存在，并依据完整报错判断是编译器兼容性、CUDA 代码架构、系统库还是驱动问题。不要直接升级驱动作为第一步。

### 模型目录错误或模型不完整

确认 `--gguf-dir` 指向实际模型目录，所有模型分片都已下载，且当前 Strata 版本支持相应模型和量化格式。不要仅根据目录名称判断模型已准备好。

### GPU 显存不足或推理速度异常

先执行 `nvidia-smi`，检查其他任务占用。模型量化、上下文长度、并发数、GPU 分配方式都会影响显存与速度。不要未经确认终止已有 GPU 任务。

### 服务只能本机访问

确认启动配置是否设置了 `0.0.0.0`，再用 `ss -lntp` 检查。随后检查防火墙、局域网路由和认证设置。

## 11. Strata 部署验收清单

- [ ] `Strata/.venv/bin/python` 存在且版本符合预期。
- [ ] 独立 GCC/G++ 11 工具链可执行。
- [ ] CUDA `nvcc` 路径和版本符合预期。
- [ ] `setup.py --help` 或当前入口帮助已核对。
- [ ] 模型目录存在，所需文件与分片完整。
- [ ] 构建日志和 CMake 缓存显示使用预期编译器。
- [ ] 模型能在本机成功加载并完成一次 API 请求。
- [ ] 如需局域网访问，监听地址和端口正确。
- [ ] API Key 认证已验证。
- [ ] 只向可信网络开放服务，没有无保护地暴露公网。

# 第四部分：两个项目共存时的维护原则

## 1. 保持项目环境隔离

- Maya Python：`/mnt/data/ProjectMoE/project-maya/.venv`
- Strata Python：`/mnt/data/ProjectMoE/Strata/.venv`
- 共享编译工具链：`/mnt/data/ProjectMoE/gcc11-env`
- CUDA Toolkit：`/usr/local/cuda-12.0.1`

共享编译工具链不代表共享 Python 依赖或构建缓存。每个项目的构建日志、CMake 缓存、模型目录和启动配置都应单独管理。

## 2. 不要默认两个服务使用同一端口

本指南中 Maya 的目标端口是 `8080`。Strata 的实际端口应以当前启动配置为准。如果两个服务同时运行，必须为它们分配不同端口，或者确认它们不会同时监听同一地址和端口。

可用以下命令查看监听情况：

```bash
ss -lntp
```

若端口已被占用，不要直接杀死未知进程；先用 `ss`、`ps` 和服务日志确认其归属。

## 3. 日志、密钥和模型数据

- 安装日志中可能出现路径、配置或错误信息；分享日志前先检查并移除 API Key、访问令牌和其他秘密。
- API Key 不应提交到 Git，也不应写入公开文档。
- 模型文件通常体积很大，更新代码前先确认模型目录与仓库目录分离。
- 不要把 `0.0.0.0` 当作客户端地址；客户端应使用服务器的实际局域网 IP。
- 如果服务不需要被其他电脑访问，优先保持 `127.0.0.1` 监听。

# 第五部分：统一部署验收清单

## Project Maya

- [ ] `maya.sh --help` 可运行，参数与当前版本一致。
- [ ] `build-maya-gcc11.sh --check` 通过。
- [ ] 构建日志确认使用预期的 GCC 11 和 CUDA Toolkit。
- [ ] GGUF 目录和模型文件符合当前 Maya 版本要求。
- [ ] 服务实际运行，监听地址与端口符合预期。
- [ ] API Key 认证和局域网请求经过实测。

## Strata

- [ ] Strata 自己的 `.venv` 可运行。
- [ ] GCC/G++ 11 和 CUDA 12.0.1 路径已确认。
- [ ] 当前 `setup.py` 或启动入口的帮助信息已核对。
- [ ] 模型目录存在，所需文件及分片完整。
- [ ] 构建缓存没有错误地引用系统 GCC。
- [ ] 本机 API 请求成功。
- [ ] 如需远程访问，监听地址、端口和 API Key 已验证。

## 服务器安全与资源

- [ ] 执行重型任务前已检查 `nvidia-smi`，没有误伤已有 GPU 任务。
- [ ] 两个服务没有发生端口冲突。
- [ ] API 只向可信网络开放。
- [ ] 防火墙规则遵循最小开放原则。
- [ ] 没有修改系统默认编译器、CUDA 软链接或驱动来绕过单个项目问题。

---

**维护建议：** 每次更新 Strata 或 Maya 仓库后，先重新检查帮助信息和版本，再运行环境检查；不要默认旧版命令仍适用于新版本。遇到错误时，先保留完整日志并确认报错属于 Python 依赖、C/C++ 编译、CUDA、模型文件、GPU 资源还是网络/认证层，再针对对应层级处理。
