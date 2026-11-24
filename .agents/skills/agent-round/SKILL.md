---
name: agent-round
description: Run a round of delegated work on quick-key with subagents: read-only reviewers that report verified findings, then worktree implementers whose commits are reviewed and merged one at a time. Use when the owner asks for reviews, or to parallelise fixes they have decided.
---

# Agent round

quick-key is trimming: major features are closed (README's Scope). A round finds bugs, cuts and simplifications, never features, and the owner decides each item before anything changes.

Read [decisions.md](../../decisions.md) first and put it in every brief: what is settled or declined there is out of scope, and a finding that repeats one is dropped unless it brings new evidence (a bug, a measured cost). A round starts from the owner's bug log from daily use, not from a fresh look at everything; with no bugs to start from, ask the owner whether a round is wanted at all. Add what the owner settles to decisions.md in the same change.

## Reviewers

Read-only. A reviewer's brief says:
- the question, and that major features are closed: no new features or settings;
- every finding verified: a bug with a repro (a failing case, a preview shot, or an exact code path with inputs and wrong output), a cut or simplification with its code (file:line) and lines saved; anything else marked unverified;
- read-only: no edits, no commits, no `qs ipc` against the live shell, no change to volume or brightness;
- what other agents are doing at the same time, so it does not repeat or collide;
- decisions.md, and that repeating a settled or declined item without new evidence is not a finding;
- "where not to": the reviewer says honestly where a change would add indirection;
- a word budget, ranked findings, one or two lines each.

Save each report under the scratchpad, verify its strongest claims yourself before relaying them, and bring the owner one consolidated list with a recommendation per item.

## Implementers

One worktree agent per area whose files do not overlap; areas that overlap run one after another. A brief says:
- first `git reset --hard <working branch>` and confirm the expected head commit (a worktree starts from `main`, which may be behind);
- the decided items only, with the findings file; smallest change, net lines down; past about 40 lines or a new concept, stop and report;
- one purpose per commit, subject under 72 characters, the why in the body;
- a test for each behaviour change that FAILS without the fix: run it both ways and say so;
- `preview-check` for anything visible, with a pixel comparison against the base where the look must hold;
- never edit AGENTS.md: report each line a change makes wrong, with replacement wording;
- `nix flake check` passes and `git status --short` is empty at the end; nothing pushed.

## Merging

For each implementer, in order:
1. `git cherry-pick <base>..<its head>`; resolve conflicts against what merged before.
2. Read the diff for over-building (`git diff --stat`, then the code): a fix much larger than its finding goes back.
3. Prove at least the riskiest fix's test fails without it: revert the fix's lines, run that suite, restore.
4. `nix flake check -L`, colour codes stripped before grepping (`sed 's/\x1b\[[0-9;]*m//g'`); a failure from two agents' changes meeting is fixed in its own commit.
5. Build the owner's downstream configuration against the branch, if they keep one, before saying it is done.
6. Tell the owner what changed, what was verified and how, and what is left; AGENTS.md lines go to them to apply.
7. Remove its worktree and branch (`git worktree remove`, `git branch -D`) once its commits are in; a branch the owner declines is kept first as `git update-ref refs/archive/<name> <branch>` (not a tag: the owner's git config prunes local tags on every fetch).
