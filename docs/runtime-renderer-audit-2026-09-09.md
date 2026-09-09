# NextGen-OTC runtime and renderer audit — 2026-09-09

## Executive decision

Keep the current C++/Lua/OTUI architecture. Do not rewrite the client in Qt/QML.
Treat Vulkan as experimental, ANGLE as the current DirectX compatibility path,
and native DirectX 12 as a new renderer project with explicit parity tests.

The supplied crash reports show a repeatable client access violation after login,
not merely a random failure of the tester's computer. The old crash reporter did
not record a usable module-relative address; commit `27eb4ee` repairs that
diagnostic path. A fresh crash from a binary produced after that commit is needed
to locate and fix the underlying instruction.

## Evidence from the supplied logs

- Four access violations occurred in two pairs at equivalent-looking executable
  addresses after login/game-start processing. That repeatability points to a
  client defect or client/data interaction.
- Assets completed loading successfully. The missing
  `assets.json.sha256` warning should be fixed in packaging, but it is not evidence
  that asset verification caused these particular crashes.
- The old stack trace printed literal printf placeholders such as `%016lX`.
  Consequently, the historical absolute addresses cannot be mapped reliably to
  source under ASLR. The repaired reporter now records operation, fault address,
  module base, RVA, symbol and source line when available.
- The log also exposed a double-destroy warning for `eventScheduleButton`; its
  termination path is now guarded.
- The distributed minimap URL pointed at `127.0.0.1`, causing avoidable request
  failures. The invalid default was removed in `27eb4ee`.

## Languages and the official client package

`C:\clients\client-15.30` is a binary distribution, not a source checkout. It
contains 454 `.qml` files plus Qt 6 QML/Quick libraries, so QML is demonstrably
used for its interface. Its compiled core is consistent with a native C++/Qt
application, but the complete source-language composition cannot be proven from
the package alone.

NextGen uses C++ for its engine, Lua for modules and gameplay UI behavior, OTUI
and OTML for declarative interface/configuration, GLSL/SPIR-V for shaders, CMake
and YAML for builds, and Android-specific Java/Kotlin/resources. Moving it to
Qt/QML would be a rewrite of the module and UI ecosystem, not a language swap.
It would not inherently reduce CPU or RAM and would make the current Linux,
macOS, Android and browser work substantially harder. QML remains useful as a
reference for UX behavior or for a separate launcher/tool, not as a runtime
migration target.

## Graphics backends

### OpenGL

OpenGL is the established/default backend and remains the compatibility
baseline against which alternatives must be compared.

### DirectX today

The Visual Studio `DirectX` configuration defines `OPENGL_ES` and links ANGLE's
`libEGL`/`libGLESv2`, plus D3D9/D3D11 support libraries. That is OpenGL ES
translation through ANGLE; it is not a native DirectX 12 renderer. No use of
`ID3D12Device`, `D3D12CreateDevice`, command queues, descriptor heaps or other
D3D12 core APIs exists in the source.

Native DirectX 12 therefore needs a new graphics implementation rather than a
linker flag. A safe delivery sequence is:

1. Define a backend-neutral renderer contract and a deterministic screenshot
   corpus for login, map, lights, shaders, text, clipping, FBO effects and UI.
2. Implement DX12 device/swapchain, resource upload, descriptor management,
   pipelines, command lists, synchronization and recovery from device loss.
3. Add shader compilation/caching and reproduce all blend, clip and temporary
   framebuffer behavior.
4. Add an opt-in CI build and runtime smoke test; keep OpenGL as fallback until
   visual and long-session parity is measured.

