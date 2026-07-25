# git-cloudsync

[![ci](https://github.com/bgrgndzz/git-cloudsync/actions/workflows/ci.yml/badge.svg)](https://github.com/bgrgndzz/git-cloudsync/actions/workflows/ci.yml)

Keep a local git worktree caught up with work pushed by cloud coding agents.

Cloudsync watches the checked-out branch's upstream and makes the local worktree match whenever new commits arrive. It is strictly one-way: **remote → local**.

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

That is the whole loop. Leave it running while you test. New commits, rebases, and force-pushes update the checked-out branch and the files your local dev server sees.

Other commands:

```sh
cloudsync sync                 # fetch and sync once
cloudsync watch --interval 10  # poll every 10 seconds (default: 5)
cloudsync status               # show current/ahead/behind/diverged
cloudsync version
```

The branch must have a remote upstream. If needed:

```sh
git branch --set-upstream-to=origin/my-feature
```

## Safety

Cloudsync has no push path. The remote branch is the authority.

It updates only when all of these are true:

- the current worktree is on a branch;
- that branch tracks a remote branch;
- the worktree has no modified, staged, or untracked files.

If the remote was rebased, force-pushed, or moved backward, Cloudsync saves the replaced local commit at `refs/cloudsync/recovery/<branch>` and then makes the clean worktree match the remote. The recovery ref has a reflog, so successive rewrites remain recoverable.

If the worktree is dirty, Cloudsync pauses and changes nothing. After you clean it, `watch` resumes automatically.

## Why not `git pull` in a loop?

`git pull` can merge or rebase depending on local config. Cloudsync has one rule: when the worktree is clean, make the current branch match its configured remote upstream. Otherwise, stop.

## Using with coding agents

Tell cloud agents to commit and push to the branch checked out in your local worktree. Run `cloudsync watch` locally. No agent needs access to your machine, and Cloudsync never sends local code back.

## License

MIT
