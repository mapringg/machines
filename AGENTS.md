# AGENTS.md

## Rules

- Run machine provisioning from `ubuntu` and automate remote steps over SSH.
- Use a PTY for `sudo` on Ubuntu and confirm each manual step before continuing.
- Keep CLIProxyAPI, Executor and WireGuard on `ubuntu`.
- Keep credentials, MAC addresses and tailnet IDs out of Git.

## Sources

- Use [PR writing](https://github.com/mapringg/standard/blob/v1.13.0/.claude/skills/pr/SKILL.md) when writing a pull request.
- Follow [Capture](https://github.com/mapringg/standard/blob/v1.13.0/.claude/skills/capture/SKILL.md) when preparing pull request evidence.
- Follow [Machine setup](.claude/skills/setup-machine/SKILL.md) when setting up or syncing a host.
