@echo off
setlocal enabledelayedexpansion

set MESA_VERSION=25.3.2
set MESA_SHA256=e69dab0d0ea03e3e8cb141b032f58ea9fcf3b9c1f61b31f6592cb4bbd8d0185d

set LLVM_VERSION=21.1.8
set LLVM_SHA256=4633a23617fa31a3ea51242586ea7fb1da7140e426bd62fc164261fe036aa142
set LLVM_RELEASE=https://discourse.llvm.org/t/llvm-21-1-8-released/89144

>nul find "'%LLVM_VERSION%'" meson\meson.llvm.build || (
  echo llvm version in meson.llvm.build does not match expected %LLVM_VERSION% value^^!
  exit /b 1
)

rem *** architectures ***

if "%PROCESSOR_ARCHITECTURE%" equ "x86" (
  set HOST_ARCH=x86
) else if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
  set HOST_ARCH=x64
) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
  set HOST_ARCH=arm64
) else (
  echo Unknown host architecture^^!
  exit /b 1
)

if "%1" neq "" (
  set MESA_ARCH=%1
) else (
  set MESA_ARCH=%HOST_ARCH%
)

if "%MESA_ARCH%" equ "x86" (
  set TARGET_ARCH=x86
  set LLVM_TARGETS_TO_BUILD=X86
  set TARGET_ARCH_NAME=i686
) else if "%MESA_ARCH%" equ "x64" (
  set TARGET_ARCH=x64
  set LLVM_TARGETS_TO_BUILD=X86
  set TARGET_ARCH_NAME=x86_64
) else if "%MESA_ARCH%" equ "arm64" (
  set TARGET_ARCH=arm64
  set LLVM_TARGETS_TO_BUILD=AArch64
  set TARGET_ARCH_NAME=aarch64
) else (
  echo Unknown "%MESA_ARCH%" build architecture^^!
  exit /b 1
)

set MESON_CROSS=--cross-file "%CD%\meson\meson-%MESA_ARCH%.txt"
if "%MESA_ARCH%" equ "x86" (
  set MESON_CROSS=%MESON_CROSS% -Dmin-windows-version=7
)

set PATH=%CD%\llvm-%MESA_ARCH%\bin;%CD%\winflexbison;%PATH%

rem *** check dependencies ***

where /q git.exe    || echo ERROR: "git.exe" not found    && exit /b 1
where /q curl.exe   || echo ERROR: "curl.exe" not found   && exit /b 1
where /q tar.exe    || echo ERROR: "tar.exe" not found    && exit /b 1
where /q cmake.exe  || echo ERROR: "cmake.exe" not found  && exit /b 1
where /q python.exe || echo ERROR: "python.exe" not found && exit /b 1
where /q pip.exe    || echo ERROR: "pip.exe" not found    && exit /b 1

where /q meson.exe || pip install meson || exit /b 1

python.exe -c "import packaging" 2>nul || pip.exe install packaging || exit /b 1
python.exe -c "import mako"      2>nul || pip.exe install mako      || exit /b 1
python.exe -c "import yaml"      2>nul || pip.exe install pyyaml    || exit /b 1

if "%GITHUB_WORKFLOW%" neq "" (
  if exist "%ProgramFiles%\7-Zip\7z.exe" (
    set SZIP="%ProgramFiles%\7-Zip\7z.exe"
  ) else (
    where /q 7za.exe || (
      echo ERROR: 7-Zip installation or "7za.exe" not found^^!
      exit /b 1
    )
    set SZIP=7za.exe
  )
)

where /q ninja.exe || (
  if "%HOST_ARCH%" equ "x86" (
    echo Sorry, ninja binary is not available on 32-bit windows anymore^^!
    exit /b 1
  ) else if "%HOST_ARCH%" equ "x64" (
    curl.exe -sfLO https://github.com/ninja-build/ninja/releases/download/v1.13.1/ninja-win.zip || exit /b 1
  ) else if "%HOST_ARCH%" equ "arm64" (
    curl.exe -sfLo ninja-win.zip https://github.com/ninja-build/ninja/releases/download/v1.13.1/ninja-winarm64.zip || exit /b 1
  )
  tar.exe -xf ninja-win.zip || exit /b 1
  del ninja-win.zip 1>nul 2>nul
)

