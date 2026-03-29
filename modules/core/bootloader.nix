{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 30;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "amdgpu.gpu_recovery=1" # Recover instead of panicking
    "amdgpu.lockup_timeout=10000" # Give it 10 seconds to recover
    # "amdgpu.dc_log=1" # Not a valid param on 6.19+ (ignored)
    # "drm.debug=0x04" # Enable DRM driver debug -> ENABLE ON FREQUENT ISSUES - logs too much otherwise, each frame
    # "drm.debug=0x02" # Enable DRM driver debug
    "amdgpu.halt_if_hws_hang=0"

    # Attempt to enhance GPU stability and fix coredumps through better recovery and power management
    # "amdgpu.noretry=0"
    # "amdgpu.halt_if_hws_hang=0"
    # "amd_pstate=guided"

    # New fix attempts

    # Power Management (try passive for better stability)
    "amd_pstate=passive"

    # PCIe Stability — both igc NIC and amdgpu fell off PCIe bus (device lost from bus, GPU recovery failed)
    # Removed after BIOS update to 3842 (AGESA 1.3.0.0a) — ASPM now handled correctly by firmware
    # "pcie_aspm=off" # igc I226-V and RDNA4 both drop from bus with aggressive ASPM
    # "pci=noaer"  # suppress PCIe AER errors cascading after a device dropout

    # RDNA 4 stability
    "amdgpu.ppfeaturemask=0xffffbfff" # Default features minus overdrive (bit 14 = 0x4000); previous value 0xfffd7fff was wrong (cleared bits 15+17, NOT 14)
    "amdgpu.gfxoff=0" # Disable GfxOff - was failing during PCIe bus dropout crashes
    "amdgpu.runpm=0"  # Disable runtime power management - GPU drops PCIe on display sleep/DPMS
    "amdgpu.mes=0"    # Disable Micro Engine Scheduler - MES fails to respond on ring reset, causing device lost from bus
    "amdgpu.mes_kiq=0" # Disable MES KIQ (Kernel Interface Queue) - separate from mes=0, both needed on RDNA4 GFX1201

    # Watchdog to force reboot on hard freeze
    "nmi_watchdog=1"

    # "softlockup_panic=1"
    # "hardlockup_panic=1"
  ];
}
