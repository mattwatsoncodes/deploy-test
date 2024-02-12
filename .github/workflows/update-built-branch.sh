#!/bin/bash -e
#
# Build the assets and SFTP the files to the Pantheon environment.
#

set -ex

# Read some variables from the current CI job configuration.
BRANCH="${GITHUB_REF#refs/heads/}"
COMMIT_SHA=${GITHUB_SHA}

# This is where the deploy branch will be built and pushed to.
SRC_DIR="${PWD}"
BUILD_DIR="/tmp/pantheon-build-$(date +%s)"

# Deploy the "main" branch to Pantheon's "dev" branch
if [ "$BRANCH" = "main" ]; then
    DEPLOY_BRANCH="dev"
# Deploy the "staging" branch to Pantheon's "qa" branch.
elif [ "$BRANCH" = "staging" ]; then
    DEPLOY_BRANCH="qa"
# No reason to deploy any other branches, so exit early.
else
    echo "Not deploying, due to branch name format not matching."
    exit
fi

cd "$SRC_DIR"

# Get the PR title from the merged branch so that we can create a commit.
PR_TITLE="$(git log -1 --pretty=format:%b)"

# Copy the built files from src repo over to the build repo
# ---------------------------------------------------------

if ! command -v 'rsync'; then
	APT_GET_PREFIX=''
	if command -v 'sudo'; then
		APT_GET_PREFIX='sudo'
	fi

	$APT_GET_PREFIX apt-get update
	$APT_GET_PREFIX apt-get install -q -y rsync
fi

echo "Syncing files... quietly"

rsync --delete -a "${SRC_DIR}/" "${BUILD_DIR}" --exclude='.git/'

# Into built wp-content
cd ${BUILD_DIR}/wp-content

# A list of folders we want to selectively deploy
# We don't want to deploy everything as other agencies are
# also pushing plugins to this repo via SFTP.
declare -a paths=(
    "themes/my-theme" 
    "plugins/gutenberg"
)

## Loop through the paths array
for path in "${paths[@]}"
do
   # Get the root folder.
   FOLDER=$(echo "$path" | cut -d "/" -f1)

   # rsync the files with the following options:
   # -r - Recursively sync folders
   # -l - Recreate symlinks
   # -p - Set same permissions from source to destination
   # -z - Compress the files on sync
   rsync -rlpz --info=progress2 --temp-dir=~/tmp --delay-updates --ipv4 --exclude=.git -e 'ssh -o "StrictHostKeyChecking=no" -p 2222' "./$path" "$DEPLOY_BRANCH.$PANTHEON_PROJECT_ID@appserver.$DEPLOY_BRANCH.$PANTHEON_PROJECT_ID.drush.in:code/wp-content/$paths"
done

# If we are on the dev branch, create a commit message with the PR Title (JIRA ID and Description)
if [ "$DEPLOY_BRANCH" = "dev" ]; then
  terminus auth:login --machine-token=${PANTHEON_MACHINE_KEY}
  terminus env:commit --message "$PR_TITLE" -- "$PANTHEON_PROJECT_ID.$DEPLOY_BRANCH"
fi