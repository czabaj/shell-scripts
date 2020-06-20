#!/usr/bin/env bash

declare -r __usage="
Usage: $(basename $0) [OPTIONS]

Options:
  -l, --level <n>              Something something something level
  -n, --nnnnn <levels>         Something something something n
  -h, --help                   Something something something help
  -v, --version                Something something something version
"

while getopts "hdf:s:" opt; do
    case "$opt" in
    h)
        echo -e "$__usage"
        exit 0
        ;;
    d)  git_cat_file_format='%(objectsize:disk)'
        ;;
    f)  output_file=$OPTARG
        ;;
    s)  min_size=$(dehumanise $OPTARG)
        ;;
    *)
        echo -e "$__usage"
        exit 1
    esac
done

git fetch
git remote prune origin

echo "The following _local_ branches are fully merged and will be removed:"
git branch --merged $master | grep -v $master

read -p "Continue (y/n)? "
if [ "$REPLY" == "y" ]
then
    git branch --merged $master | grep -v $master | xargs git branch -d
fi

# Show remote fully merged branches
echo "The following _remote_ branches are fully merged and will be removed:"
git branch -r --merged $master | sed 's/ *origin\///' | grep -v $master

read -p "Continue (y/n)? "
if [ "$REPLY" == "y" ]
then
   # Remove remote fully merged branches
   git branch -r --merged $master | sed 's/ *origin\///' \
             | grep -v $master | xargs -I% git push origin :%
   echo "Done!"
   say "Obsolete branches are removed"
fi

echo "Please, tell your teammates to run 'git remote prune origin' command in order to clean their local repository"