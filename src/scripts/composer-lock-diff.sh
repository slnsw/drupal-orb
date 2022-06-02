#!/usr/bin/env bash
set -eoux pipefail
IFS=$'\n\t'

# If we are not on a pull request, exit.
[[ ! -v CIRCLE_PULL_REQUEST ]] && exit 0
echo "CIRCLE_PULL_REQUEST: ${CIRCLE_PULL_REQUEST}"

# Find the base branch this PR is being merged into.
BASE_BRANCH=$(gh pr view --json baseRefName --jq .baseRefName $CIRCLE_PULL_REQUEST)
echo "BASE_BRANCH: ${BASE_BRANCH}"

# Generate the diff.
$HOME/.config/composer/vendor/bin/composer-lock-diff --from ${BASE_BRANCH} --md > /tmp/diff.md

# If there is no diff, exit.
if [ -s /tmp/diff.md ]; then
  echo "Diff found"
else
  echo "No diff found"
  exit 0
fi

# Extract Pull Request ID.
PULL_REQUEST_ID=${CIRCLE_PULL_REQUEST##*/}
echo "PULL_REQUEST_ID: ${PULL_REQUEST_ID}"

# Find existing comment, if it exists.
COMMENT_ID=$(gh api --jq 'map(select(.body | contains("*Composer lock diff*"))) | first .id' /repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/issues/${PULL_REQUEST_ID}/comments)
echo "COMMENT_ID: ${COMMENT_ID}"

echo -e "*Composer lock diff*\n\n" >> /tmp/comment.md
cat /tmp/diff.md >> /tmp/comment.md

if [[ -z "${COMMENT_ID}" ]]; then
  # Create a new comment.
  gh pr comment ${PULL_REQUEST_ID} -F /tmp/comment.md
else
  # Update existing comment.
  COMMENT_BODY=$(cat /tmp/comment.md)
  gh api --method PATCH /repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/issues/comments/${COMMENT_ID} -f body="${COMMENT_BODY}"
fi
