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

    # RDNA 4: amdgpu.mes/mes_kiq/gfxoff aren't params (boot log: "unknown parameter ... ignored"); GfxOff is ppfeaturemask bit 0x8000
    # "amdgpu.runpm=0"  # Disable runtime power management - GPU drops PCIe on display sleep/DPMS (re-enabled after BIOS 3842/AGESA 1.3.0.0a fixed PCIe ASPM)

    # Watchdog to force reboot on hard freeze
    "nmi_watchdog=1"

    # "softlockup_panic=1"
    # "hardlockup_panic=1"
  ];
}
