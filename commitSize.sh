#!/usr/bin/env bash

function print_help {
    echo -e "Usage"
    echo -e "output to stdout: commitSize"
    echo -e "output to file: commitSize -f filename"
}

function humanise {
    echo -e $1 | awk '  function human(x) {
                            if (x<1000) {return x} else {x/=1024}
                            s="kMGTEPZY";
                            while (x>=1000 && length(s)>1)
                                {x/=1024; s=substr(s,2)}
                            return int(x+0.5) substr(s,1,1)
                        }
                        {print human($0)}'
}

function dehumanise {
    echo -e $1 | awk '/[0-9]$/{print $1;next};/[mM]$/{printf "%u\n", $1*(1024*1024);next};/[kK]$/{printf "%u\n", $1*1024;next}'
}

# see https://git-scm.com/docs/git-cat-file#_batch_output
git_cat_file_format='%(objectsize)'
min_size=0
output_file=''

while getopts "?hdf:s:" opt; do
    case "$opt" in
    h|\?)
        print_help
        exit 0
        ;;
    d)  git_cat_file_format='%(objectsize:disk)'
        ;;
    f)  output_file=$OPTARG
        ;;
    s)  min_size=$(dehumanise $OPTARG)
        ;;
    *)
        print_help
        exit 1
    esac
done

if [ ! -z "$output_file" ]; then
    echo '' > $output_file
fi

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
    size=$(git diff-tree -r -c -M -C --no-commit-id "$commit_sha" \
        | cut -d ' ' -f4 \
        | grep -v 0000000000000000000000000000000000000000 \
        | git cat-file --batch-check=$git_cat_file_format \
        | awk '{sum+=$1} END {print sum}')
    
	if [ ! -z "$size" ] && [ $size -gt $min_size ]; then
        humanSize=$(humanise $size)
        if [ -z  "$output_file" ]; then
            echo -e "$size\t$humanSize\t$commit"
        else
            echo -e "$size\t$humanSize\t$commit" >> $output_file
        fi
    fi
done
