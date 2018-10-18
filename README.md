# zfsbackup: work in progress for a complete Wake-on-Lan, GEOM ELI attach crypted disks and zfs send & receive increments.

### wake_amd.sh

wakes up the remote machine and when ssh is up the script then creates a onetime only geli encrypted memorybacked fs and transfers the disk keys and the prompted passphrase over. Once the disks are attached the keys and the passphrase is destroyed by unmounting the memfs and then detaching the geli and then destroying the memorydisk.


### ping_fantti.expect 

loops ping test until target host responds. Then loops spawn ssh to same host until ssh responds. This expect script probably is not needed because this looping can be done in sh too

### zfssnap.sh

first iteration of how to zfs send and receive snapshots. is doing it recursively for the whole pool dataset which is not ideal in all cases. should change it to check each snapshot existance on the remote and send&receive the increments or new datasets individually instead.

