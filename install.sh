#!/usr/bin/env bash
# Install the q1-book-reviewer skill into the personal skill folders of
# the agent tools found on this machine. Does not use sudo and does not
# need administrator rights. Safe to re-run. Re-running replaces the
# installed copy of this skill.
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/dotron99/q1-book-reviewer/main/install.sh | bash
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/dotron99/q1-book-reviewer/main/install.sh | bash -s -- --uninstall

set -euo pipefail

REPO_SLUG="dotron99/q1-book-reviewer"
REPO_HTTP="https://github.com/${REPO_SLUG}"
ARCHIVE_REF="${Q1_BOOK_REVIEWER_REF:-main}"
SKILL_NAME="q1-book-reviewer"

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Install q1-book-reviewer for the agent tools found on this machine.

The installer looks for Claude Code, Codex, Cursor, Gemini CLI and
GitHub Copilot, then installs the skill for each one it finds.
If none are found, it installs to the standard Claude Code and Codex
personal folders so the skill is ready when you use those tools.

Options:
  --symlink         Link to a local clone instead of copying
                    (only when this script is run from a checkout)
  --copy            Copy the skill folder (default)
  --all             Install for every supported tool, even if not detected
  --claude-only     Install only for Claude Code
  --codex-only      Install only for Codex
  --cursor-only     Install only for Cursor
  --gemini-only     Install only for Gemini CLI
  --copilot-only    Install only for GitHub Copilot
  --legacy-codex    Also install to the older Codex path
                    (~/.codex/skills, or $CODEX_HOME/skills if set)
  --uninstall       Remove this skill from the installer destinations
  --dry-run         Show what would happen, without changing files
  -h, --help        Show this help
USAGE
}

MODE="copy"
DETECT=1
FORCE_ALL=0
ONLY=""
DO_LEGACY=0
UNINSTALL=0
DRY_RUN=0
CLEANUP_DIR=""

die() {
  printf 'install.sh: %s\n' "$1" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --symlink) MODE="symlink" ;;
    --copy) MODE="copy" ;;
    --all)
      FORCE_ALL=1
      DETECT=0
      ;;
    --claude-only|--codex-only|--cursor-only|--gemini-only|--copilot-only)
      [ -z "$ONLY" ] || die "use only one --*-only option"
      ONLY=${1#--}
      ONLY=${ONLY%-only}
      DETECT=0
      ;;
    --legacy-codex) DO_LEGACY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1 (try --help)"
      ;;
  esac
  shift
done

[ -n "${HOME:-}" ] || die "HOME is not set"
[ -d "$HOME" ] || die "HOME is not a directory: $HOME"

cleanup() {
  if [ -n "$CLEANUP_DIR" ] && [ -d "$CLEANUP_DIR" ]; then
    rm -rf "$CLEANUP_DIR"
  fi
}
trap cleanup EXIT

script_path=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_path="${BASH_SOURCE[0]}"
elif [ -n "${0:-}" ] && [ -f "$0" ] && [ "$0" != "bash" ] && [ "$0" != "sh" ]; then
  script_path="$0"
fi

skill_from_root() {
  local root="$1"
  if [ -f "$root/skills/${SKILL_NAME}/SKILL.md" ]; then
    printf '%s\n' "$root/skills/${SKILL_NAME}"
    return 0
  fi
  return 1
}

find_local_skill() {
  local candidate
  if [ -n "$script_path" ]; then
    candidate=$(CDPATH= cd -- "$(dirname -- "$script_path")" && pwd)
    skill_from_root "$candidate" && return 0
  fi
  if [ -n "${PWD:-}" ]; then
    skill_from_root "$PWD" && return 0
    skill_from_root "$PWD/${SKILL_NAME}" && return 0
  fi
  return 1
}

