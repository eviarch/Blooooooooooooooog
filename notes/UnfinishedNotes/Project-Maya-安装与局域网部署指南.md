# Project Maya 安装与局域网服务部署指南（Ubuntu）

> 适用环境：当前服务器上的 Project Maya 项目目录为
> `/mnt/data1/ProjectMoE/project-maya`，独立 GCC 11 环境为
> `/mnt/data1/ProjectMoE/gcc11-env`，CUDA Toolkit 为
> `/usr/local/cuda-12.0.1`。本指南以现有环境为基础，说明工具链原理、检查步骤、安装/构建、API
> Key、GGUF 目录和局域网访问。
>
> **重要：**
> 本文中的路径和硬件信息来自当前部署上下文。执行前请核对实际路径。安装脚本已做
> Bash 语法检查，但完整安装与服务启动仍需在服务器上实测；Maya
> 版本不同，参数行为也可能不同。

## 1. 当前环境与目标

已知环境：

-   操作系统：Ubuntu 18.04
-   GPU：8 × NVIDIA RTX 4090，每张 24 GB 显存
-   NVIDIA 驱动：530.41.03
-   CUDA Toolkit：12.0.1，`nvcc` 位于 `/usr/local/cuda-12.0.1/bin/nvcc`
-   独立 GCC/G++：11.4.0，位于 `/mnt/data1/ProjectMoE/gcc11-env/bin/`
-   Maya 项目：`/mnt/data1/ProjectMoE/project-maya`
-   Maya Python 虚拟环境：`/mnt/data1/ProjectMoE/project-maya/.venv`
-   计划服务地址：`0.0.0.0:8080`

目标是：使用独立 GCC 11 和指定 CUDA Toolkit 检查并构建
Maya，按需选择模型与 GGUF 目录，并使用 API Key 在局域网内访问服务。

## 2. 安装原理

### 2.1 为什么使用独立 GCC 11

Ubuntu 18.04 自带的系统编译器可能较旧。此前 Maya 的检查结果显示系统
`g++` 为 7.5.0，而独立环境中已有 GCC/G++ 11.4.0。

脚本通过环境变量将编译器明确指向独立环境：

-   `CC`：C 编译器
-   `CXX`：C++ 编译器
-   `CUDAHOSTCXX`：CUDA 编译时使用的主机 C++ 编译器

这样做的目的是让构建系统优先使用 GCC 11，而不是系统
`g++`。它不会修改系统默认编译器，也不会通过 `update-alternatives`
更改全局配置。

### 2.2 CUDA Toolkit、驱动和 GPU 架构的区别

-   **NVIDIA 驱动**负责让操作系统与 GPU 通信。
-   **CUDA Toolkit / `nvcc`**提供 CUDA 编译工具。
-   **GPU 架构参数**决定编译产物针对哪些 GPU 架构。RTX 4090 属于 `sm_89`
    架构。

脚本指定 `/usr/local/cuda-12.0.1/bin/nvcc`，并把 GCC 11 的 `g++` 传给
Maya 的 `--host-compiler` 参数。此前已经成功完成了最小 C++
编译/链接和一个 `sm_89` CUDA 文件编译；这只证明基本工具链可用，**不代表
Maya 的完整项目一定能构建成功**。

### 2.3 Python 虚拟环境的作用

Maya 的 Python 环境位于项目的 `.venv`。它将 Python 包与系统
Python、Strata 的环境隔离，降低依赖版本相互影响的风险。运行脚本时会把
`.venv/bin` 放入 `PATH`。

### 2.4 `--setup`、模型下载与服务启动

Maya 命令行帮助提供了
`--setup`、`--check`、`--download-model`、`--model`、`--gguf-dir`、`--host`、`--port`
和 `--api-key` 等参数。

-   `--check`：执行环境检查。
-   `--setup`：执行 Maya 的安装/构建配置流程。
-   `--download-model`：显式请求下载模型。
-   `--model`：选择 Maya 支持的模型标识。
-   `--gguf-dir`：指定 GGUF 模型目录。
-   `--host` / `--port`：指定监听地址和端口。
-   `--api-key`：配置 API 访问密钥。

