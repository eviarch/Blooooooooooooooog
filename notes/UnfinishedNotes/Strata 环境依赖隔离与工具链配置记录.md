# Strata 环境依赖隔离与工具链配置记录

## 1. 目的与总体方案

在 Ubuntu 18.04 服务器上部署和编译 Strata 时，系统自带的编译器与项目所需的 GCC、CUDA 版本可能不一致。为避免直接升级系统组件或影响其他项目，采用以下隔离方案：

1. **Python 环境独立管理**：使用 Strata 自己的 Python 虚拟环境 `.venv` 管理 Python 包。
2. **C++ 编译环境独立管理**：使用 Micromamba 创建独立的 GCC 11 工具链环境，提供 GCC、G++ 及构建工具。
3. **CUDA Toolkit 显式指定**：使用服务器上已有的 CUDA 12.0.1。
4. **构建时显式选择工具链**：通过环境变量和项目构建参数指定编译器，避免自动使用系统默认版本。
5. **不修改系统级配置**：不替换系统默认 GCC，不修改 `/usr/local/cuda` 软链接，也不随意升级 NVIDIA 驱动。

需要注意：这套方案隔离的是项目依赖和编译工具链，并不能完全隔离 Linux 内核、glibc、系统头文件或 NVIDIA 驱动。

## 2. 服务器环境与目录结构

| 项目                   | 路径或版本                                   |
| ---------------------- | -------------------------------------------- |
| 操作系统               | Ubuntu 18.04 x86_64                          |
| Strata 仓库            | `/mnt/data1/ProjectMoE/Strata`               |
| Strata 数据目录        | `/mnt/data1/ProjectMoE/Strata-data`          |
| Strata Python 虚拟环境 | `/mnt/data1/ProjectMoE/Strata/.venv`         |
| 独立 GCC 编译环境      | `/mnt/data1/ProjectMoE/gcc11-env`            |
| Micromamba 可执行文件  | `/mnt/data1/ProjectMoE/tools/bin/micromamba` |
| Micromamba 根目录      | `/mnt/data1/ProjectMoE/mamba-root`           |
| CUDA Toolkit           | `/usr/local/cuda-12.0.1`                     |
| CUDA 编译器            | `/usr/local/cuda-12.0.1/bin/nvcc`            |
| Python 版本记录        | Python 3.12.15                               |
| GCC/G++ 版本记录       | GCC/G++ 11.4.0                               |
| 构建工具记录           | CMake 4.4.4、Ninja                           |

以上是此前安装过程中的记录，实际操作前应重新检查路径和版本。

整体目录关系如下：

```
/mnt/data1/ProjectMoE/
├── Strata/
│   ├── .venv/                 # Python 依赖环境
│   ├── setup.py               # 项目安装与构建入口
│   └── build-cuda12/          # CUDA 12 构建目录（如已生成）
├── Strata-data/
│   └── models/                # 模型数据
├── gcc11-env/                 # 独立 GCC 11 编译环境
├── mamba-root/                # Micromamba 环境管理目录
└── tools/
    └── bin/micromamba
```

## 3. Python 环境：独立管理运行依赖

### 3.1 环境设计

Strata 的 Python 环境位于：

```
/mnt/data1/ProjectMoE/Strata/.venv
```

这个环境主要负责：

- Python 解释器及项目运行所需的 Python 包。
- Strata 安装脚本及 Python 侧的依赖管理。
- 避免项目 Python 包与系统 Python 包相互污染。

它与 `gcc11-env` 是两个独立环境。即使 C++ 编译器由 Micromamba 提供，执行 Strata 的 Python 入口仍然可以使用 `.venv/bin/python`。

### 3.2 检查 Python 环境

```
cd /mnt/data1/ProjectMoE/Strata

test -x .venv/bin/python && .venv/bin/python --version
.venv/bin/python -m pip --version
.venv/bin/python -m pip list

.venv/bin/python -c \
'import sys; print(sys.executable); print(sys.prefix)'
```

