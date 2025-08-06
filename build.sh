#!/usr/bin/env sh

set -e

EXE_NAME="odin_sdl2_template"
SDL_VERSION="release-2.32.8"

mkdir -p build
mkdir -p build/output
mkdir -p build/vendor

clear

if [ "$1" = "build-sdl2" ]; then
    cd build/vendor
    [ -d sdl ] || git clone https://github.com/libsdl-org/SDL.git sdl
    cd sdl
    git checkout "$SDL_VERSION"
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    sudo cmake --install build
    sudo ldconfig
fi

if [ "$1" = "build" ]; then
    odin build source -out:build/output/"$EXE_NAME"
fi

if [ "$1" = "run" ]; then
    odin run source -out:build/output/"$EXE_NAME"
fi

if [ "$1" = "build-debug" ]; then
    odin build source -out:build/output/"$EXE_NAME" -debug
fi

if [ "$1" = "run-debug" ]; then
    odin run source -out:build/output/"$EXE_NAME" -debug
fi
