{ config, ... }:
{
  # Frame-time overlay. gamescope's --mangoapp runs this compositor-side rather
  # than as a Vulkan layer inside pressure-vessel, which is what makes it work
  # under Proton here at all.
  programs.mangohud = {
    enable = true;
    settings = {
      # GTA V puts its control prompts and mission text top-left, so the HUD
      # goes bottom-right where the game draws nothing.
      position = "bottom-right";
      font_size = 20;
      # Bound explicitly rather than relying on MangoHud's default, so hiding
      # the overlay is discoverable. Logging is separate and keeps running.
      toggle_hud = "Shift_R+F12";

      # Capped in the game's own present path. gamescope's --framerate-limit is
      # a vblank divisor and measurably did NOT hold (mean 139fps against a
      # nominal 120, frames under 8.33ms), while still interposing on
      # presentation -- GTA V couples physics to frame delivery, so a limiter
      # that perturbs pacing without capping is worse than none. Drop
      # --framerate-limit from the launch options; do not run both.
      fps_limit = 120;

      fps = true;
      frametime = true;
      frame_timing = 1;
      gpu_stats = true;
      gpu_temp = true;
      gpu_power = true;
      gpu_core_clock = true;
      gpu_mem_clock = true;
      cpu_stats = true;
      cpu_temp = true;
      vram = true;
      ram = true;

      # One row per frame: an average cannot separate "slower but even" from
      # "same average, badly spaced", which is the only question worth asking.
      output_folder = "${config.home.homeDirectory}/games/mangohud-logs";
      log_interval = 0;
      log_duration = 7200;
      autostart_log = 15;
      toggle_logging = "Shift_L+F2";
    };
  };
}