download_skill() {
  local tmp archive root
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/q1-book-reviewer-src.XXXXXX")
  archive="$tmp/src.tar.gz"
  if have_cmd curl; then
    curl -fsSL "${REPO_HTTP}/archive/refs/heads/${ARCHIVE_REF}.tar.gz" -o "$archive" \
      || curl -fsSL "${REPO_HTTP}/archive/refs/tags/${ARCHIVE_REF}.tar.gz" -o "$archive" \
      || die "could not download ${REPO_SLUG} (${ARCHIVE_REF})"
  elif have_cmd wget; then
    wget -q -O "$archive" "${REPO_HTTP}/archive/refs/heads/${ARCHIVE_REF}.tar.gz" \
      || wget -q -O "$archive" "${REPO_HTTP}/archive/refs/tags/${ARCHIVE_REF}.tar.gz" \
      || die "could not download ${REPO_SLUG} (${ARCHIVE_REF})"
  elif have_cmd git; then
    git clone --depth 1 --branch "$ARCHIVE_REF" "${REPO_HTTP}.git" "$tmp/repo" >/dev/null 2>&1 \
      || die "could not clone ${REPO_SLUG} (${ARCHIVE_REF})"
    CLEANUP_DIR="$tmp"
    skill_from_root "$tmp/repo" && return 0
    die "downloaded repository is missing skills/${SKILL_NAME}"
  else
    die "need curl, wget or git to download the skill"
  fi
  mkdir -p "$tmp/unpack"
  tar -xzf "$archive" -C "$tmp/unpack"
  root=$(find "$tmp/unpack" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  [ -n "$root" ] || die "downloaded archive was empty"
  CLEANUP_DIR="$tmp"
  skill_from_root "$root" && return 0
  die "downloaded repository is missing skills/${SKILL_NAME}"
}

is_this_skill() {
  local dir="$1"
  local skill_file="$dir/SKILL.md"
  [ -f "$skill_file" ] && grep -Eq '^name:[[:space:]]*q1-book-reviewer[[:space:]]*$' "$skill_file"
}

claude_parent() {
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    printf '%s\n' "${CLAUDE_CONFIG_DIR}/skills"
  else
    printf '%s\n' "${HOME}/.claude/skills"
  fi
}

legacy_codex_parent() {
  printf '%s\n' "${CODEX_HOME:-$HOME/.codex}/skills"
}

detect_claude() {
  [ -n "${CLAUDE_CONFIG_DIR:-}" ] || have_cmd claude || [ -d "${HOME}/.claude" ]
}

detect_codex() {
  # ~/.agents/skills is the current official Codex personal path, and is
  # also created by this installer, so it must count on a re-run.
  [ -n "${CODEX_HOME:-}" ] || have_cmd codex || [ -d "${HOME}/.codex" ] || [ -d "${HOME}/.agents" ]
}

detect_cursor() {
  have_cmd cursor || have_cmd cursor-agent || [ -d "${HOME}/.cursor" ]
}

detect_gemini() {
  have_cmd gemini || [ -d "${HOME}/.gemini" ]
}

detect_copilot() {
  have_cmd copilot || [ -d "${HOME}/.copilot" ]
}

# tool<TAB>path
collect_targets() {
  local want_claude=0 want_codex=0 want_cursor=0 want_gemini=0 want_copilot=0

  if [ -n "$ONLY" ]; then
    case "$ONLY" in
      claude) want_claude=1 ;;
      codex) want_codex=1 ;;
      cursor) want_cursor=1 ;;
      gemini) want_gemini=1 ;;
      copilot) want_copilot=1 ;;
    esac
  elif [ "$FORCE_ALL" -eq 1 ]; then
    want_claude=1
    want_codex=1
    want_cursor=1
    want_gemini=1
    want_copilot=1
  else
    detect_claude && want_claude=1
    detect_codex && want_codex=1
    detect_cursor && want_cursor=1
    detect_gemini && want_gemini=1
    detect_copilot && want_copilot=1
    if [ "$want_claude" -eq 0 ] && [ "$want_codex" -eq 0 ] && [ "$want_cursor" -eq 0 ] && [ "$want_gemini" -eq 0 ] && [ "$want_copilot" -eq 0 ]; then
      printf 'No supported tools were detected. Installing to the standard Claude Code and Codex folders.\n' >&2
      want_claude=1
      want_codex=1
    fi
  fi

  # Codex, Cursor and Gemini CLI all read ~/.agents/skills. Put the
  # canonical copy there whenever any of those tools is selected.
  if [ "$want_codex" -eq 1 ] || [ "$want_cursor" -eq 1 ] || [ "$want_gemini" -eq 1 ]; then
    printf 'shared\t%s/%s\n' "${HOME}/.agents/skills" "$SKILL_NAME"
  fi
  if [ "$want_claude" -eq 1 ]; then
    printf 'Claude Code\t%s/%s\n' "$(claude_parent)" "$SKILL_NAME"
  fi
  if [ "$want_cursor" -eq 1 ]; then
    printf 'Cursor\t%s/%s\n' "${HOME}/.cursor/skills" "$SKILL_NAME"
  fi
  if [ "$want_copilot" -eq 1 ]; then
    printf 'GitHub Copilot\t%s/%s\n' "${HOME}/.copilot/skills" "$SKILL_NAME"
  fi
  if [ "$DO_LEGACY" -eq 1 ] || [ -n "${CODEX_HOME:-}" ]; then
    if [ "$want_codex" -eq 1 ] || [ "$DO_LEGACY" -eq 1 ]; then
      printf 'Codex (older path)\t%s/%s\n' "$(legacy_codex_parent)" "$SKILL_NAME"
    fi
  fi
}

