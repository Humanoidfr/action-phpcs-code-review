#!/usr/bin/env bash

cd $GITHUB_WORKSPACE

COMMIT_ID=$(cat $GITHUB_EVENT_PATH | jq -r '.pull_request.head.sha')

echo "COMMIT ID: $COMMIT_ID"

PR_BODY=$(cat "$GITHUB_EVENT_PATH" | jq -r .pull_request.body)
if [[ "$PR_BODY" == *"[do-not-scan]"* ]]; then
  echo "[do-not-scan] found in PR description. Skipping PHPCS scan."
  exit 0
fi

stars=$(printf "%-30s" "*")

export RTBOT_WORKSPACE="/home/rtbot/github-workspace"
hosts_file="$GITHUB_WORKSPACE/.github/hosts.yml"

rsync -a "$GITHUB_WORKSPACE/" "$RTBOT_WORKSPACE"
rsync -a /root/vip-go-ci-tools/ /home/rtbot/vip-go-ci-tools
chown -R rtbot:rtbot /home/rtbot/

GITHUB_REPO_NAME=${GITHUB_REPOSITORY##*/}
GITHUB_REPO_OWNER=${GITHUB_REPOSITORY%%/*}

if [[ -n "$VAULT_GITHUB_TOKEN" ]] || [[ -n "$VAULT_TOKEN" ]]; then
  export GH_BOT_TOKEN=$(vault read -field=token secret/rtBot-token)
fi

# Remove spaces from GitHub token, at times copying token can give leading space.
GH_BOT_TOKEN=${GH_BOT_TOKEN//[[:blank:]]/}

phpcs_standard=''

defaultFiles=(
  '.phpcs.xml'
  'phpcs.xml'
  '.phpcs.xml.dist'
  'phpcs.xml.dist'
)

phpcsfilefound=1

for phpcsfile in "${defaultFiles[@]}"; do
  if [[ -f "$RTBOT_WORKSPACE/$phpcsfile" ]]; then
      phpcs_standard="--phpcs-standard=$RTBOT_WORKSPACE/$phpcsfile"
      phpcsfilefound=0
  fi
done

if [[ $phpcsfilefound -ne 0 ]]; then
    if [[ -n "$1" ]]; then
      phpcs_standard="--phpcs-standard=$1"
    else
      phpcs_standard="--phpcs-standard=WordPress"
    fi
fi

if [[ -n "$PHPCS_STANDARD_FILE_NAME" ]] && [[ -f "$RTBOT_WORKSPACE/$PHPCS_STANDARD_FILE_NAME" ]]; then
  phpcs_standard="--phpcs-standard=$RTBOT_WORKSPACE/$PHPCS_STANDARD_FILE_NAME"
fi;

# We always want to use our phpcs
phpcs_file_path="--phpcs-path='$RTBOT_WORKSPACE/$PHPCS_FILE_PATH'"

[[ -z "$PHPCS_SNIFFS_EXCLUDE" ]] && phpcs_sniffs_exclude='' || phpcs_sniffs_exclude="--phpcs-sniffs-exclude='$PHPCS_SNIFFS_EXCLUDE'"

[[ -z "$SKIP_FOLDERS" ]] && skip_folders_option='' || skip_folders_option="--lint-skip-folders='$SKIP_FOLDERS'"

/usr/games/cowsay "Running with the flag $phpcs_standard $phpcs_file_path"

php_lint_option='--lint=true'
if [[ "$(echo "$PHP_LINT" | tr '[:upper:]' '[:lower:]')" = 'false' ]]; then
  php_lint_option='--lint=false'
fi

echo "Running the following command"
echo "/home/rtbot/vip-go-ci-tools/vip-go-ci/vip-go-ci.php \
  --phpcs-skip-folders-in-repo-options-file=true \
  --lint-skip-folders-in-repo-options-file=true \
  --repo-options=true \
  --phpcs=true \
  --repo-owner=$GITHUB_REPO_OWNER \
  --repo-name=$GITHUB_REPO_NAME \
  --commit=$COMMIT_ID \
  --token=\$GH_BOT_TOKEN \
  --local-git-repo=$RTBOT_WORKSPACE \
  $phpcs_file_path \
  $phpcs_standard \
  $phpcs_sniffs_exclude \
  $skip_folders_option \
  $php_lint_option \
  --informational-url='https://github.com/rtCamp/action-phpcs-code-review/'"

gosu rtbot bash -c \
  "/home/rtbot/vip-go-ci-tools/vip-go-ci/vip-go-ci.php \
  --phpcs-skip-folders-in-repo-options-file=true \
  --lint-skip-folders-in-repo-options-file=true \
  --repo-options=true \
  --phpcs=true \
  --repo-owner=$GITHUB_REPO_OWNER \
  --repo-name=$GITHUB_REPO_NAME \
  --commit=$COMMIT_ID \
  --token=$GH_BOT_TOKEN \
  --local-git-repo=$RTBOT_WORKSPACE \
  $phpcs_file_path \
  $phpcs_standard \
  $phpcs_sniffs_exclude \
  $skip_folders_option \
  $php_lint_option \
  --informational-url='https://github.com/rtCamp/action-phpcs-code-review/'"
