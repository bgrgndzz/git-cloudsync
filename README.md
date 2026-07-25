# git-cloudsync

[![ci](https://github.com/bgrgndzz/git-cloudsync/actions/workflows/ci.yml/badge.svg)](https://github.com/bgrgndzz/git-cloudsync/actions/workflows/ci.yml)

Keep a local git worktree caught up with work pushed by cloud coding agents.

Cloudsync watches the checked-out branch's upstream and fast-forwards the local worktree whenever new commits arrive. It is strictly one-way: **remote → local**.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/bgrgndzz/git-cloudsync/main/install.sh | bash
```

Or clone and run `make install`. Both install `cloudsync` and link `git-cloudsync`, so `git cloudsync watch` works too.

Requirements: bash and git.

## Use

Open the local worktree for the same branch your cloud agents push to:

```sh
cd ~/worktrees/my-feature
cloudsync watch
```

That is the whole loop. Leave it running while you test. Each new remote commit fast-forwards the checked-out branch and updates the files your local dev server sees.

Other commands:

```sh
cloudsync sync                 # fetch and fast-forward once
cloudsync watch --interval 10  # poll every 10 seconds (default: 5)
cloudsync status               # show current/ahead/behind/diverged
cloudsync version
```

The branch must have a remote upstream. If needed:

```sh
git branch --set-upstream-to=origin/my-feature
```

## Safety

Cloudsync has no push path and never runs reset, rebase, stash, force checkout, or a merge commit.

It updates only when all of these are true:

- the current worktree is on a branch;
- that branch tracks a remote branch;
- the local commit is an ancestor of the remote commit;
- the worktree has no modified, staged, or untracked files.

If the branch is dirty, ahead, or diverged, Cloudsync pauses and keeps the worktree untouched. After you resolve the local state, `watch` resumes automatically.

Remote force-pushes are fetched, but they are never forced onto the local branch. If history diverges, choose how to reconcile it yourself.

## Why not `git pull` in a loop?

`git pull` can merge or rebase depending on local config. Cloudsync accepts one update only: a clean fast-forward from the configured remote upstream. Every other state stops.

## Using with coding agents

Tell cloud agents to commit and push to the branch checked out in your local worktree. Run `cloudsync watch` locally. No agent needs access to your machine, and Cloudsync never sends local code back.

## License

MIT
