#!/bin/sh
# kit: install the toolkit on this machine.
#
#   sh install.sh [--no-background] [--no-plugin]
#
# Needs git and curl. Installs uv if missing, then each tool in manifest.toml at its tag with
# `uv tool install`, sets up local state on first run, and adds kit's Claude Code marketplace and
# plugins when `claude` is on PATH. Nothing asks a question: it runs the same way for a person
# and for kit's rig. Run it again any time; a finished step is left alone.
#
# GitHub: the tools are private. Set GH_TOKEN (a token that can read them), or sign in with the
# GitHub CLI first (`gh auth login`) and this script uses that. The token is given to git through
# the environment for this run only; nothing here writes it to disk.
set -eu

UV_VERSION=0.12.19
no_background=; no_plugin=
for arg in "$@"; do
    case "$arg" in
        --no-background) no_background=1 ;;
        --no-plugin) no_plugin=1 ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "install.sh: unknown argument $arg (see --help)" >&2; exit 2 ;;
    esac
done

say() { printf 'kit: %s\n' "$*"; }
fail() { printf 'kit: %s\n' "$*" >&2; exit 1; }

here=$(cd "$(dirname "$0")" && pwd)
manifest="$here/manifest.toml"
[ -f "$manifest" ] || fail "manifest.toml is not beside install.sh; get both from the same place"
tools=$(sed -n 's/^\[tools\.\([a-z0-9_-]*\)\]$/\1/p' "$manifest")
field() { sed -n "/^\[tools.$1\]/,/^\[/p" "$manifest" | sed -n "s/^$2 *= *\"\(.*\)\".*/\1/p"; }
kit_field() { sed -n '/^\[kit\]/,/^\[tools/p' "$manifest" | sed -n "s/^$1 *= *\"\(.*\)\".*/\1/p"; }

# 1. Prerequisites.
for need in git curl; do
    command -v "$need" >/dev/null || fail "$need is needed; install it with your package manager and run this again"
done
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH"; path_hint=1 ;; esac
if ! command -v uv >/dev/null; then
    say "installing uv $UV_VERSION into ~/.local/bin"
    curl -LsSf "https://astral.sh/uv/$UV_VERSION/install.sh" | env UV_NO_MODIFY_PATH=1 UV_INSTALL_DIR="$HOME/.local/bin" sh -s -- --quiet \
        || fail "uv did not install; see https://docs.astral.sh/uv/getting-started/installation/"
fi
say "uv $(uv --version | cut -d' ' -f2)"

# 2. GitHub access, for this run only.
if [ -z "${GH_TOKEN:-}" ]; then
    if command -v gh >/dev/null && GH_TOKEN=$(gh auth token 2>/dev/null) && [ -n "$GH_TOKEN" ]; then
        say "using the GitHub CLI's login"
    else
        fail "no GitHub access: run 'gh auth login' (GitHub CLI) and try again, or set GH_TOKEN to a token that can read the tools"
    fi
fi
export GH_TOKEN GIT_TERMINAL_PROMPT=0
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0='!f() { echo username=x-access-token; echo "password=$GH_TOKEN"; }; f'
export GIT_CONFIG_KEY_1=url.https://github.com/.insteadOf GIT_CONFIG_VALUE_1=ssh://git@github.com/
export GIT_CONFIG_KEY_2=url.https://github.com/.insteadOf GIT_CONFIG_VALUE_2=git@github.com:
login=$(curl -sf -H "Authorization: token $GH_TOKEN" https://api.github.com/user | sed -n 's/^ *"login": *"\(.*\)",*$/\1/p' | head -1)
[ -n "$login" ] || fail "GitHub does not accept this token; sign in again ('gh auth login') or check GH_TOKEN"
for repo in $(for tool in $tools; do field "$tool" repo; field "$tool" reads; done); do
    git ls-remote -q "https://github.com/$repo" HEAD >/dev/null 2>&1 \
        || fail "signed in to GitHub as $login, but github.com/$repo is not readable: ask the person who invited you to add $login to $repo, accept the invitation (github.com/notifications), then run this again"
done
say "signed in to GitHub as $login; the tools are readable"

# 3. The tools, at their tags.
for tool in $tools; do
    repo=$(field "$tool" repo); tag=$(field "$tool" tag)
    [ -n "$repo" ] && [ -n "$tag" ] || fail "manifest.toml has no repo and tag for $tool"
    say "$tool $tag"
    uv tool install --quiet "git+https://github.com/$repo@$tag" || fail "$tool did not install from $repo at $tag"
done

# 4. Each tool's own first-run setup, from the manifest. A tool refuses a second setup, saying
# "already"; that is the finished step.
for tool in $tools; do
    setup=$(field "$tool" setup); [ -n "$setup" ] || continue
    [ -z "$no_background" ] || setup="$setup $(field "$tool" setup_no_background)"
    if out=$($setup 2>&1); then
        printf '%s\n' "$out" | sed 's/^/kit:   /'
    else
        case "$out" in *already*) say "$tool: set up already" ;; *) fail "$tool setup: $out" ;; esac
    fi
done

# 5. Claude Code: kit's marketplace and each tool's plugin.
plugins=$(for tool in $tools; do field "$tool" plugin; done)
if [ -n "$no_plugin" ]; then
    say "plugins skipped (--no-plugin)"
elif [ -z "$plugins" ]; then
    say "no plugins in the manifest yet"
elif ! command -v claude >/dev/null; then
    say "Claude Code is not installed; when it is, run: claude plugin marketplace add $(kit_field marketplace_repo)"
    for p in $plugins; do say "  then: claude plugin install $p@$(kit_field marketplace)"; done
else
    command -v gh >/dev/null && gh auth setup-git >/dev/null 2>&1 && say "git uses the GitHub CLI's login (gh auth setup-git), so Claude Code can fetch private plugins"
    export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1
    claude plugin marketplace add "$(kit_field marketplace_repo)" >/dev/null 2>&1 || claude plugin marketplace update "$(kit_field marketplace)" >/dev/null
    for p in $plugins; do claude plugin install "$p@$(kit_field marketplace)" >/dev/null && say "plugin $p"; done
fi

say "done: $(echo $tools | tr ' ' ',') installed under ~/.local/bin"
[ -z "${path_hint:-}" ] || say "add ~/.local/bin to your PATH (uv tool update-shell does it) and open a new shell"
