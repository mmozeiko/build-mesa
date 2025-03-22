@echo off
setlocal enabledelayedexpansion

set LLVM_VERSION=20.1.1
set MESA_VERSION=25.0.2

rem *** architectures ***

if "%1" equ "x86" (
  set MESA_ARCH=x86
) else if "%1" equ "x64" (
  set MESA_ARCH=x64
) else if "%1" equ "arm64" (
  set MESA_ARCH=arm64
) else if "%1" equ "x86" (
  set MESA_ARCH=x86
) else if "%1" neq "" (
  echo Unknown "%1" architecture!
  exit /b 1
) else if "%PROCESSOR_ARCHITECTURE%" equ "x86" (
  set MESA_ARCH=x86
) else if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
  set MESA_ARCH=x64
) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
  set MESA_ARCH=arm64
) else if "%PROCESSOR_ARCHITECTURE%" equ "x86" (
  set MESA_ARCH=x86
) else (
  echo Unknown host architecture!
  exit /b 1
)

if "%MESA_ARCH%" equ "x86" (
  set TARGET_ARCH=x86
  set LLVM_TARGETS_TO_BUILD=X86
  set TARGET_ARCH_NAME=i686
) else if "%MESA_ARCH%" equ "x64" (
  set TARGET_ARCH=amd64
  set LLVM_TARGETS_TO_BUILD=X86
  set TARGET_ARCH_NAME=x86_64
) else if "%MESA_ARCH%" equ "arm64" (
  set TARGET_ARCH=arm64
  set LLVM_TARGETS_TO_BUILD=AArch64
  set TARGET_ARCH_NAME=aarch64
) else if "%MESA_ARCH%" equ "x86" (
  set TARGET_ARCH=x86
  set LLVM_TARGETS_TO_BUILD=X86
  set TARGET_ARCH_NAME=x86
)

if "%PROCESSOR_ARCHITECTURE%" equ "x86" (
  set HOST_ARCH=x86
) else if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
  set HOST_ARCH=amd64
) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
  set HOST_ARCH=arm64
) else if "%PROCESSOR_ARCHITECTURE%" equ "x86" (
  set HOST_ARCH=x86
)

if "!TARGET_ARCH!" neq "!HOST_ARCH!" (
  set LLVM_CROSS_CMAKE_FLAGS=-D CMAKE_SYSTEM_NAME=Windows -D LLVM_NATIVE_TOOL_DIR="%CD%\llvm.build-native\bin"
  set MESON_CROSS=--cross-file "%CD%\meson-%MESA_ARCH%.txt"
) else if "%MESA_ARCH%" equ "arm64" (
  set LLVM_CROSS_CMAKE_FLAGS=
  set MESON_CROSS=
) else if "%MESA_ARCH%" equ "x86" (
  set LLVM_CROSS_CMAKE_FLAGS=
  set MESON_CROSS=
)

if "%MESA_ARCH%" equ "x86" (
  set MESON_CROSS=%MESON_CROSS% -Dmin-windows-version=7
)

set PATH=%CD%\llvm-%MESA_ARCH%\bin;%CD%\winflexbison;%PATH%

rem *** check dependencies ***

where /q python.exe || (
  echo ERROR: "python.exe" not found
  exit /b 1
)

where /q pip.exe || (
  echo ERROR: "pip.exe" not found
  exit /b 1
)

where /q meson.exe || (
  pip install meson
  where /q meson.exe || (
    echo ERROR: "meson.exe" not found
    exit /b 1
  )
)

python -c "import mako" 2>nul || (
  pip install mako
  python -c "import mako" 2>nul || (
    echo ERROR: "mako" module not found for python
    exit /b 1
  )
)

python -c "import yaml" 2>nul || (
  pip install pyyaml
  python -c "import yaml" 2>nul || (
    echo ERROR: "yaml" module not found for python
    exit /b 1
  )
)

where /q git.exe || (
  echo ERROR: "git.exe" not found
  exit /b 1
)

where /q curl.exe || (
  echo ERROR: "curl.exe" not found
  exit /b 1
)

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo ERROR: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

where /q cmake.exe || (
  echo ERROR: "cmake.exe" not found
  exit /b 1
)

where /q ninja.exe || (
  if "%PROCESSOR_ARCHITECTURE%" equ "x86" (
    curl -LOsf https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip || exit /b 1
  ) else if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
    curl -LOsf https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip || exit /b 1
  ) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
    curl -Lsf -o ninja-win.zip https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-winarm64.zip || exit /b 1
  ) else if "%PROCESSOR_ARCHITECTURE%" equ "x86" (
    curl -LOsf https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip || exit /b 1
  )
  %SZIP% x -bb0 -y ninja-win.zip 1>nul 2>nul || exit /b 1
  del ninja-win.zip 1>nul 2>nul
)

