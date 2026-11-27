# Machines

## Operations

[README.md](README.md) is the single source of truth for machine setup. When asked to `set up <machine>` (or sync an existing one), drive its **Setup** checklist from `ubuntu`:

- Run automated steps over SSH (use a PTY for `sudo` — Ubuntu 26.04 `sudo-rs` prompts `password:`).
- For **Manual** steps, give one short exact instruction, wait for confirmation, verify, and continue.
- Never ask for passwords in chat — use `request_secret` (`delivery: "file"`), and store machine passwords in 1Password `mapringg.machines.ops`. For `secret setup` on spokes, you may request `1Password Service Account (Dev)` via `request_secret` and pipe it to `ssh <host> '~/.local/bin/secret setup' < "$file"`.
- `ubuntu` is the sole hub (`cliproxyapi`, `executor`, `wg0`) — never run those services on spokes.
- This repo is public — never commit secrets, MAC addresses, or tailnet IDs.

## Sources

- Use [PR writing](https://github.com/mapringg/standard/blob/v1.11.0/.claude/skills/pr/SKILL.md) when writing a pull request.
- Follow [Capture](https://github.com/mapringg/standard/blob/v1.11.0/.claude/skills/capture/SKILL.md) when preparing pull request evidence.
