# Linux Lab on CNB — Structured Implementation Plan

## Goal Description

Build a Docker + QEMU based Linux development platform running on CNB (Tencent Cloud Native Build) Cloud IDE. The platform enables one-click boot for ARM (vexpress-a9), RISC-V (virt), and x86_64 boards, targeting teaching/learning and kernel development/debugging scenarios. Users interact via Makefile CLI and dialog-based TUI. The entire environment runs inside a custom Docker image used as the CNB Cloud IDE base, with no Docker-in-Docker dependency.

## Acceptance Criteria

Following TDD philosophy, each criterion includes positive and negative tests for deterministic verification.

- AC-1: Makefile framework correctly loads board configurations and dispatches targets
  - Positive Tests (expected to PASS):
    - `make help` prints formatted help text listing all targets
    - `make info BOARD=arm/vexpress-a9` shows ARM board config with QEMU_MACHINE=vexpress-a9
    - `make info BOARD=riscv/virt` shows RISC-V board config with QEMU_SYSTEM=qemu-system-riscv64
    - `make info BOARD=x86_64/pc` shows x86_64 config with KERNEL_IMAGE=bzImage
    - `make list-boards` lists all three boards with descriptions
    - `make list-kernels BOARD=arm/vexpress-a9` shows "5.15 6.1 6.6"
  - Negative Tests (expected to FAIL):
    - `make info BOARD=nonexistent/board` fails with include error
    - `make info BOARD=arm/vexpress-a9 KERNEL=9.9` gracefully handles missing kernel config

- AC-2: Board configuration system supports declarative .mk files for all three architectures
  - Positive Tests (expected to PASS):
    - Each board directory contains board.mk, rootfs.mk, and at least two kernel-*.mk files
    - All board.mk files define required variables: BOARD_ARCH, QEMU_SYSTEM, QEMU_MACHINE, KERNEL_DEFAULT, KERNEL_SUPPORTED
    - `.linux-lab.conf` overrides board defaults when present (e.g., custom KERNEL_SRC path)
    - CLI variable `KERNEL=6.1` overrides both .linux-lab.conf and board defaults
  - Negative Tests (expected to FAIL):
    - A board.mk file with syntax errors causes make to report a clear error
    - Missing required variables in board.mk causes dependent targets to fail with actionable messages

- AC-3: Kernel management handles download, patching, configuration, and out-of-tree build
  - Positive Tests (expected to PASS):
    - `make kernel-download KERNEL=6.6` downloads tarball to `src/linux-6.6/` with checksum verification
    - `make kernel-config BOARD=arm/vexpress-a9 KERNEL=6.6` generates `.config` in `output/arm/vexpress-a9/linux-6.6/`
    - `make kernel-build` performs out-of-tree build using `make O=` and CROSS_COMPILE
    - `make kernel-build KERNEL_SRC=/custom/path` uses the specified external kernel source
    - Patches in `patches/linux/common/` and `patches/linux/6.6/` are applied in correct order
    - Same kernel source shared across different boards (out-of-tree isolation)
  - Negative Tests (expected to FAIL):
    - `make kernel-build` before `kernel-download` either auto-downloads (boot target) or fails with hint (qemu-boot target)
    - Download from invalid mirror URL falls back to alternate mirror
    - Corrupted download fails SHA256 verification with clear error

- AC-4: Rootfs management provides prebuilt cpio images and Buildroot integration
  - Positive Tests (expected to PASS):
    - `make rootfs-prepare` copies prebuilt rootfs and applies overlay files
    - Rootfs overlay includes working inittab, rcS, passwd, fstab
    - `make rootfs-modules` injects kernel modules into existing rootfs.cpio.gz
    - `ROOTFS_IMAGE=/path/to/custom.cpio.gz` uses custom rootfs image directly
    - `make rootfs-build` triggers Buildroot build when src/buildroot submodule is initialized
  - Negative Tests (expected to FAIL):
    - `make rootfs-build` without Buildroot submodule fails with clear init instructions
    - Overlay files applied exactly once (no double-application)