if not exist winflexbison (
  echo Downloading win_flex_bison
  mkdir winflexbison
  pushd winflexbison
  rem 2.5.25 is buggy when running parallel make, see: https://github.com/lexxmark/winflexbison/issues/86
  curl.exe -sfL -o win_flex_bison.zip https://github.com/lexxmark/winflexbison/releases/download/v2.5.24/win_flex_bison-2.5.24.zip || exit /b 1
  tar.exe -xf win_flex_bison.zip || exit /b 1
  del win_flex_bison.zip 1>nul 2>nul
  popd
)

rem *** find Visual Studio ***

set VSCMD_SKIP_SENDTELEMETRY=1
for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
if "%VS%" equ "" (
  echo ERROR: Visual Studio installation not found^^!
  exit /b 1
)

rem *** download & build llvm ***

if exist "llvm-%LLVM_VERSION%-%MESA_ARCH%\lib\LLVMSupport.lib" (
  call "%VS%\Common7\Tools\VsDevCmd.bat" -arch=%TARGET_ARCH% -host_arch=%HOST_ARCH% -startdir=none -no_logo || exit /b 1
  goto :skip-llvm-build
)

call :get "https://github.com/llvm/llvm-project/releases/download/llvmorg-%LLVM_VERSION%/llvm-project-%LLVM_VERSION%.src.tar.xz" "llvm-project-%LLVM_VERSION%.src" "%LLVM_SHA256%" || exit /b 1

if "%TARGET_ARCH%" neq "%HOST_ARCH%" (

  call "%VS%\Common7\Tools\VsDevCmd.bat" -arch=%HOST_ARCH% -host_arch=%HOST_ARCH% -startdir=none -no_logo || exit /b 1
  cmake.exe ^
    -Wno-dev ^
    -G Ninja ^
    -S llvm-project-%LLVM_VERSION%.src\llvm ^
    -B llvm-project-%LLVM_VERSION%.build-native ^
    -D CMAKE_INSTALL_PREFIX="%CD%\llvm-%LLVM_VERSION%-native" ^
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

  ninja.exe -C llvm-project-%LLVM_VERSION%.build-native llvm-tblgen || exit /b 1
  echo . > llvm-project-%LLVM_VERSION%.build-native\bin\llvm-nm.exe
  echo . > llvm-project-%LLVM_VERSION%.build-native\bin\llvm-readobj.exe

  set LLVM_CMAKE_FLAGS=-D CMAKE_SYSTEM_NAME=Windows -D LLVM_NATIVE_TOOL_DIR="%CD%\llvm-project-%LLVM_VERSION%.build-native\bin"
) else (
  set LLVM_CMAKE_FLAGS=
)

call "%VS%\Common7\Tools\VsDevCmd.bat" -arch=%TARGET_ARCH% -host_arch=%HOST_ARCH% -startdir=none -no_logo || exit /b 1
cmake.exe ^
  -Wno-dev ^
  -G Ninja ^
  -S llvm-project-%LLVM_VERSION%.src\llvm ^
  -B llvm-project-%LLVM_VERSION%.build-%MESA_ARCH% ^
  %LLVM_CMAKE_FLAGS% ^
  -D CMAKE_INSTALL_PREFIX="%CD%\llvm-%LLVM_VERSION%-%MESA_ARCH%" ^
  -D CMAKE_BUILD_TYPE="Release" ^
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -D BUILD_SHARED_LIBS=OFF ^
  -D LLVM_HOST_TRIPLE=%TARGET_ARCH_NAME%-pc-windows-msvc ^
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
ninja.exe -C llvm-project-%LLVM_VERSION%.build-%MESA_ARCH% llvm-headers llvm-libraries || exit /b 1
ninja.exe -C llvm-project-%LLVM_VERSION%.build-%MESA_ARCH% install-llvm-headers install-llvm-libraries 1>nul || exit /b 1

:skip-llvm-build

rem *** extra libs ***

set LINK=version.lib ntdll.lib

rem *** download mesa source ***

rd /s /q mesa-%MESA_VERSION% 1>nul 2>nul

call :get "https://archive.mesa3d.org/mesa-%MESA_VERSION%.tar.xz" "mesa-%MESA_VERSION%" "%MESA_SHA256%" || exit /b 1

git.exe apply --directory=mesa-%MESA_VERSION% patches/mesa-require-dxheaders.patch    || exit /b 1
git.exe apply --directory=mesa-%MESA_VERSION% patches/gallium-use-tex-cache.patch     || exit /b 1
git.exe apply --directory=mesa-%MESA_VERSION% patches/gallium-static-build.patch      || exit /b 1

mkdir mesa-%MESA_VERSION%\subprojects\llvm                                   1>nul || exit /b 1
copy meson\meson.llvm.build mesa-%MESA_VERSION%\subprojects\llvm\meson.build 1>nul || exit /b 1

