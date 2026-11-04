#!/usr/bin/env bash
# Keeps qa-installer-branch an exact mirror of main (the branch testers pull with GitHub Desktop; they copy the XayaUI*
# folders from it into AddOns and /reload). The tester installer was removed on 2026-11-04 (Xaya: "just eliminate the
# installers"); the branch keeps its name. Later it is to become the test stage before main ("the qa-test environment can be
# the test environment before pushing to main later down the road"); until then it only mirrors main.
#
#   tools/sync-qa-branch.sh            rebuild the branch from origin/main and push it (fast-forward only, never force)
#   tools/sync-qa-branch.sh --check    change nothing; exit 1 if the branch is not an exact mirror of origin/main right now
#   tools/sync-qa-branch.sh --dry-run  build the commit, print what would be pushed, push nothing
#
# What the branch contains: every file of origin/main, unchanged, nothing else. Nothing is ever taken from the branch back
# into main.
#
# Why it is safe for GitHub Desktop: each run adds ONE new commit on top of the branch's current tip (its second parent is the
# main commit it mirrors), so every tester's "Pull origin" is a plain fast-forward. The branch is never rewritten or force-pushed.
# A run with no difference to publish makes no commit.
#
# Environment: QA_REMOTE (origin), QA_MAIN_BRANCH (main), QA_BRANCH (qa-installer-branch), QA_COMMIT_TRAILER (text appended to
# the commit message, for example attribution lines).
set -euo pipefail

REMOTE="${QA_REMOTE:-origin}"
MAIN="${QA_MAIN_BRANCH:-main}"
QA="${QA_BRANCH:-qa-installer-branch}"
MODE=push
for arg in "$@"; do
  case "$arg" in
    --check)   MODE=check ;;
    --dry-run) MODE=dry ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"
git fetch -q "$REMOTE" "$MAIN"
main_sha=$(git rev-parse "refs/remotes/$REMOTE/$MAIN")

qa_sha=""
if git ls-remote --exit-code --heads "$REMOTE" "$QA" >/dev/null 2>&1; then
  git fetch -q "$REMOTE" "+refs/heads/$QA:refs/remotes/$REMOTE/$QA"
  qa_sha=$(git rev-parse "refs/remotes/$REMOTE/$QA")
fi

# The branch's files are main's files: main's own tree (the working tree and the index are never touched).
tree=$(git rev-parse "$main_sha^{tree}")

short=${main_sha:0:9}
if [ -n "$qa_sha" ] && [ "$(git rev-parse "$qa_sha^{tree}")" = "$tree" ]; then
  echo "up to date: $QA already mirrors $MAIN @ $short"
  exit 0
fi
if [ "$MODE" = check ]; then
  echo "OUT OF DATE: $QA does not match $MAIN @ $short" >&2
  exit 1
fi

parents=()
if [ -n "$qa_sha" ]; then
  parents+=(-p "$qa_sha")
  git merge-base --is-ancestor "$main_sha" "$qa_sha" 2>/dev/null || parents+=(-p "$main_sha")
else
  parents+=(-p "$main_sha")
fi

if ! git config user.email >/dev/null 2>&1; then
  export GIT_AUTHOR_NAME="XayaUI QA mirror" GIT_AUTHOR_EMAIL="noreply@github.com"
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
fi
subject=$(git log -1 --format=%s "$main_sha")
msg="Mirror $MAIN @ $short: $subject

Automatic mirror: this commit's files are exactly those of $MAIN @ $main_sha.
Do not commit to this branch; the next sync replaces anything changed here."
if [ -n "${QA_COMMIT_TRAILER:-}" ]; then msg="$msg

$QA_COMMIT_TRAILER"; fi
commit=$(git commit-tree "$tree" "${parents[@]}" -m "$msg")

if [ "$MODE" = dry ]; then
  echo "dry run: would push ${commit:0:9} to $REMOTE/$QA (mirrors $MAIN @ $short)"
  exit 0
fi
git push -q "$REMOTE" "$commit:refs/heads/$QA"
echo "pushed ${commit:0:9} to $REMOTE/$QA (mirrors $MAIN @ $short)"
