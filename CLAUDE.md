# machines

Setup scripts for my machines. README explains the design and holds the manual steps.

## Commits

- Imperative subject, capitalized, no trailing period, no `file:` prefix.
- Aim for 50 characters; never over 72, where GitHub truncates.
- Subject only, by default. Add a body, wrapped at 72, when the reason isn't obvious.

## Comments

- None, apart from the shebang and `#Requires`.
- A reason goes in a name, a check that fails loudly, or the commit body.
- Before changing a line that looks odd, read why with `git log -L`.

## Scripts

- Safe to re-run: check state before changing it.
- Defaults unless I'd notice the difference within a day.

## README

- Wrap at 88.
- Say each fact once; link to the section that owns it instead of restating it.
