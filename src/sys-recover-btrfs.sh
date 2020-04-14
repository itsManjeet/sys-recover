#!/bin/sh

source /usr/lib/rsb/io.sh

tmp_file=$(mktemp block_file.XXXXXXXXXX)
# check root permission
CheckRooot

if [ -z $1 ] ; then
    err "please specify file or folder location from the root location of your disk or simply regex pattern"
    exit 5
fi


function genPathRegex {
    if [ -z $REGEX_PATTERN ] ; then
        REGEX_PATTERN="^/(|$(echo $1 | tr '/' ' ' | awk '${print $1}')"
        regex_count=1
        for i in $(echo $1 | tr '/' ' ' | cut -d ' ' -f2-) ; do
            $((regex_count=regex_count+1))
            REGEX_PATTERN="'$REGEX_PATTERN(|/$i"
        done

        REGEX_PATTERN="$REGEX_PATTERN(|/.*)"
        for i in {0..$regex_count} ; do
            REGEX_PATTERN="$REGEX_PATTERN)"
        done

        REGEX_PATTERN="$REGEX_PATTERN\$'"

    fi
}

if ! which btrfs &>/dev/null ; do
    err "unable to find btrfs toolkit, please install btrfs-progs"
    err "use command - 'sys-app in btrfs-progs'"
    exit 5
fi


btrfs_parts=$(lsblk -o "name,fstype" | grep "btrfs" | awk '{print $1}')
search_count=0

echo $REGEX_PATTERN
for i in $btrfs_parts ; do
    search_count=$((search_count+1))
    Process "generating well block number list"
    btrfs-find-root $i &> $tmp_file
    Check $?

    block_count=0
    for j in $(cat $tmp_file | grep 'Well block [0-9]*' | awk '{print $3}') ; do
        block_count=$((block_count+1))
        process "hit and trial for searching in block $j of $i"
        btrfs restore $i $PWD -vi -t $j -D
        Check $?

        Confirm "Do you find out the complete path for your file or folder [Y|N]" "ok then trying in more oldder block" || continue

        success "ok then, trying to restore file from block $j of $i"
        btrfs restore $i $PWD -vi -t $j --path-regex $REGEX_PATTERN
        success "i done from my side, check if your file is in our current directory"
    done
done