- AC-5: QEMU boot assembles correct parameters from board config and starts virtual machine
  - Positive Tests (expected to PASS):
    - `make qemu-boot` assembles and executes correct QEMU command for each board
    - Pre-boot validation checks kernel image, rootfs, QEMU binary, and DTB existence
    - `make boot` performs full autonomous flow: download → build → prepare → boot
    - `make qemu-debug` appends `-s -S` flags for GDB debugging
    - `make debug` launches gdb-multiarch with correct architecture and remote target
    - `QEMU_EXTRA="-smp 2"` appends additional QEMU arguments
  - Negative Tests (expected to FAIL):
    - `make qemu-boot` with missing kernel image fails with "Run make kernel-build" hint
    - `make qemu-boot` with missing rootfs fails with "Run make rootfs-prepare" hint

- AC-6: TUI provides interactive board selection, management menus, and board creation wizard
  - Positive Tests (expected to PASS):
    - `make tui` launches dialog-based main menu with 6 options
    - Board selection flow: architecture → board → kernel version → confirm → boot
    - Board creation wizard generates valid board.mk, kernel-*.mk, rootfs.mk files
    - Generated board configs use correct arch-specific defaults (kernel image name, serial device)
    - All TUI submenu actions correctly dispatch to corresponding Makefile targets
  - Negative Tests (expected to FAIL):
    - Creating a board with an existing name shows error message
    - TUI gracefully handles missing dialog/whiptail with clear install instructions

- AC-7: Docker image builds successfully with all tools pre-installed
  - Positive Tests (expected to PASS):
    - `docker build .` completes without errors
    - Built image contains qemu-system-arm, qemu-system-riscv64, qemu-system-x86_64
    - Built image contains ARM and RISC-V cross-compilation toolchains in /opt/toolchains/
    - Built image contains prebuilt rootfs images for ARM architecture
    - Built image contains dialog, gdb-multiarch, fakeroot, and all kernel build dependencies
  - Negative Tests (expected to FAIL):
    - Image does not contain unnecessary packages or bloat beyond specified tools

- AC-8: CNB integration provides pipeline config and Cloud IDE configuration
  - Positive Tests (expected to PASS):
    - `.cnb.yml` defines build-image and test-image stages
    - `.ide.yaml` specifies correct image, resource limits (4 CPU, 8Gi RAM, 50Gi disk), and port mappings
    - `scripts/cnb-detect.sh` correctly identifies CNB environment and disables KVM
    - `scripts/welcome.sh` displays quick-start guide on IDE startup
  - Negative Tests (expected to FAIL):
    - CNB detection does not interfere when running outside CNB (non-CNB environments work normally)

- AC-9: All shell scripts pass shellcheck and smoke tests pass
  - Positive Tests (expected to PASS):
    - `shellcheck scripts/*.sh scripts/tui/*.sh` reports no errors
    - `tests/smoke-test.sh` passes all checks (make targets, board configs, script syntax)
    - `make boot-test` performs automated smoke test with login prompt detection
  - Negative Tests (expected to FAIL):
    - Scripts with syntax errors are caught by shellcheck

- AC-10: Git submodules for QEMU and Buildroot are correctly configured
  - Positive Tests (expected to PASS):
    - `.gitmodules` references QEMU and Buildroot repositories
    - `make check-submodules` auto-initializes submodules if not present
    - `make qemu-build` compiles QEMU from submodule source for all three target architectures
    - `make qemu-export-patches` exports modifications as patches
  - Negative Tests (expected to FAIL):
    - Targets depending on submodules fail gracefully with init instructions when submodules are empty

## Path Boundaries

Path boundaries define the acceptable range of implementation quality and choices.

### Upper Bound (Maximum Acceptable Scope)

