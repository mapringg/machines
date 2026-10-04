# machines

Setup scripts for three machines. README explains the design and holds the manual steps.

## Commits

- Imperative subject, capitalized, no trailing period, no `file:` prefix.
- Aim for 50 characters; never over 72, where GitHub truncates.
- Subject only, by default. Add a body, wrapped at 72, only when the reason is neither
  obvious nor in a code comment.

## Comments

- Comment only what the code can't say: a trap, a non-obvious reason, where a number
  comes from. One or two lines, wrapped at 80.
- Keep the comments that stop a "simplification" from breaking things.
- Don't narrate what the next line does, or repeat what the commit body explains.
- Manual steps go in README, not script headers.
- Sections are `# --- name ---`, padded with dashes to 80 columns.

## Scripts

- Safe to re-run: check state before changing it.
- Defaults unless I'd notice the difference within a day.

## README

- Wrap at 88.
- Say each fact once; link to the section that owns it instead of restating it.
