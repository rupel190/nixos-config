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
    "drm.debug=0x02" # Enable DRM driver debug
    "amdgpu.halt_if_hws_hang=0"

    # "pcie_aspm=off"
    # Attempt to enhance GPU stability and fix coredumps through better recovery and power management
    # "amdgpu.noretry=0"
    # "amdgpu.halt_if_hws_hang=0"
    # "amd_pstate=guided"

    # New fix attempts

    # Power Management (try passive for better stability)
    "amd_pstate=passive"

    # PCIe Stability
    # "pcie_aspm=off"
    # "pci=noaer"  # Disable PCIe Advanced Error Reporting that can cause hangs

    # RDNA 4 stability
    "amdgpu.ppfeaturemask=0xfffd7fff" # Default features minus overdrive (bit 14)
    "amdgpu.gfxoff=0" # Disable GfxOff - was failing during PCIe bus dropout crashes

    # Watchdog to force reboot on hard freeze
    "nmi_watchdog=1"

    # "softlockup_panic=1"
    # "hardlockup_panic=1"
  ];
}
