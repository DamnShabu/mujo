# mujo desktop — sourced by mujo.sh, never run on its own.
#
# The dispatcher sources this file only when the subcommand is reached, so an
# unrelated `mujo` call never parses it. Every helper from mujo.sh is in scope,
# because sourcing happens in the same shell.

mujo_desktop() {
    [[ $# -ge 1 ]] || { echo "Usage: mujo desktop list|mkdir [name]|new-file [name]|rename <old> <new>|trash <name>...|open <name>|info <name>|path <name>|into <folder> <name>...|copy <name>...|cut <name>...|paste|import <copy|cut> <uri>...|terminal|pos <name> <col> <row>|pos-batch <json>|forget <name>" >&2; exit 1; }
    SUB="$1"; shift
    [[ -d "${DESKTOP_DIR}" && -d "${DESKTOP_POS%/*}" ]] || mkdir -p "${DESKTOP_DIR}" "${DESKTOP_POS%/*}"
    [[ -f "${DESKTOP_POS}" ]] || printf '{}\n' > "${DESKTOP_POS}"

    # Every desktop mutation is a read-modify-write of one small JSON file, and a
    # relayout fires several of them at once. Without this lock they interleave
    # and leave the file unparseable — which then reads as an empty desktop.
    exec 9>"${DESKTOP_POS}.lock"
    flock 9

    # Trust boundary: every name arrives from the shell UI and is joined onto
    # ${DESKTOP_DIR}. Reject anything that could escape that directory or be
    # read as an option, so no UI bug turns a rename into a write elsewhere.
    d_safe() {
      case "$1" in
        ""|.|..)  echo "invalid name: ${1:-<empty>}" >&2; exit 1 ;;
        */*)      echo "name may not contain '/': $1" >&2; exit 1 ;;
        -*)       echo "name may not start with '-': $1" >&2; exit 1 ;;
      esac
    }
    d_commit() { mv "${DESKTOP_POS}.$$" "${DESKTOP_POS}"; }

    # Delete means trash, never unlink — a desktop delete has to stay undoable.
    #
    # gio is tried first so the item lands wherever this system's file managers
    # already look. It refuses when ~/Desktop is its own mount (impermanence
    # bind-mounts it, so it is a different device from $HOME and gio calls that
    # a system-internal mount), and the FreeDesktop spec covers exactly that
    # case with a per-mount .Trash-$uid: same device, so the move is an atomic
    # rename, and every file manager can still restore it.
    d_trash_one() {
      local name="$1" src="${DESKTOP_DIR}/$1"
      gio trash -- "${src}" 2>/dev/null && return 0
      local td
      td="${DESKTOP_DIR}/.Trash-$(id -u)"
      mkdir -p "${td}/files" "${td}/info" || return 1
      local target="${name}" n=2
      while [[ -e "${td}/files/${target}" || -e "${td}/info/${target}.trashinfo" ]]; do
        target="${name}.${n}"; n=$((n + 1))
      done
      # Path is relative to the trash dir's top level and URL-encoded, per spec.
      printf '[Trash Info]\nPath=%s\nDeletionDate=%s\n' \
        "$(jq -rn --arg s "${name}" '$s | @uri')" "$(date +%Y-%m-%dT%H:%M:%S)" \
        > "${td}/info/${target}.trashinfo" || return 1
      mv -nT -- "${src}" "${td}/files/${target}" && return 0
      rm -f "${td}/info/${target}.trashinfo"   # our own metadata only
      return 1
    }

    # A name that does not collide inside ${1}, suffixed " (2)", " (3)", … before
    # the extension the way every file manager does it.
    d_free_name() {
      local dir="$1" base="$2" stem="${2%.*}" ext="" target n=2
      [[ "${stem}" != "${base}" ]] && ext=".${base##*.}"
      target="${base}"
      while [[ -e "${dir}/${target}" ]]; do target="${stem} (${n})${ext}"; n=$((n + 1)); done
      printf '%s' "${target}"
    }

    # file:// URI → path. Percent-decoding goes through printf %b, so literal
    # backslashes in a name are escaped first or %b would eat them.
    d_uri2path() {
      local u="${1#file://}"
      u="${u//\\/\\\\}"
      printf '%b' "${u//%/\\x}"
    }

    # Copy or move a newline-separated URI/path list from stdin into ~/Desktop.
    # Shared by `paste` (system clipboard) and `import` (a drag from another app).
    d_import() {
      local mode="$1" line src base target
      while IFS= read -r line; do
        line="${line%$'\r'}"
        [[ -n "${line}" ]] || continue
        case "${line}" in \#*) continue ;; esac
        src="$(d_uri2path "${line}")"
        [[ -e "${src}" ]] || continue
        # Dropping something back onto the desktop it already lives on is a
        # no-op for a move, and a duplicate for a copy.
        [[ "${mode}" == "cut" && "$(dirname -- "${src}")" == "${DESKTOP_DIR}" ]] && continue
        base="$(basename -- "${src}")"
        target="$(d_free_name "${DESKTOP_DIR}" "${base}")"
        if [[ "${mode}" == "cut" ]]; then
          # Cross-device moves cannot rename, so fall back to copy-then-remove.
          mv -nT -- "${src}" "${DESKTOP_DIR}/${target}" 2>/dev/null && continue
          cp -aT -- "${src}" "${DESKTOP_DIR}/${target}" && rm -rf -- "${src}"
        else
          cp -aT -- "${src}" "${DESKTOP_DIR}/${target}"
        fi
      done
    }

    case "${SUB}" in
      list)
        # Fields are '|'-separated and the name comes last, so a name containing
        # '|' is put back together by the join; "/" is the one byte a POSIX
        # filename can never hold, so it delimits records safely. Size and mtime
        # ride along because the UI sorts and shows properties from them, and a
        # second stat pass per icon would cost a process each.
        # Dotfiles stay hidden, as on any other desktop. Folders sort before files.
        find "${DESKTOP_DIR}" -mindepth 1 -maxdepth 1 -not -name '.*' -printf '%Y|%s|%T@|%f/' 2>/dev/null \
          | jq -Rs --slurpfile pos "${DESKTOP_POS}" '
              ($pos[0] // {}) as $p
              | split("/") | map(select(length > 0))
              | map(split("|") | { name: (.[3:] | join("|")), isDir: (.[0] == "d"),
                                   size: (.[1] | tonumber), mtime: (.[2] | tonumber) })
              | sort_by([(if .isDir then 0 else 1 end), (.name | ascii_downcase)])
              | { items: ., positions: $p }'
        ;;
      new-file)
        BASE="${1:-New Text Document.txt}"
        d_safe "${BASE}"
        NAME="$(d_free_name "${DESKTOP_DIR}" "${BASE}")"
        : > "${DESKTOP_DIR}/${NAME}"
        echo "${NAME}"
        ;;
      path)
        [[ $# -ge 1 ]] || { echo "usage: path <name>" >&2; exit 1; }
        d_safe "$1"
        printf '%s\n' "${DESKTOP_DIR}/$1"
        ;;
      info)
        [[ $# -ge 1 ]] || { echo "usage: info <name>" >&2; exit 1; }
        d_safe "$1"
        P="${DESKTOP_DIR}/$1"
        [[ -e "${P}" ]] || { echo "no such item: $1" >&2; exit 1; }
        if [[ -d "${P}" ]]; then
          KIND="Folder"
          COUNT="$(find "${P}" -mindepth 1 -maxdepth 1 -not -name '.*' -printf 'x' 2>/dev/null | wc -c)"
          BYTES="$(du -sb -- "${P}" 2>/dev/null | cut -f1)"
        else
          KIND="$(xdg-mime query filetype "${P}" 2>/dev/null || true)"
          [[ -n "${KIND}" ]] || KIND="File"
          COUNT="null"
          BYTES="$(stat -c %s -- "${P}")"
        fi
        jq -n --arg n "$1" --arg p "${P}" --arg k "${KIND}" \
              --arg m "$(stat -c %y -- "${P}" | cut -d. -f1)" \
              --arg a "$(stat -c %A -- "${P}")" \
              --argjson b "${BYTES:-0}" --argjson c "${COUNT:-null}" \
              '{name:$n,path:$p,kind:$k,modified:$m,mode:$a,bytes:$b,items:$c}'
        ;;
      into)
        # Drop one desktop item onto a desktop folder: the move a file manager
        # does, minus any notion of a destination outside ~/Desktop.
        [[ $# -ge 2 ]] || { echo "usage: into <folder> <name>..." >&2; exit 1; }
        DEST="$1"; shift
        d_safe "${DEST}"
        [[ -d "${DESKTOP_DIR}/${DEST}" ]] || { echo "not a folder: ${DEST}" >&2; exit 1; }
        for NAME in "$@"; do
          d_safe "${NAME}"
          [[ "${NAME}" == "${DEST}" ]] && continue
          [[ -e "${DESKTOP_DIR}/${NAME}" ]] || continue
          T="$(d_free_name "${DESKTOP_DIR}/${DEST}" "${NAME}")"
          mv -nT -- "${DESKTOP_DIR}/${NAME}" "${DESKTOP_DIR}/${DEST}/${T}" || continue
          jq --arg n "${NAME}" 'del(.[$n])' "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        done
        ;;
      copy | cut)
        # x-special/gnome-copied-files is what every GTK file manager reads and
        # writes, so a desktop copy pastes into Nautilus/Thunar/Nemo and back.
        # Line 1 is the verb, then one file URI per line.
        [[ $# -ge 1 ]] || { echo "usage: ${SUB} <name>..." >&2; exit 1; }
        PAYLOAD="${SUB}"
        for NAME in "$@"; do
          d_safe "${NAME}"
          [[ -e "${DESKTOP_DIR}/${NAME}" ]] || continue
          # @uri escapes the separators too, so put the path separators back.
          URI="$(jq -rn --arg s "${DESKTOP_DIR}/${NAME}" '$s | @uri' | sed 's/%2F/\//g')"
          PAYLOAD="${PAYLOAD}"$'\n'"file://${URI}"
        done
        # wl-copy stays resident to serve the selection. Hand it a closed fd 9 or
        # it inherits the flock and every later desktop command blocks on it.
        printf '%s' "${PAYLOAD}" | wl-copy -t x-special/gnome-copied-files 9>&- >/dev/null 2>&1
        ;;
      paste)
        DATA="$(wl-paste -t x-special/gnome-copied-files 2>/dev/null || true)"
        if [[ -n "${DATA}" ]]; then
          MODE="$(printf '%s' "${DATA}" | head -1)"
          printf '%s\n' "${DATA}" | tail -n +2 | d_import "${MODE}"
        else
          # Anything that offers plain URIs (a browser, a terminal drag) is a copy.
          DATA="$(wl-paste -t text/uri-list 2>/dev/null || true)"
          [[ -n "${DATA}" ]] || { echo "clipboard holds no files" >&2; exit 1; }
          printf '%s\n' "${DATA}" | d_import copy
        fi
        ;;
      import)
        [[ $# -ge 2 ]] || { echo "usage: import <copy|cut> <uri>..." >&2; exit 1; }
        MODE="$1"; shift
        printf '%s\n' "$@" | d_import "${MODE}"
        ;;
      terminal)
        setsid -f "${TERMINAL:-kitty}" --directory "${DESKTOP_DIR}" 9>&- >/dev/null 2>&1 &
        ;;
      mkdir)
        BASE="${1:-New Folder}"
        d_safe "${BASE}"
        NAME="${BASE}"; N=2
        while [[ -e "${DESKTOP_DIR}/${NAME}" ]]; do NAME="${BASE} (${N})"; N=$((N + 1)); done
        mkdir -- "${DESKTOP_DIR}/${NAME}"
        echo "${NAME}"
        ;;
      rename)
        [[ $# -ge 2 ]] || { echo "usage: rename <old> <new>" >&2; exit 1; }
        d_safe "$1"; d_safe "$2"
        [[ -e "${DESKTOP_DIR}/$1" ]] || { echo "no such item: $1" >&2; exit 1; }
        [[ "$1" == "$2" ]] && exit 0
        [[ -e "${DESKTOP_DIR}/$2" ]] && { echo "already exists: $2" >&2; exit 1; }
        # -T so renaming onto a directory errors instead of silently nesting the
        # source inside it; -n so an item created in the race is never clobbered.
        mv -nT -- "${DESKTOP_DIR}/$1" "${DESKTOP_DIR}/$2"
        jq --arg o "$1" --arg n "$2" \
          'if has($o) then (.[$n] = .[$o] | del(.[$o])) else . end' \
          "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        echo "$2"
        ;;
      trash)
        [[ $# -ge 1 ]] || { echo "usage: trash <name>..." >&2; exit 1; }
        for NAME in "$@"; do
          d_safe "${NAME}"
          [[ -e "${DESKTOP_DIR}/${NAME}" ]] || continue
          d_trash_one "${NAME}" || { echo "could not trash: ${NAME}" >&2; exit 1; }
          jq --arg n "${NAME}" 'del(.[$n])' "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        done
        ;;
      open)
        [[ $# -ge 1 ]] || { echo "usage: open <name>" >&2; exit 1; }
        d_safe "$1"
        [[ -e "${DESKTOP_DIR}/$1" ]] || { echo "no such item: $1" >&2; exit 1; }
        # 9>&- so a launched app never inherits the flock and wedges the next command.
        gio open "${DESKTOP_DIR}/$1" 9>&-
        ;;
      pos)
        [[ $# -ge 3 ]] || { echo "usage: pos <name> <col> <row>" >&2; exit 1; }
        d_safe "$1"
        jq --arg n "$1" --argjson c "$2" --argjson r "$3" '.[$n] = {col: $c, row: $r}' \
          "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        ;;
      pos-batch)
        # {"name":{"col":N,"row":M},...} in one write. A first run on a populated
        # desktop places every icon at once; one process per icon would be both
        # slower and a pile-up on the lock.
        [[ $# -ge 1 ]] || { echo "usage: pos-batch <json>" >&2; exit 1; }
        echo "$1" | jq -e 'type == "object"' >/dev/null 2>&1 \
          || { echo "pos-batch expects a JSON object" >&2; exit 1; }
        if echo "$1" | jq -e 'any(keys[]; test("/") or . == "" or . == "." or . == "..")' >/dev/null 2>&1; then
          echo "pos-batch: invalid name in payload" >&2; exit 1
        fi
        jq --argjson b "$1" '. + $b' "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        ;;
      forget)
        [[ $# -ge 1 ]] || { echo "usage: forget <name>" >&2; exit 1; }
        jq --arg n "$1" 'del(.[$n])' "${DESKTOP_POS}" > "${DESKTOP_POS}.$$" && d_commit
        ;;
      *) echo "unknown: ${SUB}" >&2; exit 1 ;;
    esac
}
