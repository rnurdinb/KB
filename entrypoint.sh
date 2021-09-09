#!/bin/bash

# Variable
if [ -z "$API_TOKEN_GITHUB" ]; # check if commit msg is empty
then
  echo "Secret API_TOKEN_GITHUB not found in this repo. Please add it first"
  exit 1
fi 

echo "\nList of your variable:"
echo "DEST_GITHUB_USERNAME: $DEST_GITHUB_USERNAME"
echo "DEST_REPO_NAME: $DEST_REPO_NAME"
echo "USER_EMAIL: $USER_EMAIL"
echo "PUSH_TO_BRANCH: $PUSH_TO_BRANCH"
echo "PR_TO_BRANCH: $PR_TO_BRANCH"
DEST_GITHUB_REPO="github.com/$DEST_GITHUB_USERNAME/$DEST_REPO_NAME"
echo "DEST_GITHUB_REPO: $DEST_GITHUB_REPO"

CLONE_DIR=$(mktemp -d)
CUR_DIR=$(pwd)
echo "CLONE_DIR: $CLONE_DIR"
echo "CUR_DIR: $CUR_DIR"
echo "SRC_DIR: $SRC_DIR"
echo "DEST_DIR: $DEST_DIR"
echo "PR_MESSAGE: $PR_MESSAGE"

echo "===================\n\n"

# Setup git
echo "Setting Up Git with username $DEST_GITHUB_USERNAME and email $USER_EMAIL"
git config --global user.email "$USER_EMAIL"
git config --global user.name "$DEST_GITHUB_USERNAME"
git config --global pull.rebase false # Suppressing warning msg

echo "Preparing your system"

echo "Try to clone $DEST_REPO_NAME"
# check if failed to clone branch $PUSH_TO_BRANCH (! is negation, so if command is error)
if ! git clone --single-branch -b $PUSH_TO_BRANCH "https://$API_TOKEN_GITHUB@$DEST_GITHUB_REPO.git" "$CLONE_DIR"
then
    echo "Because branch $PUSH_TO_BRANCH not found, then clone from $PR_TO_BRANCH"
    git clone --single-branch -b $PR_TO_BRANCH "https://$API_TOKEN_GITHUB@$DEST_GITHUB_REPO.git" "$CLONE_DIR"
    cd $CLONE_DIR && git checkout -b $PUSH_TO_BRANCH && cd $CUR_DIR
fi
cd $CLONE_DIR && git pull origin $PR_TO_BRANCH
cd $CUR_DIR

# Flexible copy mechanism
echo "Copying from $SRC_DIR to $CLONE_DIR/$DEST_DIR"
mkdir -p "$CLONE_DIR/$DEST_DIR"
if ! cp -R $SRC_DIR "$CLONE_DIR/$DEST_DIR" ; then
    echo "Error copying $SRC_DIR to $CLONE_DIR/$DEST_DIR"
    rm -Rf "$CLONE_DIR"
    exit 1
fi

# Rename file or folder if exist
if [ ! -z "$RENAME" ]; # check if rename variable is not empty
then
    # Convert string to array
    OLDIFS=$IFS
    IFS=' ' read -r -a RENAME_ARRAY <<< "$RENAME"
    
    # Do rename
    echo "Try to rename ${#RENAME_ARRAY[@]} file(s) or folder(s)"
    IFS=',' # separate line with comma
    for i in ${!RENAME_ARRAY[@]};
    do
        read source target <<< "${RENAME_ARRAY[$i]}"
        echo "rename $CLONE_DIR/$DEST_DIR/$source to $CLONE_DIR/$DEST_DIR/$target"
        mv $CLONE_DIR/$DEST_DIR/$source $CLONE_DIR/$DEST_DIR/$target
    done
    IFS=$OLDIFS
fi

echo "Push to $DEST_GITHUB_USERNAME/$DEST_REPO_NAME in branch $PUSH_TO_BRANCH"
cd "$CLONE_DIR"
git add .
git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
if ! git push origin "$PUSH_TO_BRANCH" ; then
    echo "push to $DEST_GITHUB_USERNAME/$DEST_REPO_NAME failed"
    exit 1
fi

echo "Create Pull Request"
if ! curl --location -s --request POST "https://api.github.com/repos/$DEST_GITHUB_USERNAME/$DEST_REPO_NAME/pulls" \
--header "Authorization: token $API_TOKEN_GITHUB" \
--header 'Accept: application/vnd.github.v3+json' \
--header 'Content-Type: application/json' \
--data-raw "{
    \"title\": \"$PR_MESSAGE at $(date)\",
    \"head\": \"$PUSH_TO_BRANCH\",
    \"base\": \"$PR_TO_BRANCH\"
}" ; then
    echo "Creating pull request failed"
    exit 1
fi

echo "Done, thank you"
