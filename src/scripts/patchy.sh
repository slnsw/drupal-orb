#!/usr/bin/env bash
set -eoux pipefail
IFS=$'\n\t'

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
PATCHY_BRANCH=patchy

export COMPOSER_MEMORY_LIMIT=-1

git config --global user.email "admin@previousnext.com.au"
git config --global user.name "Patchy"

git checkout -B $PATCHY_BRANCH
composer2 update --prefer-dist --no-interaction --no-progress --no-suggest
if git diff-files --quiet --ignore-submodules -- composer.lock ; then
  echo "No composer changes"
else
  echo "[PATCHY] Updates composer dependencies" >> /tmp/commit-message.txt
  echo "" >> /tmp/commit-message.txt
  $COMPOSER_LOCK_DIFF_PATH --md --no-links >> /tmp/lock-diff.txt
  cat /tmp/lock-diff.txt >> /tmp/commit-message.txt
  git add composer.lock
  git commit -F /tmp/commit-message.txt
  make config-import updb config-export
  git add $DRUPAL_CONFIG_EXPORT_DIR
  git commit -m "[PATCHY] Updates config" || echo "No config changes"
  git push -f origin $PATCHY_BRANCH
  # Create a new PR or updating existing.
  gh pr create -t "[PATCHY] Updates composer dependencies" -F /tmp/lock-diff.txt -l "dependencies" -l "php" || gh pr edit $PATCHY_BRANCH -F /tmp/lock-diff.txt
fi
# Reset defaults.
git checkout "$CURRENT_BRANCH"
