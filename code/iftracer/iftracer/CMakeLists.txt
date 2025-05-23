cmake_minimum_required(VERSION 3.5.1)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(OPT_CFLAGS "${OPT_CFLAGS} -DDEBUG")
find_package(DynamoRIO EXACT REQUIRED PATHS ${CMAKE_CURRENT_SOURCE_DIR}/../../workspace/deps/dynamorio/build)
if (NOT DynamoRIO_FOUND)
  message(FATAL_ERROR "DynamoRIO package required to build")
endif(NOT DynamoRIO_FOUND)
option(OPTIMIZE_SAMPLES
  "Build samples with optimizations to increase the chances of clean call inlining (overrides debug flags)"
  ON)
add_library(iftracer SHARED "acbrtrace.c;")
configure_DynamoRIO_client(iftracer)
use_DynamoRIO_extension(iftracer drmgr)
use_DynamoRIO_extension(iftracer drutil)