all_known_paths() {
  printf '%s/%s\n' "$(claude_parent)" "$SKILL_NAME"
  printf '%s/%s\n' "${HOME}/.agents/skills" "$SKILL_NAME"
  printf '%s/%s\n' "$(legacy_codex_parent)" "$SKILL_NAME"
  printf '%s/%s\n' "${HOME}/.cursor/skills" "$SKILL_NAME"
  printf '%s/%s\n' "${HOME}/.gemini/skills" "$SKILL_NAME"
  printf '%s/%s\n' "${HOME}/.copilot/skills" "$SKILL_NAME"
}

confirm_replace() {
  local dest="$1"
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    return 0
  fi
  if is_this_skill "$dest"; then
    return 0
  fi
  die "refusing to replace $dest (it does not look like ${SKILL_NAME}). Remove it by hand if that is intentional."
}

resolve_link() {
  local dest="$1"
  local link
  link=$(readlink "$dest")
  case "$link" in
    /*) printf '%s\n' "$link" ;;
    *) printf '%s\n' "$(CDPATH= cd -- "$(dirname -- "$dest")" && CDPATH= cd -- "$(dirname -- "$link")" && pwd)/$(basename -- "$link")" ;;
  esac
}

install_copy() {
  local dest="$1"
  local parent tmp
  parent=$(dirname -- "$dest")
  mkdir -p "$parent"
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/q1-book-reviewer.XXXXXX")
  cp -R "$SKILL_SRC" "$tmp/$SKILL_NAME"
  rm -rf "$dest"
  mv "$tmp/$SKILL_NAME" "$dest"
  rmdir "$tmp" 2>/dev/null || rm -rf "$tmp"
  printf 'Installed copy at %s\n' "$dest"
}

install_link() {
  local dest="$1"
  local target="$2"
  local parent current
  parent=$(dirname -- "$dest")
  mkdir -p "$parent"
  if [ -L "$dest" ]; then
    current=$(resolve_link "$dest")
    if [ "$current" = "$target" ]; then
      printf 'Already linked: %s -> %s\n' "$dest" "$target"
      return 0
    fi
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    rm -rf "$dest"
  fi
  ln -s "$target" "$dest"
  printf 'Linked %s -> %s\n' "$dest" "$target"
}

try_link_or_copy() {
  local dest="$1"
  local target="$2"
  local parent
  parent=$(dirname -- "$dest")
  mkdir -p "$parent"
  if [ -L "$dest" ]; then
    if [ "$(resolve_link "$dest")" = "$target" ]; then
      printf 'Already linked: %s -> %s\n' "$dest" "$target"
      return 0
    fi
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    rm -rf "$dest"
  fi
  if ln -s "$target" "$dest" 2>/dev/null; then
    printf 'Linked %s -> %s\n' "$dest" "$target"
    return 0
  fi
  printf 'Could not create a symlink at %s; installing a copy instead.\n' "$dest"
  install_copy "$dest"
}

if [ "$UNINSTALL" -eq 0 ]; then
  SKILL_SRC=""
  if SKILL_SRC=$(find_local_skill); then
    :
  else
    if [ "$MODE" = "symlink" ]; then
      die "--symlink needs a local checkout; download-based installs can only copy"
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'dry-run: would download %s (%s)\n' "$REPO_SLUG" "$ARCHIVE_REF"
      SKILL_SRC="(downloaded skills/${SKILL_NAME})"
    else
      SKILL_SRC=$(download_skill)
    fi
  fi
  if [ "$DRY_RUN" -eq 0 ]; then
    [ -d "$SKILL_SRC" ] && [ -f "$SKILL_SRC/SKILL.md" ] || die "skill folder not found at $SKILL_SRC"
    is_this_skill "$SKILL_SRC" || die "source folder is missing a q1-book-reviewer SKILL.md"
    SKILL_SRC=$(CDPATH= cd -- "$SKILL_SRC" && pwd)
  fi
fi

if [ "$UNINSTALL" -eq 1 ]; then
  found=0
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
      continue
    fi
    if ! is_this_skill "$dest"; then
      printf 'Skipping %s (it does not look like %s)\n' "$dest" "$SKILL_NAME"
      continue
    fi
    found=1
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'dry-run: remove %s\n' "$dest"
    else
      rm -rf "$dest"
      printf 'Removed %s\n' "$dest"
    fi
  done <<TARGETS
$(all_known_paths | awk 'NF && !seen[$0]++')
TARGETS
  if [ "$found" -eq 0 ]; then
    printf 'No installed %s skill was found.\n' "$SKILL_NAME"
  fi
  exit 0
fi

# Prefer the shared ~/.agents/skills copy as the canonical destination
# so other folders can link to it.
canonical=""
targets=$(collect_targets | awk -F '\t' 'NF==2 && !seen[$2]++ {print}')
[ -n "$targets" ] || die "no installation targets selected"

while IFS="$(printf '\t')" read -r tool dest; do
  [ -n "$dest" ] || continue
  case "$dest" in
    */.agents/skills/*)
      canonical="$dest"
      break
      ;;
  esac
done <<TARGETS
$targets
TARGETS

if [ -z "$canonical" ]; then
  canonical=$(printf '%s\n' "$targets" | head -n 1 | awk -F '\t' '{print $2}')
fi

if [ "$DRY_RUN" -eq 1 ]; then
  while IFS="$(printf '\t')" read -r tool dest; do
    [ -n "$dest" ] || continue
    printf 'dry-run: install for %s at %s\n' "$tool" "$dest"
  done <<TARGETS
$targets
TARGETS
  exit 0
fi

installed_any=0
while IFS="$(printf '\t')" read -r tool dest; do
  [ -n "$dest" ] || continue
  confirm_replace "$dest"
  if [ "$dest" = "$canonical" ]; then
    if [ "$MODE" = "symlink" ]; then
      install_link "$dest" "$SKILL_SRC"
    else
      install_copy "$dest"
    fi
    canonical=$(CDPATH= cd -- "$dest" && pwd)
  else
    # Point extra tool folders at the canonical copy, not at a temp download.
    try_link_or_copy "$dest" "$canonical"
  fi
  printf '  (%s)\n' "$tool"
  installed_any=1
done <<TARGETS
$targets
TARGETS

if [ "$installed_any" -eq 1 ]; then
  printf '\nStart a new session and invoke the skill as /q1-book-reviewer (Claude Code or Cursor) or $q1-book-reviewer (Codex).\n'
fi