应确认 Python 解释器指向 Strata 的 `.venv`，而不是系统 Python 或其他项目的虚拟环境。

### 3.3 Python 包管理原则

安装或更新 Strata 的 Python 包时，优先使用：

```
/mnt/data1/ProjectMoE/Strata/.venv/bin/python -m pip install 包名
```

应遵守以下原则：

- 不因为系统 GCC 版本旧，就直接升级系统 Python。
- 不把 Strata 的 Python 依赖全部安装到 `gcc11-env`。
- 不将系统 Python 与项目虚拟环境混用。
- Python 包版本冲突应在 Python 环境内排查。
- 如果使用 pip 镜像，应确认镜像中的包版本和依赖可用性。

此前的构建脚本使用过阿里云 PyPI 镜像，但这属于安装源配置，不是编译器隔离的必要条件。

### 3.4 Python 环境的边界

Python 虚拟环境只能隔离 Python 层的依赖，不能解决：

- 系统 glibc 版本不兼容。
- Linux 内核或系统库问题。
- NVIDIA 驱动无法加载。
- C++ 编译器与 CUDA Toolkit 不兼容。

这些问题应分别从系统、编译工具链和驱动层进行排查。

## 4. C++ 编译环境：独立 GCC 11 与 CUDA 12

### 4.1 为什么需要独立编译环境

服务器系统较旧，部分项目所需的 C++ 标准、编译器功能或 CUDA host compiler 版本可能超出系统默认工具链的能力。

因此，使用 Micromamba 在独立目录中建立 GCC 11 环境：

```
/mnt/data1/ProjectMoE/gcc11-env
```

此前记录的环境包括：

- GCC/G++ 11.4.0。
- CMake 4.4.4。
- Ninja。
- C++20 编译测试通过。

CUDA Toolkit 则使用：

```
/usr/local/cuda-12.0.1
```

这种方案可以避免为了一个项目而全局替换系统 GCC，但仍然依赖宿主机提供的系统库、内核和 NVIDIA 驱动。

### 4.2 Micromamba 路径配置

```
export MAMBA_EXE="/mnt/data1/ProjectMoE/tools/bin/micromamba"
export MAMBA_ROOT_PREFIX="/mnt/data1/ProjectMoE/mamba-root"
export ENV_PREFIX="/mnt/data1/ProjectMoE/gcc11-env"
```

检查工具是否存在：

```
test -x "$MAMBA_EXE" && echo "Micromamba OK"
test -d "$ENV_PREFIX" && echo "GCC 11 environment OK"

"$MAMBA_EXE" run -p "$ENV_PREFIX" gcc --version
"$MAMBA_EXE" run -p "$ENV_PREFIX" g++ --version
"$MAMBA_EXE" run -p "$ENV_PREFIX" cmake --version
"$MAMBA_EXE" run -p "$ENV_PREFIX" ninja --version
```

此前构建脚本使用的编译器路径是：

```
/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc
/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++
```

检查这两个文件：

```
test -x "$ENV_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
test -x "$ENV_PREFIX/bin/x86_64-conda-linux-gnu-g++"
```

如果文件不存在，应先检查环境内的实际可执行文件名称，不要直接假定路径正确。

### 4.3 CUDA Toolkit 配置

```
export CUDA_HOME="/usr/local/cuda-12.0.1"

test -x "$CUDA_HOME/bin/nvcc" && echo "CUDA nvcc OK"
"$CUDA_HOME/bin/nvcc" --version
```

后续构建时显式指定：

```
/usr/local/cuda-12.0.1/bin/nvcc
```

这样可以避免构建脚本误选其他 CUDA 版本。

需要区分：

- `nvcc --version`：检查 CUDA 编译器版本。
- `nvidia-smi`：检查 NVIDIA 驱动和 GPU 状态。

两者检查的是不同层面，不能相互替代。

### 4.4 显式设置编译器环境变量

此前 Strata 构建脚本使用以下配置：

