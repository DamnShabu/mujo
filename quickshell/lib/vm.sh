# mujo vm — sourced by mujo.sh, never run on its own.
#
# The dispatcher sources this file only when the subcommand is reached, so an
# unrelated `mujo` call never parses it. Every helper from mujo.sh is in scope,
# because sourcing happens in the same shell.

mujo_vm() {
    [[ $# -ge 1 ]] || vm_usage
    SUB="$1"; shift
    VM_DIR="${HOME}/VMs"
    mkdir -p "${VM_DIR}" 2>/dev/null
    case "${SUB}" in
      list)
        KVM_OK="false"
        [[ -r /dev/kvm && -w /dev/kvm ]] && KVM_OK="true"
        
        # Check Mujō Testing Sandbox VM status
        SANDBOX_PID="$(pgrep -f "qemu.*mujo-sandbox|nixos-test-driver|sandbox/mcp\.py" | head -1 || echo "")"
        SANDBOX_STATUS="stopped"
        SANDBOX_DISPLAY_READY=false
        if [[ -n "${SANDBOX_PID}" && -d "/proc/${SANDBOX_PID}" ]]; then
          SANDBOX_STATUS="running"
          if timeout 1 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5920 && exec 3>&-' 2>/dev/null; then
            SANDBOX_DISPLAY_READY=true
          fi
        fi
        
        SANDBOX_JSON="$(jq -n \
          --arg status "${SANDBOX_STATUS}" \
          --arg pid "${SANDBOX_PID}" \
          --argjson displayReady "${SANDBOX_DISPLAY_READY}" \
          '{
            name: "mujo-sandbox",
            conf: "nixos/sandbox/sandbox.nix",
            os: "nixos",
            release: "25.11",
            category: "NixOS",
            icon: "nixos",
            status: $status,
            displayReady: $displayReady,
            pid: (if $pid == "" then null else ($pid | tonumber) end),
            cores: 8,
            ram: "4G",
            diskSize: "tmpfs (ephemeral)",
            diskMb: 0,
            spicePort: 5920,
            iso: "repo (9p /mnt/nixconf)",
            isSandbox: true,
            desc: "Disposable NixOS graphical testing sandbox with live 9p quickshell mount & MCP integration"
          }')"

        USER_VMS_JSON="$(
          find "${VM_DIR}" -maxdepth 2 -name "*.conf" 2>/dev/null | sort | while read -r conf_file; do
            [[ -f "${conf_file}" ]] || continue
            vm_name="$(basename "${conf_file}" .conf)"
            vm_dir="$(dirname "${conf_file}")"
            
            # Parse configuration keys
            guest_os="$(grep -E '^[[:space:]]*guest_os=' "${conf_file}" | head -1 | cut -d= -f2- | tr -d '"'\'' ' || echo "")"
            os_name="$(grep -E '^[[:space:]]*os=' "${conf_file}" | head -1 | cut -d= -f2- | tr -d '"'\'' ' || echo "")"
            release_val="$(grep -E '^[[:space:]]*release=' "${conf_file}" | head -1 | cut -d= -f2- | tr -d '"'\'' ' || echo "")"
            cores_val="$(grep -E '^[[:space:]]*cpu_cores=' "${conf_file}" | head -1 | cut -d= -f2- | tr -d '"'\'' ' || echo "8")"
            ram_val="$(grep -E '^[[:space:]]*ram=' "${conf_file}" | head -1 | cut -d= -f2- | tr -d '"'\'' ' || echo "8G")"
            disk_size_val="$(grep -E '^[[:space:]]*disk_size=' "${conf_file}" | head -1 | cut -d= -f2- | tr -d '"'\'' ' || echo "40G")"
            iso_val="$(grep -E '^[[:space:]]*iso=' "${conf_file}" | head -1 | cut -d= -f2- | tr -d '"'\'' ' || echo "")"
            
            # Check running state via qemu process or pid files
            pid=""
            status="stopped"
            qpid="$(pgrep -f "qemu.*${vm_name}" | head -1 || echo "")"
            if [[ -z "${qpid}" && -f "${vm_dir}/${vm_name}.pid" ]]; then
              saved_pid="$(cat "${vm_dir}/${vm_name}.pid" 2>/dev/null || echo "")"
              if [[ -n "${saved_pid}" && -d "/proc/${saved_pid}" ]]; then
                qpid="${saved_pid}"
              fi
            fi
            if [[ -z "${qpid}" && -f "${vm_dir}/${vm_name}/${vm_name}.pid" ]]; then
              saved_pid="$(cat "${vm_dir}/${vm_name}/${vm_name}.pid" 2>/dev/null || echo "")"
              if [[ -n "${saved_pid}" && -d "/proc/${saved_pid}" ]]; then
                qpid="${saved_pid}"
              fi
            fi
            
            spice_port="5900"
            if [[ -n "${qpid}" ]]; then
              status="running"
              pid="${qpid}"
              ports_file=""
              [[ -f "${vm_dir}/${vm_name}.ports" ]] && ports_file="${vm_dir}/${vm_name}.ports"
              [[ -z "${ports_file}" && -f "${vm_dir}/${vm_name}/${vm_name}.ports" ]] && ports_file="${vm_dir}/${vm_name}/${vm_name}.ports"
              if [[ -n "${ports_file}" ]]; then
                p_val="$(grep -E '^spice,' "${ports_file}" | cut -d, -f2 | tr -d ' ' || echo "")"
                [[ -n "${p_val}" ]] && spice_port="${p_val}"
              fi
            fi
            
            # Calculate disk size on host
            disk_mb=0
            disk_file="$(find "${vm_dir}" -name "${vm_name}*.qcow2" 2>/dev/null | head -1 || echo "")"
            [[ -z "${disk_file}" ]] && disk_file="$(find "${vm_dir}/${vm_name}" -name "*.qcow2" 2>/dev/null | head -1 || echo "")"
            if [[ -f "${disk_file}" ]]; then
              disk_mb="$(du -m "${disk_file}" 2>/dev/null | awk '{print $1}' || echo 0)"
            fi
            
            # Infer human-friendly OS display name and category
            inferred_os="${guest_os:-${os_name}}"
            category="Linux"
            icon="linux"
            check_str="${inferred_os,,}-${vm_name,,}"
            case "${check_str}" in
              *windows*|*win*) category="Windows"; icon="windows" ;;
              *ubuntu*) category="Linux"; icon="ubuntu" ;;
              *fedora*) category="Linux"; icon="fedora" ;;
              *arch*) category="Linux"; icon="arch" ;;
              *debian*) category="Linux"; icon="debian" ;;
              *alpine*) category="Linux"; icon="alpine" ;;
              *macos*|*darwin*|*osx*) category="Apple"; icon="macos" ;;
              *freebsd*|*bsd*) category="BSD"; icon="freebsd" ;;
              *nixos*|*sandbox*) category="NixOS"; icon="nixos" ;;
              *) category="Linux"; icon="terminal" ;;
            esac
            
            jq -n \
              --arg name "${vm_name}" \
              --arg conf "${conf_file}" \
              --arg os "${inferred_os:-linux}" \
              --arg release "${release_val}" \
              --arg category "${category}" \
              --arg icon "${icon}" \
              --arg status "${status}" \
              --arg pid "${pid}" \
              --arg cores "${cores_val}" \
              --arg ram "${ram_val}" \
              --arg diskSize "${disk_size_val}" \
              --argjson diskMb "${disk_mb:-0}" \
              --arg spicePort "${spice_port}" \
              --arg iso "${iso_val}" \
              '{
                name: $name,
                conf: $conf,
                os: $os,
                release: $release,
                category: $category,
                icon: $icon,
                status: $status,
                pid: (if $pid == "" then null else ($pid | tonumber) end),
                cores: ($cores | tonumber? // 8),
                ram: $ram,
                diskSize: $diskSize,
                diskMb: $diskMb,
                spicePort: ($spicePort | tonumber? // 5900),
                iso: $iso,
                isSandbox: false
              }'
          done | jq -s '.'
        )"
        [[ -n "${USER_VMS_JSON}" ]] || USER_VMS_JSON="[]"
        VMS_JSON="$(printf '%s\n%s' "${SANDBOX_JSON}" "${USER_VMS_JSON}" | jq -s '.[0] as $sb | (.[1] // []) as $rest | [$sb] + $rest')"
        
        jq -n \
          --argjson kvm "${KVM_OK}" \
          --argjson vms "${VMS_JSON}" \
          --arg vmDir "${VM_DIR}" '
          ($vms | map(select(.status == "running"))) as $active |
          ($active | map(.cores) | add // 0) as $vcpus |
          {
            kvm: $kvm,
            vmDir: $vmDir,
            vms: $vms,
            totalCount: ($vms | length),
            activeCount: ($active | length),
            vcpusAllocated: $vcpus
          }'
        ;;

      catalog)
        cat <<'EOF'
