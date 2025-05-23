cmake_minimum_required(VERSION 3.5.1)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(OPT_CFLAGS "${OPT_CFLAGS} -DDEBUG")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CL_CFLAGS}")
find_package(DynamoRIO  REQUIRED )
if (NOT DynamoRIO_FOUND)
  message(FATAL_ERROR "DynamoRIO package required to build")
endif(NOT DynamoRIO_FOUND)
option(OPTIMIZE_SAMPLES
  "Build samples with optimizations to increase the chances of clean call inlining (overrides debug flags)"
  ON)
add_library(ifLineTracer SHARED "findline.cpp;")
configure_DynamoRIO_client(ifLineTracer)
use_DynamoRIO_extension(ifLineTracer drmgr)
use_DynamoRIO_extension(ifLineTracer drutil)




