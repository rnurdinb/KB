#!/bin/bash

SOURCE_TABLE="list_system.csv" # get list of system
SYSTEM_NAME=$(git log -1 --pretty=%B) # get which system from git commit
echo "Start to push back to $SYSTEM_NAME"

# Get REPO URL to push
OLDIFS=$IFS
IFS=',' # separate line with comma
[ ! -f $SOURCE_TABLE ] && { echo "$SOURCE_TABLE file not found"; exit 99; } # check if file is available

echo "Search $SYSTEM_NAME in table"
while read TARGET URL REPONAME KB BU CATEGORY PIC USERNAME BRANCH STATUS EMPTY  # will read $SOURCE_TABLE 
do
    if [ "$SYSTEM_NAME" = $TARGET  ] && [ $STATUS = "new"  ];
    then
      DEST_GITHUB_REPO=$URL
      REPO_NAME=$REPONAME
      KB_NAME=$KB
      BU_NAME=$BU
      CATEGORY_NAME=$CATEGORY
      DEST_GITHUB_USERNAME=$USERNAME
      PIC_SYSTEM=$PIC
      DEST_BRANCH=$BRANCH
      STATUS_MIGRATION=$STATUS
      break
    elif [ "$SYSTEM_NAME" = $TARGET  ] && [ $STATUS = "old"  ];
    then
      DEST_GITHUB_REPO=$URL
      REPO_NAME=$REPONAME
      KB_NAME=$KB
      DEST_GITHUB_USERNAME=$USERNAME
      PIC_SYSTEM=$PIC
      DEST_BRANCH=$BRANCH
      STATUS_MIGRATION=$STATUS
      break
    fi
done < $SOURCE_TABLE
IFS=$OLDIFS

if [ -z "$DEST_GITHUB_REPO" ]; # check if commit msg is empty
then
  echo "\"$SYSTEM_NAME\" not found in table"
  exit 1
fi 

CLONE_DIR=$(mktemp -d)
CUR_DIR=$(pwd)

# Setup git
echo "Setting Up Git with username $DEST_GITHUB_USERNAME and email $USER_EMAIL"
git config --global user.email "$USER_EMAIL"
git config --global user.name "$DEST_GITHUB_USERNAME"
git config --global pull.rebase false # Suppressing warning msg

# End of initiation
echo "\nList of your variable:"
echo "DEST_GITHUB_USERNAME = "$DEST_GITHUB_USERNAME
echo "USER_EMAIL = "$USER_EMAIL
echo "SYSTEM_NAME = "$SYSTEM_NAME

echo "DEST_GITHUB_REPO = "$DEST_GITHUB_REPO
echo "KB_NAME = "$KB
echo "REPO_NAME = "$REPO_NAME
echo "BU_NAME = " $BU
echo "CATEGORY = " $CATEGORY
echo "DEST_GITHUB_USERNAME = "$DEST_GITHUB_USERNAME
echo "PIC_SYSTEM = "$PIC_SYSTEM

echo "CLONE_DIR = "$CLONE_DIR
echo "CUR_DIR = "$CUR_DIR
echo "DEST_BRANCH = "$DEST_BRANCH

echo "Try to clone $DEST_GITHUB_REPO"
echo "$API_TOKEN_GITHUB"

# check if failed to clone branch docs (! is negation, so if command is error)
if ! git clone --single-branch -b docs "https://$API_TOKEN_GITHUB@$DEST_GITHUB_REPO.git" "$CLONE_DIR"
then
    echo "Because branch docs not found, then clone from $DEST_BRANCH"
    git clone --single-branch -b $DEST_BRANCH "https://$API_TOKEN_GITHUB@$DEST_GITHUB_REPO.git" "$CLONE_DIR"
    cd $CLONE_DIR && git checkout -b docs && cd $CUR_DIR
fi
cd $CLONE_DIR && git pull origin $DEST_BRANCH
cd $CUR_DIR

echo "Copying from $KB/$BU/$CATEGORY/doc-$SYSTEM_NAME/* to $CLONE_DIR/docs/"
if [ $STATUS = "new"  ];
then 
cp -R $KB/$BU/$CATEGORY/$SYSTEM_NAME/* $CLONE_DIR/docs/ || (rm -Rf "$CLONE_DIR" && exit 1)
# cp $KB/$BU/$CATEGORY/$SYSTEM_NAME/index.adoc $CLONE_DIR/readme.adoc || (rm -Rf "$CLONE_DIR" && exit 1)
elif [ $STATUS = "old"  ];
then 
cp -R $KB/$BU/$CATEGORY/$SYSTEM_NAME/* $CLONE_DIR/docs/ || (rm -Rf "$CLONE_DIR" && exit 1)
# cp $KB/$BU/$CATEGORY/$SYSTEM_NAME/docs.adoc $CLONE_DIR/readme.adoc || (rm -Rf "$CLONE_DIR" && exit 1)
fi
# cp $INITIATIVE_NAME/$SYSTEM_NAME/docs2.adoc $CLONE_DIR/test/readme2.adoc || (rm -Rf "$CLONE_DIR" && exit 1) jika ingin multiple, harus di sesuaikan


echo "Push to $DEST_GITHUB_USERNAME/$REPONAME in branch $INITIATIVE_NAME"
cd $CLONE_DIR || exit 1
git add .
git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
git push origin docs || (echo "push to $DEST_GITHUB_USERNAME/$REPONAME failed" && exit 1)



echo "Create Pull Request in $DEST_GITHUB_USERNAME/$REPONAME from docs to $DEST_BRANCH"
curl --location -s --request POST "https://api.github.com/repos/$DEST_GITHUB_USERNAME/$REPONAME/pulls" \
--header 'Authorization: token $API_TOKEN_GITHUB' \
--header 'Accept: application/vnd.github.v3+json' \
--header 'Content-Type: application/json' \
--data-raw "{
    \"title\": \"Change documentation by $PIC for $SYSTEM_NAME at $(date)\",
    \"head\": \"docs\",
    \"base\": \"$DEST_BRANCH\"
}" || (echo "Creating pull request failed" && exit 1)

echo "Done, thank you"
