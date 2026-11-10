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

If Claude Code is installed, the installer also adds this repository as a plugin marketplace and
installs its plugins.
