# NextGen platform builds

The main client is NextGen-OTC. The new workflows build its own source and
runtime modules; they do not substitute executables from another fork.

## Outputs and requirements

| Target | Output | Runtime requirement / validation still needed |
| --- | --- | --- |
| Windows / Windows Server | Existing Windows workflows | Test the new editor with a rebuilt executable |
| Linux x64 | `NextGen-OTC-linux-release` | Ubuntu 24.04-compatible environment; OpenGL, GLEW, X11 and audio system libraries |
| macOS arm64 | `NextGen-OTC-macos-release` | XQuartz: NextGen currently uses X11/OpenGL, not CrystalOTC's Cocoa/Metal backend |
| Android | `NextGen-OTC-android-release` | Four ABIs from Gradle; development-signed APK, not a store release |
| Browser | `NextGen-OTC-browser-release` | HTTP server with COOP/COEP headers for SharedArrayBuffer; WebSocket-compatible game transport |

The workflow configuration is not proof of a working runtime. Confirm successful
compilation and test startup, login, UI, sound and gameplay on each target.
Linux/macOS packages include loose tracked runtime files. Large `data/things`
assets excluded from Git must be supplied separately. The macOS package is not
notarized and currently requires XQuartz, rather than being a self-contained app.
Android CI creates a development signing key when absent; APKs signed by different
runs may require uninstalling the previous test APK. Do not use these keys for a
production release.

For browser testing, the repository provides `tools/emscripten-web-serve.py`.
Opening the HTML using `file://` is insufficient. Browser TCP restrictions cannot
be fixed by compiling an existing native client to WebAssembly.

## Caches

The Linux/macOS/browser workflow saves vcpkg binary packages and downloads,
plus ccache compiler objects. Android saves these, Gradle dependencies/build
cache, and the LuaJIT libraries for all four ABIs. Emscripten is pinned to 6.0.9
and cached separately. Dependency/compiler saves run even after compilation
fails, preserving packages successfully built before the failure.

These ccache builds disable precompiled headers, avoiding a PCH configuration
that ccache cannot reuse without relaxed timestamp/macro checks. Windows uses
sccache. Windows and Windows Server share compatible vcpkg binary archives;
their compiler settings still determine which objects can be reused.
When precompilation is disabled, CMake still includes the common `pch.h` as an
ordinary header: legacy source files depend on its declarations. Emscripten
toolchain snapshots are also saved after a failed client compilation.

Keys separate operating systems and target architectures. vcpkg additionally
checks package ABI hashes; ccache checks source/compiler/options. Every run gets
a new cache snapshot so an incomplete first build cannot freeze the cache.
GitHub cache eviction and compiler/dependency changes can cause another cold
build. Cross-repository cache reuse is not configured; ordinary Actions caches
belong to their repository. Windows objects cannot be linked into the other
platforms. CI logs include compiler-cache statistics for checking actual reuse.

## Sources

- CrystalOTC `cc9298b0`: persistent vcpkg cache approach and exact executable packaging.
- OpenTibiaBR/otclient `dd5641492`: missing browser overlay patches and reference builds.
- Android failure `JV-071/CrystalOTC/actions/runs/34008018231`: forcing system
  binaries made vcpkg use an incompatible CMake for `STRING_ENCODE`.
- Browser failure `JV-071/CrystalOTC/actions/runs/34008018237`: missing protobuf
  patch; NextGen also excluded all `*.patch` files via `.gitignore`.
