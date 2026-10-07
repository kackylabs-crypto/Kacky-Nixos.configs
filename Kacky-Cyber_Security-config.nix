{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Optional secondary drive. Replace the UUID with your own
  # (`lsblk -f` or `blkid`) or delete this block if you don't need it.
  fileSystems."/mnt/d" = {
    device = "/dev/disk/by-uuid/YOUR-DISK-UUID-HERE";
    fsType = "btrfs";
    options = [ "defaults" "nofail" "compress=zstd" ];
  };

  # --- BOOTLOADER ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- NETWORKING ---
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # --- LOCALE ---
  time.timeZone = "Asia/Kolkata"; # change to your timezone
  i18n.defaultLocale = "en_IN.UTF-8"; # change to your locale
  i18n.supportedLocales = [ "all" ];

  # --- DESKTOP ENVIRONMENT (KDE PLASMA 6, WAYLAND) ---
  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
  };

  # --- SOUND (PIPEWIRE) ---
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # --- GRAPHICS ---
  # NVIDIA block below targets Turing/Ampere (GTX 16xx/RTX 20xx/30xx).
  # Delete or swap for your own vendor if different.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  nixpkgs.config.allowUnfree = true;
  # Enables GPU-accelerated hashcat via the NVIDIA card above.
  # Adds real build/download weight on first rebuild — comment out
  # if you don't need GPU cracking.
  nixpkgs.config.cudaSupport = true;

  # --- GAMING ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # --- USER ACCOUNT ---
  # Replace "youruser" with your actual username.
  users.users."youruser" = {
    isNormalUser = true;
    description = "youruser";
    extraGroups = [
      "networkmanager"
      "wheel"
      "wireshark" # capture packets without sudo
      "libvirtd"  # own/attack lab VMs
      "docker"    # containerised tools & lab targets
    ];
    packages = with pkgs; [ kdePackages.kate ];
  };

  # --- VIRTUALISATION (spin up lab targets to practice against) ---
  virtualisation.libvirtd.enable = true;
  virtualisation.docker.enable = true;
  programs.virt-manager.enable = true;
  programs.wireshark.enable = true;

  # ============================================================
  # HOST HARDENING — always on. Cheap, and this is what actually
  # defends this machine, as opposed to the blue-team tooling
  # below which defends/monitors *other* things.
  # ============================================================
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ]; # open specific ports as you need them
    allowedUDPPorts = [ ];
    logRefusedConnections = true;
  };

  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = false;
  };

  security.auditd.enable = true;
  security.audit.enable = true;
  security.audit.rules = [
    "-w /etc/passwd -p wa -k passwd_changes"
    "-w /etc/shadow -p wa -k shadow_changes"
    "-w /etc/nixos -p wa -k nixos_config_changes"
  ];

  boot.kernel.sysctl = {
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
  };

  # --- Heavy defensive DAEMONS: installed, NOT auto-started ---
  # Keeps the box daily-driveable — no background IDS/AV eating
  # resources while gaming. Start on demand:
  #   sudo systemctl start suricata     (set an interface first)
  #   sudo systemctl start clamav-daemon clamav-freshclam
  #   sudo systemctl start fail2ban
  services.suricata.enable = false;
  services.clamav = {
    daemon.enable = false;
    updater.enable = false;
  };
  services.fail2ban = {
    enable = false;
    maxretry = 5;
  };

  services.flatpak.enable = true;

  # ============================================================
  # SYSTEM PACKAGES — daily driver + offence + defence, one
  # closure. None of this runs in the background by itself;
  # it's CLI tooling you invoke when you need it.
  # ============================================================
  environment.systemPackages = with pkgs; [
    # --- Daily driver / general ---
    nerd-fonts.iosevka
    neovim
    cmatrix
    peaclock
    figlet
    cava
    fastfetch
    kitty
    wget
    git
    curl
    btop
    obs-studio
    vlc
    python3
    rofi
    vscodium
    openssh
    wireguard-tools
    gnupg
    mtr
    whois
    ripgrep
    jq

    # --- OFFENCE (red team) ---
    nmap
    masscan
    nuclei
    wpscan
    nikto
    burpsuite
    sqlmap
    ffuf
    gobuster
    dirb
    zap # OWASP ZAP
    bettercap
    ettercap
    proxychains-ng
    tor
    torsocks
    macchanger
    aircrack-ng
    reaverwps
    john
    hashcat
    hashcat-utils
    hydra
    metasploit
    impacket
    responder

    # --- DEFENCE (blue team) ---
    suricata
    zeek
    ntopng
    wireshark
    tcpdump
    netcat-gnu
    socat
    osquery
    sysdig
    logwatch
    clamav
    rkhunter
    chkrootkit
    aide # file integrity monitoring — run `aide --init` once
    lynis
    sigma-cli

    # --- SHARED: forensics / reverse engineering / analysis ---
    yara
    radare2
    cutter
    ghidra
    binwalk
    gdb
    pwndbg
    sleuthkit
    autopsy
    testdisk
    foremost
    exiftool
    volatility3
    steghide

    # --- Python offsec/defsec tooling ---
    (python3.withPackages (ps: with ps; [
      pwntools
      requests
      scapy
      yara-python
    ]))
  ];

  system.stateVersion = "26.05";
}
