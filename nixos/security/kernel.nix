{...}: {
  flake.nixosModules.security-kernel = {
    config,
    lib,
    ...
  }: let
    cfg = config.security.mujo;
  in {
    config = lib.mkIf (cfg.enable && cfg.kernel.enable) {
      boot = {
        # Kernel memory initialization and allocator hardening.
        #
        # page_poison=1 used to head this list. It defeated the two lines below
        # it: when page poisoning is requested, mem_debugging_and_hardening_init()
        # (mm/mm_init.c) logs "CONFIG_PAGE_POISONING is on, will take precedence
        # over init_on_alloc and init_on_free" and switches both off. What ran
        # instead was the debugging feature: every freed page memset to 0xaa and
        # every allocated page scanned back for that pattern -- an extra full
        # read of each page on the allocation path (amdgpu's GTT/TTM pages
        # included) on top of the write, while init_on_alloc never ran at all.
        # init_on_free alone already guarantees freed memory holds no stale data.
        kernelParams = [
          "slab_nomerge"
          "init_on_alloc=1"
          "init_on_free=1"
        ];

        kernel.sysctl = {
          # Hide kernel pointers in /proc and elsewhere from unprivileged users
          "kernel.kptr_restrict" = 2;

          # Restrict kernel ring buffer (dmesg) to processes with CAP_SYSLOG / CAP_SYS_ADMIN
          "kernel.dmesg_restrict" = 1;

          # Disable unprivileged eBPF to prevent speculative execution / side-channel attacks
          "kernel.unprivileged_bpf_disabled" = 1;

          # Enable BPF JIT constant blinding to mitigate JIT spraying
          "net.core.bpf_jit_harden" = 2;

          # Restrict ptrace attachment: processes can only ptrace their own descendants (PR_SET_PTRACER)
          "kernel.yama.ptrace_scope" = 1;

          # Restrict opening of FIFOs and regular files in world-writable sticky directories
          "fs.protected_fifos" = 2;
          "fs.protected_regular" = 2;
          "fs.protected_symlinks" = 1;
          "fs.protected_hardlinks" = 1;

          # Restrict Magic SysRq key to safe operations (sync)
          "kernel.sysrq" = 16;

          # Restrict auto-loading of TTY line disciplines to prevent privilege escalation via unused drivers
          "dev.tty.ldisc_autoload" = 0;

          # Disable kexec to prevent live replacement of the running kernel
          "kernel.kexec_load_disabled" = 1;
        };
      };
    };
  };
}
