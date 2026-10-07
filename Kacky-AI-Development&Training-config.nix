{ config, pkgs, ... }:

# ============================================================
# AI / LOCAL LLM WORKSTATION
# Tuned for running models locally (Ollama) and GPU compute,
# not for desktop daily-driving. Pair with a thin WM, not KDE,
# if you want every spare MB of VRAM/RAM for models.
# ============================================================

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Use all cores for builds (CUDA-linked packages are heavy to build).
  nix.settings.max-jobs = "auto";
  nix.settings.cores = 0;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-ai";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN.UTF-8";

  # --- Minimal desktop — enough to work in, not a gaming/daily-driver DE ---
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true; # swap for i3/sway if you want it leaner

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  # --- GPU: NVIDIA + CUDA ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = false; # don't let the GPU sleep mid-inference
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # GPU inside containers (for text-generation-webui, vLLM, etc in Docker).
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.enable = true;

  # Force the GPU into persistence mode at boot so there's no clock-ramp
  # delay on the first inference request after idle.
  systemd.services.nvidia-persistenced = {
    description = "NVIDIA Persistence Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-powerd.service" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${pkgs.linuxPackages.nvidia_x11.bin}/bin/nvidia-persistenced --persistence-mode";
      ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-persistenced";
    };
  };

  # --- OLLAMA ---
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    host = "127.0.0.1"; # change to "0.0.0.0" if you want it reachable on your LAN
    port = 11434;
    # Pulled automatically on first activation. Swap/add tags as you like —
    # "hermes3" is Nous Hermes 3; check `ollama list`/ollama.com for exact tags.
    loadModels = [
      "hermes3"
      "hermes3:8b"
    ];
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "30m"; # keep model resident longer between requests
      OLLAMA_NUM_PARALLEL = "2";
    };
  };

  # If you want it reachable on your LAN, open the port explicitly
  # instead of binding to 0.0.0.0 blind — safer default.
  networking.firewall.allowedTCPPorts = [ ]; # add 11434 here if host = "0.0.0.0"

  # --- Open WebUI (optional chat frontend for Ollama) ---
  # Uncomment if you want a browser UI instead of the CLI / API.
  # services.open-webui = {
  #   enable = true;
  #   port = 8080;
  #   environment = { OLLAMA_BASE_URL = "http://127.0.0.1:11434"; };
  # };

  # --- MEMORY / SWAP TUNING ---
  # Large models can spike RAM during load even when they mostly run on
  # GPU; zram keeps the box from hard-locking instead of OOM-killing.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  boot.kernel.sysctl = {
    "vm.overcommit_memory" = 1; # some ML loaders expect this
    "vm.swappiness" = 10;
  };
  boot.kernelParams = [ "transparent_hugepage=always" ];

  # Raise file descriptor / mmap limits — large model weight files and
  # multi-GPU IPC both want headroom here.
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "1048576"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "1048576"; }
  ];

  users.users."youruser" = {
    isNormalUser = true;
    description = "youruser";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" ];
  };

  environment.systemPackages = with pkgs; [
    # GPU monitoring
    nvtopPackages.nvidia
    glances

    # Model / dataset tooling
    git
    git-lfs
    wget
    curl
    jq
    ripgrep

    # Python ML environment — use uv/pip for torch+cuda wheels rather than
    # nixpkgs' python3Packages.torch; it tracks CUDA versions far faster
    # than nixpkgs does and avoids multi-hour source builds.
    python3
    uv

    # Local inference / serving alternatives alongside Ollama
    llama-cpp

    # Hugging Face CLI for pulling models/datasets directly
    (python3.withPackages (ps: with ps; [ huggingface-hub ]))

    kitty
    neovim
    btop
  ];

  system.stateVersion = "26.05";
}
