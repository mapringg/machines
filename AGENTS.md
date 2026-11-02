# machines

Setup changes: read [README.md](README.md) for the target machine's procedure and
design decisions, then its linked script for installed tools and configuration.
Keep executable setup in the scripts and manual steps and rationale in the README.

- Scripts must be safe to re-run. Keep their contents executable, with only shebangs
  and PowerShell `#Requires` directives as comments.
- README: wrap prose at 88 columns and keep each fact in one place.
- Commits: use a subject only, imperative and capitalized, aiming for 50 characters
  with a 72-character maximum. Omit a trailing period and `file:` prefix.

Before finishing a change, check every affected README step against its script and
resolve local links. Run `git diff --check`; for shell changes, run
`bash -n apple.sh ubuntu.sh`. For PowerShell changes, parse `windows.ps1` with
PowerShell's parser and resolve any syntax errors. Review rerun behavior for each
changed setup command. Use static checks for review; provisioning scripts belong on
the intended machine during an authorized setup. Report checks performed and any
machine-specific verification still outstanding.