```
export CC="/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc"

export CXX="/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++"

export CUDAHOSTCXX="$CXX"

export STRATA_NVCC="/usr/local/cuda-12.0.1/bin/nvcc"

export STRATA_CUDA=12

export CUDA_HOME="/usr/local/cuda-12.0.1"

export PATH="/mnt/data1/ProjectMoE/gcc11-env/bin:/usr/local/cuda-12.0.1/bin:$PATH"
```

各变量用途：

| 变量          | 作用                                            |
| ------------- | ----------------------------------------------- |
| `CC`          | 指定 C 编译器                                   |
| `CXX`         | 指定 C++ 编译器                                 |
| `CUDAHOSTCXX` | 向支持该变量的构建系统指定 CUDA host C++ 编译器 |
| `CUDA_HOME`   | 指定 CUDA Toolkit 根目录                        |
| `STRATA_NVCC` | Strata 构建脚本使用的 CUDA 编译器路径变量       |
| `STRATA_CUDA` | 向 Strata 构建流程提供 CUDA 主版本信息          |
| `PATH`        | 调整命令搜索顺序，优先找到指定工具              |

注意：`STRATA_NVCC` 和 `STRATA_CUDA` 是项目侧使用的变量，只有构建脚本读取它们时才会产生作用。对于 CMake 已经生成的构建缓存，仅设置环境变量也不一定能替换原来的编译器路径。

验证当前选择：

```
printf 'CC=%s\nCXX=%s\nCUDAHOSTCXX=%s\nCUDA_HOME=%s\n' \
  "$CC" "$CXX" "$CUDAHOSTCXX" "$CUDA_HOME"

"$CC" --version | head -n 1
"$CXX" --version | head -n 1
"$CUDA_HOME/bin/nvcc" --version
```

## 5. 如何让 Python 环境和 C++ 环境协同工作

核心做法是：

**使用 Micromamba 的 GCC 11 环境提供编译工具，同时使用 Strata** `**.venv**` **中的 Python 执行** `**setup.py**`**。**

此前构建脚本采用的命令结构如下：

```
ROOT="/mnt/data1/ProjectMoE/Strata"
MAMBA_EXE="/mnt/data1/ProjectMoE/tools/bin/micromamba"
MAMBA_ROOT_PREFIX="/mnt/data1/ProjectMoE/mamba-root"
ENV_PREFIX="/mnt/data1/ProjectMoE/gcc11-env"
CUDA_HOME="/usr/local/cuda-12.0.1"

export CC="$ENV_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
export CXX="$ENV_PREFIX/bin/x86_64-conda-linux-gnu-g++"
export CUDAHOSTCXX="$CXX"
export STRATA_NVCC="$CUDA_HOME/bin/nvcc"
export STRATA_CUDA=12
export CUDA_HOME
export PATH="$ENV_PREFIX/bin:$CUDA_HOME/bin:$PATH"

"$MAMBA_EXE" run -p "$ENV_PREFIX" \
  "$ROOT/.venv/bin/python" "$ROOT/setup.py" \
  --setup \
  --source modelscope \
  --family unsloth \
  --gguf-dir /mnt/data1/ProjectMoE/Strata-data/models/unsloth-UD-Q4_K_XL/ \
  --cuda 12 \
  --build \
  --no-start
```

这是此前构建脚本使用过的命令结构示例。重新执行前，应先确认当前版本 `setup.py --help` 中的参数仍然有效，并根据实际目标调整模型类型和模型目录。

参数含义：

- `--setup`：执行项目配置流程。
- `--source modelscope`：指定脚本支持的模型来源。
- `--family unsloth`：指定模型系列。
- `--gguf-dir`：指定模型文件目录。
- `--cuda 12`：指定 CUDA 主版本。
- `--build`：执行构建。
- `--no-start`：构建后不自动启动服务。

如果只是检查工具链是否正确，不必直接重新下载模型或运行完整构建流程。

## 6. CMake 缓存与旧编译器问题

### 6.1 为什么设置了 GCC 11 仍可能使用系统 GCC

CMake 在首次配置时可能将编译器路径写入 `CMakeCache.txt`。