rem *** download sources ***

if "%SKIP_LLVM%" neq "" goto :no-llvm-download

echo Downloading llvm
curl -sfL https://github.com/llvm/llvm-project/releases/download/llvmorg-%LLVM_VERSION%/llvm-%LLVM_VERSION%.src.tar.xz ^
  | %SZIP% x -bb0 -txz -si -so ^
  | %SZIP% x -bb0 -ttar -si -aoa 1>nul 2>nul
curl -sfL https://github.com/llvm/llvm-project/releases/download/llvmorg-%LLVM_VERSION%/cmake-%LLVM_VERSION%.src.tar.xz ^
  | %SZIP% x -bb0 -txz -si -so ^
  | %SZIP% x -bb0 -ttar -si -aoa 1>nul 2>nul
rd /s /q cmake llvm.src 1>nul 2>nul
move llvm-%LLVM_VERSION%.src llvm.src 1>nul 2>nul
move cmake-%LLVM_VERSION%.src cmake 1>nul 2>nul

:no-llvm-download

echo Downloading mesa
curl -sfL https://archive.mesa3d.org/mesa-%MESA_VERSION%.tar.xz ^
  | %SZIP% x -bb0 -txz -si -so ^
  | %SZIP% x -bb0 -ttar -si -aoa 1>nul 2>nul
rd /s /q mesa.src 1>nul 2>nul
move mesa-%MESA_VERSION% mesa.src 1>nul 2>nul
git apply -p0 --directory=mesa.src mesa.patch || exit /b 1

mkdir mesa.src\subprojects\llvm
copy meson.llvm.build mesa.src\subprojects\llvm\meson.build

if not exist winflexbison (
  echo Downloading win_flex_bison
  mkdir winflexbison
  pushd winflexbison
  rem 2.5.25 is buggy when running parallel make, see: https://github.com/lexxmark/winflexbison/issues/86
  curl -sfL -o win_flex_bison.zip https://github.com/lexxmark/winflexbison/releases/download/v2.5.24/win_flex_bison-2.5.24.zip || exit /b 1
  %SZIP% x -bb0 -y win_flex_bison.zip 1>nul 2>nul || exit /b 1
  del win_flex_bison.zip 1>nul 2>nul
  popd
)

del "@PaxHeader" "HEAD" "pax_global_header" 1>nul 2>nul

rem *** Visual Studio ***

set __VSCMD_ARG_NO_LOGO=1
for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
if "!VS!" equ "" (
  echo ERROR: Visual Studio installation not found
  exit /b 1
)

rem *** llvm ***

if "%SKIP_LLVM%" neq "" (
  call "!VS!\Common7\Tools\VsDevCmd.bat" -arch=!TARGET_ARCH! -host_arch=!HOST_ARCH! -startdir=none -no_logo || exit /b 1
  goto :no-llvm-build
)

if "!TARGET_ARCH!" neq "!HOST_ARCH!" (

  call "!VS!\Common7\Tools\VsDevCmd.bat" -arch=!HOST_ARCH! -host_arch=!HOST_ARCH! -startdir=none -no_logo || exit /b 1
  cmake ^
    -G Ninja ^
    -S llvm.src ^
    -B llvm.build-native ^
    -D CMAKE_INSTALL_PREFIX="%CD%\llvm-native" ^
    -D CMAKE_BUILD_TYPE="Release" ^
    -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
    -D BUILD_SHARED_LIBS=OFF ^
    -D LLVM_TARGETS_TO_BUILD=%LLVM_TARGETS_TO_BUILD% ^
    -D LLVM_ENABLE_BACKTRACES=OFF ^
    -D LLVM_ENABLE_UNWIND_TABLES=OFF ^
    -D LLVM_ENABLE_CRASH_OVERRIDES=OFF ^
    -D LLVM_ENABLE_LIBXML2=OFF ^
    -D LLVM_ENABLE_LIBEDIT=OFF ^
    -D LLVM_ENABLE_LIBPFM=OFF ^
    -D LLVM_ENABLE_ZLIB=OFF ^
    -D LLVM_ENABLE_Z3_SOLVER=OFF ^
    -D LLVM_ENABLE_WARNINGS=OFF ^
    -D LLVM_ENABLE_PEDANTIC=OFF ^
    -D LLVM_ENABLE_WERROR=OFF ^
    -D LLVM_ENABLE_ASSERTIONS=OFF ^
    -D LLVM_BUILD_LLVM_C_DYLIB=OFF ^
    -D LLVM_BUILD_UTILS=OFF ^
    -D LLVM_BUILD_TESTS=OFF ^
    -D LLVM_BUILD_DOCS=OFF ^
    -D LLVM_BUILD_EXAMPLES=OFF ^
    -D LLVM_BUILD_BENCHMARKS=OFF ^
    -D LLVM_INCLUDE_UTILS=OFF ^
    -D LLVM_INCLUDE_TESTS=OFF ^
    -D LLVM_INCLUDE_DOCS=OFF ^
    -D LLVM_INCLUDE_EXAMPLES=OFF ^
    -D LLVM_INCLUDE_BENCHMARKS=OFF ^
    -D LLVM_ENABLE_BINDINGS=OFF ^
    -D LLVM_OPTIMIZED_TABLEGEN=ON ^
    -D LLVM_ENABLE_PLUGINS=OFF ^
    -D LLVM_ENABLE_IDE=OFF || exit /b 1

    ninja -C llvm.build-native llvm-tblgen || exit /b 1
    echo . > llvm.build-native\bin\llvm-nm.exe
    echo . > llvm.build-native\bin\llvm-readobj.exe
)

