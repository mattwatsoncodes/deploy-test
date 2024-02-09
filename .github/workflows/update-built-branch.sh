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


terminus auth:login --machine-token=${PANTHEON_MACHINE_KEY}
terminus rsync ./wp-content/themes/my-theme ${PANTHEON_PROJECT_ID}.dev:wp-content/themes/

rsync --delete -a "${SRC_DIR}/" "${BUILD_DIR}" --exclude='.git/'