本指南的包装脚本**不会默认添加
`--download-model`**。如需下载模型，必须明确传入该参数。模型文件来源、下载行为和所需磁盘空间应以当前
Maya 版本的帮助信息及项目文档为准。

### 2.5 `0.0.0.0` 的含义与安全性

-   `127.0.0.1`：通常只接受服务器本机的回环访问。
-   `0.0.0.0`：让服务监听所有 IPv4
    网络接口，局域网内其他设备才有机会连接。

`0.0.0.0` **不是客户端要访问的地址**。客户端应使用服务器的实际局域网
IP，例如 `http://192.168.1.20:8080`。启用网络监听后应设置强 API
Key，并只向可信网络开放端口；不要未经防火墙和访问控制就直接暴露到公网。

## 3. 安装前检查

### 第 1 步：登录服务器并进入项目目录

``` bash
ssh mim@你的服务器地址
cd /mnt/data1/ProjectMoE/project-maya
```

如果 `mim20` 已配置为 SSH 主机别名，也可以使用 `ssh mim20`。请根据自己的
SSH 配置替换示例。

### 第 2 步：确认项目和脚本存在

``` bash
pwd
ls -l ./maya.sh
./maya.sh --help
```

帮助信息应列出当前版本实际支持的参数。如果 `maya.sh`
不存在或帮助输出与本文不同，先检查仓库目录和版本，不要盲目继续。

### 第 3 步：确认 GCC 11 与 CUDA 路径

``` bash
/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc --version
/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++ --version
/usr/local/cuda-12.0.1/bin/nvcc --version
```

应能看到 GCC/G++ 11.4.0 和 CUDA
12.0。若路径不存在，先修复工具链路径；不要为此直接更改系统 GCC 或 CUDA
软链接。

### 第 4 步：检查 GPU 与当前占用

``` bash
nvidia-smi
```

确认 GPU 可见，并检查显存占用、GPU
利用率及运行中的进程。此前服务器上曾有 `./demo` 进程占用多张
GPU；运行重型构建或加载模型前务必重新检查。**不要为了安装 Maya
擅自终止其他用户或任务的 GPU 进程。**

### 第 5 步：检查 Maya 环境（推荐先做）

将 `build-maya-gcc11.sh` 放在 Maya 项目目录后：

``` bash
cd /mnt/data1/ProjectMoE/project-maya
chmod +x ./build-maya-gcc11.sh
./build-maya-gcc11.sh --check
```

包装脚本会使用指定的 GCC 11、CUDA `nvcc` 和主机编译器运行 Maya 的
`--check`。检查通过只代表前置环境检查通过，不等于安装已完成。

## 4. 安装脚本的准备与使用

### 第 1 步：把脚本放到服务器

如果脚本在本地电脑当前目录，可以从本地终端上传：

``` bash
scp build-maya-gcc11.sh mim@你的服务器地址:/mnt/data1/ProjectMoE/project-maya/
```

如果你配置了 `mim20` SSH 别名：

``` bash
scp build-maya-gcc11.sh mim20:/mnt/data1/ProjectMoE/project-maya/
```

然后在服务器上执行：

``` bash
cd /mnt/data1/ProjectMoE/project-maya
chmod +x build-maya-gcc11.sh
```

### 第 2 步：理解脚本默认配置

脚本默认配置如下：

  配置            默认值
  --------------- -------------------------------------------
  Maya 项目目录   `/mnt/data1/ProjectMoE/project-maya`
  GCC 环境        `/mnt/data1/ProjectMoE/gcc11-env`
  CUDA Toolkit    `/usr/local/cuda-12.0.1`
  GPU             `0,1,2,3,4,5,6,7`
  服务监听地址    `0.0.0.0`
  服务端口        `8080`
  日志目录        `/mnt/data1/ProjectMoE/project-maya/logs`
  Python 包索引   阿里云 PyPI 镜像（仅影响 pip 包安装）

