#!/bin/bash
set -e

# === Configurations ===
PYTHON_VERSION=3.7.2
WORKSPACE="/srv/scratch/PAG/Wjw/workspace"
PYTHON_INSTALL="$WORKSPACE/python$PYTHON_VERSION"
VENV_DIR="$WORKSPACE/venv"
DEPS="$WORKSPACE/deps"
SETUPTOOLS_VERSION="44.1.1"
NUMPY_VERSION="1.16.6"

mkdir -p "$DEPS"
cd "$DEPS"

# Build OpenSSL (required for ssl module)
OPENSSL_VERSION=1.1.1w
wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
tar -xzf openssl-$OPENSSL_VERSION.tar.gz
cd openssl-$OPENSSL_VERSION
./config --prefix=$DEPS/openssl --openssldir=$DEPS/openssl shared zlib
make -j$(nproc)
make install

# === Step 1: Build and install Python 3.7.2 ===
if [ ! -x "$PYTHON_INSTALL/bin/python3.7" ]; then
    echo "🔧 Installing Python $PYTHON_VERSION..."
    wget https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz
    tar -xzf Python-$PYTHON_VERSION.tgz
    cd Python-$PYTHON_VERSION
    ./configure --prefix="$PYTHON_INSTALL" --enable-optimizations
    make -j$(nproc)
    make install
    cd "$DEPS"
    rm -rf Python-$PYTHON_VERSION Python-$PYTHON_VERSION.tgz
fi

# === Step 2: Create virtualenv using installed Python ===
if [ ! -d "$VENV_DIR" ]; then
    echo "🧪 Creating virtualenv..."
    "$PYTHON_INSTALL/bin/python3.5" -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# === Step 3: Install setuptools manually ===
wget https://bootstrap.pypa.io/pip/3.5/get-pip.py
python3 get-pip.py
rm get-pip.py

# === Step 4: Install numpy manually ===
if ! python -c "import numpy" &> /dev/null; then
    echo "📦 Installing numpy $NUMPY_VERSION..."
    cd "$DEPS"
    wget https://github.com/numpy/numpy/releases/download/v$NUMPY_VERSION/numpy-$NUMPY_VERSION.zip
    unzip numpy-$NUMPY_VERSION.zip
    cd numpy-$NUMPY_VERSION
    python3 setup.py install
    cd "$DEPS"
    rm -rf numpy-$NUMPY_VERSION*
fi

# === Set environment paths ===
export PATH="$WORKSPACE/bin:$PATH"
export LD_LIBRARY_PATH="$WORKSPACE/lib:$LD_LIBRARY_PATH"
export CPATH="$WORKSPACE/include:$CPATH"
export PKG_CONFIG_PATH="$WORKSPACE/lib/pkgconfig:$PKG_CONFIG_PATH"

# === Step 5: Build CMake ===
if [ ! -x "$WORKSPACE/bin/cmake" ]; then
    echo "⚙️  Building CMake..."
    cd "$DEPS"
    wget https://github.com/Kitware/CMake/releases/download/v3.16.2/cmake-3.16.2.tar.gz
    tar -xzf cmake-3.16.2.tar.gz
    cd cmake-3.16.2
    ./bootstrap --prefix="$WORKSPACE"
    make -j$(nproc)
    make install
    cd "$DEPS"
    rm -rf cmake-3.16.2*
fi

# === Step 6: Build DynamoRIO ===
if [ ! -d "$DEPS/dynamorio" ]; then
    echo "⚙️  Cloning and building DynamoRIO..."
    cd "$DEPS"
    git clone https://github.com/DynamoRIO/dynamorio.git
    cd dynamorio
    git checkout cronbuild-8.0.18901
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="$WORKSPACE" ..
    make -j$(nproc)
    make install
fi

# === Step 7: Build Tracers ===
echo "⚙️  Building tracers..."
cp -rn ./code/iftracer ./iftracer || true
cd iftracer/iftracer
cmake -DCMAKE_INSTALL_PREFIX="$WORKSPACE" CMakeLists.txt
make -j$(nproc)
cd ../ifLineTracer
cmake -DCMAKE_INSTALL_PREFIX="$WORKSPACE" CMakeLists.txt
make -j$(nproc)

# === Step 8: Setup CVE-2016-5314 ===
echo "🛠️  Setting up CVE-2016-5314 test case..."
CVE_DIR="$WORKSPACE/cves/cve_2016_5314"
mkdir -p "$CVE_DIR"
cd "$CVE_DIR"
cp -n ../../data/libtiff/cve_2016_5314/source.zip . || true
unzip -o source.zip
cd source
./configure --prefix="$WORKSPACE"
make -j$(nproc) CFLAGS="-static -ggdb" CXXFLAGS="-static -ggdb"
cd ..
cp -n ../../data/libtiff/cve_2016_5314/exploit ./exploit || true

# === Step 9: Build Valgrind ===
if [ ! -x "$WORKSPACE/bin/valgrind" ]; then
    echo "⚙️  Building Valgrind..."
    cd "$DEPS"
    wget https://sourceware.org/pub/valgrind/valgrind-3.15.0.tar.bz2
    tar xjf valgrind-3.15.0.tar.bz2
    cd valgrind-3.15.0
    ./configure --prefix="$WORKSPACE"
    make -j$(nproc)
    make install
    cd "$DEPS"
    rm -rf valgrind-3.15.0*
fi

# === Step 10: Clone VulnLoc-docker and copy code ===
echo "📂 Copying VulnLoc code and test files..."
cd "$WORKSPACE"
[ ! -d "VulnLoc-docker" ] && git clone https://github.com/MingxiuWang/VulnLoc-docker.git
cp -rn VulnLoc-docker/test ./test
mkdir -p "$WORKSPACE/code"
cp -n ../../code/*.py "$WORKSPACE*
