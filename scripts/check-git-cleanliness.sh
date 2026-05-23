#!/bin/bash
# check-git-cleanliness.sh — commit-discipline hook script
#
#   MODIFICATION 1: The closed_issue_refs_from_local_commits() function
#   That check is now driven by the actual remote URL of the target repo
#   (repo_name_with_owner()) — so it will check issue state for whatever
#   repo the caller is working in, as long as `gh` is available.
#
#   MODIFICATION 2: The guard-push deny messages originally referenced
#   language so the message is coherent in any target repo.
#
# All other logic (warn-dirty, return-default-branch, guard-push) is
# identical to the original scripts/check-git-cleanliness.sh.
#
set -euo pipefail

MODE="${1:-warn-dirty}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  exit 0
fi

canonical_path() {
  (
    cd "$1" >/dev/null 2>&1
    pwd -P
  )
}

resolve_default_branch() {
  local resolved

  resolved="$(
    git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null \
      | sed 's#^origin/##'
  )"
  if [[ -z "$resolved" ]]; then
    resolved="$(
      git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p'
    )"
  fi

  printf '%s\n' "$resolved"
}

status_output() {
  git status --short --branch
}

dirty_lines_from_status() {
  printf '%s\n' "$1" | tail -n +2 | sed '/^$/d'
}

print_dirty_warning() {
  local current_status="$1"

  {
    echo "COMMIT-DISCIPLINE: tracked or untracked changes remain in the worktree."
    echo "This session is not done until the changes are either:"
    echo "1. committed locally with the intended Conventional Commit,"
    echo "2. handed off to /delegate or BUILDER for PR-oriented completion, or"
    echo "3. explicitly called out as intentionally left uncommitted."
    echo
    echo "Current git status:"
    printf '%s\n' "$current_status"
  } >&2
}

worktree_path_for_branch() {
  local branch_name="$1"
  local target_ref="refs/heads/$branch_name"
  local current_path=""
  local current_branch_ref=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == worktree\ * ]]; then
      current_path="${line#worktree }"
      current_branch_ref=""
      continue
    fi

    if [[ "$line" == branch\ * ]]; then
      current_branch_ref="${line#branch }"
      continue
    fi

    if [[ -z "$line" ]]; then
      if [[ "$current_branch_ref" == "$target_ref" ]]; then
        printf '%s\n' "$current_path"
        return 0
      fi
      current_path=""
      current_branch_ref=""
    fi
  done < <(git worktree list --porcelain)

  if [[ "$current_branch_ref" == "$target_ref" ]]; then
    printf '%s\n' "$current_path"
    return 0
  fi

  return 1
}

repo_name_with_owner() {
  local remote_url
  remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"

  case "$remote_url" in
    git@github.com:*.git)
      printf '%s\n' "${remote_url#git@github.com:}" | sed 's/\.git$//'
      ;;
    git@github.com:*)
      printf '%s\n' "${remote_url#git@github.com:}"
      ;;
    https://github.com/*.git)
      printf '%s\n' "${remote_url#https://github.com/}" | sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${remote_url#https://github.com/}"
      ;;
    *)
      printf '\n'
      ;;
  esac
}

# MODIFICATION 1: repo_name is now resolved from the actual remote URL (generic).
closed_issue_refs_from_local_commits() {
  local branch_name="$1"
  local repo_name="$2"
  local issue_ref
  local issue_number
  local issue_state
  local -a issue_refs=()
  local -a closed_refs=()

  [[ -n "$repo_name" ]] || return 0
  command -v gh >/dev/null 2>&1 || return 0

  while IFS= read -r issue_ref; do
    [[ -n "$issue_ref" ]] || continue
    issue_refs+=("$issue_ref")
  done < <(
    git log --format='%s%n%b' "origin/$branch_name..$branch_name" \
      | grep -oE '#[0-9]+' \
      | sort -u
  )

  for issue_ref in "${issue_refs[@]}"; do
    issue_number="${issue_ref#\#}"
    issue_state="$(
      gh issue view "$issue_number" --repo "$repo_name" --json state --jq '.state' 2>/dev/null || true
    )"
    if [[ "$issue_state" == "CLOSED" ]]; then
      closed_refs+=("$issue_ref")
    fi
  done

  printf '%s\n' "${closed_refs[*]}"
}