call "!VS!\Common7\Tools\VsDevCmd.bat" -arch=!TARGET_ARCH! -host_arch=!HOST_ARCH! -startdir=none -no_logo || exit /b 1
cmake ^
  -G Ninja ^
  -S llvm.src ^
  -B llvm.build-%MESA_ARCH% ^
  !LLVM_CROSS_CMAKE_FLAGS! ^
  -D CMAKE_INSTALL_PREFIX="%CD%\llvm-%MESA_ARCH%" ^
  -D CMAKE_BUILD_TYPE="Release" ^
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -D BUILD_SHARED_LIBS=OFF ^
  -D LLVM_HOST_TRIPLE=!TARGET_ARCH_NAME!-pc-windows-msvc ^
  -D LLVM_TARGETS_TO_BUILD=%LLVM_TARGETS_TO_BUILD% ^
  -D LLVM_ENABLE_BACKTRACES=OFF ^
  -D LLVM_ENABLE_UNWIND_TABLES=OFF ^
  -D LLVM_ENABLE_CRASH_OVERRIDES=OFF ^
  -D LLVM_ENABLE_LIBXML2=OFF ^
  -D LLVM_ENABLE_LIBEDIT=OFF ^
  -D LLVM_ENABLE_LIBPFM=OFF ^
  -D LLVM_ENABLE_ZLIB=OFF ^
  -D LLVM_ENABLE_Z3_SOLVER=OFF ^
  -D LLVM_ENABLE_WARNINGS=OFF ^
  -D LLVM_ENABLE_PEDANTIC=OFF ^
  -D LLVM_ENABLE_WERROR=OFF ^
  -D LLVM_ENABLE_ASSERTIONS=OFF ^
  -D LLVM_BUILD_LLVM_C_DYLIB=OFF ^
  -D LLVM_BUILD_UTILS=OFF ^
  -D LLVM_BUILD_TESTS=OFF ^
  -D LLVM_BUILD_DOCS=OFF ^
  -D LLVM_BUILD_EXAMPLES=OFF ^
  -D LLVM_BUILD_BENCHMARKS=OFF ^
  -D LLVM_INCLUDE_UTILS=OFF ^
  -D LLVM_INCLUDE_TESTS=OFF ^
  -D LLVM_INCLUDE_DOCS=OFF ^
  -D LLVM_INCLUDE_EXAMPLES=OFF ^
  -D LLVM_INCLUDE_BENCHMARKS=OFF ^
  -D LLVM_ENABLE_BINDINGS=OFF ^
  -D LLVM_OPTIMIZED_TABLEGEN=ON ^
  -D LLVM_ENABLE_PLUGINS=OFF ^
  -D LLVM_ENABLE_IDE=OFF || exit /b 1
ninja -C llvm.build-%MESA_ARCH% llvm-headers llvm-libraries || exit /b 1
ninja -C llvm.build-%MESA_ARCH% install-llvm-headers install-llvm-libraries 1>nul || exit /b 1

:no-llvm-build

rem *** extra libs ***

set LINK=version.lib ntdll.lib

rem *** llvmpipe, lavapipe, osmesa ***

rd /s /q mesa.build-%MESA_ARCH% 1>nul 2>nul
meson setup ^
  mesa.build-%MESA_ARCH% ^
  mesa.src ^
  --prefix="%CD%\mesa-llvmpipe-%MESA_ARCH%" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=enabled ^
  -Dplatforms=windows ^
  -Dosmesa=true ^
  -Dgallium-drivers=swrast ^
  -Dvulkan-drivers=swrast ^
  !MESON_CROSS! || exit /b 1
