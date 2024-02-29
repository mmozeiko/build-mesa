@echo off
setlocal enabledelayedexpansion

set LLVM_VERSION=18.1.0rc4
set LLVM2_VERSION=18.1.0-rc4
set MESA_VERSION=24.0.2

set PATH=%CD%\llvm\bin;%CD%\winflexbison;%PATH%

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
  curl -Lsf -o ninja-win.zip https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-win.zip || exit /b 1
  %SZIP% x -bb0 -y ninja-win.zip 1>nul 2>nul || exit /b 1
  del ninja-win.zip 1>nul 2>nul
)

rem *** Visual Studio environment ***

where /Q cl.exe || (
  set __VSCMD_ARG_NO_LOGO=1
  for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
  if "!VS!" equ "" (
    echo ERROR: Visual Studio installation not found
    exit /b 1
  )  
  call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" amd64 || exit /b 1
)

rem *** download sources ***

echo Downloading llvm
curl -sfL https://github.com/llvm/llvm-project/releases/download/llvmorg-%LLVM2_VERSION%/llvm-%LLVM_VERSION%.src.tar.xz ^
 | %SZIP% x -bb0 -txz -si -so ^
 | %SZIP% x -bb0 -ttar -si -aoa 1>nul 2>nul
curl -sfL https://github.com/llvm/llvm-project/releases/download/llvmorg-%LLVM2_VERSION%/cmake-%LLVM_VERSION%.src.tar.xz ^
  | %SZIP% x -bb0 -txz -si -so ^
  | %SZIP% x -bb0 -ttar -si -aoa 1>nul 2>nul
move llvm-%LLVM_VERSION%.src llvm.src
move cmake-%LLVM_VERSION%.src cmake

echo Downloading mesa
curl -sfL https://archive.mesa3d.org/mesa-%MESA_VERSION%.tar.xz ^
  | %SZIP% x -bb0 -txz -si -so ^
  | %SZIP% x -bb0 -ttar -si -aoa 1>nul 2>nul
move mesa-%MESA_VERSION% mesa.src
git apply -p0 --directory=mesa.src mesa.patch || exit /b 1

echo Downloading win_flex_bison
if not exist winflexbison (
  mkdir winflexbison
  pushd winflexbison
  curl -sfL -o win_flex_bison.zip https://github.com/lexxmark/winflexbison/releases/download/v2.5.25/win_flex_bison-2.5.25.zip || exit /b 1
  %SZIP% x -bb0 -y win_flex_bison.zip 1>nul 2>nul || exit /b 1
  del win_flex_bison.zip 1>nul 2>nul
  popd
)

del "@PaxHeader" "HEAD" "pax_global_header" 1>nul 2>nul

rem *** llvm ***

cmake ^
  -G Ninja ^
  -S llvm.src ^
  -B llvm.build ^
  -D CMAKE_INSTALL_PREFIX="%CD%\llvm" ^
  -D CMAKE_BUILD_TYPE="Release" ^
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -D BUILD_SHARED_LIBS=OFF ^
  -D LLVM_TARGETS_TO_BUILD="X86" ^
  -D LLVM_ENABLE_BACKTRACES=OFF ^
  -D LLVM_ENABLE_UNWIND_TABLES=OFF ^
  -D LLVM_ENABLE_CRASH_OVERRIDES=OFF ^
  -D LLVM_ENABLE_TERMINFO=OFF ^
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
ninja -C llvm.build
ninja -C llvm.build install || exit /b 1

rem *** extra libs ***

set LINK=version.lib

rem *** llvmpipe ***

rd /s /q mesa.build 1>nul 2>nul
meson setup ^
  mesa.build ^
  mesa.src ^
  --prefix="%CD%\mesa-llvmpipe" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=enabled ^
  -Dplatforms=windows ^
  -Dosmesa=true ^
  -Dgallium-drivers=swrast ^
  -Dvulkan-drivers=swrast || exit /b 1
ninja -C mesa.build install || exit /b 1

rem *** d3d12 ***

rd /s /q mesa.build 1>nul 2>nul
meson setup ^
  mesa.build ^
  mesa.src ^
  --prefix="%CD%\mesa-d3d12" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=d3d12 || exit /b 1
ninja -C mesa.build install || exit /b 1

rem *** zink ***

rd /s /q mesa.build 1>nul 2>nul
git apply -p0 --directory=mesa.src mesa-zink.patch || exit /b 1
meson setup ^
  mesa.build ^
  mesa.src ^
  --prefix="%CD%\mesa-zink" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=zink || exit /b 1
ninja -C mesa.build install || exit /b 1

rem *** done ***
rem output is in mesa-llvmpipe, mesa-d3d12, mesa-zink folders

if "%GITHUB_WORKFLOW%" neq "" (
  mkdir archive-llvmpipe
  pushd archive-llvmpipe
  copy /y ..\mesa-llvmpipe\bin\opengl32.dll .
  %SZIP% a -mx=9 ..\mesa-llvmpipe-%MESA_VERSION%.zip 
  popd

  mkdir archive-osmesa
  pushd archive-osmesa
  copy /y ..\mesa-llvmpipe\bin\osmesa.dll      .
  copy /y ..\mesa-llvmpipe\lib\osmesa.lib      .
  copy /y ..\mesa-llvmpipe\include\GL\osmesa.h .
  %SZIP% a -mx=9 ..\mesa-osmesa-%MESA_VERSION%.zip 
  popd

  mkdir archive-lavapipe
  pushd archive-lavapipe
  copy /y ..\mesa-llvmpipe\bin\vulkan_lvp.dll .
  python ..\mesa.src\src\vulkan\util\vk_icd_gen.py --api-version 1.1 --xml ..\mesa.src\src\vulkan\registry\vk.xml --lib-path vulkan_lvp.dll --out lvp_icd.x86_64.json

  %SZIP% a -mx=9 ..\mesa-lavapipe-%MESA_VERSION%.zip 
  popd

  mkdir archive-d3d12
  pushd archive-d3d12
  copy /y ..\mesa-d3d12\bin\opengl32.dll .
  if exist "%ProgramFiles(x86)%\Windows Kits\10\Redist\D3D\x64\dxil.dll" (
    copy /y "%ProgramFiles(x86)%\Windows Kits\10\Redist\D3D\x64\dxil.dll" .
  ) else if exist "%WindowsSdkVerBinPath%x64\dxil.dll" (
    copy /y "%WindowsSdkVerBinPath%x64\dxil.dll" .
  )
  %SZIP% a -mx=9 ..\mesa-d3d12-%MESA_VERSION%.zip 
  popd

  mkdir archive-zink
  pushd archive-zink
  copy /y ..\mesa-zink\bin\opengl32.dll .
  %SZIP% a -mx=9 ..\mesa-zink-%MESA_VERSION%.zip 
  popd

  echo ::set-output name=LLVM_VERSION::%LLVM_VERSION%
  echo ::set-output name=MESA_VERSION::%MESA_VERSION%
)
