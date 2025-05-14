#!/bin/bash
set -e


PYTHON_VERSION=3.5.2
PREFIX="$HOME/Wjw"
PYTHON_INSTALL="$PREFIX/python$PYTHON_VERSION"
WORKSPACE="/srv/scratch/PAG/Wjw/workspace"
VENV_DIR="$WORKSPACE/venv"
DEPS="$WORKSPACE/deps"
mkdir -p "$DEPS"

# === 1. 编译安装 Python 3.7 到本地路径 ===
cd "$DEPS"
if [ ! -d "Python-$PYTHON_VERSION" ]; then
    wget https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz
    tar -xzf Python-$PYTHON_VERSION.tgz
    rm Python-$PYTHON_VERSION.tgz
fi

cd Python-$PYTHON_VERSION
./configure --prefix="$PYTHON_INSTALL" --enable-optimizations
make -j$(nproc)
make install

# === 2. 使用 Python 3.7 创建虚拟环境 ===
"$PYTHON_INSTALL/bin/python3.7" -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# === 3. 安装 pip 包 ===
pip install --upgrade pip
pip install numpy==1.16.6 pyelftools


# Set env paths
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
export CPATH="$PREFIX/include:$CPATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

cd "$DEPS"

# Build CMake 3.16.2
wget https://github.com/Kitware/CMake/releases/download/v3.16.2/cmake-3.16.2.tar.gz
tar -xvzf cmake-3.16.2.tar.gz
rm cmake-3.16.2.tar.gz
cd cmake-3.16.2
./bootstrap --prefix="$PREFIX"
make -j$(nproc)
make install
cd "$DEPS"

# Clone and build DynamoRIO
git clone https://github.com/DynamoRIO/dynamorio.git
cd dynamorio
git checkout cronbuild-8.0.18901
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" ..
make -j$(nproc)
make install
cd "$DEPS"

# Setup the tracer
cp -r ./code/iftracer ./iftracer
cd iftracer/iftracer
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" CMakeLists.txt
make -j$(nproc)
cd ../ifLineTracer
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" CMakeLists.txt
make -j$(nproc)
cd "$WORKSPACE"

# Setup CVE-2016-5314
mkdir -p "$WORKSPACE/cves/cve_2016_5314"
cd "$WORKSPACE/cves/cve_2016_5314"
cp ../../data/libtiff/cve_2016_5314/source.zip .
unzip source.zip
rm source.zip
cd source
./configure --prefix="$PREFIX"
make -j$(nproc) CFLAGS="-static -ggdb" CXXFLAGS="-static -ggdb"
cd ..
cp ../../data/libtiff/cve_2016_5314/exploit ./exploit

# Build valgrind locally
cd "$DEPS"
wget https://sourceware.org/pub/valgrind/valgrind-3.15.0.tar.bz2
tar xjf valgrind-3.15.0.tar.bz2
rm valgrind-3.15.0.tar.bz2
cd valgrind-3.15.0
./configure --prefix="$PREFIX"
make -j$(nproc)
make install

# Clone VulnLoc-docker repo
cd "$WORKSPACE"
git clone https://github.com/MingxiuWang/VulnLoc-docker.git
cp -r VulnLoc-docker/test ./test

# Copy your Python code
mkdir -p "$WORKSPACE/code"
cd "$WORKSPACE/code"
cp ../../code/*.py ./

echo "✅ Local environment setup completed in $WORKSPACE using Python $PYTHON_VERSION"