[
  {
    "id": "mujo-sandbox",
    "os": "nixos",
    "release": "25.11",
    "name": "Mujō Testing Sandbox",
    "category": "NixOS",
    "icon": "nixos",
    "defaultCores": 8,
    "defaultRamGb": 4,
    "defaultDiskGb": 0,
    "desc": "Disposable NixOS graphical testing sandbox with live 9p quickshell/bar mount, Niri compositor & MCP agent integration.",
    "isSandbox": true
  },
  {
    "id": "ubuntu-24.04",
    "os": "ubuntu",
    "release": "24.04",
    "name": "Ubuntu 24.04 LTS (Noble Numbat)",
    "category": "Linux",
    "icon": "ubuntu",
    "defaultCores": 8,
    "defaultRamGb": 8,
    "defaultDiskGb": 40,
    "desc": "Long-term support release featuring GNOME 46 and Linux 6.8 kernel."
  },
  {
    "id": "windows-11",
    "os": "windows",
    "release": "11",
    "name": "Windows 11 (UEFI & TPM 2.0)",
    "category": "Windows",
    "icon": "windows",
    "defaultCores": 8,
    "defaultRamGb": 8,
    "defaultDiskGb": 64,
    "desc": "Full Microsoft Windows 11 desktop with VirtIO drivers & TPM support."
  },
  {
    "id": "windows-10",
    "os": "windows",
    "release": "10",
    "name": "Windows 10 Pro / Home",
    "category": "Windows",
    "icon": "windows",
    "defaultCores": 8,
    "defaultRamGb": 8,
    "defaultDiskGb": 50,
    "desc": "Stable Windows 10 workstation with full DirectX/Direct3D acceleration."
  },
  {
    "id": "fedora-42",
    "os": "fedora",
    "release": "42",
    "name": "Fedora 42 Workstation",
    "category": "Linux",
    "icon": "fedora",
    "defaultCores": 8,
    "defaultRamGb": 8,
    "defaultDiskGb": 40,
    "desc": "Upstream innovation with Wayland, GNOME, and PipeWire integration."
  },
  {
    "id": "archlinux",
    "os": "archlinux",
    "release": "latest",
    "name": "Arch Linux",
    "category": "Linux",
    "icon": "arch",
    "defaultCores": 8,
    "defaultRamGb": 8,
    "defaultDiskGb": 40,
    "desc": "Rolling release base environment with pacman package ecosystem."
  },
  {
    "id": "debian-12",
    "os": "debian",
    "release": "12.15.0",
    "name": "Debian 12 (Bookworm)",
    "category": "Linux",
    "icon": "debian",
    "defaultCores": 6,
    "defaultRamGb": 6,
    "defaultDiskGb": 30,
    "desc": "Rock-solid stability for mission-critical builds and sandboxed servers."
  },
  {
    "id": "alpine",
    "os": "alpine",
    "release": "v3.24",
    "name": "Alpine Linux Extended",
    "category": "Linux",
    "icon": "alpine",
    "defaultCores": 4,
    "defaultRamGb": 4,
    "defaultDiskGb": 20,
    "desc": "Ultra-lightweight, secure musl-based container & virtualization base."
  },
  {
    "id": "macos-sonoma",
    "os": "macos",
    "release": "sonoma",
    "name": "macOS 14 (Sonoma)",
    "category": "Apple",
    "icon": "macos",
    "defaultCores": 8,
    "defaultRamGb": 12,
    "defaultDiskGb": 80,
    "desc": "Apple macOS guest environment powered by OpenCore EFI bootloader."
  }
]
EOF
        ;;

      create)
        [[ $# -ge 2 ]] || { echo "Usage: mujo vm create <os> <release> [--name <name>] [--cores <N>] [--ram <GB>] [--disk <GB>]" >&2; exit 1; }
        OS_NAME="$1"; RELEASE="$2"; shift 2
        VM_NAME="${OS_NAME}-${RELEASE}"
        CORES=8
        RAM_GB=8
        DISK_GB=40
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            --cores) CORES="$2"; shift 2 ;;
            --ram) RAM_GB="$2"; shift 2 ;;
            --disk) DISK_GB="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        
        if [[ "${OS_NAME}" == "mujo-sandbox" || "${OS_NAME}" == "nixos" ]]; then
          echo '{"type":"progress","phase":"done","percent":100,"status":"Testing sandbox VM is built-in. Run with: nix run .#sandbox"}'
          exit 0
        fi

        CONF_FILE="${VM_DIR}/${VM_NAME}.conf"
        echo '{"type":"progress","phase":"init","percent":5,"status":"Initializing VM configuration..."}'
        if command -v quickget >/dev/null 2>&1; then
          echo '{"type":"progress","phase":"download","percent":10,"status":"Downloading OS image with quickget..."}'
          if ! (cd "${VM_DIR}" && quickget "${OS_NAME}" "${RELEASE}" 2>&1 | tr '\r' '\n'); then
            echo '{"type":"progress","phase":"error","percent":0,"status":"quickget failed to download image"}' >&2
            exit 1
          fi
        else
          echo '{"type":"progress","phase":"error","percent":0,"status":"quickget is not installed"}' >&2
          exit 1
        fi
        
        # Check if quickget created a conf file (e.g. ${OS_NAME}-${RELEASE}.conf or ${OS_NAME}.conf)
        GEN_CONF=""
        if [[ -f "${VM_DIR}/${OS_NAME}-${RELEASE}.conf" ]]; then
          GEN_CONF="${VM_DIR}/${OS_NAME}-${RELEASE}.conf"
        elif [[ -f "${VM_DIR}/${OS_NAME}.conf" ]]; then
          GEN_CONF="${VM_DIR}/${OS_NAME}.conf"
        elif [[ -f "${CONF_FILE}" ]]; then
          GEN_CONF="${CONF_FILE}"
        fi

        if [[ -n "${GEN_CONF}" && "${GEN_CONF}" != "${CONF_FILE}" ]]; then
          cp "${GEN_CONF}" "${CONF_FILE}"
        fi

        echo '{"type":"progress","phase":"configuring","percent":85,"status":"Writing hardware configuration..."}'
        if [[ -f "${CONF_FILE}" ]]; then
          grep -q '^cpu_cores=' "${CONF_FILE}" && sed -i "s/^cpu_cores=.*/cpu_cores=\"${CORES}\"/" "${CONF_FILE}" || echo "cpu_cores=\"${CORES}\"" >> "${CONF_FILE}"
          grep -q '^ram=' "${CONF_FILE}" && sed -i "s/^ram=.*/ram=\"${RAM_GB}G\"/" "${CONF_FILE}" || echo "ram=\"${RAM_GB}G\"" >> "${CONF_FILE}"
          grep -q '^disk_size=' "${CONF_FILE}" && sed -i "s/^disk_size=.*/disk_size=\"${DISK_GB}G\"/" "${CONF_FILE}" || echo "disk_size=\"${DISK_GB}G\"" >> "${CONF_FILE}"
          echo '{"type":"progress","phase":"done","percent":100,"status":"Created VM configuration '"${CONF_FILE}"'"}'
        else
          echo '{"type":"progress","phase":"error","percent":0,"status":"Configuration file could not be generated"}' >&2
          exit 1
        fi
        ;;

      create-iso)
        [[ $# -ge 2 ]] || { echo "Usage: mujo vm create-iso <name> <iso-path> [--cores <N>] [--ram <GB>] [--disk <GB>] [--os <linux|windows>]" >&2; exit 1; }
        VM_NAME="$1"; ISO_PATH="$2"; shift 2
        CORES=8
        RAM_GB=8
        DISK_GB=40
        GUEST_OS="linux"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --cores) CORES="$2"; shift 2 ;;
            --ram) RAM_GB="$2"; shift 2 ;;
            --disk) DISK_GB="$2"; shift 2 ;;
            --os) GUEST_OS="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        
        if [[ ! -f "${ISO_PATH}" ]]; then
          echo '{"type":"progress","phase":"error","percent":0,"status":"ISO file not found: '"${ISO_PATH}"'"}' >&2
          exit 1
        fi

        echo '{"type":"progress","phase":"init","percent":20,"status":"Configuring VM for custom ISO..."}'
        mkdir -p "${VM_DIR}/${VM_NAME}" 2>/dev/null
        CONF_FILE="${VM_DIR}/${VM_NAME}.conf"
        cat > "${CONF_FILE}" <<EOF