The implementation includes all 20 tasks from the draft plan: project skeleton with git submodules, board configurations for all three architectures (ARM vexpress-a9, RISC-V virt, x86_64 PC), complete Makefile framework with variable override chain, all core scripts (kernel.sh, rootfs.sh, qemu.sh, debug.sh, toolchain.sh, cnb-detect.sh, welcome.sh), full TUI with all 6 main menu items including board creation wizard, multi-stage Dockerfile with prebuilt rootfs, CNB pipeline and Cloud IDE configuration, bilingual documentation (zh/en), and smoke test suite. All scripts pass shellcheck. The `make boot` command performs fully autonomous end-to-end flow.

### Lower Bound (Minimum Acceptable Scope)

The implementation includes the project skeleton, ARM vexpress-a9 board configuration, base Makefile framework, common script library, kernel management script, rootfs management script (with prebuilt cpio), QEMU boot script, and a basic smoke test. This enables `make boot BOARD=arm/vexpress-a9` to work end-to-end. TUI, additional boards, Dockerfile, CNB config, and documentation can be deferred.

### Allowed Choices

- Can use: GNU Make, Bash (4.x+), dialog or whiptail for TUI, wget or curl for downloads, fakeroot + cpio for rootfs, POSIX shell utilities
- Can use: Bootlin or Linaro prebuilt toolchains, or any self-contained cross-compilation toolchain
- Can use: Ubuntu 24.04 or Debian bookworm as Docker base image
- Cannot use: Docker-in-Docker, KVM-dependent features, Python or other languages for core scripts (Bash only)
- Cannot use: Non-free or proprietary toolchains
- Fixed per spec: QEMU built from source (submodule), Buildroot as submodule, kernel downloaded on demand, cpio/initramfs as default rootfs format

## Feasibility Hints and Suggestions

> **Note**: This section is for reference and understanding only. These are conceptual suggestions, not prescriptive requirements.

### Conceptual Approach

The implementation follows a bottom-up dependency order:

1. **Foundation layer**: Project skeleton → .gitignore, directory structure, git submodules
2. **Configuration layer**: Board .mk files → declarative configs loaded by Makefile include chain
3. **Framework layer**: Makefile → variable system, config loading, target dispatch to scripts
4. **Engine layer**: Shell scripts → kernel.sh, rootfs.sh, qemu.sh handle actual operations
5. **Interface layer**: TUI scripts → dialog wrappers providing interactive frontend to Makefile targets
6. **Infrastructure layer**: Dockerfile, CNB config → packaging everything for cloud deployment

Each layer depends only on layers below it. The Makefile acts as the central hub — it loads configurations and dispatches to scripts, while scripts are self-contained and use environment variables exported by Make.

Key technical patterns:
- Out-of-tree kernel build (`make O=`) enables source sharing across boards
- `?=` (conditional assignment) in board .mk files enables CLI/env/config override
- `.linux-lab.conf` loaded before board configs, using `:=` to take precedence over `?=`
- QEMU parameter assembly from board config variables, with QEMU_EXTRA for user additions
- `fakeroot + cpio` for rootfs creation without root privileges

### Relevant References

- `docs/superpowers/specs/2026-03-25-linux-lab-cnb-design.md` — Complete design specification
- `docs/superpowers/plans/2026-03-25-linux-lab-cnb.md` — Detailed implementation plan with full code
- Bootlin toolchains: `https://toolchains.bootlin.com` — Prebuilt cross-compilers
- Linux kernel out-of-tree build: `Documentation/kbuild/kbuild.rst` in kernel source

## Dependencies and Sequence

### Milestones

1. **Foundation**: Project skeleton and configuration system
   - Phase A: Create directory structure, .gitignore, initialize git submodules (Task 1)
   - Phase B: ARM vexpress-a9 board configuration (Task 2)
   - Phase C: Rootfs overlay files (Task 3)

2. **Core Framework**: Makefile and shared library
   - Phase A: Common script library — logging, checks, download functions (Task 4)
   - Phase B: Base Makefile — config loading, variable system, all target stubs (Task 5)