如果之前配置时使用的是 `/usr/bin/g++`，之后即使设置了 `CXX`，已有构建目录也可能继续使用缓存中的系统编译器。

### 6.2 检查 Strata 的构建缓存

```
grep -E '^(CMAKE_C_COMPILER|CMAKE_CXX_COMPILER|CMAKE_CUDA_COMPILER|CMAKE_CUDA_HOST_COMPILER):' \
  /mnt/data1/ProjectMoE/Strata/build-cuda12/CMakeCache.txt \
  2>/dev/null
```

检查输出是否指向预期的 GCC 11 工具链和 CUDA 12.0.1。

### 6.3 发现旧路径后的处理方式

1. 备份对应构建目录或缓存文件。
2. 检查当前 Strata 版本的构建脚本和重建参数。
3. 只清理或重新配置 Strata 对应的构建目录。
4. 重新构建后再次检查 `CMakeCache.txt`。
5. 确认编译器路径正确后，再继续启动服务。

不要未经确认就删除整个仓库、模型数据目录或其他项目的构建目录。

## 7. 明确避免的系统级修改

为降低对服务器和其他项目的影响，采用以下原则：

- 不使用 `update-alternatives` 全局切换系统默认 GCC。
- 不覆盖 `/usr/bin/gcc` 或 `/usr/bin/g++`。
- 不为了 Strata 修改 `/usr/local/cuda` 软链接。
- 不因单个项目的编译问题直接升级或替换 NVIDIA 驱动。
- 不把 Strata 的 Python `.venv` 与 GCC 11 环境混为一体。
- 不直接共享不同项目的 CMake 构建缓存。

如果仍然出现 glibc、系统头文件、内核模块或驱动接口相关错误，需要根据具体日志单独诊断。独立编译器环境不能自动消除这些问题。

## 8. 故障排查清单

### 8.1 Python 环境

```
/mnt/data1/ProjectMoE/Strata/.venv/bin/python --version

/mnt/data1/ProjectMoE/Strata/.venv/bin/python -m pip --version

/mnt/data1/ProjectMoE/Strata/.venv/bin/python -c \
'import sys; print(sys.executable); print(sys.prefix)'
```

重点检查：

- 是否使用 Strata 自己的 Python 解释器。
- 依赖是否安装在 `.venv`。
- 错误是否来自 Python 包缺失或版本冲突。

### 8.2 C++ 与 CUDA 工具链

```
/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc --version

/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++ --version

/usr/local/cuda-12.0.1/bin/nvcc --version
```

重点检查：

- 实际使用的 GCC/G++ 是否为预期版本。
- `nvcc` 是否来自 CUDA 12.0.1。
- CMake 是否缓存了旧编译器路径。
- CUDA 与 host compiler 的组合是否满足当前项目的要求。

### 8.3 GPU 与驱动

```
nvidia-smi
```

如果错误涉及驱动加载、GPU 初始化或内核模块，应单独检查驱动层，而不是直接归因于 Python 环境。

## 9. 总结

| 层次     | 采用的方案                   | 主要作用                   |
| -------- | ---------------------------- | -------------------------- |
| Python   | Strata 自己的 `.venv`        | 隔离 Python 包和运行依赖   |
| C/C++    | Micromamba 的 `gcc11-env`    | 避免依赖系统默认 GCC       |
| CUDA     | 显式使用 CUDA 12.0.1         | 避免误选其他 CUDA 编译器   |
| 构建配置 | 环境变量与 CMake 缓存检查    | 确保编译过程选择正确工具链 |
| 系统环境 | 不修改全局编译器和 CUDA 配置 | 降低对其他项目的影响       |

**核心结论：** Strata 的 Python 依赖由 `.venv` 独立管理，C++ 编译由独立 GCC 11 工具链负责，CUDA 使用明确指定的 12.0.1 版本。构建时通过环境变量、显式路径和 CMake 缓存检查将两者连接起来，从而减少旧版系统默认工具链带来的兼容性问题。