guest_os="${GUEST_OS}"
os="${GUEST_OS}"
iso="${ISO_PATH}"
disk_img="${VM_NAME}/disk.qcow2"
cpu_cores="${CORES}"
ram="${RAM_GB}G"
disk_size="${DISK_GB}G"
EOF
        echo '{"type":"progress","phase":"done","percent":100,"status":"Created custom ISO VM configuration '"${CONF_FILE}"'"}'
        ;;

      start)
        [[ $# -ge 1 ]] || { echo "Usage: mujo vm start <name> [--viewer <true|false>] [--display <gtk|spice|sdl>]" >&2; exit 1; }
        VM_NAME="$1"; shift
        LAUNCH_VIEWER="true"
        DISPLAY_BACKEND=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --viewer) LAUNCH_VIEWER="$2"; shift 2 ;;
            --no-viewer) LAUNCH_VIEWER="false"; shift ;;
            --display) DISPLAY_BACKEND="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        
        if [[ "${VM_NAME}" == "mujo-sandbox" || "${VM_NAME}" == "sandbox" ]]; then
          QPID="$(pgrep -f "qemu.*mujo-sandbox|nixos-test-driver|sandbox/mcp\.py" | head -1 || echo "")"
          if [[ -z "${QPID}" || ! -d "/proc/${QPID}" ]]; then
            REPO_PATH="${HOME}/nixconf"
            [[ -d "${REPO_PATH}" ]] || REPO_PATH="$(git rev-parse --show-toplevel 2>/dev/null || echo "${HOME}/nixconf")"
            (
              cd "${REPO_PATH}"
              export MUJO_SANDBOX_STANDALONE=1
              # setsid: the driver must outlive the process group of whatever
              # shell quickshell ran this in, or a stray SIGTERM takes the VM.
              nohup setsid nix run .#sandbox >"${VM_DIR}/mujo-sandbox.log" 2>&1 &
            )
            echo "Started Testing Sandbox (mujo-sandbox)"
          else
            echo "VM mujo-sandbox is already running (PID ${QPID})"
          fi
          exit 0
        fi

        CONF_FILE="${VM_DIR}/${VM_NAME}.conf"
        [[ -f "${CONF_FILE}" ]] || { echo "VM config not found: ${CONF_FILE}" >&2; exit 1; }
        
        # Check if already running
        QPID="$(pgrep -f "qemu.*${VM_NAME}" | head -1 || echo "")"
        if [[ -z "${QPID}" && -f "${VM_DIR}/${VM_NAME}.pid" ]]; then
          saved_pid="$(cat "${VM_DIR}/${VM_NAME}.pid" 2>/dev/null || echo "")"
          [[ -n "${saved_pid}" && -d "/proc/${saved_pid}" ]] && QPID="${saved_pid}"
        fi
        if [[ -z "${QPID}" && -f "${VM_DIR}/${VM_NAME}/${VM_NAME}.pid" ]]; then
          saved_pid="$(cat "${VM_DIR}/${VM_NAME}/${VM_NAME}.pid" 2>/dev/null || echo "")"
          [[ -n "${saved_pid}" && -d "/proc/${saved_pid}" ]] && QPID="${saved_pid}"
        fi

        if [[ -n "${QPID}" ]]; then
          echo "VM ${VM_NAME} is already running (PID ${QPID})"
          if [[ "${LAUNCH_VIEWER}" == "true" ]]; then
            "$0" vm display "${VM_NAME}"
          fi
          exit 0
        fi

        # Determine display backend (default to gtk for native desktop rendering)
        if [[ -z "${DISPLAY_BACKEND}" ]]; then
          CONF_DISPLAY="$(grep -E '^[[:space:]]*display=' "${CONF_FILE}" | head -1 | cut -d= -f2- | tr -d '"'\'' ' || echo "")"
          DISPLAY_BACKEND="${CONF_DISPLAY:-gtk}"
        fi

        # Start Quickemu / QEMU launcher in background
        (
          cd "${VM_DIR}"
          if command -v quickemu >/dev/null 2>&1; then
            nohup quickemu --vm "${VM_NAME}.conf" --display "${DISPLAY_BACKEND}" --viewer none >"${VM_DIR}/${VM_NAME}.log" 2>&1 &
          else
            SH_SCRIPT=""
            [[ -f "${VM_DIR}/${VM_NAME}/${VM_NAME}.sh" ]] && SH_SCRIPT="${VM_DIR}/${VM_NAME}/${VM_NAME}.sh"
            [[ -z "${SH_SCRIPT}" && -f "${VM_DIR}/${VM_NAME}.sh" ]] && SH_SCRIPT="${VM_DIR}/${VM_NAME}.sh"
            if [[ -n "${SH_SCRIPT}" ]]; then
              nohup bash "${SH_SCRIPT}" >"${VM_DIR}/${VM_NAME}.log" 2>&1 &
            else
              nohup qemu-system-x86_64 -enable-kvm -cpu host -m 8G -smp 8 -vga virtio -display gtk,gl=on >"${VM_DIR}/${VM_NAME}.log" 2>&1 &
            fi
          fi
        )
        
        if [[ "${DISPLAY_BACKEND}" == "spice" && "${LAUNCH_VIEWER}" == "true" ]]; then
          (
            for i in $(seq 1 40); do
              sleep 0.2
              if [[ -S "${VM_DIR}/${VM_NAME}.sock" || -S "${VM_DIR}/${VM_NAME}/${VM_NAME}.sock" || -f "${VM_DIR}/${VM_NAME}.spice" || -f "${VM_DIR}/${VM_NAME}/${VM_NAME}.spice" || -f "${VM_DIR}/${VM_NAME}.ports" || -f "${VM_DIR}/${VM_NAME}/${VM_NAME}.ports" ]]; then
                break
              fi
            done
            sleep 0.3
            "$0" vm display "${VM_NAME}"
          ) &
        fi
        echo "Started VM ${VM_NAME} (display: ${DISPLAY_BACKEND})"
        ;;

      stop)
        [[ $# -ge 1 ]] || { echo "Usage: mujo vm stop <name> [--force]" >&2; exit 1; }
        VM_NAME="$1"; shift
        FORCE="false"
        [[ "$1" == "--force" ]] && FORCE="true"
        
        if [[ "${VM_NAME}" == "mujo-sandbox" || "${VM_NAME}" == "sandbox" ]]; then
          if [[ "${FORCE}" == "true" ]]; then
            pkill -9 -f "qemu.*mujo-sandbox|nixos-test-driver|sandbox/mcp\.py" 2>/dev/null || true
          else
            pkill -15 -f "qemu.*mujo-sandbox|nixos-test-driver|sandbox/mcp\.py" 2>/dev/null || true
          fi
          echo "Stopped VM mujo-sandbox"
          exit 0
        fi

        QPID="$(pgrep -f "qemu.*${VM_NAME}" | head -1 || echo "")"
        if [[ -z "${QPID}" && -f "${VM_DIR}/${VM_NAME}.pid" ]]; then
          QPID="$(cat "${VM_DIR}/${VM_NAME}.pid" 2>/dev/null || echo "")"
        fi
        if [[ -z "${QPID}" && -f "${VM_DIR}/${VM_NAME}/${VM_NAME}.pid" ]]; then
          QPID="$(cat "${VM_DIR}/${VM_NAME}/${VM_NAME}.pid" 2>/dev/null || echo "")"
        fi

        (cd "${VM_DIR}" && quickemu --vm "${VM_NAME}.conf" --kill >/dev/null 2>&1) || true

        if [[ -n "${QPID}" && -d "/proc/${QPID}" ]]; then
          if [[ "${FORCE}" == "true" ]]; then
            kill -9 "${QPID}" 2>/dev/null || true
          else
            kill -15 "${QPID}" 2>/dev/null || true
          fi
        fi

        echo "Stopped VM ${VM_NAME}"
        rm -f "${VM_DIR}/${VM_NAME}.sock" "${VM_DIR}/${VM_NAME}.spice" "${VM_DIR}/${VM_NAME}.pid" "${VM_DIR}/${VM_NAME}.ports" \
              "${VM_DIR}/${VM_NAME}/${VM_NAME}.sock" "${VM_DIR}/${VM_NAME}/${VM_NAME}.spice" "${VM_DIR}/${VM_NAME}/${VM_NAME}.pid" "${VM_DIR}/${VM_NAME}/${VM_NAME}.ports" 2>/dev/null || true
        ;;

      display)
        [[ $# -ge 1 ]] || { echo "Usage: mujo vm display <name>" >&2; exit 1; }
        VM_NAME="$1"
        
        if [[ "${VM_NAME}" == "mujo-sandbox" || "${VM_NAME}" == "sandbox" ]]; then
          if timeout 1 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5920 && exec 3>&-' 2>/dev/null; then
            if command -v remote-viewer >/dev/null 2>&1; then
              remote-viewer "spice://127.0.0.1:5920" --title="Mujō Sandbox (AI Workspace)" 9>&- >/dev/null 2>&1 &
              echo "Connected remote-viewer to Sandbox display (spice://127.0.0.1:5920)"
            elif command -v spicy >/dev/null 2>&1; then
              spicy -h 127.0.0.1 -p 5920 --title="Mujō Sandbox (AI Workspace)" 9>&- >/dev/null 2>&1 &
              echo "Connected viewer to Sandbox display (spice://127.0.0.1:5920)"
            fi
          else
            echo "Sandbox display server (port 5920) is still initializing, please wait a moment..."
          fi
          exit 0
        fi

        SOCK_PATH=""
        SPICE_PORT=""

        # 1. Direct socket file
        if [[ -S "${VM_DIR}/${VM_NAME}.sock" ]]; then
          SOCK_PATH="${VM_DIR}/${VM_NAME}.sock"
        elif [[ -S "${VM_DIR}/${VM_NAME}/${VM_NAME}.sock" ]]; then
          SOCK_PATH="${VM_DIR}/${VM_NAME}/${VM_NAME}.sock"
        fi

        # 2. .spice pointer file
        if [[ -z "${SOCK_PATH}" && -f "${VM_DIR}/${VM_NAME}.spice" ]]; then
          s_content="$(cat "${VM_DIR}/${VM_NAME}.spice" 2>/dev/null | tr -d ' \r\n')"
          if [[ "${s_content}" == *.sock ]]; then
            [[ "${s_content}" = /* ]] && SOCK_PATH="${s_content}" || SOCK_PATH="${VM_DIR}/${s_content}"
          elif [[ "${s_content}" =~ ^[0-9]+$ ]]; then
            SPICE_PORT="${s_content}"
          fi
        elif [[ -z "${SOCK_PATH}" && -f "${VM_DIR}/${VM_NAME}/${VM_NAME}.spice" ]]; then
          s_content="$(cat "${VM_DIR}/${VM_NAME}/${VM_NAME}.spice" 2>/dev/null | tr -d ' \r\n')"
          if [[ "${s_content}" == *.sock ]]; then
            [[ "${s_content}" = /* ]] && SOCK_PATH="${s_content}" || SOCK_PATH="${VM_DIR}/${s_content}"
          elif [[ "${s_content}" =~ ^[0-9]+$ ]]; then
            SPICE_PORT="${s_content}"
          fi
        fi

        # 3. .ports file
        if [[ -z "${SOCK_PATH}" && -z "${SPICE_PORT}" ]]; then
          ports_file=""
          [[ -f "${VM_DIR}/${VM_NAME}.ports" ]] && ports_file="${VM_DIR}/${VM_NAME}.ports"
          [[ -z "${ports_file}" && -f "${VM_DIR}/${VM_NAME}/${VM_NAME}.ports" ]] && ports_file="${VM_DIR}/${VM_NAME}/${VM_NAME}.ports"
          if [[ -n "${ports_file}" ]]; then
            u_sock="$(grep -E '^unix,' "${ports_file}" | head -1 | cut -d, -f2 | tr -d ' \r\n' || echo "")"
            if [[ -n "${u_sock}" ]]; then
              [[ "${u_sock}" = /* ]] && SOCK_PATH="${u_sock}" || SOCK_PATH="${VM_DIR}/${u_sock}"
            else
              s_port="$(grep -E '^spice,' "${ports_file}" | head -1 | cut -d, -f2 | tr -d ' \r\n' || echo "")"
              [[ -n "${s_port}" ]] && SPICE_PORT="${s_port}"
            fi
          fi
        fi

        if [[ -n "${SOCK_PATH}" && -S "${SOCK_PATH}" ]]; then
          if command -v remote-viewer >/dev/null 2>&1; then
            remote-viewer "spice+unix://${SOCK_PATH}" --title="${VM_NAME}" 9>&- >/dev/null 2>&1 &
            echo "Connected remote-viewer to spice+unix://${SOCK_PATH}"
          elif command -v spicy >/dev/null 2>&1; then
            spicy --uri="spice+unix://${SOCK_PATH}" --title="${VM_NAME}" 9>&- >/dev/null 2>&1 &
            echo "Connected spicy to spice+unix://${SOCK_PATH}"
          else
            echo "Neither remote-viewer nor spicy is installed" >&2
            exit 1
          fi
        elif [[ -n "${SPICE_PORT}" ]]; then
          if command -v remote-viewer >/dev/null 2>&1; then
            remote-viewer "spice://127.0.0.1:${SPICE_PORT}" --title="${VM_NAME}" 9>&- >/dev/null 2>&1 &
            echo "Connected remote-viewer to spice://127.0.0.1:${SPICE_PORT}"
          elif command -v spicy >/dev/null 2>&1; then
            spicy -h 127.0.0.1 -p "${SPICE_PORT}" --title="${VM_NAME}" 9>&- >/dev/null 2>&1 &
            echo "Connected spicy to 127.0.0.1:${SPICE_PORT}"
          else
            echo "Neither remote-viewer nor spicy is installed" >&2
            exit 1
          fi
        else
          echo "VM ${VM_NAME} is active (native window display)"
        fi
        ;;

      delete)
        [[ $# -ge 1 ]] || { echo "Usage: mujo vm delete <name>" >&2; exit 1; }
        VM_NAME="$1"
        if [[ "${VM_NAME}" == "mujo-sandbox" || "${VM_NAME}" == "sandbox" ]]; then
          pkill -f "qemu.*mujo-sandbox|nixos-test-driver.*mujo-sandbox" 2>/dev/null || true
          rm -f "${VM_DIR}/mujo-sandbox.log" 2>/dev/null || true
          echo "Reset testing sandbox VM (ephemeral root wiped)"
          exit 0
        fi
        "$0" vm stop "${VM_NAME}" --force 2>/dev/null || true
        rm -rf "${VM_DIR}/${VM_NAME}.conf" "${VM_DIR}/${VM_NAME}".* "${VM_DIR}/${VM_NAME}-"* "${VM_DIR}/${VM_NAME}" 2>/dev/null || true
        echo "Deleted VM ${VM_NAME}"
        ;;

      *) vm_usage ;;
    esac
}
