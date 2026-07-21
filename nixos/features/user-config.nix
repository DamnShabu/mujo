{
  flake.nixosModules.user-config = {
    lib,
    pkgs,
    config,
    ...
  }: let
    # ponytail: read the connection secret decrypted by sops-nix (never plaintext)
    connPath = lib.attrByPath ["sops" "secrets" "connection" "path"] null config;
    conn = if connPath != null && builtins.pathExists connPath
           then builtins.fromJSON (builtins.readFile connPath)
           else {};
  in {
    networking.hostName = lib.mkIf (conn ? hostname && conn.hostname != "") conn.hostname;

    environment.sessionVariables = {
      XDG_DESKTOP_DIR = "$HOME/Desktop";
      XDG_DOCUMENTS_DIR = "$HOME/Documents";
      XDG_DOWNLOAD_DIR = "$HOME/Downloads";
      XDG_MUSIC_DIR = "$HOME/Music";
      XDG_PICTURES_DIR = "$HOME/Pictures";
      XDG_PUBLICSHARE_DIR = "$HOME/.local/share/Public";
      XDG_TEMPLATES_DIR = "$HOME/Templates";
      XDG_VIDEOS_DIR = "$HOME/Videos";
    };

    environment.etc."NetworkManager/system-connections/setup-wifi.nmconnection" = lib.mkIf (conn ? wifi_ssid && conn.wifi_ssid != "") {
      text = ''
        [connection]
        id=setup-wifi
        type=wifi
        interface-name=wlan0
        autoconnect=true
        permissions=

        [wifi]
        ssid=${conn.wifi_ssid}
        mode=infrastructure
        hidden=false

        [wifi-security]
        key-mgmt=wpa-psk
        psk=${conn.wifi_password}
      '';
      mode = "0600";
    };
  };
}