3. **Engine Scripts**: Core operational scripts
   - Phase A: Kernel management — download, patch, config, build (Task 6)
   - Phase B: Rootfs management — prebuilt prepare, Buildroot build, modules (Task 7)
   - Phase C: QEMU boot — parameter assembly, boot, debug, smoke test (Task 8)
   - Phase D: GDB debug script (Task 9)
   - Phase E: Toolchain management and CNB detection (Tasks 10-11)

4. **Multi-Architecture**: Additional board support
   - Phase A: RISC-V virt and x86_64 PC board configurations (Task 12)
   - Depends on: Milestone 2 (Makefile must load any board config)

5. **TUI Interface**: Interactive user interface
   - Phase A: TUI framework — dialog wrappers, main menu (Task 13)
   - Phase B: Board selection flow (Task 14)
   - Phase C: Board creation wizard (Task 15)
   - Phase D: Kernel, rootfs, QEMU submenus (Task 16)
   - Depends on: Milestone 3 (TUI dispatches to make targets which call scripts)

6. **Infrastructure**: Docker and CNB deployment
   - Phase A: Multi-stage Dockerfile (Task 17)
   - Phase B: CNB pipeline and Cloud IDE configuration (Task 18)
   - Depends on: Milestones 1-3 (needs to know what tools to install)

7. **Documentation and Testing**: Quality assurance
   - Phase A: Bilingual documentation — zh/en (Task 19)
   - Phase B: Smoke test script (Task 20)
   - Depends on: Milestones 1-5 (documents and tests the completed system)

### Dependency Graph

```
Milestone 1 (Foundation)
    ↓
Milestone 2 (Core Framework)
    ↓
Milestone 3 (Engine Scripts) ← Milestone 4 (Multi-Arch, parallel with M3)
    ↓
Milestone 5 (TUI) ← requires M2 + M3
    ↓
Milestone 6 (Infrastructure) ← requires M1 + M2 + M3
    ↓
Milestone 7 (Docs + Tests) ← requires M1-M5
```

Milestones 3 and 4 can proceed in parallel. Milestone 6 can start after Milestone 3. TUI (M5) requires the engine scripts to be functional.

## Implementation Notes

### Code Style Requirements
- Implementation code and comments must NOT contain plan-specific terminology such as "AC-", "Milestone", "Step", "Phase", or similar workflow markers
- These terms are for plan documentation only, not for the resulting codebase
- Use descriptive, domain-appropriate naming in code instead
- All shell scripts must start with `set -euo pipefail`
- All code comments in English, documentation in both Chinese and English
- Indentation: 4 spaces (no tabs) for shell scripts, tabs for Makefile (required by make)
- Git commits signed with: `Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>`
- No AI co-author lines in commits

### Key Technical Constraints
- CNB Cloud IDE runs inside Docker — no nested Docker, no KVM, no privileged mode
- QEMU operates in pure software emulation (TCG) — x86_64-on-x86_64 is notably slower
- Rootfs must use cpio/initramfs format (no loop device mount available)
- QEMU networking limited to user mode (`-netdev user`)
- Toolchain coexistence via independent prefix installation under `/opt/toolchains/`

--- Original Design Draft Start ---

# Linux Lab on CNB — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Docker + QEMU based Linux development platform on CNB Cloud IDE, enabling one-click boot for ARM/RISC-V/x86_64 boards with interactive kernel development and debugging.

**Architecture:** Declarative board configs (`.mk` files) drive a Makefile that dispatches to shell scripts for kernel management, rootfs preparation, and QEMU boot. A TUI provides interactive board selection and creation. The whole environment runs inside a custom Docker image used as the CNB Cloud IDE base.

**Tech Stack:** GNU Make, Bash, QEMU, Docker, dialog/whiptail (TUI), cross-compilation toolchains (Bootlin/Linaro), Buildroot, Git submodules.

**Spec:** `docs/superpowers/specs/2026-03-25-linux-lab-cnb-design.md`

(Full 20-task implementation plan preserved in `docs/superpowers/plans/2026-03-25-linux-lab-cnb.md`)