Microsoft's primary documentation for this work is the
[Direct3D 12 programming guide](https://learn.microsoft.com/windows/win32/direct3d12/directx-12-programming-guide).

### Vulkan

Vulkan support is real but incomplete and Windows-only today: the client loads
`vulkan-1.dll`, creates the instance/device/swapchain, records command buffers,
uses SPIR-V shaders and presents frames. It is correctly opt-in with OpenGL
fallback.

It cannot yet be described as feature-complete. The current feeder skips legacy
OpenGL action callbacks, ignores some shader/effect operations, substitutes the
normal blend mode for unsupported modes, cannot reproduce every temporary-FBO
clip path, and can omit objects that only have an OpenGL texture handle. It
needs the same screenshot corpus and gameplay soak tests proposed for DX12.

The `vulkan-memory-allocator` package had no call site in the repository and was
removed from the dependency manifest; `vulkan-headers` remains required.

## CPU and memory findings

The supplied log sampled private memory from about 679 MB up to about 1.98 GB;
this is a real client-side peak. Lua accounted for only tens of MB. At the peak,
Thing textures were roughly 339 MB and the map atlas selected 8192x8192. A
single RGBA 8192 atlas layer can occupy roughly 256 MiB before driver overhead,
so atlas/textures are the first measurement target.

Do not blindly force a 4096 atlas: it may create more layers, uploads and draw
calls. Benchmark 4096 versus 8192 on the same route and hardware, recording
private bytes, GPU dedicated/shared memory, frame time percentiles, atlas layer
count and upload count. Then add an automatic budget or hardware-aware choice.

Other high-value candidates:

- Adapt Astra [PR #147](https://github.com/Mateuzkl/AstraClient/pull/147), which
  narrows colorized-loot widget refreshes instead of repeatedly scanning a broad
  UI tree.
- Evaluate OTBR [PR #1794](https://github.com/opentibiabr/otclient/pull/1794)
  with regression tests. It invalidates stale negative Lua-event lookups when
  handlers are connected late; it must distinguish class tables from userdata.
- Do not port OTBR [PR #1824](https://github.com/opentibiabr/otclient/pull/1824):
  NextGen already compiles its automatic statistics out unless stats are enabled.
- Add a manual/nightly AddressSanitizer job for crash hunting instead of making
  every normal push pay its compile/runtime cost.

## On-demand modules and the reported “timestamp” optimization

The description corresponds to lazy loading plus a delayed-unload/idle timeout:
load a feature when first opened, retain it briefly for fast reopen, then unload
it after a quiet period.

NextGen already has `Module::load`, `Module::unload` and
`ensureModuleLoaded`, so the engine foundation exists. However, unloading Lua
code alone does not reclaim resources retained by global callbacks, scheduled
events, widgets, textures, dispatcher closures or references from other modules.
That is why a generic timer applied to all 95 module definitions would be risky.

Recommended pilot:

1. Instrument per-module load time and memory delta.
2. Select one isolated, heavy, infrequently used feature such as Wheel of
   Destiny; keep login, game interface, protocol, map, console and options
   resident.
3. Give it an explicit lifecycle contract: no open window, no pending request,
   no game callback and no dependent module before unloading.
4. Use an idle timeout (for example 30–60 seconds), cancel it on reopen, and
   verify every event/widget/resource is released.
5. Compare cold open, warm reopen, RAM, CPU and crash behavior. Generalize only
   after the pilot shows a net win.

A claim of approximately 200 MB while actively playing is not transferable
without matching assets, resolution, atlas size, enabled modules and measurement
method. The mechanism is plausible, but the number is not evidence by itself.

## HD mode and minimap

NextGen's HD minimap is a version-specific satellite-map system, not the same
implementation as Astra's proposals. It loads chunks on demand and caps cached
chunks, which is directionally good, but the repository only packages satellite
data for client version 1530.

Astra [PR #132](https://github.com/Mateuzkl/AstraClient/pull/132) is a large,
still-open sparse HD minimap/cache design with unresolved integration risk;
[PR #133](https://github.com/Mateuzkl/AstraClient/pull/133) is an alternative
classic/raster synchronization approach. Neither should be copied wholesale.
The next diagnostic needs the exact symptom and a screenshot while toggling HD
minimap, followed by chunk-coordinate/cache logging. Classic minimap behavior
must remain the regression baseline.

## OTUI editor

The current editor originated from the OTBR implementation. Astra's merged
[PR #119](https://github.com/Mateuzkl/AstraClient/pull/119) is the strongest
upgrade source: it adds undo/redo, dirty-document confirmation, stronger cleanup,
state editing and gallery improvements. It uses different toolbar, keybinding and
autoload APIs, so an incremental port is safer than replacing the file.

Delivery order:

1. Undo/redo, dirty-close/reload confirmation and lifecycle cleanup.
2. State/style gallery improvements and mixed-line-ending safeguards.
3. Schema-aware diagnostics, autocomplete and go-to-style/source.
4. Headless tests plus a manual editor workflow on a Debug build.

## CI and Windows compatibility

Run [34323277229](https://github.com/JV-071/NextGen-OTC/actions/runs/34323277229)
confirmed Linux Release/Debug, macOS, Android and browser compilation. CMake
Release/Debug failed because `cpp-httplib` 0.53 rejects the global Windows 8
target; Docker failed because its builder omitted Python 3.

The current cpp-httplib README explicitly says Windows 8 and lower are neither
supported nor tested ([upstream documentation](https://github.com/yhirose/cpp-httplib#readme)).
Therefore normal Windows builds now use the SDK default, while a dedicated
Windows Server job explicitly targets Windows 10 APIs and runs on Windows Server
2022. This establishes a defensible Windows Server 2016+ baseline. Supporting
Server 2012 safely requires replacing or maintaining a tested legacy HTTP layer;
silencing the upstream guard or pinning an old security-sensitive dependency is
not accepted as proof of compatibility.

Release and RelWithDebInfo are GUI-subsystem executables and do not open a
console window. Debug is console-subsystem for diagnostics. Visual Studio Debug
now follows the same rule.

## Prioritized backlog

### P0

- Obtain one fresh crash report from `27eb4ee` or newer with the matching PDB,
  then symbolicate the RVA and fix the actual post-login crash.
- Keep the complete CI matrix green after the Windows/Server separation.

### P1

- Build renderer screenshot baselines; label Vulkan experimental in user-facing
  settings; start DX12 behind an opt-in build/runtime flag.
- Benchmark atlas sizes and texture/cache budgets before changing defaults.
- Port OTBR #1794 with focused Lua-event tests.
- Pilot delayed unloading on one isolated module with resource-leak assertions.

### P2

- Adapt Astra #147 and the first safe phase of Astra #119.
- Diagnose the exact HD-minimap symptom and compare Astra approaches without
  changing the persisted map format prematurely.
- Ship the expected asset-signature metadata or make its absence explicitly
  non-warning for unsigned development packages.
