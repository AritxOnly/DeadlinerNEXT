cmake_minimum_required(VERSION 3.16)
project(deadliner_persistence)

add_library(deadliner_persistence SHARED napi_init.cpp)

target_link_libraries(deadliner_persistence
    PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
    dl
)

target_compile_features(deadliner_persistence PUBLIC cxx_std_17)
