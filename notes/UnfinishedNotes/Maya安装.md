# Maya安装

~~~ bash
export ROOT="/mnt/data1/ProjectMoE"
export STRATA_ROOT="$ROOT/Strata"
export MAYA_ROOT="$ROOT/project-maya"
export ENV_PREFIX="$ROOT/gcc11-env"
export CUDA_HOME="/usr/local/cuda-12.0.1"

export CC="$ENV_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
export CXX="$ENV_PREFIX/bin/x86_64-conda-linux-gnu-g++"

echo "===== GCC ====="
"$CC" --version | head -n 1
"$CXX" --version | head -n 1

echo "===== CUDA ====="
"$CUDA_HOME/bin/nvcc" --version

echo "===== NVIDIA Driver ====="
nvidia-smi

echo "===== Existing Strata Python ====="
"$STRATA_ROOT/.venv/bin/python" --version
~~~

~~~ bash
mim@mim20:/mnt/data1/ProjectMoE/project-maya$ BASE_PY="/home/mim/.local/share/uv/python/cpython-3.12.15-linux-x86_64-gnu/bin/python3.12"
mim@mim20:/mnt/data1/ProjectMoE/project-maya$ "$BASE_PY" --version
Python 3.12.15
mim@mim20:/mnt/data1/ProjectMoE/project-maya$ "$BASE_PY" -c '
> import sys, venv, ensurepip
> print("Python:", sys.version)
> print("venv: available")
> print("ensurepip: available")
> '
Python: 3.12.15 (main, Oct  9 2026, 15:22:32) [Clang 22.1.3 ]
venv: available
ensurepip: available
mim@mim20:/mnt/data1/ProjectMoE/project-maya$ "$BASE_PY" -m venv --help >/dev/null \
>   && echo "可以创建虚拟环境" \
>   || echo "暂时无法创建虚拟环境"
可以创建虚拟环境
mim@mim20:/mnt/data1/ProjectMoE/project-maya$
~~~

~~~ bash
cd /mnt/data1/ProjectMoE/project-maya

if [ -e .venv ]; then
    echo "Maya .venv 已存在，请勿覆盖"
    ls -ld .venv
else
    BASE_PY="/home/mim/.local/share/uv/python/cpython-3.12.15-linux-x86_64-gnu/bin/python3.12"
    "$BASE_PY" -m venv .venv
fi
~~~

环境验证：

~~~ bash
./.venv/bin/python --version
./.venv/bin/python -m pip --version

./.venv/bin/python -c '
import sys
print("executable:", sys.executable)
print("prefix:", sys.prefix)
print("base_prefix:", sys.base_prefix)
'
~~~

~~~ bash
cd /mnt/data1/ProjectMoE/project-maya

./maya.sh --help
~~~

确认编译工具和 GPU 状态：

~~~ bash
/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc --version

/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++ --version

/usr/local/cuda-12.0.1/bin/nvcc --version

nvidia-smi
~~~

做一次不下载模型、不占用 GPU 的编译测试：

它只会在 `/tmp` 创建临时测试文件，不会启动 Maya、下载模型或修改系统 CUDA/GCC 配置。

~~~ bash
cd /mnt/data1/ProjectMoE/project-maya

GCC11="/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-gcc"
GXX11="/mnt/data1/ProjectMoE/gcc11-env/bin/x86_64-conda-linux-gnu-g++"
NVCC="/usr/local/cuda-12.0.1/bin/nvcc"

# 1. 检查编译器版本
"$GCC11" --version | head -n 1
"$GXX11" --version | head -n 1

# 2. 检查普通 C++ 编译和链接
TMPDIR_MAYA=$(mktemp -d /tmp/maya-toolchain-test.XXXXXX)

cat > "$TMPDIR_MAYA/test.cpp" <<'EOF'
#include <iostream>
int main() {
    std::cout << "GCC 11 C++ compile and link: OK" << std::endl;
    return 0;
}
EOF

"$GXX11" "$TMPDIR_MAYA/test.cpp" -o "$TMPDIR_MAYA/test_cpp" &&
"$TMPDIR_MAYA/test_cpp"

# 3. 检查 CUDA 编译器能否调用 GCC 11
cat > "$TMPDIR_MAYA/test.cu" <<'EOF'
__global__ void test_kernel() {}
int main() { return 0; }
EOF

"$NVCC" \
  -ccbin "$GXX11" \
  -arch=sm_89 \
  -c "$TMPDIR_MAYA/test.cu" \
  -o "$TMPDIR_MAYA/test_cuda.o"

echo "测试文件目录：$TMPDIR_MAYA"
~~~

