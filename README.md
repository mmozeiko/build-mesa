Automatic build of [mesa][] opengl implementations for 64-bit Windows.

Builds are linked statically to their dependencies, just place necessary dll file next to your exe and it will use it.

Download binary builds as zip archive from [latest release][] page. It provides following builds:

* [llvmpipe][] - software implementation of opengl using llvm jit
* [osmesa][] - off-screen software rendering implementation using llvmpipe
* [d3d12][] - [Collabora & Microsoft][collabora] implementation of opengl using D3D12

To build locally run `build.cmd` batch file, make sure you have installed all necessary dependencies (see the beginning of file).

[mesa]: https://www.mesa3d.org/
[llvmpipe]: https://docs.mesa3d.org/drivers/llvmpipe.html
[osmesa]: https://docs.mesa3d.org/osmesa.html
[d3d12]: https://docs.mesa3d.org/drivers/d3d12.html
[collabora]: https://www.collabora.com/news-and-blog/news-and-events/introducing-opencl-and-opengl-on-directx.html
[latest release]: https://github.com/mmozeiko/build-mesa/releases/latest
