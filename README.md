# unity-via-distrobox-flake

Declarative Unity Hub and Unity Editor development environment for NixOS, provided as a self-contained [Nix flake](https://nixos.wiki/wiki/Flakes).

Unity Hub and the Unity Editor run inside a [Distrobox](https://github.com/89luca89/distrobox) container (Ubuntu 22.04 LTS), where Unity is officially supported, while the host retains full control of the container spec and the launcher.

---

## 1. Why Distrobox? (Architecture)

The native NixOS `unityhub` package relies on FHS emulation (bubblewrap). While Unity Hub itself runs, the Unity Editor spawns build processes and external scripts (like Burst compiler JIT compilation) that run outside the initial sandbox. These sub-processes often fail to link against host system libraries (e.g., GLIBC, OpenGL, Vulkan), leading to crashes during script compilation.

By using **Distrobox** with an Ubuntu 22.04 LTS image, we provide a complete, officially supported Ubuntu FHS environment. Both Unity Hub and the Unity Editor run inside this container, sharing the host's networking, X11/Wayland display, and GPU acceleration.

## 2. Usage

Add this flake as an input of your NixOS configuration:

```nix
# flake.nix
inputs = {
  unity-via-distrobox.url = "github:t3u-tsu/unity-via-distrobox-flake";
};
```

Import the home-manager module and enable it for your user:

```nix
# NixOS module (home-manager users.<name>.imports or sharedModules)
{ inputs, ... }:
{
  imports = [ inputs.unity-via-distrobox.homeManagerModules.unity ];

  my.unity.enable = true;
}
```

After `nixos-rebuild switch` (or `home-manager switch`), launching `unityhub` (from your application launcher or a terminal) provisions the container on first run and starts Unity Hub.

## 3. Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `my.unity.enable` | bool | `false` | Enable the Unity development tools (Distrobox-based). |

## 4. What the module installs

- **`distrobox.ini`** → `~/.config/distrobox/distrobox.ini`. Declarative container spec used by `distrobox assemble create --file`. See [files/distrobox.ini](files/distrobox.ini).
- **`unityhub` launcher** → `~/.local/bin/unityhub` (via `writeShellApplication`, shellcheck-verified at build time). See [files/launcher.sh](files/launcher.sh).
- **Desktop entry** → `~/.local/share/applications/unityhub.desktop`, wired through `systemd-run --user` so browsers can deep-link `unityhub://` back into the container even from their own sandboxed namespaces.

## 5. Key challenges & workarounds

### Host-to-Container GIO & SSL variable conflicts
*   **Problem:** Host environment variables like `GIO_EXTRA_MODULES` (pointing to dconf/gvfs in the Nix store) and NixOS-specific `SSL_CERT_FILE` variables are inherited by the container. The container's glibc (2.35) crashes or fails to load host modules compiled against newer glibc versions, and OpenSSL fails to locate valid certificates.
*   **Solution:** The launcher unsets `GIO_EXTRA_MODULES`, `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, `CURL_CA_BUNDLE`, `SSL_CERT_DIR`, and `NIX_SSL_CERT_DIR` before entering the container, forcing Unity to use native Ubuntu libraries and certificates.

### Browser sandbox escape (deep-linking for sign-in)
*   **Problem:** Web browsers (e.g., Zen Browser) running in their own sandboxed user namespaces cannot spawn container processes or escalate privileges inside the container via `su` when trying to handle the `unityhub://` protocol.
*   **Solution:** The desktop entry launches the hub via `systemd-run --user`. This delegates the execution back to the user's host systemd session, effectively escaping the browser's sandbox.

### SSL/TLS handshake timeout (failed to call Unity ID to get auth code)
*   **Problem:** Modern .NET Sockets (CoreCLR used by Unity Editor 6) dynamically loads `libssl.so.1.1` via P/Invoke for TLS handshakes. Ubuntu 22.04 and NixOS host only provide `libssl.so.3`. This discrepancy caused the Editor's HTTPS connections to services like `api.unity.com` and `services.unity.com` to hang/timeout right after establishing the TCP connection (`ESTABLISHED`), breaking UPM and Asset Store OAuth.
*   **Solution:** The container's `pre_init_hooks` download and install the official `libssl1.1` deb package directly into the container using `curl` and `dpkg`.

### Distrobox INI parser constraints
*   **Problem:** distrobox-assemble's simplified INI parser misinterprets square brackets `[` `]` inside keys (like `[1/5]` or `[arch=amd64]`) as new section boundaries, causing the rest of the script to be discarded.
*   **Solution:** Raw brackets are completely avoided in [files/distrobox.ini](files/distrobox.ini). For the APT repository line where brackets are required, they are written dynamically using `printf` with hex escapes (`\x5b` and `\x5d`). Repeated keys (e.g. the six `pre_init_hooks` lines) are joined by distrobox's cumulative parser and executed in order with `&&`.

### Persistent `xdg-open` redirection
*   **Problem:** Distrobox periodically regenerates `/usr/bin/xdg-open` inside the container, breaking browser redirects for authentication.
*   **Solution:** The launcher features a self-healing block that checks and replaces `/usr/bin/xdg-open` with a symlink to `/usr/bin/distrobox-host-exec` every time the launcher is run.

## 6. Maintenance & troubleshooting

### Rebuilding the container
If you modify `distrobox.ini` (e.g., adding packages or updating hooks):
1.  Apply the changes (`nixos-rebuild switch` or `home-manager switch`).
2.  Remove the existing container: `distrobox rm -f unity-via-distrobox`
3.  Launch Unity Hub (`unityhub`) — the launcher recreates the container automatically.

### Verifying symlinks
Inside the container, ensure `xdg-open` correctly redirects to the host:

```bash
distrobox enter unity-via-distrobox -- ls -la /usr/bin/xdg-open
# Should return: /usr/bin/xdg-open -> /usr/bin/distrobox-host-exec
```

### Setup failures
If container provisioning fails, the launcher prints the tail of the container log and keeps the full assemble log at `/tmp/unity-assemble-*.log` for debugging.

## 7. Development

- `nix flake check` — evaluates the module in both configurations (Distrobox / native) and runs shellcheck on the launcher.
- `nix build .#unityhub` — builds the standalone launcher package.
- `nix develop` — shell with `shellcheck` and `nixfmt`.
- GitHub Actions runs `nix flake check` + `nix build .#unityhub` on every push/PR.

## 8. License

0BSD — see [LICENSE](LICENSE).
