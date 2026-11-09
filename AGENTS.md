# machines

Public: never add secrets, hostnames beyond the three machines, or work details.
README.md holds each machine's manual steps; its linked script holds the rest.

- Keep scripts minimal, idempotent and comment-free. Never run them here.
- Wrap README prose at 88 columns.
- Commits: one short imperative subject line, no body or trailers.
- Check: `git diff --check`, `bash -n apple.sh ubuntu.sh`, and keep README steps in
  sync with the scripts.
