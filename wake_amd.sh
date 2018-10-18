#!/bin/sh
# wake and wait for ssh to be ready
wake bge0 XX:XX:XX:XX:XX:XX
expect /root/bin/ping_fantti.expect

stty -echo; read -p "GELI passphrase: " PWORD; stty echo;

ssh_cmd() {
    ssh -i /root/.ssh/fantti_rsa ruupert@10.0.0.15 "$@"
}

echo "Creating memory filesystem."
ssh_cmd sudo mdconfig -s 5m -u md10
ssh_cmd sudo geli onetime /dev/md10
ssh_cmd sudo newfs -U /dev/md10.eli
ssh_cmd sudo mount /dev/md10.eli /memfs
ssh_cmd sudo chmod g+w /memfs
ssh_cmd sudo chmod o-rwx /memfs

MOUNT=$( ssh_cmd mount | grep md10.eli | awk '{print $1$3}' )

if [ "$MOUNT" != "/dev/md10.eli/memfs" ]; then
    echo "memfs not correctly created";
    exit 1;
fi


echo "Transferring geli keys and pfile."
scp -r -i /root/.ssh/fantti_rsa /root/fantti_geli ruupert@10.0.0.15:/memfs
ssh -i /root/.ssh/fantti_rsa ruupert@10.0.0.15 "sudo echo $PWORD > /memfs/pfile"

unset PWORD

geli_attach() {
    for DISK in "$@"; do
        echo "Attaching $DISK"
	ssh_cmd "sudo geli attach -k /memfs/fantti_geli/$DISK.key -j /memfs/pfile /dev/$DISK"
    done;

};

geli_attach ada1 ada2 ada3 da0 da1 da2 da3 da4 da5 da6

echo "Done"

echo "Removing memory filesystem."
ssh_cmd sudo umount /memfs
ssh_cmd sudo geli detach /dev/md10.eli
ssh_cmd sudo mdconfig -d -u 10

echo ""
 
STATUS=$( ssh_cmd "zpool list backup|tail -n 1"|awk '{print $10}' )

if [ "$STATUS" == "ONLINE" ]; then
    echo "storage pool is ONLINE"
    # we can zfs send
else
    echo "something went wrong"
    
fi