rem *** llvmpipe, lavapipe ***

rd /s /q mesa-build-%MESA_ARCH% 1>nul 2>nul
meson.exe setup ^
  mesa-build-%MESA_ARCH% ^
  mesa-%MESA_VERSION% ^
  --prefix="%CD%\mesa-llvmpipe-%MESA_ARCH%" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=enabled ^
  -Dplatforms=windows ^
  -Dvideo-codecs= ^
  -Dgallium-drivers=llvmpipe ^
  -Dvulkan-drivers=swrast ^
  -Degl=enabled ^
  -Dgles1=enabled ^
  -Dgles2=enabled ^
  %MESON_CROSS% || exit /b 1
ninja.exe -C mesa-build-%MESA_ARCH% install || exit /b 1
python.exe mesa-%MESA_VERSION%\src\vulkan\util\vk_icd_gen.py --api-version 1.4 --xml mesa-%MESA_VERSION%\src\vulkan\registry\vk.xml --lib-path vulkan_lvp.dll --out mesa-llvmpipe-%MESA_ARCH%\bin\lvp_icd.%TARGET_ARCH_NAME%.json || exit /b 1

rem *** d3d12, dzn ***

rd /s /q mesa-build-%MESA_ARCH% 1>nul 2>nul
meson.exe setup ^
  mesa-build-%MESA_ARCH% ^
  mesa-%MESA_VERSION% ^
  --prefix="%CD%\mesa-d3d12-%MESA_ARCH%" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dvideo-codecs=all ^
  -Dmediafoundation-codecs=all ^
  -Dgallium-mediafoundation=enabled ^
  -Dgallium-drivers=d3d12 ^
  -Dvulkan-drivers=microsoft-experimental ^
  -Degl=enabled ^
  -Dgles1=enabled ^
  -Dgles2=enabled ^
  %MESON_CROSS% || exit /b 1
ninja.exe -C mesa-build-%MESA_ARCH% install || exit /b 1
python.exe mesa-%MESA_VERSION%\src\vulkan\util\vk_icd_gen.py --api-version 1.1 --xml mesa-%MESA_VERSION%\src\vulkan\registry\vk.xml --lib-path vulkan_dzn.dll --out mesa-d3d12-%MESA_ARCH%\bin\dzn_icd.%TARGET_ARCH_NAME%.json || exit /b 1
if exist "%ProgramFiles(x86)%\Windows Kits\10\Redist\D3D\%MESA_ARCH%\dxil.dll" (
  copy /y "%ProgramFiles(x86)%\Windows Kits\10\Redist\D3D\%MESA_ARCH%\dxil.dll" mesa-d3d12-%MESA_ARCH%\bin\
) else if exist "%WindowsSdkVerBinPath%%MESA_ARCH%\dxil.dll" (
  copy /y "%WindowsSdkVerBinPath%%MESA_ARCH%\dxil.dll" mesa-d3d12-%MESA_ARCH%\bin\
)

rem *** zink ***

git.exe apply --directory=mesa-%MESA_VERSION% patches/zink-static-build.patch || exit /b 1

rd /s /q mesa-build-%MESA_ARCH% 1>nul 2>nul
meson.exe setup ^
  mesa-build-%MESA_ARCH% ^
  mesa-%MESA_VERSION% ^
  --prefix="%CD%\mesa-zink-%MESA_ARCH%" ^
  --default-library=static ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dvideo-codecs= ^
  -Dgallium-drivers=zink ^
  -Degl=enabled ^
  -Dgles1=enabled ^
  -Dgles2=enabled ^
  %MESON_CROSS% || exit /b 1
ninja.exe -C mesa-build-%MESA_ARCH% install || exit /b 1

rem *** done ***

