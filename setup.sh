#!/bin/bash
set -e

PREFIX="$HOME/Wjw"
WORKSPACE="/srv/scratch/PAG/Wjw/workspace"
DEPS="$WORKSPACE/deps"
mkdir -p "$DEPS"

export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
export CPATH="$PREFIX/include:$CPATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

cd "$DEPS"

# Install Python packages locally
pip install --user numpy==1.16.6 pyelftools

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

# Setup the tracer (assumes ./code/iftracer is copied here)
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

# Copy your Python code (assumes it's already in ./code)
mkdir -p "$WORKSPACE/code"
cd "$WORKSPACE/code"
cp ../../code/*.py ./

echo "✅ Local environment setup completed in $WORKSPACE"
