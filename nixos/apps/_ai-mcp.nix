# The MCP servers every agent on this host should see, in a tool-neutral shape:
# `command` is the executable and `args` are its arguments, which is how both
# Claude's .mcp.json and Antigravity's mcp_config.json spell it. opencode wants
# the two joined into one list, so its module concatenates them on the way out.
#
# `_`-prefixed, so flake.nix's importTree skips it (AGENTS.md, MODULE DISCOVERY)
# — this is a plain function returning an attrset, not a flake-parts module.
{user}: {
  # mcp-nixos is installed system-wide in nixos/core/nix.nix.
  nixos = {
    command = "mcp-nixos";
    args = [];
  };

  # Testing sandbox for quickshell/desktop work (nixos/sandbox/sandbox.nix).
  # Speaks MCP over stdio to a disposable graphical VM with virgl acceleration.
  sandbox = {
    command = "nix";
    args = ["run" "/home/${user}/nixconf#sandbox"];
  };
}