脚本不会主动杀死 GPU
进程，不会更改系统编译器或驱动，也不会默认强制下载模型。

### 第 3 步：先查看帮助与检查环境

``` bash
./build-maya-gcc11.sh --help
./build-maya-gcc11.sh --check
```

`--help` 会转交给 Maya 自己的帮助命令。`--check`
只执行环境检查，不要求输入 API Key，也不启动服务。

### 第 4 步：启动安装流程

``` bash
./build-maya-gcc11.sh
```

正常安装运行时，脚本会提示输入 API Key 和可选 GGUF 目录。

-   **API Key**：输入时不回显；不能为空。
-   **GGUF 目录**：输入已存在的目录绝对路径。直接回车表示不传
    `--gguf-dir`，由 Maya 使用自身默认配置。
-   **模型下载**：默认不添加 `--download-model`。若需要下载，先确认当前
    Maya 版本支持的模型和下载方式，再显式添加对应参数。

脚本会将安装输出保存到
`logs/maya-setup-gcc11-时间戳.log`。如果命令失败，按终端提示查看最后 100
行日志：

``` bash
tail -n 100 /mnt/data1/ProjectMoE/project-maya/logs/你的日志文件名.log
```

**注意：** 当前包装脚本会把
`--setup`、`--host 0.0.0.0`、`--port 8080`、`--api-key` 及可选的
`--gguf-dir` 传给 `maya.sh`。Maya 的 `--setup`
在当前版本中是否会在同一流程里完成构建并启动服务，需要以实际日志和该版本文档为准。若它只完成安装而没有启动服务，不要直接假设服务已运行。

## 5. 如何选择 API Key 与 GGUF 目录

### 方式 A：交互式输入（推荐）

``` bash
./build-maya-gcc11.sh
```

按提示输入 API Key。然后输入 GGUF 模型目录；如果想使用 Maya
默认目录，直接按回车。

### 方式 B：使用环境变量

``` bash
export MAYA_API_KEY='替换为你自己生成的强随机密钥'
export MAYA_GGUF_DIR='/实际存在的/GGUF/目录'
export MAYA_HOST='0.0.0.0'
export MAYA_PORT='8080'

./build-maya-gcc11.sh
```

如果不想指定自定义 GGUF 目录，可以取消该变量：

``` bash
unset MAYA_GGUF_DIR
```

安全提示：环境变量可能被同一账户下的调试工具、进程信息或 shell
配置间接暴露。不要把真实密钥提交到
Git、写进公开脚本或粘贴到公开日志中。交互输入可避免终端回显，但仍应保护服务器账户和日志访问权限。

### 方式 C：指定模型（仅在确认需要时）

先检查支持的模型：

``` bash
./maya.sh --help
```

如果确认要使用某个支持的模型，例如帮助中列出的
`Maya-S-v2-IQ2_XXS`，可按该版本的参数规则显式指定：

``` bash
./build-maya-gcc11.sh --model Maya-S-v2-IQ2_XXS
```

只有明确希望触发下载时才添加 `--download-model`：

``` bash
./build-maya-gcc11.sh --model Maya-S-v2-IQ2_XXS --download-model
```

上面是参数使用示例，不代表已验证模型下载源、文件完整性、模型所需显存或当前服务器可用空间。下载前应先阅读该版本文档并检查磁盘与
GPU 资源。

## 6. 验证服务是否启动

### 第 1 步：检查监听端口

``` bash
ss -lntp | grep ':8080'
```

如果服务成功监听所有 IPv4 接口，通常会看到类似 `0.0.0.0:8080`
的监听项。若没有输出，服务可能没有启动、启动失败，或使用了其他端口；先查看
Maya 日志。

### 第 2 步：在服务器本机测试

``` bash
curl -i http://127.0.0.1:8080/
```

不同 Maya 版本的根路径可能不提供网页或健康检查端点，因此 `404`
并不必然代表服务进程没启动。应根据 Maya 文档找到正确的健康检查或 API
路径。对需要认证的 API 请求，应按该版本要求传递 API Key。

