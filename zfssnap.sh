#!/bin/sh
#
# description: automatic zfs snapshot and *zfs send | mbuffer -> mbuffer | zfs recv* the increments
#
# prequisites: ssh-key auth and zfs allow -u user the rights to receive into remote dataset (RDSET)
#
# tissues:
#          - remote mbuffer processes stay alive if this spaghetti is run on an user on sending machine
#            that does not have rights to send the datasets
#
#          - LATEST_SNAP likely is not checked correctly in "if [ "$LATEST_SNAP" == NULL ];"
#          
# todo:
#         - send all stdout to null and stderr somewhere else
#
#

# config start
RDSET="backup"              # backup server dataset path for backups
HOST="tardis"                      # name of the dataset in backup dataset
RECV_PORT="9090"                    # unique for each host
SSH_ID="/home/ruupert/.ssh/fantti_rsa" #
SSH_USER="ruupert"
SSH_HOST="10.0.13.5"
POOLS="storage"                       # space separated values for each pool to be backed up
# config end

# checks if required commands are available
cmds_exists() {
    exit=0;
    for cmd in "$@"; do
        loc=$( command -v $cmd )  # standard posix

        if [ "$loc" == ''  ]; then
            echo "command not found! ($cmd)"
            exit=1;
        else
            # echo "cmd found : $cmd"   # no need to print
        fi
    done
    if [ $exit -eq 1 ]; then
        exit 1
    fi
}
cmds_exists zfs zpool ssh date grep printf awk ssh echo sleep sort mbuffer head rm cat xargs mktemp basename

remote_cmds_exists() {
    exit=0;
    for cmd in "$@"; do
        loc=$(  ssh -i $SSH_ID $SSH_USER@$SSH_HOST "command -v $cmd" )

        if [ "$loc" == ''  ]; then
            echo "remote command not found! ($cmd)"
            exit=1;
        else
            # echo "remote cmd found : $cmd"   # no need to print
        fi
    done
    if [ $exit -eq 1 ]; then
        exit 1
    fi
}
remote_cmds_exists zfs mbuffer

# Uncomment following if all pools are to be backed up
# POOLS=$( zpool list -H -o name |xargs )

# Non configurable constants
SNAP_DATE=$( date +"%Y%m%d%H" )     # current rolling number yyyyddmm
LATEST_SNAP=$( ssh -i $SSH_ID $SSH_USER@$SSH_HOST 'zfs list -H -o name -t snap' )
temp=`basename $0`
TMPFILE=`mktemp -q /tmp/${temp}.XXXXXX`
if [ $? -ne 0 ]; then
    echo "$0: Can't create temp file"
    exit 1
fi

for line in $LATEST_SNAP; do
    printf "$line\n"| grep $RDSET/$HOST|awk -F "@" '{print $2}' >> $TMPFILE;
done;

LSNAP=$( cat $TMPFILE | sort -nur|head -n 1 )
rm $TMPFILE

previous_snap() {
    if [ "$1" == "" ]; then  
	return 1
    else
	return 0
    fi
    

}

if [ "$LSNAP" == NULL ]; then
NO_PRV_SNAP=1;
else

NO_PRV_SNAP=0;
fi

echo "";
echo $NO_PRV_SNAP;
echo "no_prv_snap=$NO_PRV_SNAP";

zfs_send_recv() {
    printf $POOLS
    for pool in $POOLS; do
        zfs snapshot -r $pool@$SNAP_DATE
        ssh -i $SSH_ID $SSH_USER@$SSH_HOST "sudo mbuffer -4 -s 128k -m 512M -I $RECV_PORT | sudo zfs receive -F $RDSET/$HOST/$pool" &>/dev/null
        sleep 4;
#        if [ $1 -eq 1 ]; then
#        sleep 4;
#            zfs send -R $pool@$SNAP_DATE| mbuffer -s 128k -m 512M -O $SSH_HOST:$RECV_PORT
#        elif [ $1 -eq 0 ]; then
	echo "$pool@$LSNAP - $pool@$SNAP_DATE"
        zfs send -R -I $pool@$LSNAP $pool@$SNAP_DATE | mbuffer -s 128k -m 512M -O $SSH_HOST:$RECV_PORT
#        fi
   done;
}

if [ "$NO_PRV_SNAP" == "1" ]; then
    echo "no prvious snap";
#       zfs_send_recv 1
else
    echo "previous snap exists";
    # this following function in this case should send snapshots that dont exist
    # at the remote with the zfs_send_recv 0 method instead.
    zfs_send_recv 0
fi
