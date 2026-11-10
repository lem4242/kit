# kit

A toolkit to work with models. This repository is its installer; the tools themselves are private,
and you need an invitation to them.

## Install

You need `git`, `curl`, and a GitHub login that has been invited. Sign in with the GitHub CLI
(`gh auth login`), then:

```sh
git clone https://github.com/lem4242/kit kit && sh kit/install.sh
```

Run it again any time: finished steps are left alone. It asks no questions. Without the GitHub
CLI, set `GH_TOKEN` to a token that can read the tools.

It also installs a `kit` command: `kit status` shows what is installed, `kit link` and `kit unlink`
choose which tools Claude Code and Codex are told about, and `kit update` brings everything to the
newest release. `kit help` says more.