### 第 3 步：取得服务器局域网 IP

``` bash
hostname -I
```

从输出中选择与客户端电脑处于同一局域网的服务器地址。不要把 `0.0.0.0`
当成访问地址。

### 第 4 步：从另一台电脑访问

浏览器或客户端使用：

``` text
http://服务器局域网IP:8080
```

例如（仅为格式示例）：

``` text
http://192.168.1.20:8080
```

如果使用 API 客户端，请根据 Maya 当前版本的 API
文档配置认证头或参数。不要把 API Key 放进公开分享的 URL。

### 第 5 步：如果无法访问，按顺序排查

1.  在服务器执行 `ss -lntp | grep ':8080'`，确认端口确实在监听。
2.  查看 Maya 日志，确认服务没有在启动后退出。
3.  确认客户端使用的是服务器局域网 IP，而不是 `0.0.0.0` 或 `127.0.0.1`。
4.  检查 Ubuntu 防火墙、上游防火墙、路由器 ACL、VLAN 或无线客户端隔离。
5.  检查 Maya 是否要求特定 API 路径或认证头。
6.  不要为排障而直接关闭全部防火墙，也不要将服务无保护地暴露到公网。

## 7. 常见问题

### 问题：检查仍显示系统 `g++` 7.5

先通过包装脚本运行：

``` bash
./build-maya-gcc11.sh --check
```

查看 Maya 检查输出是否识别了 `--host-compiler` 指定的 GCC
11。构建系统可能缓存先前的编译器选择；若日志仍显示旧编译器，应先检查
Maya 构建目录和该版本的 CMake
配置方式，再决定是否清理或重建。不要直接删除未知目录。

### 问题：提示找不到 GCC、CUDA 或 Maya 脚本

逐项确认以下文件存在且可执行：

``` bash
ls -l /mnt/data1/ProjectMoE/project-maya/maya.sh
ls -l /mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc
ls -l /mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++
ls -l /usr/local/cuda-12.0.1/bin/nvcc
```

若项目实际安装在其他位置，可在脚本中修改默认路径，或设置相应环境变量
`MAYA_ROOT`、`MAYA_GCC_ENV`、`MAYA_CUDA_HOME`。

### 问题：GGUF 目录输入后报错

脚本会检查目录是否存在，但目录存在不代表其中的模型文件一定符合 Maya
的要求。确认文件格式、命名、分片完整性以及该 Maya 版本的目录约定。

### 问题：API Key 输入后仍然无法调用 API

API Key
必须与服务端实际配置一致。还要确认客户端采用的认证方式、请求路径和 API
格式符合当前 Maya 版本文档。不要把密钥贴进公共日志或问题帖。

### 问题：显存不足或服务启动很慢

先运行 `nvidia-smi` 检查其他进程、显存占用和 GPU 利用率。多 GPU
推理的显存分配、上下文长度、并发数和模型量化都会影响资源需求。不要未经确认就终止正在运行的任务。

## 8. 日常使用速查

``` bash
# 进入项目目录
cd /mnt/data1/ProjectMoE/project-maya

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
ls -lt /mnt/data1/ProjectMoE/project-maya/logs/
```

## 9. 部署完成的判断标准

逐项确认：

-   [ ] `./maya.sh --help` 能正常运行，参数与当前版本一致。
-   [ ] `./build-maya-gcc11.sh --check` 通过。
-   [ ] 日志表明构建过程使用了预期的 GCC 11 与 CUDA
    Toolkit，而不是意外回退到系统编译器。
-   [ ] 所需模型文件已准备好，且 GGUF 路径与 Maya 配置一致。
-   [ ] 服务进程实际运行，`ss` 能看到预期监听端口。
-   [ ] 本机请求可到达正确的 API 路径。
-   [ ] 另一台局域网电脑能够访问，并且 API Key 认证按预期生效。
-   [ ] 服务只开放给可信网络，日志和密钥受到保护。

完成这些检查后，才可以认为 Maya
已完成从工具链准备、构建、模型配置到局域网 API 访问的整套部署。
