cmake_minimum_required(VERSION 3.21)

project(wallhaven_multi_engine_sync_test LANGUAGES CXX)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml)

add_executable(multi_engine_sync multi_engine_sync.cpp)
target_compile_features(multi_engine_sync PRIVATE cxx_std_17)
target_link_libraries(multi_engine_sync PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)
