#!/bin/bash -e
#
# Check in built assets from the current branch, and push them to a -built
# branch in preparation for deploying to Pantheon
#
# Source and inspiration: https://github.com/Automattic/wpe-build-deploy/blob/master/deploy.sh
#

set -ex

# Read some variables from the current CI job configuration.
BRANCH="${GITHUB_REF#refs/heads/}"
COMMIT_SHA=${GITHUB_SHA}

# This is where the deploy branch will be built and pushed to.
SRC_DIR="${PWD}"
BUILD_DIR="/tmp/pantheon-build-$(date +%s)"

# If branch name matches an allowed pattern (JIRA ticket number, with up to 3
# optional characters to differentiate different branches attached to the same
# JIRA ticket), then push it to a Pantheon environment to build as a multidev
# preview environment.
DEPLOYABLE_BRANCH_PATTERN=^"([[:alpha:]]+-[[:digit:]]+)[^/]{0,4}"

if [[ "$BRANCH" =~ $DEPLOYABLE_BRANCH_PATTERN ]]; then
    DEPLOY_BRANCH=$( echo ${BASH_REMATCH[0]} | tr '[:upper:]' '[:lower:]' )
# Deploy the "main" branch to Pantheon's "master" branch
elif [ "$BRANCH" = "main" ]; then
    DEPLOY_BRANCH="dev"
# Deploy the "staging" branch to Pantheon's "qa" branch.
elif [ "$BRANCH" = "staging" ]; then
    DEPLOY_BRANCH="qa"
# No reason to deploy any other branches, so exit early.
else
    echo "Not deploying, due to branch name format not matching."
    exit
fi

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

rsync --delete -a "${SRC_DIR}/" "${BUILD_DIR}" --exclude='.git/'

cd ${BUILD_DIR}/wp-content/themes/
# terminus auth:login --machine-token=${PANTHEON_MACHINE_KEY}
rsync -rlIpz --info=progress2 --temp-dir=~/tmp --delay-updates --ipv4 --exclude=.git -e 'ssh -o "StrictHostKeyChecking=no" -p 2222' './my-theme' 'dev.65401411-429a-476e-8dc8-4bd98e5d9164@appserver.dev.65401411-429a-476e-8dc8-4bd98e5d9164.drush.in:code/wp-content/themes'
# mkdir -p ~/.ssh/ && touch ~/.ssh/known_hosts
# echo "[appserver.dev.${PANTHEON_PROJECT_ID}.drush.in]:2222" > ~/.ssh/known_hosts
# ssh -tt -o StrictHostKeyChecking=no appserver.${DEPLOY_BRANCH}.${PANTHEON_PROJECT_ID}.drush.in
# terminus rsync ./my-theme ${PANTHEON_PROJECT_ID}.${DEPLOY_BRANCH}:code/wp-content/themes -- --info=progress2