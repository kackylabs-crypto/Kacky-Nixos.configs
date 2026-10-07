{ config, pkgs, ... }:

# ============================================================
# GAMING WORKSTATION
# Tuned for frame rate, low input latency, and launcher coverage
# (Steam/Lutris/Heroic). Trades a bit of hardening for performance
# where noted — read the mitigations comment before copying blind.
# ============================================================

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Zen kernel: better desktop/gaming scheduler responsiveness than the
  # default LTS kernel. (For even more, look at the chaotic-cx or
  # cachyos overlays for a cachyos-patched kernel — more setup, bigger gains.)
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # OPTIONAL, read before uncommenting: disables Spectre/Meltdown-class
  # CPU mitigations for a real (several %) FPS gain on some titles.
  # This is a genuine security tradeoff — fine on an isolated gaming box
  # you don't use for banking/work, not fine on a general daily driver.
  # boot.kernelParams = [ "mitigations=off" ];

  # Some newer games (Star Citizen, etc.) need a higher mmap count or they
  # crash on startup.
  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
  };

  networking.hostName = "nixos-gaming";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN.UTF-8";

  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  services.xserver.xkb = { layout = "us"; variant = ""; };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  nixpkgs.config.allowUnfree = true;

  # --- GRAPHICS (NVIDIA shown; swap for amdgpu if that's your card) ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # required for Proton/Wine 32-bit games
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # --- LOW-LATENCY AUDIO ---
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # Lower quantum = lower audio latency. 32/48000 ~0.7ms buffer.
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 32;
        "default.clock.min-quantum" = 32;
      };
    };
  };

  # --- GAMEMODE: on-demand CPU governor / priority boost while playing ---
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        inhibit_screensaver = 1;
      };
      gpu = {
        apply_gpu_optimisations = "accel";
        gpu_device = 0;
        nv_powermizer_mode = 1; # prefer max performance on NVIDIA
      };
      cpu = {
        park_cores = "no";
        pin_cores = "no";
      };
    };
  };

  # --- STEAM + PROTON-GE + CONTROLLER SUPPORT ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true; # Steam Big Picture via gamescope
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  hardware.steam-hardware.enable = true; # Steam Controller, Steam Deck, etc.
  hardware.xone.enable = true; # official Xbox wireless dongle support

  programs.gamescope.enable = true;

  users.users."youruser" = {
    isNormalUser = true;
    description = "youruser";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  services.flatpak.enable = true; # Bottles, Heroic, etc. often ship as flatpaks too

  environment.systemPackages = with pkgs; [
    # Launchers
    lutris
    heroic # Epic Games / GOG
    bottles
    wineWowPackages.stable
    winetricks

    # Performance overlay / monitoring
    mangohud
    gamescope
    nvtopPackages.nvidia
    btop

    # GPU tuning GUI (fan curves, OC) — NVIDIA users mostly want
    # nvidia-settings instead; corectrl shines more on AMD.
    corectrl

    # Streaming / recording
    obs-studio
    discord

    kitty
    neovim
    git
    wget
    curl
  ];

  system.stateVersion = "26.05";
}
