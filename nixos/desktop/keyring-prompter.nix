{self, ...}: {
  # mujō keyring prompter: a themed replacement for gcr's GTK "system prompter".
  #
  # gnome-keyring provides the Secret Service (org.freedesktop.secrets) that apps
  # use to store/retrieve secrets. When a keyring is locked it needs a UI to ask
  # for the password; normally that's gcr's GTK dialog. This feature swaps in a
  # small Python helper (mujo-keyring-prompter) that owns the
  # org.gnome.keyring.SystemPrompter D-Bus name and draws its UI through the
  # quickshell shell (KeyringPrompt.qml) over a unix socket, so keyring prompts
  # match the rest of the desktop. See quickshell/keyring/ for the helper and
  # quickshell/bar/AGENTS.md for the shell side.
  flake.nixosModules.keyring-prompter = {
    pkgs,
    config,
    lib,
    ...
  }: let
    # Python + PyGObject, with the gcr/gck/glib GObject-introspection typelibs
    # the helper needs (Gcr.SecretExchange handles the DH secret exchange so the
    # password is never sent in cleartext over D-Bus).
    pyEnv = pkgs.python3.withPackages (ps: [ps.pygobject3]);
    giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" [
      pkgs.glib
      pkgs.gobject-introspection
      pkgs.gcr_4
    ];
    ldLibraryPath = lib.makeLibraryPath [pkgs.glib pkgs.gcr_4];

    mujoKeyringPrompter =
      pkgs.runCommand "mujo-keyring-prompter"
      {
        nativeBuildInputs = [pkgs.makeWrapper];
      } ''
        mkdir -p $out/libexec $out/bin
        cp ${../../quickshell/keyring/mujo-keyring-prompter.py} $out/libexec/mujo-keyring-prompter.py
        makeWrapper ${pyEnv}/bin/python3 $out/bin/mujo-keyring-prompter \
          --add-flags "$out/libexec/mujo-keyring-prompter.py" \
          --set GI_TYPELIB_PATH "${giTypelibPath}" \
          --prefix LD_LIBRARY_PATH : "${ldLibraryPath}"
      '';

    generationTrigger = self.rev or self.dirtyRev or "unknown";
  in {
    # Secret Service daemon + PAM auto-unlock at login. When the login keyring is
    # auto-unlocked the prompter stays out of the way; it only appears for locked
    # keyrings or apps that request a secret while locked.
    services.gnome.gnome-keyring.enable = true;

    environment.systemPackages = [mujoKeyringPrompter];

    # The keyrings themselves must survive the impermanence root wipe.
    persistence.data.directories = [
      ".local/share/keyrings"
    ];

    systemd.user.services.mujo-keyring-prompter = {
      description = "mujō keyring prompter (gcr system prompter replacement)";
      after = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        ExecStart = "${mujoKeyringPrompter}/bin/mujo-keyring-prompter";
        Restart = "always";
        RestartSec = 2;
      };
      restartTriggers = [generationTrigger];
    };

    # Keep it started across switches mid-session (see quickshell.nix for why
    # upholds= is used rather than relying on wantedBy alone).
    systemd.user.targets.graphical-session.upholds = ["mujo-keyring-prompter.service"];
  };
}
