{...}: {
  flake.wrappers.fish = {
    wlib,
    pkgs,
    lib,
    ...
  }: {
    imports = [wlib.wrapperModules.fish];
    configFile.content = let
      lf = pkgs.lf;
    in
      # fish
      ''
        # -------------------------------------------------------------------------
        # Theme & Prompt (Mūjō — dynamic palette synced with quickshell)
        # -------------------------------------------------------------------------
        if test -f "$HOME/.config/quickshell/fish-theme.fish"
            source "$HOME/.config/quickshell/fish-theme.fish"
        end

        # Git prompt styling with Nerd Font symbols
        set -g __fish_git_prompt_showdirtystate 1
        set -g __fish_git_prompt_showstashstate 1
        set -g __fish_git_prompt_showuntrackedfiles 1
        set -g __fish_git_prompt_showupstream auto
        set -g __fish_git_prompt_char_dirtystate '󰏫 '
        set -g __fish_git_prompt_char_stagedstate '󰐕 '
        set -g __fish_git_prompt_char_untrackedfiles '󰄱 '
        set -g __fish_git_prompt_char_stashstate '󰋚 '
        set -g __fish_git_prompt_char_upstream_ahead '↑'
        set -g __fish_git_prompt_char_upstream_behind '↓'
        set -g __fish_git_prompt_char_cleanstate ""

        function fish_prompt
            set -l last_status $status

            # Dynamic theme colors (fallback to palette defaults)
            set -l c_accent $mujo_prompt_color_accent
            test -n "$c_accent"; or set c_accent "5cc2ff"

            set -l c_error $mujo_prompt_color_error
            test -n "$c_error"; or set c_error "f07178"

            set -l c_dim $mujo_prompt_color_dim
            test -n "$c_dim"; or set c_dim "565d68"

            set -l c_cwd $mujo_prompt_color_cwd
            test -n "$c_cwd"; or set c_cwd "e5c07b"

            set -l c_bg $mujo_prompt_color_bg
            test -n "$c_bg"; or set c_bg "242831"

            set -l c_fg $mujo_prompt_color_text
            test -n "$c_fg"; or set c_fg "abb2bf"

            set -l c_git $mujo_prompt_color_git
            test -n "$c_git"; or set c_git "c678dd"

            set -l c_nix $mujo_prompt_color_nix
            test -n "$c_nix"; or set c_nix "56b6c2"

            # Line 1: Rounded pills
            # Remote SSH session or root user indicator
            if test -n "$SSH_TTY" -o "$USER" = "root"
                set_color $c_bg
                echo -n ""
                set_color -b $c_bg $c_error -o
                if test "$USER" = "root"
                    echo -n "󰀶 "
                else
                    echo -n "󰌢 "
                end
                set_color -b $c_bg $c_fg
                echo -n "$USER@$hostname "
                set_color normal
                set_color $c_bg
                echo -n ""
                set_color normal
                echo -n " "
            end

            # Working directory pill
            set -l pwd_str (prompt_pwd)
            set_color $c_bg
            echo -n ""
            set_color -b $c_bg $c_cwd -o
            echo -n "󰉋 "
            set_color -b $c_bg $c_fg
            echo -n "$pwd_str "
            set_color normal
            set_color $c_bg
            echo -n ""
            set_color normal

            # Git prompt indicator pill
            if type -q fish_git_prompt
                set -l git_info (string trim (fish_git_prompt "%s"))
                if test -n "$git_info"
                    echo -n " "
                    set_color $c_bg
                    echo -n ""
                    set_color -b $c_bg $c_git -o
                    echo -n "󰊢 "
                    set_color -b $c_bg $c_fg
                    echo -n "$git_info "
                    set_color normal
                    set_color $c_bg
                    echo -n ""
                    set_color normal
                end
            end

            # Nix shell / dev environment pill
            if test -n "$IN_NIX_SHELL" -o -n "$DIRENV_DIR"
                echo -n " "
                set_color $c_bg
                echo -n ""
                set_color -b $c_bg $c_nix -o
                echo -n "󱄅 "
                set_color -b $c_bg $c_fg
                if test -n "$name"
                    echo -n "$name "
                else
                    echo -n "nix "
                end
                set_color normal
                set_color $c_bg
                echo -n ""
                set_color normal
            end

            # Exit error badge (if previous command returned error)
            if test $last_status -ne 0
                echo -n " "
                set_color $c_bg
                echo -n ""
                set_color -b $c_bg $c_error -o
                echo -n "󰅚 "
                set_color -b $c_bg $c_error
                echo -n "$last_status "
                set_color normal
                set_color $c_bg
                echo -n ""
                set_color normal
            end

            # Line 2: Prompt character
            echo
            if test $last_status -eq 0
                set_color $c_accent -o
            else
                set_color $c_error -o
            end
            echo -n '$ '
            set_color normal
        end

        set -g fish_greeting

        function cf --wraps=cutefetch --description="Cute fetch"
            if test (count $argv) -eq 0
                command cutefetch -r
            else
                command cutefetch $argv
            end
        end

        if status is-interactive
            and test -z "$NVIM"
            and test -z "$INSIDE_EMACS"
            if type -q cutefetch
                cutefetch -r
            else if type -q cf
                cf -r
            end
        end
        set -gx PATH $HOME/.local/bin $PATH

        ${lib.getExe pkgs.zoxide} init fish | source

        function lf --wraps="${lib.getExe lf}" --description="lf - Terminal file manager (changing directory on exit)"
            cd "$(command ${lib.getExe lf} -print-last-dir $argv)"
        end

        if type -q direnv
            direnv hook fish | source
        end

        function sshell
            if test (count $argv) -lt 1
                echo "Usage: sshfs_mount user@host:/remote/path"
                return 1
            end

            set remote $argv[1]
            set host (string replace -r ':.*' "" $remote | string replace -r '.*@' "")
            set mnt $HOME/.local/mnt/$host

            mkdir -p $mnt || return 1

            if mountpoint -q $mnt
                echo "Already mounted at $mnt"
                return 1
            end

            echo "Mounting $remote at $mnt"

            fish --init-command "
                sshfs -f -o auto_unmount $remote $mnt &
                cd $mnt
                function fish_prompt
                    set_color cyan --bold
                    echo -n '[$remote] '
                    set_color normal
                    echo -n (prompt_pwd)
                    set_color green
                    echo -n ' > '
                    set_color normal
                end
                function exit_handler --on-event fish_exit
                    cd ~
                    set mnt "(string escape $mnt)"
                    if test -n \"$mnt\"
                        if mountpoint -q \"$mnt\"
                            if umount \"$mnt\"
                                echo \"unmounted $mnt successfully\"
                            else
                                echo \"failed to unmount $mnt\"
                            end
                        else
                            echo \"$mnt is not a mountpoint\"
                        end
                    end
                end
            "
        end

        complete -c sshell -a '(__fish_complete_user_at_hosts)' -d 'Remote host'

        # -------------------------------------------------------------------------
        # Abbreviations (auto-expand inline on Space / Enter)
        # -------------------------------------------------------------------------

        # Navigation
        abbr -a .. 'cd ..'
        abbr -a ... 'cd ../..'
        abbr -a .... 'cd ../../..'
        abbr -a nconf 'cd ~/nixconf'

        # Nix / NixOS & Flakes
        abbr -a nos 'nh os switch ~/nixconf/'
        abbr -a nob 'nh os boot ~/nixconf/'
        abbr -a nclean 'nh clean all'
        abbr -a nfc 'nix flake check'
        abbr -a nfs 'nix flake show'
        abbr -a nfu 'nix flake update'
        abbr -a nr 'nix run'
        abbr -a nb 'nix build'
        abbr -a nd 'nix develop'
        abbr -a ns 'nix-shell -p'
        abbr -a npr 'nix run .#sandbox'

        # Quickshell & Mujō Desktop
        abbr -a qsb 'qs -p ./quickshell/bar/shell.qml'
        abbr -a qsk 'qs kill -i'
        abbr -a mj 'mujo'
        abbr -a mjs 'mujo settings'
        abbr -a mjt 'mujo theme'
        abbr -a mjts 'mujo theme set'
        abbr -a mjta 'mujo theme accent'

        # Git
        abbr -a g 'git'
        abbr -a ga 'git add'
        abbr -a gaa 'git add --all'
        abbr -a gap 'git add -p'
        abbr -a gc 'git commit -v'
        abbr -a gcm 'git commit -m'
        abbr -a gca 'git commit --amend'
        abbr -a gcan 'git commit --amend --no-edit'
        abbr -a gco 'git checkout'
        abbr -a gcb 'git checkout -b'
        abbr -a gsw 'git switch'
        abbr -a gswc 'git switch -c'
        abbr -a gst 'git status --short --branch'
        abbr -a gd 'git diff'
        abbr -a gds 'git diff --staged'
        abbr -a gl 'git log --oneline --graph --decorate -n 20'
        abbr -a gla 'git log --oneline --graph --decorate --all'
        abbr -a gp 'git push'
        abbr -a gpf 'git push --force-with-lease'
        abbr -a gpl 'git pull --rebase'
        abbr -a gf 'git fetch --all --prune'
        abbr -a grb 'git rebase'
        abbr -a grba 'git rebase --abort'
        abbr -a grbc 'git rebase --continue'
        abbr -a gsta 'git stash push'
        abbr -a gstp 'git stash pop'
        abbr -a gstl 'git stash list'
        abbr -a lg 'lazygit'

        # Modern CLI tools (eza, dust, ripgrep, cutefetch)
        abbr -a l 'eza -lh --group-directories-first --icons'
        abbr -a ll 'eza -lah --group-directories-first --icons'
        abbr -a la 'eza -a --group-directories-first --icons'
        abbr -a lt 'eza --tree --level=2 --icons'
        abbr -a ltt 'eza --tree --level=3 --icons'
        abbr -a rg 'rg --smart-case'
        abbr -a du 'dust'
        abbr -a cf 'cutefetch -r'
        abbr -a ff 'cutefetch -r'

        # Systemd & Journalctl
        abbr -a sc 'systemctl'
        abbr -a scu 'systemctl --user'
        abbr -a scs 'systemctl status'
        abbr -a scus 'systemctl --user status'
        abbr -a scr 'systemctl restart'
        abbr -a scur 'systemctl --user restart'
        abbr -a jc 'journalctl'
        abbr -a jcf 'journalctl -f'
        abbr -a jcu 'journalctl --user'
        abbr -a jcuf 'journalctl --user -f'
        abbr -a jce 'journalctl -xe'

        # Graphify
        abbr -a gqu 'graphify query'
        abbr -a gup 'graphify update .'
        abbr -a gex 'graphify explain'
      '';
  };
}