if "%GITHUB_WORKFLOW%" neq "" (
  mkdir archive-llvmpipe-%MESA_ARCH%
  pushd archive-llvmpipe-%MESA_ARCH%
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\opengl32.dll     .           || exit /b 1
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\libEGL.dll       .           || exit /b 1
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\lib\libEGL.lib       .           || exit /b 1
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\libGLESv1_CM.dll .           || exit /b 1
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\lib\libGLESv1_CM.lib .           || exit /b 1
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\libGLESv2.dll    .           || exit /b 1
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\lib\libGLESv2.lib    .           || exit /b 1
  %SZIP% a -mx=9 -mqs=on ..\mesa-llvmpipe-%MESA_ARCH%-%MESA_VERSION%.7z || exit /b 1
  popd

  mkdir archive-lavapipe-%MESA_ARCH%
  pushd archive-lavapipe-%MESA_ARCH%
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\vulkan_lvp.dll                  . || exit /b 1
  copy /y ..\mesa-llvmpipe-%MESA_ARCH%\bin\lvp_icd.%TARGET_ARCH_NAME%.json . || exit /b 1
  %SZIP% a -mx=9 -mqs=on ..\mesa-lavapipe-%MESA_ARCH%-%MESA_VERSION%.7z      || exit /b 1
  popd

  mkdir archive-d3d12-%MESA_ARCH%
  pushd archive-d3d12-%MESA_ARCH%
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\dxil.dll         .           || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\opengl32.dll     .           || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\libEGL.dll       .           || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\lib\libEGL.lib       .           || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\libGLESv1_CM.dll .           || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\lib\libGLESv1_CM.lib .           || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\libGLESv2.dll    .           || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\lib\libGLESv2.lib    .           || exit /b 1
  %SZIP% a -mx=9 -mqs=on ..\mesa-d3d12-%MESA_ARCH%-%MESA_VERSION%.7z || exit /b 1
  popd

  mkdir archive-zink-%MESA_ARCH%
  pushd archive-zink-%MESA_ARCH%
  copy /y ..\mesa-zink-%MESA_ARCH%\bin\opengl32.dll     .           || exit /b 1
  copy /y ..\mesa-zink-%MESA_ARCH%\bin\libEGL.dll       .           || exit /b 1
  copy /y ..\mesa-zink-%MESA_ARCH%\lib\libEGL.lib       .           || exit /b 1
  copy /y ..\mesa-zink-%MESA_ARCH%\bin\libGLESv1_CM.dll .           || exit /b 1
  copy /y ..\mesa-zink-%MESA_ARCH%\lib\libGLESv1_CM.lib .           || exit /b 1
  copy /y ..\mesa-zink-%MESA_ARCH%\bin\libGLESv2.dll    .           || exit /b 1
  copy /y ..\mesa-zink-%MESA_ARCH%\lib\libGLESv2.lib    .           || exit /b 1
  %SZIP% a -mx=9 -mqs=on ..\mesa-zink-%MESA_ARCH%-%MESA_VERSION%.7z || exit /b 1
  popd

  mkdir archive-dzn-%MESA_ARCH%
  pushd archive-dzn-%MESA_ARCH%
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\dxil.dll                        . || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\vulkan_dzn.dll                  . || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\dzn_icd.%TARGET_ARCH_NAME%.json . || exit /b 1
  %SZIP% a -mx=9 -mqs=on ..\mesa-dzn-%MESA_ARCH%-%MESA_VERSION%.7z        || exit /b 1
  popd

  mkdir archive-mft-%MESA_ARCH%
  pushd archive-mft-%MESA_ARCH%
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\msh264enchmft.dll          . || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\msh265enchmft.dll          . || exit /b 1
  copy /y ..\mesa-d3d12-%MESA_ARCH%\bin\msav1enchmft.dll           . || exit /b 1
  %SZIP% a -mx=9 -mqs=on ..\mesa-mft-%MESA_ARCH%-%MESA_VERSION%.7z   || exit /b 1
  popd

  echo MESA_VERSION=%MESA_VERSION%>>"%GITHUB_OUTPUT%"
  echo LLVM_VERSION=%LLVM_VERSION%>>"%GITHUB_OUTPUT%"
  echo LLVM_RELEASE=%LLVM_RELEASE%>>"%GITHUB_OUTPUT%"
)

echo Done^^!

goto :eof


:get
rem arguments <url> <folder> <sha256>
set URL=%~1
set FILENAME=%~nx1
set FOLDER=%~2
set SHA256=%~3

if exist "%FOLDER%" goto :eof

if not exist "%FILENAME%" (
  echo Downloading %FILENAME%
  curl.exe -sfLo "%FILENAME%" "%URL%" || exit /b 1
)

echo Checking %FILENAME% sha256
for /f "tokens=*" %%s in ('certutil.exe -hashfile "%FILENAME%" sha256 ^| findstr /v hash') do (
  if "%%s" neq "%SHA256%" (
    echo SHA256 hash mismatch for %FILENAME%
    echo Expected: %SHA256%
    echo Actual:   %%s
    exit /b 1
  )
)

echo Unpacking %FILENAME%
tar.exe -xf "%FILENAME%" || exit /b 1

goto :eof
