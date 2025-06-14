#!/bin/bash
set -e

# === Configuration ===
PYTHON_VERSION=3.7.9
OPENSSL_VERSION=1.1.1w
NUMPY_VERSION=1.16.6
CMAKE_VERSION=3.15.5
GCC_VERSION=9.4.0



CUR_ROOT=$(pwd)
WORKSPACE="$CUR_ROOT/workspace"
PYTHON_INSTALL="$WORKSPACE/python$PYTHON_VERSION"
VENV_DIR="$WORKSPACE/venv"
DEPS="$WORKSPACE/deps"
GCC_INSTALL="$DEPS/gcc-$GCC_VERSION"

# === Prepare directories ===
mkdir -p "$DEPS"
cd "$DEPS"


# === 1. Build and install OpenSSL ===
if [ ! -d "$DEPS/openssl" ]; then
    echo "🔐 Installing OpenSSL $OPENSSL_VERSION..."
    wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
    tar -xzf openssl-$OPENSSL_VERSION.tar.gz
    cd openssl-$OPENSSL_VERSION
    ./config --prefix="$DEPS/openssl" --openssldir="$DEPS/openssl" shared zlib
    make -j$(nproc)
    make install
    cd "$DEPS"
    rm -rf openssl-$OPENSSL_VERSION*
fi

rm -rf "$PYTHON_INSTALL"
# === Step 1: Build Python ===
if [ ! -x "$PYTHON_INSTALL/bin/python3.7" ]; then
    echo "🐍 Building Python $PYTHON_VERSION with OpenSSL..."
    wget https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz
    tar -xzf Python-$PYTHON_VERSION.tgz
    cd Python-$PYTHON_VERSION


    export CPPFLAGS="-I$DEPS/openssl/include"
    export LDFLAGS="-L$DEPS/openssl/lib"
    export LD_RUN_PATH="$DEPS/openssl/lib"
    export LD_LIBRARY_PATH="$DEPS/openssl/lib:$LD_LIBRARY_PATH"

    ./configure --prefix="$PYTHON_INSTALL" \
                --with-openssl="$DEPS/openssl" \
                --enable-optimizations
    make -j$(nproc)
    make install

    ./configure --prefix="$PYTHON_INSTALL" \
                --with-openssl="$DEPS/openssl"
    make -j$(nproc)
    make install NO_TEST=1
    cd "$DEPS"
    rm -rf Python-$PYTHON_VERSION*
fi


# === 3. Create virtual environment ===
if [ ! -d "$VENV_DIR" ]; then
    echo "🧪 Creating virtualenv..."
    "$PYTHON_INSTALL/bin/python3.7" -m venv "$VENV_DIR"
fi

# === 4. Activate venv and install pip ===
source "$VENV_DIR/bin/activate"

echo "📥 Installing pip..."
wget https://bootstrap.pypa.io/pip/3.7/get-pip.py
python get-pip.py
rm get-pip.py

# === 5. Install numpy ===
# === 5. Install numpy ===
if ! python -c "import numpy" &>/dev/null; then
    echo "📦 Installing numpy $NUMPY_VERSION..."
    pip install --no-cache-dir numpy==$NUMPY_VERSION
fi

# === 6. Build CMake (💡 Put this part exactly like this) ===
if [ ! -x "$WORKSPACE/bin/cmake" ]; then
    echo "⚙️  Building CMake $CMAKE_VERSION..."
    cd "$DEPS"
    wget https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION.tar.gz
    tar -xzf cmake-$CMAKE_VERSION.tar.gz
    cd cmake-$CMAKE_VERSION

    # ✅ Note the extra args to force OpenSSL linkage
    ./bootstrap --prefix="$WORKSPACE" \
      -- -DCMAKE_USE_OPENSSL=ON -DOPENSSL_ROOT_DIR="$DEPS/openssl"

    make -j$(nproc)
    make install
    cd "$DEPS"
    rm -rf cmake-$CMAKE_VERSION*
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

# === 1.5: Download and install prebuilt GCC 9.4.0 ===
if [ ! -x "$GCC_INSTALL/bin/gcc" ]; then
    echo "📦 Downloading prebuilt GCC 9.4.0..."
    cd "$DEPS"
    wget http://ftp.gnu.org/gnu/gcc/gcc-9.4.0/gcc-9.4.0.tar.gz
    tar -xzf gcc-9.4.0.tar.gz
    cd gcc-9.4.0
    ./contrib/download_prerequisites
    rm -rf build
    mkdir build && cd build
    ../configure --prefix="$GCC_INSTALL" --enable-languages=c,c++ --disable-multilib
    make -j$(nproc)
    make install
fi

# Use local GCC
export PATH="$GCC_INSTALL/bin:$PATH"
export CC="$GCC_INSTALL/bin/gcc"
export CXX="$GCC_INSTALL/bin/g++"

rm -rf "$DEPS/dynamorio"
# === Step 6: Build DynamoRIO ===
if [ ! -d "$DEPS/dynamorio" ]; then
    echo "⚙️  Cloning and building DynamoRIO..."
    cd "$DEPS"
    git clone https://github.com/DynamoRIO/dynamorio.git
    cd dynamorio
    git checkout cronbuild-8.0.18901
    mkdir build && cd build
    cmake -DDynamoRIO_BUILD_DRUTIL=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DDRCMAKE_SKIP_WARNINGS_AS_ERRORS=ON\
    -DDynamoRIO_BUILD_DRMGR=ON \
    -DCMAKE_INSTALL_PREFIX="$WORKSPACE" \
    -DCMAKE_C_FLAGS="-Wno-error" -DCMAKE_CXX_FLAGS="-Wno-error"  ..
    make -j$(nproc)
    make install
fi


cd $DEPS
# === Step 7: Build Tracers ===
echo "⚙️  Building tracers..."
rm -rf iftracer
cp -r $CUR_ROOT/code/iftracer ./iftracer || true
cd iftracer/iftracer
echo "$(pwd)/../../dynamorio/build"
cmake  CMakeLists.txt
make -j$(nproc)
cd ../ifLineTracer
cmake  CMakeLists.txt
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
cp -n ../../code/*.py "$WORKSPACE"
echo "✅ Setup complete!"
