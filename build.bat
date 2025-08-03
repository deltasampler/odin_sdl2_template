@echo off

set EXE_NAME=odin_sdl2_template.exe
set SDL_VERSION=release-2.32.8
set VSDEVCMD="C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"

if not exist build mkdir build
if not exist build\output mkdir build\output
if not exist build\vendor mkdir build\vendor

cls

if "%~1" == "get-sdl2" (
    curl -L -o build\output\SDL2.dll https://raw.githubusercontent.com/odin-lang/Odin/master/vendor/sdl2/SDL2.dll
    curl -L -o build\output\SDL2.lib https://raw.githubusercontent.com/odin-lang/Odin/master/vendor/sdl2/SDL2.lib
)

if "%~1" == "build-sdl2" (
    cd build\vendor
    git clone https://github.com/libsdl-org/SDL.git sdl
    cd sdl
    git checkout %SDL_VERSION%
    %VSDEVCMD%
    cmake -S . -B build
    cmake --build build --config Release
    cd ..\..
    copy /Y "vendor\sdl\build\Release\SDL2.dll" "output\SDL2.dll"
    copy /Y "vendor\sdl\build\Release\SDL2.lib" "output\SDL2.lib"
)

if "%~1" == "build" (
    odin build source -out:build/output/%EXE_NAME%
)

if "%~1" == "run" (
    odin run source -out:build/output/%EXE_NAME%
)
