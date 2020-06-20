#!/usr/bin/env bash

function humanise {
    local size_in_bytes=$1
    echo -e $size_in_bytes | awk '
function human(x) {
    if (x<1000) {return x} else {x/=1024}
    s="kMGTEPZY";
    while (x>=1000 && length(s)>1)
        {x/=1024; s=substr(s,2)}
    return int(x+0.5) substr(s,1,1)
}
{print human($0); exit}
'
}

function dehumanise {
    local human_deadable_size=$1
    echo -e $human_deadable_size | awk '
/[0-9][bB]?$/ {print $1 ;next}
/[0-9][kK]$/  {printf "%u\n", $1*1024; next}
/[0-9][mM]$/  {printf "%u\n", $1*(1024*1024); next}
/[0-9][gG]$/  {printf "%u\n", $1*(1024*1024*1024); next}
'
}


# https://stackoverflow.com/a/51911626/2508019
declare -r __usage="
Print size of all commits in GIT history.
Useful to find commit which increases your git repo size.

Output is printed as fields separated by tabulator:

    size_in_bytes human_readable_size commit_sha commit_message

Usage: $(basename $0) [OPTIONS]

    By default outputs to stdout

Options:
  -h,   Print usage
  -d,   Print size of packed objects on disk
        see https://git-scm.com/docs/git-cat-file#Documentation/git-cat-file.txt-codeobjectsizediskcode
  -f,   Print output to file

            $(basename $0) -f fileName

  -s,   Print only commits increasing given size limit

            $(basename $0) -s 10m
"

git_cat_file_format='%(objectsize)'
declare -i min_size=0
output_file=''

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

if [ ! -z "$output_file" ]; then
    echo '' > $output_file
fi

function commit_size {
    local commit_sha=$1
    git diff-tree -r -c -M -C --no-commit-id "$commit_sha" \
        | cut -d ' ' -f4 \
        | grep -v 0000000000000000000000000000000000000000 \
        | git cat-file --batch-check=$git_cat_file_format \
        | awk '{sum+=$1} END {print sum}'
}

# this is sometimes needed, is restored in the end
orig_diff_rename_limit=$(git config diff.renameLimit)
git config diff.renameLimit 999999
function reset_renameLimit {
    if [ -z $orig_diff_rename_limit ]; then
        git config --unset diff.renameLimit
    else
        git config diff.renameLimit $orig_diff_rename_limit
    fi
}
trap 'reset_renameLimit' 0 1 2 3 6 15 


git rev-list --all --pretty=oneline | while read -r commit; do
    commit_sha=$(echo $commit | cut -d ' ' -f1)
    commit_message=${commit:${#commit_sha} + 1}
    size=$(commit_size $commit_sha)
    
	if [ ! -z "$size" ] && [ $size -gt $min_size ]; then
        humanSize=$(humanise $size)
        output="$size\t$humanSize\t$commit_sha\t$commit_message"
        [ -z  "$output_file" ] && echo -e $output || echo -e $output >> $output_file
    fi
done
