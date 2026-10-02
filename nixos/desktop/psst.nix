{
  inputs,
  self,
  ...
}: let
  # phisch/psst draws the three password prompts a Wayland session raises --
  # pinentry, the keyring prompter and the polkit agent -- as one layer-shell
  # overlay, and all three are wired up here. The keyring half displaces
  # mujo-keyring-prompter (nixos/desktop/keyring-prompter.nix): both own
  # org.gnome.keyring.SystemPrompter, so exactly one of them may run, and
  # `desktop.keyringPrompter` picks which.
  psstPackage = {pkgs}:
    pkgs.rustPlatform.buildRustPackage {
      pname = "psst";
      version = "0.2.0";
      src = inputs.psst;
      cargoLock.lockFile = "${inputs.psst}/Cargo.lock";

      nativeBuildInputs = [pkgs.pkg-config];
      buildInputs = [pkgs.wayland pkgs.libxkbcommon pkgs.fontconfig pkgs.systemdLibs];

      # The UI is gpui, which reaches its Wayland and Vulkan libraries through
      # dlopen rather than DT_NEEDED, so the loader needs them on the runpath or
      # every prompt dies on a blank screen.
      postFixup = ''
        for bin in "$out"/bin/*; do
          patchelf --add-rpath "${pkgs.lib.makeLibraryPath [pkgs.wayland pkgs.libxkbcommon pkgs.vulkan-loader]}" "$bin"
        done
      '';

      # psst-keyring-prompter only accepts prompts whose caller resolves to an
      # executable literally named "gnome-keyring-daemon". On NixOS the daemon
      # runs through a wrapper, so /proc/<pid>/exe points at
      # ".gnome-keyring-daemon-wrapped" and every unlock prompt is refused with
      # "refusing prompt from unauthorized caller" -- the keyring then stays
      # locked forever for every app that needs a secret. Accept the wrapper
      # name too rather than setting PSST_ALLOW_ANY_CALLER, which would drop the
      # caller check altogether.
      postPatch = ''
        substituteInPlace crates/keyring-prompter/src/prompter.rs \
          --replace-fail \
            'name == "gnome-keyring-daemon"' \
            'name == "gnome-keyring-daemon" || name == ".gnome-keyring-daemon-wrapped"'
      '';

      # doCheck = false: upstream ships no tests, and the PIN path this host
      # cares about is ours, covered by nixos/desktop/test-psst-pin.sh.
      doCheck = false;
      meta.mainProgram = "psst-polkit-agent";
    };
in {
  perSystem = {pkgs, ...}: {
    packages.psst = psstPackage {inherit pkgs;};
  };

  flake.nixosModules.psst = {
    pkgs,
    config,
    lib,
    ...
  }: let
    psst = psstPackage {inherit pkgs;};
    t = self.theme;
    user = config.preferences.user.name;

    # gpg-agent picks its pinentry by meta.mainProgram, and ours names the
    # polkit agent. Only the metadata differs, so this is the same store path.
    psstPinentry = psst.overrideAttrs (old: {
      meta = old.meta // {mainProgram = "psst-pinentry";};
    });

    keyringIsPsst = config.desktop.keyringPrompter == "psst";

    # 0700 root, same directory the vault container lives in, so the hash is
    # unreadable by the user whose prompt it guards and survives the
    # impermanence root wipe.
    pinFile = "/persist/secure/psst-pin";

    checkPin = pkgs.writeShellApplication {
      name = "psst-check-pin";
      runtimeInputs = [pkgs.coreutils pkgs.mkpasswd];
      text = builtins.readFile ./psst-check-pin.sh;
    };

    mujoPin = pkgs.writeShellApplication {
      name = "mujo-pin";
      runtimeInputs = [pkgs.coreutils pkgs.mkpasswd];
      text = builtins.readFile ./psst-pin.sh;
    };

    # psst's own default theme is a perfectly good dark one, but a prompt that
    # takes the whole screen is shell chrome, so its colours come from
    # modules/flake/theme.nix like everything else. Only colours are overridden:
    # sizes, radii and padding fall back to upstream's defaults, and the
    # low-alpha white overlays stay literal for the same reason they do in QML.
    themeKdl = pkgs.writeText "psst-theme.kdl" ''
      backdrop {
          background "${t.base00}a0"
      }

      window {
          background "${t.base00}"
          border "${t.base02}"
          text "${t.base05}"

          icon { background "${t.base0D}30"; text "${t.base0D}" }

          description-label { text "${t.base03}" }
          description-value { text "${t.base04}" }

          error { text "${t.base08}"; background "${t.base08}20" }

          field {
              background "${t.base01}"
              placeholder "${t.base03}"
              selection "${t.base0D}50"
              border "${t.base02}"
              focus { border "${t.base0D}"; background "${t.base01}" }
          }

          reveal { text "${t.base03}" }

          strength { background "${t.base02}" }
          strength-weak { background "${t.base08}" }
          strength-medium { background "${t.base0A}" }
          strength-strong { background "${t.base0B}" }

          checkbox {
              background "${t.base01}"
              text "${t.base04}"
              border "${t.base02}"
              focus { border "${t.base0D}" }
              checked { text "${t.base05}"; border "${t.base0D}" }
          }

          confirm {
              background "${t.base0D}"
              text "${t.base00}"
              hover { background "${t.base0C}" }
              active { background "${t.base0D}c0" }
          }

          cancel {
              background "#ffffff08"
              text "${t.base04}"
              hover { background "#ffffff14" }
              active { background "#ffffff0a" }
          }

          hint-key { text "${t.base04}" }
          hint-word { text "${t.base03}" }
      }
    '';

    pam = config.security.pam.package;

    # pam_exec hardcodes `_("Password: ")` as the prompt it raises, and that
    # string is exactly what psst draws as the field label. One substitution
    # makes pkexec ask for the right noun. Only this build's pam_exec.so is
    # referenced -- every other service keeps the stock pam.
    pamPinPrompt = pkgs.pam.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace modules/pam_exec/pam_exec.c \
            --replace-fail '_("Password: ")' '_("PIN: ")'
        '';
    });
    pinModule = "${pamPinPrompt}/lib/security/pam_exec.so";
    authRules = config.security.pam.services.polkit-1.rules.auth;

    # Three tries an hour, as asked. The tally deliberately does not live in
    # pam_faillock's default /run/faillock: /run is a tmpfs and SDDM autologins,
    # so "reboot the box" would be a way to wipe the count and keep guessing.
    # /var/lib/faillock is persisted instead, and `sudo faillock --user <name>
    # --reset` is the way out of a lockout that is not worth waiting out.
    faillock = {
      deny = 3;
      fail_interval = 3600;
      unlock_time = 3600;
      dir = "/var/lib/faillock";
    };
    faillockModule = "${pam}/lib/security/pam_faillock.so";
  in {
    options.desktop.keyringPrompter = lib.mkOption {
      type = lib.types.enum ["psst" "mujo"];
      default = "psst";
      description = ''
        Which program answers gnome-keyring's unlock prompts. Both candidates
        own org.gnome.keyring.SystemPrompter, so only one may run: "psst" is
        psst-keyring-prompter, "mujo" is the quickshell-drawn helper in
        nixos/desktop/keyring-prompter.nix.
      '';
    };

    config = {
      environment.systemPackages = [psst mujoPin];

      hjem.users."${user}".files.".config/psst/theme.kdl".source = themeKdl;

      # pam_faillock records nothing at all when its tally directory is missing
      # (open_tally treats ENOENT as "no failures yet"), so without these two the
      # lockout would silently never happen. The btrfs root is wiped on boot, so
      # the directory has to be persisted as well as created.
      systemd.tmpfiles.rules = ["d /var/lib/faillock 0700 root root -"];
      persistence.directories = ["/var/lib/faillock"];

      # One place the policy is written: pam_faillock reads this, and so does the
      # `faillock` CLI, so `faillock --user <name> --reset` looks in the same
      # directory the PAM rules tally into. The rules below only say where in the
      # stack they sit.
      environment.etc."security/faillock.conf".text =
        lib.concatLines (lib.mapAttrsToList (k: v: "${k} = ${toString v}") faillock);

      # ── the prompts ───────────────────────────────────────────────────────────
      systemd.user.services = {
        psst-polkit-agent = {
          description = "psst polkit authentication agent";
          after = ["graphical-session.target"];
          partOf = ["graphical-session.target"];
          wantedBy = ["graphical-session.target"];
          serviceConfig = {
            ExecStart = lib.getExe' psst "psst-polkit-agent";
            Restart = "always";
            RestartSec = 2;
          };
        };

        # Answers gnome-keyring's unlock and create prompts for as long as it
        # owns org.gnome.keyring.SystemPrompter -- which is why this and
        # mujo-keyring-prompter are mutually exclusive rather than stacked.
        psst-keyring-prompter = lib.mkIf keyringIsPsst {
          description = "psst keyring prompter";
          after = ["graphical-session.target"];
          partOf = ["graphical-session.target"];
          wantedBy = ["graphical-session.target"];
          serviceConfig = {
            ExecStart = lib.getExe' psst "psst-keyring-prompter";
            Restart = "always";
            RestartSec = 2;
          };
        };
      };
      # Same reason as quickshell.nix: wantedBy alone does not restart these when
      # a switch happens mid-session.
      systemd.user.targets.graphical-session.upholds =
        ["psst-polkit-agent.service"]
        ++ lib.optional keyringIsPsst "psst-keyring-prompter.service";

      # gpg-agent's own prompt. The settings land in /etc/gnupg/gpg-agent.conf,
      # so nothing has to be written into the 0700 ~/.gnupg. Worth knowing: this
      # is a Wayland overlay, so `gpg` on a bare TTY has nowhere to draw -- set
      # `programs.gnupg.agent.pinentryPackage = pkgs.pinentry-curses` if that ever
      # becomes the common case here.
      programs.gnupg.agent = {
        enable = true;
        pinentryPackage = psstPinentry;
      };

      # ── what the prompt accepts ───────────────────────────────────────────────
      #
      # psst has no idea what a PIN is; it runs whatever conversation
      # /etc/pam.d/polkit-1 asks for. So the PIN lives here, in front of the
      # pam_unix the stack already had:
      #
      #   faillock preauth   are we locked out?
      #   pin (sufficient)   PIN right -> done, nothing below runs
      #   fallback (required) a PIN is configured -> fail, and keep failing
      #   unix (sufficient)  only reachable while no PIN is configured
      #   faillock authfail  record the failure
      #   deny               refuse
      #
      # The fallback rule is what makes the PIN the only answer pkexec takes. A
      # `required` failure cannot be undone by a later `sufficient` success --
      # libpam only short-circuits on `sufficient` while its impression is still
      # positive -- so once a PIN exists the account password stops opening
      # polkit prompts, while the stack still runs on to the authfail rule and
      # the attempt is counted. Before `mujo-pin set` has ever run the gate
      # succeeds and pam_unix decides, so rebuilding does not cost you pkexec.
      #
      # sudo, login and the lock screen are untouched and still want the password.
      security.pam.services.polkit-1.rules = {
        auth = {
          mujoFaillockPreauth = {
            order = authRules.unix.order - 100;
            control = "required";
            modulePath = faillockModule;
            settings.preauth = true;
          };

          mujoPin = {
            order = authRules.unix.order - 50;
            control = "sufficient";
            modulePath = pinModule;
            # expose_authtok makes pam_exec raise the prompt (and stash the
            # answer as PAM_AUTHTOK, so nothing below asks a second time) and
            # hand it to us on stdin. seteuid is not optional:
            # polkit-agent-helper-1 is setuid, so without it the child keeps the
            # caller's real uid and bash drops euid 0 on startup, leaving the
            # verifier unable to read the hash -- the PIN would simply never
            # match. The hash path is an argument rather than an environment
            # variable so nothing the calling user controls can redirect it.
            args = ["expose_authtok" "seteuid" "quiet" "${checkPin}/bin/psst-check-pin" pinFile];
          };

          # No expose_authtok here: this one asks nothing, it only reports
          # whether a PIN exists.
          mujoPasswordFallback = {
            order = authRules.unix.order - 25;
            control = "required";
            modulePath = pinModule;
            args = ["seteuid" "quiet" "${checkPin}/bin/psst-check-pin" "--unset" pinFile];
          };

          mujoFaillockAuthfail = {
            order = authRules.deny.order - 50;
            control = "[default=die]";
            modulePath = faillockModule;
            settings.authfail = true;
          };
        };

        # Clears the tally after a success and reports the lockout as an account
        # failure; pam_faillock needs both halves to tell consecutive failures
        # from scattered ones.
        account.mujoFaillock = {
          order = config.security.pam.services.polkit-1.rules.account.unix.order - 100;
          control = "required";
          modulePath = faillockModule;
        };
      };
    };
  };
}