ninja -C mesa.build-%MESA_ARCH% install || exit /b 1
python mesa.src\src\vulkan\util\vk_icd_gen.py --api-version 1.4 --xml mesa.src\src\vulkan\registry\vk.xml --lib-path vulkan_lvp.dll --out mesa-llvmpipe-%MESA_ARCH%\bin\lvp_icd.!TARGET_ARCH_NAME!.json || exit /b 1

rem *** d3d12, dzn ***

rd /s /q mesa.build-%MESA_ARCH% 1>nul 2>nul
meson setup ^
  mesa.build-%MESA_ARCH% ^
  mesa.src ^
  --prefix="%CD%\mesa-d3d12-%MESA_ARCH%" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=d3d12 ^
  -Dvulkan-drivers=microsoft-experimental ^
  !MESON_CROSS! || exit /b 1
ninja -C mesa.build-%MESA_ARCH% install || exit /b 1
python mesa.src\src\vulkan\util\vk_icd_gen.py --api-version 1.1 --xml mesa.src\src\vulkan\registry\vk.xml --lib-path vulkan_dzn.dll --out mesa-d3d12-%MESA_ARCH%\bin\dzn_icd.!TARGET_ARCH_NAME!.json || exit /b 1
if exist "%ProgramFiles(x86)%\Windows Kits\10\Redist\D3D\%MESA_ARCH%\dxil.dll" (
  copy /y "%ProgramFiles(x86)%\Windows Kits\10\Redist\D3D\%MESA_ARCH%\dxil.dll" mesa-d3d12-%MESA_ARCH%\bin\
) else if exist "%WindowsSdkVerBinPath%%MESA_ARCH%\dxil.dll" (
  copy /y "%WindowsSdkVerBinPath%%MESA_ARCH%\dxil.dll" mesa-d3d12-%MESA_ARCH%\bin\
)

rem *** zink ***

rd /s /q mesa.build-%MESA_ARCH% 1>nul 2>nul
git apply -p0 --directory=mesa.src mesa-zink.patch || exit /b 1
meson setup ^
  mesa.build-%MESA_ARCH% ^
  mesa.src ^
  --prefix="%CD%\mesa-zink-%MESA_ARCH%" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=zink ^
  !MESON_CROSS! || exit /b 1
ninja -C mesa.build-%MESA_ARCH% install || exit /b 1

rem *** done ***
rem output is in mesa-llvmpipe, mesa-d3d12, mesa-zink folders

if "%GITHUB_WORKFLOW%" neq "" (
  mkdir archive-llvmpipe
  pushd archive-llvmpipe
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\opengl32.dll .
  %SZIP% a -mx=9 ..\mesa-llvmpipe-%MESA_ARCH%-%MESA_VERSION%.zip 
  popd

  mkdir archive-osmesa
  pushd archive-osmesa
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\osmesa.dll      .
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\lib\osmesa.lib      .
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\include\GL\osmesa.h .
  %SZIP% a -mx=9 ..\mesa-osmesa-%MESA_ARCH%-%MESA_VERSION%.zip 
  popd

  mkdir archive-lavapipe
  pushd archive-lavapipe
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\vulkan_lvp.dll .
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\lvp_icd.!TARGET_ARCH_NAME!.json .
  %SZIP% a -mx=9 ..\mesa-lavapipe-%MESA_ARCH%-%MESA_VERSION%.zip 
  popd

  mkdir archive-d3d12
  pushd archive-d3d12
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\opengl32.dll .
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\dxil.dll .
  %SZIP% a -mx=9 ..\mesa-d3d12-%MESA_ARCH%-%MESA_VERSION%.zip 
  popd

  mkdir archive-zink
  pushd archive-zink
  copy /y ..\mesa-zink-%MESA_ARCH%\bin\opengl32.dll .
  %SZIP% a -mx=9 ..\mesa-zink-%MESA_ARCH%-%MESA_VERSION%.zip 
  popd

  mkdir archive-dzn
  pushd archive-dzn
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\vulkan_dzn.dll .
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\dxil.dll .
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\dzn_icd.!TARGET_ARCH_NAME!.json .
  %SZIP% a -mx=9 ..\mesa-dzn-%MESA_ARCH%-%MESA_VERSION%.zip
  popd

  echo LLVM_VERSION=%LLVM_VERSION%>>%GITHUB_OUTPUT%
  echo MESA_VERSION=%MESA_VERSION%>>%GITHUB_OUTPUT%
)
