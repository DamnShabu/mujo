{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.skwd-wall = {
    pkgs,
    config,
    lib,
    ...
  }: let
    user = config.preferences.user.name;
    matugenDir = "${inputs.ambxst}/assets/matugen";
    skwdPkg = inputs.skwd-wall.packages.${pkgs.stdenv.hostPlatform.system}.default;

    themeHook = pkgs.writeShellScriptBin "skwd-wall-theme-hook" ''
            set -euo pipefail

            export PATH="${lib.makeBinPath (with pkgs; [
        coreutils
        findutils
        gnused
        gnugrep
        gawk
        jq
        procps
        dconf
        matugen
        util-linux
        config.programs.ambxst.package
      ])}:$PATH"

            # Prevent concurrent runs
            LOCKDIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/skwd-wall"
            mkdir -p "$LOCKDIR"
            exec 200>"$LOCKDIR/theme-hook.lock"
            ${pkgs.util-linux}/bin/flock -w 10 200 || {
              echo "skwd-wall-theme-hook: Could not acquire lock, skipping" >&2
              exit 0
            }

            SRC="''${1:-}"
            THUMB="''${2:-}"

            # skwd-helm and walld report Wallpaper Engine walls by workshop ID
            # (optionally "we:"-prefixed) and videos by their file. matugen and
            # ambxst's wallpaper layer need a still image: pass one through, map a
            # WE ID to its preview, else print the fallback $2.
            resolve_still() {
              local p="$1" f
              if [[ -f "$p" && ! "$p" =~ \.(mp4|mkv|webm|avi)$ ]]; then
                echo "$p"; return
              fi
              if [[ "$p" =~ ^(we:)?([0-9]+)$ ]]; then
                for f in "$HOME"/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/workshop/content/431960/"''${BASH_REMATCH[2]}"/preview.* \
                         "$HOME"/.local/share/Steam/steamapps/workshop/content/431960/"''${BASH_REMATCH[2]}"/preview.*; do
                  [[ -f "$f" ]] && { echo "$f"; return; }
                done
              fi
              echo "''${2:-}"
            }

            # 1. Resolve source image
            STILL=$(resolve_still "$SRC")
            if [[ -n "$STILL" ]]; then
              SRC="$STILL"
            else
              if [[ -n "$THUMB" && -f "$THUMB" ]]; then
                SRC="$THUMB"
              else
                # Try finding current wallpaper from skwd-helm outputs
                CURRENT=$(${skwdPkg}/bin/skwd-helm outputs 2>/dev/null | awk -F'\t' '{print $NF}' | head -n 1 || true)
                CURRENT=$(resolve_still "$CURRENT")
                if [[ -n "$CURRENT" ]]; then
                  SRC="$CURRENT"
                else
                  # Try latest thumbnail in skwd-wall-v2 cache
                  LATEST_THUMB=$(find "$HOME/.cache/skwd-wall-v2/thumbs" -name "*.webp" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" " || true)
                  if [[ -n "$LATEST_THUMB" && -f "$LATEST_THUMB" ]]; then
                    SRC="$LATEST_THUMB"
                  fi
                fi
              fi
            fi

            if [[ -z "$SRC" || ! -f "$SRC" ]]; then
              echo "skwd-wall-theme-hook: No source image found" >&2
              exit 0
            fi

            echo "skwd-wall-theme-hook: Processing colors from $SRC"

            # 2. Synchronize Ambxst wallpaper & backdrop
            OUTPUTS_DATA=$(${skwdPkg}/bin/skwd-helm outputs 2>/dev/null || true)
            WALL_TARGET="$SRC"
            if [[ "$SRC" =~ \.cache/skwd-wall-v2/thumbs/ && -n "$OUTPUTS_DATA" ]]; then
              FIRST_OUT=$(echo "$OUTPUTS_DATA" | awk -F'\t' '{print $NF}' | head -n 1 || true)
              WALL_TARGET=$(resolve_still "$FIRST_OUT" "$SRC")
            fi

            WALL_DIR=$(dirname "$WALL_TARGET")
            AMBXST_CACHE="$HOME/.cache/ambxst"
            AMBXST_WALL_JSON="$AMBXST_CACHE/wallpapers.json"
            mkdir -p "$AMBXST_CACHE"

            # ambxst's wallpaper layer (niri's overview backdrop) prefers
            # perScreenWallpapers over currentWall, so every entry must be a
            # drawable image, never a WE ID.
            RESOLVED=""
            if [[ -n "$OUTPUTS_DATA" ]]; then
              while IFS=$'\t' read -r mon _type _mute _vol p; do
                [[ -n "$mon" ]] && RESOLVED+="$mon"$'\t'"$(resolve_still "$p" "$WALL_TARGET")"$'\n'
              done <<< "$OUTPUTS_DATA"
            fi
            PER_SCREEN_JSON=$(printf '%s' "$RESOLVED" | ${pkgs.jq}/bin/jq -R -s '
              split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}
            ')

            if [[ -f "$AMBXST_WALL_JSON" ]]; then
              ${pkgs.jq}/bin/jq \
                --arg wall "$WALL_TARGET" \
                --arg dir "$WALL_DIR" \
                --argjson perScreen "$PER_SCREEN_JSON" \
                '.currentWall = $wall | .wallPath = $dir | .perScreenWallpapers = $perScreen' \
                "$AMBXST_WALL_JSON" > "$AMBXST_WALL_JSON.tmp" && mv "$AMBXST_WALL_JSON.tmp" "$AMBXST_WALL_JSON"
            else
              ${pkgs.jq}/bin/jq -n \
                --arg wall "$WALL_TARGET" \
                --arg dir "$WALL_DIR" \
                --argjson perScreen "$PER_SCREEN_JSON" \
                '{
                  activeColorPreset: "",
                  currentWall: $wall,
                  matugenScheme: "scheme-tonal-spot",
                  perScreenWallpapers: $perScreen,
                  tintEnabled: false,
                  wallPath: $dir
                }' > "$AMBXST_WALL_JSON"
            fi

            AMBXST_BIN="${config.programs.ambxst.package}/bin/ambxst"
            if [[ -x "$AMBXST_BIN" ]]; then
              SET_PER_MON=0
              while IFS=$'\t' read -r mon p; do
                if [[ -n "$mon" && -f "$p" ]]; then
                  "$AMBXST_BIN" wallpaper -monitor "$mon" "$p" >/dev/null 2>&1 || true
                  SET_PER_MON=1
                fi
              done <<< "$RESOLVED"
              if [[ $SET_PER_MON -eq 0 ]]; then
                "$AMBXST_BIN" wallpaper "$WALL_TARGET" >/dev/null 2>&1 || true
              fi
            fi

            # 3. Run matugen to generate ambxst colors.json
            mkdir -p "$HOME/.cache/ambxst"
            (
              cd "${matugenDir}"
              ${pkgs.matugen}/bin/matugen image "$SRC" --source-color-index 0 -c config.toml
            )

            # Wait briefly for colors.json to settle
            sleep 0.15

            COLORS_JSON="$HOME/.cache/ambxst/colors.json"
            if [[ ! -f "$COLORS_JSON" ]]; then
              echo "skwd-wall-theme-hook: $COLORS_JSON was not generated" >&2
              exit 1
            fi

            # 4. Synchronize Kitty theme
            mkdir -p "$HOME/.config/quickshell"
            if [[ -f "$HOME/.cache/ambxst/kitty.conf" ]]; then
              ln -sf "$HOME/.cache/ambxst/kitty.conf" "$HOME/.config/quickshell/kitty-theme.conf"
              ${pkgs.procps}/bin/pkill -SIGUSR1 kitty 2>/dev/null || true
            fi

            # 5. Synchronize Fish shell colors
            BG=$(${pkgs.jq}/bin/jq -r '.background' "$COLORS_JSON")
            TEXT=$(${pkgs.jq}/bin/jq -r '.overSurface' "$COLORS_JSON")
            ACCENT=$(${pkgs.jq}/bin/jq -r '.primary' "$COLORS_JSON")
            SURF_ACT=$(${pkgs.jq}/bin/jq -r '.surfaceContainer' "$COLORS_JSON")
            TEXT_SEC=$(${pkgs.jq}/bin/jq -r '.overSurfaceVariant' "$COLORS_JSON")
            TEXT_DIM=$(${pkgs.jq}/bin/jq -r '.outline' "$COLORS_JSON")
            ERROR=$(${pkgs.jq}/bin/jq -r '.error' "$COLORS_JSON")
            GREEN=$(${pkgs.jq}/bin/jq -r '.green' "$COLORS_JSON")
            YELLOW=$(${pkgs.jq}/bin/jq -r '.yellow' "$COLORS_JSON")
            MAGENTA=$(${pkgs.jq}/bin/jq -r '.magenta' "$COLORS_JSON")
            CYAN=$(${pkgs.jq}/bin/jq -r '.cyan' "$COLORS_JSON")

            F_TEXT="''${TEXT#\#}"
            F_TEXT_SEC="''${TEXT_SEC#\#}"
            F_TEXT_DIM="''${TEXT_DIM#\#}"
            F_ACCENT="''${ACCENT#\#}"
            F_SURF_ACT="''${SURF_ACT#\#}"
            F_ERROR="''${ERROR#\#}"
            F_GREEN="''${GREEN#\#}"
            F_YELLOW="''${YELLOW#\#}"
            F_MAGENTA="''${MAGENTA#\#}"
            F_CYAN="''${CYAN#\#}"

            FISH_THEME="$HOME/.config/quickshell/fish-theme.fish"
            cat > "$FISH_THEME" <<FISH_EOF
      # Generated by skwd-wall-theme-hook
      set -g fish_color_normal ''${F_TEXT}
      set -g fish_color_command ''${F_ACCENT} --bold
      set -g fish_color_keyword ''${F_MAGENTA}
      set -g fish_color_quote ''${F_GREEN}
      set -g fish_color_redirection ''${F_CYAN}
      set -g fish_color_end ''${F_YELLOW}
      set -g fish_color_error ''${F_ERROR}
      set -g fish_color_param ''${F_TEXT}
      set -g fish_color_comment ''${F_TEXT_DIM}
      set -g fish_color_selection --background=''${F_SURF_ACT}
      set -g fish_color_search_match --background=''${F_SURF_ACT}
      set -g fish_color_operator ''${F_YELLOW}
      set -g fish_color_escape ''${F_CYAN}
      set -g fish_color_autosuggestion ''${F_TEXT_DIM}
      set -g fish_color_cwd ''${F_ACCENT}
      set -g fish_color_user ''${F_TEXT_SEC}
      set -g fish_color_host ''${F_TEXT_DIM}
      set -g fish_color_cancel ''${F_ERROR}

      set -g fish_pager_color_progress ''${F_TEXT_DIM}
      set -g fish_pager_color_prefix ''${F_ACCENT} --bold
      set -g fish_pager_color_completion ''${F_TEXT}
      set -g fish_pager_color_description ''${F_TEXT_SEC}
      set -g fish_pager_color_selected_background --background=''${F_SURF_ACT}
      set -g fish_pager_color_selected_prefix ''${F_ACCENT}
      set -g fish_pager_color_selected_completion ''${F_TEXT}
      set -g fish_pager_color_selected_description ''${F_TEXT_SEC}

      set -g mujo_prompt_color_accent ''${F_ACCENT}
      set -g mujo_prompt_color_error ''${F_ERROR}
      set -g mujo_prompt_color_dim ''${F_TEXT_DIM}
      set -g mujo_prompt_color_cwd ''${F_ACCENT}
      set -g mujo_prompt_color_bg ''${F_SURF_ACT}
      set -g mujo_prompt_color_text ''${F_TEXT}
      set -g mujo_prompt_color_git ''${F_MAGENTA}
      set -g mujo_prompt_color_nix ''${F_CYAN}
      FISH_EOF

            if command -v fish >/dev/null 2>&1; then
              fish -c "
                set -U fish_color_normal ''${F_TEXT}
                set -U fish_color_command ''${F_ACCENT} --bold
                set -U fish_color_keyword ''${F_MAGENTA}
                set -U fish_color_quote ''${F_GREEN}
                set -U fish_color_redirection ''${F_CYAN}
                set -U fish_color_end ''${F_YELLOW}
                set -U fish_color_error ''${F_ERROR}
                set -U fish_color_param ''${F_TEXT}
                set -U fish_color_comment ''${F_TEXT_DIM}
                set -U fish_color_selection --background=''${F_SURF_ACT}
                set -U fish_color_search_match --background=''${F_SURF_ACT}
                set -U fish_color_operator ''${F_YELLOW}
                set -U fish_color_escape ''${F_CYAN}
                set -U fish_color_autosuggestion ''${F_TEXT_DIM}
                set -U fish_color_cwd ''${F_ACCENT}
                set -U fish_color_user ''${F_TEXT_SEC}
                set -U fish_color_host ''${F_TEXT_DIM}
                set -U fish_color_cancel ''${F_ERROR}
                set -U fish_pager_color_progress ''${F_TEXT_DIM}
                set -U fish_pager_color_prefix ''${F_ACCENT} --bold
                set -U fish_pager_color_completion ''${F_TEXT}
                set -U fish_pager_color_description ''${F_TEXT_SEC}
                set -U fish_pager_color_selected_background --background=''${F_SURF_ACT}
                set -U fish_pager_color_selected_prefix ''${F_ACCENT}
                set -U fish_pager_color_selected_completion ''${F_TEXT}
                set -U fish_pager_color_selected_description ''${F_TEXT_SEC}
                set -U mujo_prompt_color_accent ''${F_ACCENT}
                set -U mujo_prompt_color_error ''${F_ERROR}
                set -U mujo_prompt_color_dim ''${F_TEXT_DIM}
                set -U mujo_prompt_color_cwd ''${F_ACCENT}
                set -U mujo_prompt_color_bg ''${F_SURF_ACT}
                set -U mujo_prompt_color_text ''${F_TEXT}
                set -U mujo_prompt_color_git ''${F_MAGENTA}
                set -U mujo_prompt_color_nix ''${F_CYAN}
              " 2>/dev/null || true
            fi

            # 6. Synchronize Zen Browser Chrome
            if [[ -f "$HOME/.cache/ambxst/pywalzen.css" ]]; then
              for zendir in "$HOME/.var/app/app.zen_browser.zen/config/zen"/*.Default* "$HOME/.var/app/app.zen_browser.zen/.zen"/*.Default* "$HOME/.zen"/*.Default* "$HOME/.config/zen"/*.Default*; do
                if [[ -d "$zendir" ]]; then
                  mkdir -p "$zendir/chrome"
                  cp -f "$HOME/.cache/ambxst/pywalzen.css" "$zendir/chrome/pywalzen.css"
                  if ! grep -q "pywalzen.css" "$zendir/chrome/userChrome.css" 2>/dev/null; then
                    echo '@import url("pywalzen.css");' >> "$zendir/chrome/userChrome.css"
                  fi
                fi
              done
            fi

            # 7. Synchronize Vesktop Discord theme
            if [[ -f "$HOME/.config/vesktop/themes/ambxst.css" ]]; then
              for vdir in "$HOME/.var/app/dev.vencord.Vesktop/data/themes" "$HOME/.var/app/dev.vencord.Vesktop/config/vesktop/themes"; do
                if [[ -d "$vdir" ]]; then
                  cp -f "$HOME/.config/vesktop/themes/ambxst.css" "$vdir/ambxst.css"
                fi
              done
            fi

            # 8. Synchronize Flatpak GTK themes
            if [[ -f "$HOME/.config/gtk-3.0/gtk.css" ]]; then
              for gdir in "$HOME/.var/app"/*/config/gtk-3.0; do
                if [[ -d "$gdir" ]]; then
                  cp -f "$HOME/.config/gtk-3.0/gtk.css" "$gdir/gtk.css"
                fi
              done
            fi
            if [[ -f "$HOME/.config/gtk-4.0/gtk.css" ]]; then
              for gdir in "$HOME/.var/app"/*/config/gtk-4.0; do
                if [[ -d "$gdir" ]]; then
                  cp -f "$HOME/.config/gtk-4.0/gtk.css" "$gdir/gtk.css"
                fi
              done
            fi

            # 9. Synchronize Btop theme
            mkdir -p "$HOME/.config/btop/themes"
            cat > "$HOME/.config/btop/themes/skwd.theme" <<BTOP_EOF
      # Generated by skwd-wall-theme-hook
      theme[main_bg]="''${BG}"
      theme[main_fg]="''${TEXT}"
      theme[title]="''${ACCENT}"
      theme[hi_fg]="''${ACCENT}"
      theme[selected_bg]="''${SURF_ACT}"
      theme[selected_fg]="''${TEXT}"
      theme[inactive_fg]="''${TEXT_DIM}"
      theme[proc_misc]="''${CYAN}"
      theme[cpu_box]="''${ACCENT}"
      theme[mem_box]="''${GREEN}"
      theme[net_box]="''${MAGENTA}"
      theme[proc_box]="''${YELLOW}"
      theme[div_line]="''${TEXT_DIM}"
      theme[temp_start]="''${GREEN}"
      theme[temp_mid]="''${YELLOW}"
      theme[temp_end]="''${ERROR}"
      theme[cpu_start]="''${GREEN}"
      theme[cpu_mid]="''${YELLOW}"
      theme[cpu_end]="''${ERROR}"
      theme[free_start]="''${GREEN}"
      theme[free_mid]="''${YELLOW}"
      theme[free_end]="''${ERROR}"
      theme[cached_start]="''${CYAN}"
      theme[cached_mid]="''${ACCENT}"
      theme[cached_end]="''${MAGENTA}"
      theme[available_start]="''${GREEN}"
      theme[available_mid]="''${YELLOW}"
      theme[available_end]="''${ERROR}"
      theme[used_start]="''${GREEN}"
      theme[used_mid]="''${YELLOW}"
      theme[used_end]="''${ERROR}"
      theme[download_start]="''${CYAN}"
      theme[download_mid]="''${ACCENT}"
      theme[download_end]="''${MAGENTA}"
      theme[upload_start]="''${GREEN}"
      theme[upload_mid]="''${YELLOW}"
      theme[upload_end]="''${ERROR}"
      BTOP_EOF

            if [[ ! -f "$HOME/.config/btop/btop.conf" ]]; then
              cat > "$HOME/.config/btop/btop.conf" <<'BTOP_CONF_EOF'
      color_theme = "skwd"
      theme_background = False
      BTOP_CONF_EOF
            elif ! grep -q 'color_theme.*skwd' "$HOME/.config/btop/btop.conf"; then
              sed -i 's/^color_theme = .*/color_theme = "skwd"/' "$HOME/.config/btop/btop.conf" || true
            fi

            # 10. Synchronize GTK / GNOME dark mode preference via dconf
            if command -v dconf >/dev/null 2>&1; then
              HEX_CLEAN="''${BG#\#}"
              if [[ ''${#HEX_CLEAN} -eq 6 ]]; then
                R=$((16#''${HEX_CLEAN:0:2}))
                G=$((16#''${HEX_CLEAN:2:2}))
                B=$((16#''${HEX_CLEAN:4:2}))
                LUM=$(( (R * 299 + G * 587 + B * 114) / 1000 ))
                if (( LUM > 128 )); then
                  dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'" 2>/dev/null || true
                else
                  dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
                fi
              fi
            fi

            echo "skwd-wall-theme-hook: Completed successfully"
    '';
  in {
    imports = [
      inputs.skwd-wall.nixosModules.default
    ];

    services.skwd-deck.enable = true;
    services.skwd-deck.extraPackages = lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") self.packages.${pkgs.stdenv.hostPlatform.system}.skwd-deck-steamworks;

    # walld runs the configured post-processing command as `sh -c <command>`,
    # resolving both through its own PATH, which the upstream module limits to
    # skwd-paper and skwd-lens. With only the hook added it still logged
    # "post-processing spawn failed: No such file or directory" on every
    # apply: that was `sh`, not the hook. bash ships the `sh` it needs.
    systemd.user.services.skwd-walld.path = [themeHook pkgs.bash];

    environment.systemPackages = [
      themeHook
      (pkgs.writeShellScriptBin "skwd-wall" ''
        exec skwd-wall-v2 "$@"
      '')
    ];

    systemd.user.services.skwd-wall-theme-listener = {
      description = "Skwd Wall Theme Event Listener";
      after = ["skwd-walld.service" "graphical-session.target"];
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      path = with pkgs; [
        "/run/wrappers"
        "/run/current-system/sw"
        coreutils
        findutils
        gnused
        gnugrep
        gawk
        jq
        procps
        dconf
        matugen
        util-linux
        config.programs.fish.package
      ];
      serviceConfig = {
        ExecStart = pkgs.writeShellScript "skwd-wall-theme-listener-start" ''
          SOCKET="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/skwd-wall-v2/wall.sock"
          for i in {1..30}; do
            if [[ -S "$SOCKET" ]]; then
              break
            fi
            sleep 0.5
          done

          # Initial theme sync
          ${themeHook}/bin/skwd-wall-theme-hook || true

          # Event loop from skwd-helm watch. skwd.wall.applied is not handled
          # here: walld's own post-processing hook (configured below) runs the
          # theme hook for that event, and handling it here as well ran it twice.
          ${skwdPkg}/bin/skwd-helm watch 2>/dev/null | while read -r line; do
            EVENT=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.event // empty' 2>/dev/null || true)
            if [[ "$EVENT" == "skwd.wall.theme_done" ]]; then
              SRC_VAL=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.data.source // empty' 2>/dev/null || true)
              ${themeHook}/bin/skwd-wall-theme-hook "$SRC_VAL" || true
            fi
          done
        '';
        Restart = "always";
        RestartSec = 2;
      };
    };

    systemd.user.targets.graphical-session.upholds = ["skwd-wall-theme-listener.service"];

    # Edits the persisted copy: at boot, activation runs before ~/.config is
    # bind-mounted from /persist, so the home path is an empty tmpfs directory
    # and the old version never found config.json there -- the hook was only
    # ever configured by a runtime `switch`. A fresh install has no config.json
    # at all yet; start one with just these keys and walld fills in the rest.
    system.activationScripts.skwdWallInit = lib.stringAfter ["users" "createPersistentStorageDirs"] ''
      CONF_DIR="${
        if config.persistence.enable
        then "/persist/userdata/home/${user}"
        else "/home/${user}"
      }/.config/skwd-wall-v2"
      mkdir -p "$CONF_DIR"
      CONF_FILE="$CONF_DIR/config.json"
      [[ -s "$CONF_FILE" ]] || echo '{}' > "$CONF_FILE"
      # walld substitutes each %placeholder% already shell-quoted
      # ('/path/x.jpg'), so they must not be quoted again: "%path%" reached
      # the hook as a path with literal quotes in it, which no file matches.
      ${pkgs.jq}/bin/jq '.postProcessing = [{"command": "skwd-wall-theme-hook %path% %thumb% %type% %name%", "type": "all"}] | .system.postProcessOnRestore = true' "$CONF_FILE" > "$CONF_FILE.tmp" && mv "$CONF_FILE.tmp" "$CONF_FILE"
      chown -R ${user}:users "$CONF_DIR"
    '';

    persistence.data.directories = [
      ".config/skwd"
      ".local/share/skwd"
      ".local/state/skwd"
      ".config/skwd-wall-v2"
      ".local/share/skwd-wall-v2"
    ];

    persistence.cache.directories = [
      ".cache/skwd-wall-v2"
    ];
  };
}
