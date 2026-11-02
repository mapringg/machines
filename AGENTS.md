# machines

For a machine's setup, read its section in [README.md](README.md), then its linked
script. Scripts hold executable setup; the README holds manual steps and design
decisions.

- Scripts: idempotent. Comments are limited to shebangs and PowerShell `#Requires`
  directives.
- README: wrap prose at 88 columns and keep each fact in one place.
- Commits: subject only, imperative and capitalized, aiming for 50 characters with a
  72-character maximum. Omit a trailing period and `file:` prefix.

## Checks

Checks are static: provisioning scripts run only on the intended machine during an
authorized setup.

- Every change: `git diff --check`.
- Shell changes: `bash -n apple.sh ubuntu.sh`, and review each changed command for
  idempotence.
- PowerShell changes: parse `windows.ps1` with PowerShell's parser, and review each
  changed command for idempotence.
- README changes: match every affected step to its script and resolve local links.

A change is done when every applicable check passes. Report the checks run and any
verification that still needs the target machine.
