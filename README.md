# mesa builds

Automatic builds of [mesa][] OpenGL & Vulkan implementations for Windows (x86, x64, arm64).

Builds are **static** linked to their dependencies, just place necessary dll file(s) next to your exe.

# Download

Binaries available as 7z archive in [latest release][] page. Following builds are provided:

* [llvmpipe][] - software implementation of OpenGL using [LLVM][]
* [d3d12][] - [Collabora & Microsoft][collabora-d3d12] implementation of OpenGL using D3D12
* [zink][] - [Collabora][collabora-zink] implementation of OpenGL using Vulkan
* [lavapipe][] - software implementation of Vulkan using [LLVM][]
* dzn - Microsoft implementation of Vulkan using D3D12
* [mft][] -  hardware accelerated video encoders for AVC, HEVC and AV1 using D3D12

# Using OpenGL

All OpenGL implementations (llvmpipe, d3d12, zink) come in two flavors:

* `opengl32.dll` file - use [WGL][] to create GL context
* `libEGL.dll` file - use [EGL][] to create GL context

Both options support creating context for full [OpenGL][GL] (core and compatibility), and [OpenGL ES][GLES] v1/2/3.

Core context for OpenGL on WGL can be created as usual, with [WGL_ARB_create_context][] extension.

To create OpenGL ES context on WGL use [WGL_EXT_create_context_es2_profile][] extension. 

Latest EGL, WGL, OpenGL and OpenGL ES headers can be downloaded from their registries on khronos website:

* https://registry.khronos.org/EGL/
* https://registry.khronos.org/OpenGL/index_gl.php#headers
* https://registry.khronos.org/OpenGL/index_es.php#headers

# Using EGL

When using `libEGL.dll` you should query GL and GLES entry points dynamically with [eglGetProcAddress][] function.

With EGL you can also access GLES functions from `libGLESv1_CM.dll` or `libGLESv2.dll` files (by linking to .lib or
dynamic loading at runtime) - but this is optional. When using [eglGetProcAddress][] these dll files are not needed
at all, only `libEGL.dll` is necessary.

Be careful **NOT** to link with `opengl32.dll` file when using EGL - in such case GL calls won't work or simply crash!

With EGL you can use [EGL_MESA_platform_surfaceless][] extension with [eglGetPlatformDisplay][] function to create
offscreen context without dependency on any windowing system.

# Using lavapipe/dzn for Vulkan

To use Vulkan implementations, set [VK_DRIVER_FILES][] env variable to `dzn_icd.x86_64.json` or `lvp_icd.x86_64.json`

# Using MFT video encoders

To use MFT encoders use `regsvr32.exe` on binaries to register encoders globally in the system, then they will be
available using regular MFT encoder enumeration. Alternatively use [DllGetClassObject][] export from dll files to
create [IClassFactory][] object that provides [IClassFactory::CreateInstance][] method to create MFT encoder COM
object explicitly. For CLSID guids for encoders see [this file][mft-guids].

# Building locally

First make sure you have installed all necessary depenendencies:

* [Python][] - with [pip][] for installing `meson`, `packaging`, `mako` and `yaml` packages if they are missing
* [Visual Studio 2022][] (or 2026) - with [Desktop development with C++][workload] workload installed
* [7-Zip][] - either full installer, or just `7za.exe` file from "7-Zip Extra" archive
* [CMake][]
* [Git][]
* [ninja.exe][] - will be automatically downloaded if missing
* `tar.exe` and `curl.exe` - nowadays comes with [Windows 10/11][curl.exe]

Then run `build.cmd` batch file when these tools are installed. It accepts optional argument specifying architecture:

* `build.cmd x86` - for 32-bit Windows
* `build.cmd x64` - for 64-bit Windows
* `build.cmd arm64` - for Windows on ARM64, for example to use on Qualcomm Snapdragon X Elite devices

Output files will be placed in `mesa-[name]-[arch]` folders.

[mesa]: https://www.mesa3d.org/
[LLVM]: https://llvm.org/
[llvmpipe]: https://docs.mesa3d.org/drivers/llvmpipe.html
[lavapipe]: https://vulkan.org/user/pages/09.events/vulkanised-2025/T5-Lucas-Fryzek-Igalia.pdf
[d3d12]: https://docs.mesa3d.org/drivers/d3d12.html
[zink]: https://docs.mesa3d.org/drivers/zink.html
[collabora-d3d12]: https://www.collabora.com/news-and-blog/news-and-events/introducing-opencl-and-opengl-on-directx.html
[collabora-zink]: https://www.collabora.com/news-and-blog/blog/2018/10/31/introducing-zink-opengl-implementation-vulkan/
[latest release]: https://github.com/mmozeiko/build-mesa/releases/latest
[WGL]: https://learn.microsoft.com/en-us/windows/win32/opengl/wgl-functions
[EGL]: https://www.khronos.org/egl
[GL]: https://www.khronos.org/opengl/
[GLES]: https://www.khronos.org/opengles/
[eglGetProcAddress]: https://registry.khronos.org/EGL/sdk/docs/man/html/eglGetProcAddress.xhtml
[WGL_EXT_create_context_es2_profile]: https://registry.khronos.org/OpenGL/extensions/EXT/WGL_EXT_create_context_es2_profile.txt
[WGL_ARB_create_context]: https://registry.khronos.org/OpenGL/extensions/ARB/WGL_ARB_create_context.txt
[EGL_MESA_platform_surfaceless]: https://registry.khronos.org/EGL/extensions/MESA/EGL_MESA_platform_surfaceless.txt
[eglGetPlatformDisplay]: https://registry.khronos.org/EGL/sdk/docs/man/html/eglGetPlatformDisplay.xhtml
[VK_DRIVER_FILES]: https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderDriverInterface.md#driver-discovery
[Python]: https://www.python.org/downloads/
[pip]: https://packaging.python.org/en/latest/tutorials/installing-packages/#ensure-you-can-run-pip-from-the-command-line
[Visual Studio 2022]: https://visualstudio.microsoft.com/downloads/
[workload]: https://learn.microsoft.com/en-us/cpp/build/vscpp-step-0-installation?view=msvc-170#step-4---choose-workloads
[CMake]: https://cmake.org/download/
[7-Zip]: https://www.7-zip.org/
[Git]: https://git-scm.com/downloads/win
[curl.exe]: https://techcommunity.microsoft.com/blog/containers/tar-and-curl-come-to-windows/382409
[ninja.exe]: https://ninja-build.org/
[mft]: https://learn.microsoft.com/en-us/windows/win32/medfound/media-foundation-transforms
[DllGetClassObject]: https://learn.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-dllgetclassobject
[IClassFactory]: https://learn.microsoft.com/en-us/windows/win32/api/unknwn/nn-unknwn-iclassfactory
[IClassFactory::CreateInstance]: https://learn.microsoft.com/en-us/windows/win32/api/unknwn/nf-unknwn-iclassfactory-createinstance
[mft-guids]: https://gitlab.freedesktop.org/mesa/mesa/-/blob/mesa-25.3.0/src/gallium/targets/mediafoundation/dllmain.cpp?ref_type=tags#L35-45