default_branch="$(resolve_default_branch)"
repo_root_canonical="$(canonical_path "$repo_root")"

case "$MODE" in
  warn-dirty)
    current_status="$(status_output)"
    dirty_lines="$(dirty_lines_from_status "$current_status")"

    if [[ -n "$dirty_lines" ]]; then
      print_dirty_warning "$current_status"
    fi
    ;;

  return-default-branch)
    current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    current_status="$(status_output)"
    dirty_lines="$(dirty_lines_from_status "$current_status")"

    if [[ -z "$default_branch" ]]; then
      echo "DEFAULT-BRANCH-LANDING: could not resolve the repo default branch from origin/HEAD." >&2
      echo "Fix the remote default-branch metadata before relying on session branch cleanup." >&2
      exit 1
    fi

    if [[ "$default_branch" == feature/* || "$default_branch" == wip/* ]]; then
      echo "DEFAULT-BRANCH-LANDING: origin/HEAD resolves to '$default_branch', which looks like a feature or WIP branch instead of a stable default branch." >&2
      echo "Repair origin/HEAD before session cleanup relies on it." >&2
      exit 1
    fi

    if [[ -z "$current_branch" ]]; then
      echo "DEFAULT-BRANCH-LANDING: HEAD is detached, so the repo cannot safely return to '$default_branch' automatically." >&2
      echo "Check out a real branch or resolve the detached state before ending the session." >&2
      exit 1
    fi

    if [[ "$current_branch" != "$default_branch" ]]; then
      if [[ -n "$dirty_lines" ]]; then
        print_dirty_warning "$current_status"
        echo "DEFAULT-BRANCH-LANDING: repo is still on '$current_branch' and cannot switch back to '$default_branch' with a dirty worktree." >&2
        echo "Commit, hand off, or explicitly clean the worktree before ending the session on a non-default branch." >&2
        exit 1
      fi

      if ! git show-ref --verify --quiet "refs/heads/$default_branch"; then
        echo "DEFAULT-BRANCH-LANDING: local branch '$default_branch' does not exist, so automatic return cannot proceed." >&2
        echo "Create or restore the local default branch before ending the session on '$current_branch'." >&2
        exit 1
      fi

      linked_worktree_path="$(worktree_path_for_branch "$default_branch" || true)"
      if [[ -n "$linked_worktree_path" ]]; then
        linked_worktree_canonical="$(canonical_path "$linked_worktree_path")"
        if [[ -n "$linked_worktree_canonical" && "$linked_worktree_canonical" != "$repo_root_canonical" ]]; then
          echo "DEFAULT-BRANCH-LANDING: cannot switch to '$default_branch' because that branch is already checked out in another worktree: $linked_worktree_path" >&2
          echo "Resolve the linked worktree conflict before ending the session on '$current_branch'." >&2
          exit 1
        fi
      fi

      if ! checkout_output="$(git checkout --quiet "$default_branch" 2>&1)"; then
        echo "DEFAULT-BRANCH-LANDING: failed to switch from '$current_branch' to '$default_branch'." >&2
        if [[ -n "$checkout_output" ]]; then
          printf '%s\n' "$checkout_output" >&2
        fi
        exit 1
      fi

      echo "DEFAULT-BRANCH-LANDING: switched from '$current_branch' to '$default_branch'." >&2
      current_status="$(status_output)"
      dirty_lines="$(dirty_lines_from_status "$current_status")"
    fi

    if [[ -n "$dirty_lines" ]]; then
      print_dirty_warning "$current_status"
    fi

    if ! git show-ref --verify --quiet "refs/remotes/origin/$default_branch"; then
      echo "DEFAULT-BRANCH-LANDING: remote-tracking branch 'origin/$default_branch' is unavailable, so upstream alignment cannot be verified." >&2
      echo "Fetch or repair remote metadata before ending the session." >&2
      exit 1
    fi

    ahead_count="$(git rev-list --count "origin/$default_branch..$default_branch")"
    behind_count="$(git rev-list --count "$default_branch..origin/$default_branch")"

    if [[ "$ahead_count" -gt 0 && "$behind_count" -gt 0 ]]; then
      echo "DEFAULT-BRANCH-LANDING: local '$default_branch' is diverged from 'origin/$default_branch' ($ahead_count ahead, $behind_count behind)." >&2
      echo "Land or reconcile the local branch through a reviewable path before ending the session." >&2
      exit 1
    fi

    if [[ "$behind_count" -gt 0 ]]; then
      echo "DEFAULT-BRANCH-LANDING: local '$default_branch' is behind 'origin/$default_branch' by $behind_count commit(s)." >&2
      echo "Update the local default branch before ending the session." >&2
      exit 1
    fi

    if [[ "$ahead_count" -gt 0 ]]; then
      repo_name="$(repo_name_with_owner)"
      closed_issue_refs="$(closed_issue_refs_from_local_commits "$default_branch" "$repo_name")"
      if [[ -n "$closed_issue_refs" ]]; then
        echo "DEFAULT-BRANCH-LANDING: local-only commit(s) on '$default_branch' reference already-closed issue(s): $closed_issue_refs." >&2
        echo "Those commits must land through a reviewable path or remain attached to an explicit open landing step before issue closeout." >&2
        exit 1
      fi

      echo "DEFAULT-BRANCH-LANDING: local '$default_branch' is ahead of 'origin/$default_branch' by $ahead_count commit(s)." >&2
      echo "Land the local-only history through a reviewable path before ending the session." >&2
      exit 1
    fi
    ;;

  guard-push)
    input="$(cat)"
    tool_name="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("toolName",""))')"
    if [[ "$tool_name" != "bash" ]]; then
      exit 0
    fi

    command="$(
      printf '%s' "$input" | python3 -c 'import json,sys
data=json.load(sys.stdin)
tool_args=data.get("toolArgs","{}")
try:
    parsed=json.loads(tool_args)
except Exception:
    parsed={}
print(parsed.get("command",""))'
    )"

    if [[ -z "$command" ]]; then
      exit 0
    fi

    # Isolate only git-push segments before checking branch names.
    # Splits on shell-level separators (&&, ||, ;, |) to avoid false-positives
    # on chained commands such as: git push feature/x && gh pr create --base master
    # The command text is passed via COMMAND_TEXT env var because stdin is already
    # used by the Python heredoc for the script source.
    push_target="$(
      COMMAND_TEXT="$command" python3 - "$default_branch" <<'PY'
import sys, re, os

default_branch = sys.argv[1] if len(sys.argv) > 1 else ''
command_text = os.environ.get('COMMAND_TEXT', '')

# Git global options that consume a following argument
GIT_GLOBAL_OPT_WITH_ARG = frozenset([
    '-C', '--git-dir', '--work-tree', '--namespace',
    '--super-prefix', '--exec-path', '-c', '--config-env',
])

def find_git_subcommand(tokens):
    """Return the git subcommand (first non-option token after 'git')."""
    i = 1
    while i < len(tokens):
        t = tokens[i]
        if t in GIT_GLOBAL_OPT_WITH_ARG:
            i += 2
        elif t.startswith('-'):
            i += 1
        else:
            return t
    return None

# Split on common shell-level separators (approximate; not quote-aware)
segments = re.split(r'&&|\|\||(?<!\|)\|(?!\|)|;|\n', command_text)

for seg in segments:
    tokens = seg.strip().split()
    if not tokens or tokens[0] != 'git':
        continue
    if find_git_subcommand(tokens) != 'push':
        continue
    # This is a git push segment — check if it targets the default branch
    if default_branch and re.search(
        r'(?:^|[\s:/])' + re.escape(default_branch) + r'(?:\s|$)', seg
    ):
        print('default')
        sys.exit(0)
    if re.search(r'(?:^|[\s:/])(?:master|main)(?:\s|$)', seg):
        print('static')
        sys.exit(0)

print('')
PY
    )"

    if [[ "$push_target" == "default" ]]; then
      python3 - <<'PY'
import json
print(json.dumps({
    "permissionDecision": "deny",
    "permissionDecisionReason": "Pushing directly to the default branch is blocked by project workflow. Push a feature branch or use /delegate for remote PR flow."
}))
PY
      exit 0
    fi

    if [[ "$push_target" == "static" ]]; then
      python3 - <<'PY'
import json
print(json.dumps({
    "permissionDecision": "deny",
    "permissionDecisionReason": "Direct pushes to main or master are blocked by project workflow. Push a feature branch or use /delegate for remote PR flow."
}))
PY
      exit 0
    fi
    ;;

  *)
    echo "Unknown mode: $MODE" >&2
    exit 1
    ;;
esac
