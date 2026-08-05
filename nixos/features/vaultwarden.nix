{
  inputs,
  ...
}: let
  # cachix/secretspec ships no flake.nix, so the flake input is source-only
  # and the binary is built here with just the features the bw provider needs.
  secretspecPackage = {pkgs}: pkgs.rustPlatform.buildRustPackage {
    pname = "secretspec";
    version = "0.18.0";
    src = inputs.secretspec;
    cargoLock.lockFile = "${inputs.secretspec}/Cargo.lock";
    buildNoDefaultFeatures = true;
    buildFeatures = ["cli" "bw"];
    cargoBuildFlags = ["-p" "secretspec"];
    # doCheck = false: upstream tests would need network/bw fixtures; the
    # binary is validated standalone via `nix build .#secretspec` instead.
    doCheck = false;
    meta.mainProgram = "secretspec";
  };
in {
  perSystem = {pkgs, ...}: {
    packages.secretspec = secretspecPackage {inherit pkgs;};
  };

  flake.nixosModules.vaultwarden = {
    pkgs,
    config,
    lib,
    ...
  }: let
    cfg = config.secrets.vaultwarden;

    # Default bw field per entry kind (types are never defaulted; see below).
    kindDefaults = {
      files = {field = "notes";};
      sshKeys = {field = "private_key";};
      gpgKeys = {field = "notes";};
    };

    secretType = lib.types.submodule {
      options = {
        item = lib.mkOption {
          type = lib.types.str;
          description = "Vaultwarden item name to fetch";
        };
        field = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Which part of the item to extract: notes (secure note body),
            username, password, or the name of a custom field. Defaults to
            notes for files/gpgKeys and private_key for sshKeys.
          '';
        };
        type = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["securenote" "login" "card" "identity" "sshkey"]);
          default = null;
          description = ''
            Bitwarden item type: securenote, login, card, identity, sshkey.
            Sent to the provider only when set, to disambiguate duplicate
            item names; when unset, SecretSpec resolves the ref by item name
            only (no &type= in the provider URI).
          '';
        };
        mode = lib.mkOption {
          type = lib.types.str;
          default = "0600";
          description = ''
            File mode for the written secret as an octal string,
            e.g. "0600" or "0644". Applies to `files` entries only;
            sshKeys and gpgKeys are always written with mode 0600.
          '';
        };
      };
    };

    # Flatten every configured secret into a single ordered list shared by the
    # manifest and the fetch loop. Keys are s_0, s_1, ... because SecretSpec
    # identifiers may not contain dots or dashes.
    entries = let
      all =
        (lib.mapAttrsToList (name: v: {inherit name v; kind = "files";}) cfg.files)
        ++ (lib.mapAttrsToList (name: v: {inherit name v; kind = "sshKeys";}) cfg.sshKeys)
        ++ (lib.mapAttrsToList (name: v: {inherit name v; kind = "gpgKeys";}) cfg.gpgKeys);
      out = {
        files = name: "/run/secrets/${name}";
        sshKeys = name: "/run/secrets/ssh/${name}";
        gpgKeys = name: "/run/secrets/gpg/${name}.asc";
      };
    in
      lib.imap0 (i: {kind, name, v}: let
        def = kindDefaults.${kind};
      in {
        key = "s_${toString i}";
        item = v.item;
        field = if v.field != null then v.field else def.field;
        type = v.type;
        out = out.${kind} name;
        mode = if kind == "files" then v.mode else "0600";
      }) all;

    # secretspec.toml is written to /run/secrets at service start; it holds
    # item names and provider URIs, never secret values. &type= is only added
    # when the entry explicitly sets type.
    tomlQuote = s: "\"" + lib.replaceStrings
      ["\\" "\"" "\n" "\r" "\t"]
      ["\\\\" "\\\"" "\\n" "\\r" "\\t"]
      s + "\"";
    manifest = lib.concatMapStrings (e: let
      typeSuffix = if e.type != null then "&type=" + e.type else "";
    in ''
      ${e.key} = { required = true, description = ${tomlQuote ("vaultwarden-secrets " + e.item)}, providers = [${tomlQuote ("bw://?server=" + cfg.serverUrl + typeSuffix)}], ref = { item = ${tomlQuote e.item}, field = ${tomlQuote e.field} } }
    '') entries;

    fetchLine = e:
      "fetch_secret ${lib.escapeShellArg e.key} ${lib.escapeShellArg e.item} ${lib.escapeShellArg e.out} ${e.mode}";

    script = let
      lines = lib.concatLines (map fetchLine entries);
      secretspec = "${cfg.package}/bin/secretspec";
    in ''
      set -euo pipefail

      # API key and master password are read here, inside the service, so they
      # never end up in the store.
      export BW_NOINTERACTION=true

      if [ ! -r ${lib.escapeShellArg cfg.apiKeyFile} ]; then
        echo "vaultwarden-secrets: API key file '${cfg.apiKeyFile}' not readable" >&2
        exit 1
      fi

      # client_id on line 1, client_secret on line 2; strip CR and surrounding whitespace per line.
      keylines="$(tr -d '\r' < ${lib.escapeShellArg cfg.apiKeyFile} | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | sed '/^$/d')"
      if [ "$(printf '%s\n' "$keylines" | wc -l)" -lt 2 ]; then
        echo "vaultwarden-secrets: API key file '${cfg.apiKeyFile}' must contain at least 2 non-empty lines (client_id, client_secret)" >&2
        exit 1
      fi
      export BW_CLIENTID="$(printf '%s\n' "$keylines" | sed -n '1p')"
      export BW_CLIENTSECRET="$(printf '%s\n' "$keylines" | sed -n '2p')"

      if [ ! -r ${lib.escapeShellArg cfg.masterPasswordFile} ]; then
        echo "vaultwarden-secrets: master password file '${cfg.masterPasswordFile}' not readable" >&2
        exit 1
      fi

      for f in ${lib.escapeShellArg cfg.apiKeyFile} ${lib.escapeShellArg cfg.masterPasswordFile}; do
        m="$(stat -c %a "$f" 2>/dev/null)" || { echo "vaultwarden-secrets: warning: cannot stat '$f'" >&2; continue; }
        [ "$m" = "600" ] || echo "vaultwarden-secrets: warning: '$f' is mode $m, expected 0600" >&2
      done

      # The manifest maps each fetch key to a bw item ref and provider URI.
      cat > /run/secrets/secretspec.toml <<'EOF'
      [project]
      name = "vaultwarden-secrets"
      revision = "1.0"

      [profiles.default]
      ${manifest}
      EOF
      # The manifest lists item names and the provider server URL; keep it
      # root-only.
      chmod 0640 /run/secrets/secretspec.toml

      bw config server ${lib.escapeShellArg cfg.serverUrl}

      # The API key only authenticates; the vault stays LOCKED until it is
      # unlocked with the master password, so a separate unlock step is required.
      bw login --apikey --nointeraction

      trap 'bw logout >/dev/null 2>&1 || true; unset BW_SESSION BW_CLIENTID BW_CLIENTSECRET' EXIT

      export BW_SESSION="$(bw unlock --passwordfile ${lib.escapeShellArg cfg.masterPasswordFile} --raw)"

      bw sync

      fetch_secret() {
        local key="$1" item="$2" out="$3" mode="$4"
        local tmp
        mkdir -p "$(dirname "$out")"
        tmp="$(mktemp -p "$(dirname "$out")")"
        # `secretspec get` prints the value with a trailing newline; strip
        # exactly one so the file holds the stored bytes (armored GPG keys
        # keep their own trailing newline).
        if ! ${secretspec} --file /run/secrets/secretspec.toml get "$key" --reason "vaultwarden-secrets bootstrap" > "$tmp"; then
          echo "vaultwarden-secrets: fetching item '$item' failed" >&2
          rm -f "$tmp"
          return 1
        fi
        if [ -s "$tmp" ] && [ -z "$(tail -c 1 "$tmp")" ]; then
          truncate -s -1 "$tmp"
        fi
        if [ ! -s "$tmp" ]; then
          echo "vaultwarden-secrets: item '$item' is empty; skipping" >&2
          rm -f "$tmp"
          return 0
        fi
        chmod "$mode" "$tmp"
        mv -f "$tmp" "$out"
        written=$((written + 1))
      }

      written=0
      ${lines}

      if [ "$written" -eq 0 ]; then
        echo "vaultwarden-secrets: no secrets were written" >&2
        exit 1
      fi
    '';
  in {
    options.secrets.vaultwarden = {
      enable = lib.mkEnableOption "fetch secrets from Vaultwarden into /run/secrets";

      package = lib.mkOption {
        type = lib.types.package;
        default = secretspecPackage {inherit pkgs;};
        description = "secretspec binary used to fetch secrets (must include the bw provider).";
      };

      serverUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://vault.porkbuns.xyz";
        description = "Vaultwarden server URL";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.preferences.user.name}/nixconf/secrets/vaultwarden-api-key";
        description = ''
          Path to the Bitwarden API key: client_id on the first line,
          client_secret on the second line. Read only by the fetch service.
          Note: the API key alone only authenticates; the vault stays locked
          until it is unlocked with the master password (masterPasswordFile).
        '';
      };

      masterPasswordFile = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.preferences.user.name}/nixconf/secrets/vaultwarden-master-password";
        description = ''
          Path to a root-only (chmod 600) file containing the Vaultwarden
          master password, used with `bw unlock --passwordfile`. The API key
          only authenticates; the vault decryption key derives from the master
          password, so the vault cannot be unlocked without it.
        '';
      };

      files = lib.mkOption {
        type = lib.types.attrsOf secretType;
        default = {};
        description = ''
          Arbitrary files, written to /run/secrets/<name> with mode 0600
          (override per entry with mode).
        '';
      };

      sshKeys = lib.mkOption {
        type = lib.types.attrsOf secretType;
        default = {};
        description = "SSH private keys, written to /run/secrets/ssh/<name> with mode 0600";
      };
      # ponytail: provisioning-only (writes /run/secrets); loading keys into the
      # user's ssh-agent/gpg-agent is a follow-up (needs a user service that can
      # read the root-owned /run/secrets files, e.g. hjem users.<user>.services).

      gpgKeys = lib.mkOption {
        type = lib.types.attrsOf secretType;
        default = {};
        description = "Armored GPG private keys, written to /run/secrets/gpg/<name>.asc with mode 0600";
      };
    };

    config = lib.mkIf (cfg.enable && (cfg.files != {} || cfg.sshKeys != {} || cfg.gpgKeys != {})) {
      assertions = let
        okName = name: builtins.match "^[A-Za-z0-9._-]+$" name != null && name != "." && name != "..";
      in [
        {
          assertion = lib.all okName (lib.attrNames (cfg.files // cfg.sshKeys // cfg.gpgKeys));
          message = "secrets.vaultwarden: secret names must match [A-Za-z0-9._-]+ and must not be '.' or '..'";
        }
        {
          assertion = lib.all (name: name != "ssh" && name != "gpg" && name != "secretspec.toml") (lib.attrNames cfg.files);
          message = "secrets.vaultwarden: files entries cannot be named 'ssh', 'gpg', or 'secretspec.toml' (they would collide with the ssh/ and gpg/ subdirectories or the manifest)";
        }
      ];

      systemd.services.vaultwarden-secrets = {
        description = "Fetch secrets from Vaultwarden into /run/secrets";
        wants = ["network-online.target"];
        after = ["network-online.target"];
        # Ordering only: sshd is not enabled by this module, consumers must add
        # their own After=vaultwarden-secrets.service.
        before = ["sshd.service"];
        wantedBy = ["multi-user.target"];
        path = with pkgs; [bitwarden-cli bash coreutils gnused gnugrep];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "secrets";
        };
        script = script;
      };
    };
  };
}
