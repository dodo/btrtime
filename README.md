
# [btrtime](#readme)

Time Machine with Btrfs

### usage

```bash
dd if=/dev/urandom of=/home/user/.secret/backup.key bs=1024 count=4
chmod 0600 /home/user/.secret/backup.key
cryptsetup luksAddKey /dev/disk/by-uuid/01234567-89ab-cdef-0123-456789abcdef /home/user/.secret/backup.key
su
echo "backup /dev/disk/by-uuid/01234567-89ab-cdef-0123-456789abcdef /home/user/.secret/backup.key noauto,luks,tries=3" >> /etc/crypttab
echo "/dev/mapper/backup /backup btrfs noauto,noatime,compress=lzo 0 0" >> /etc/fstab
mkdir /backup
```

```bash
git clone git://github.com/dodo/btrtime.git && cd btrtime
ln -s .backup.script `hostname`
su
cryptdisks_start backup
mount /backup
./$(hostname)
vim /backup/backup/$(hostname)/config
vim /backup/backup/$(hostname)/ignore
./$(hostname) # repeat
```

```
/backup/
└── backup
    ├── $(hostname)
    │   ├── 01234567-89ab-cdef-0123-456789abcdef.luks
    │   ├── fedcba987654-3210-fedc-ba98-76543210.gpt
    │   ├── config
    │   └── ignore
    └── shared
        ├── 2013-10-22T07-15-19
        ├── 2013-10-22T07-15-19.log
        ├── 2013-10-22T07-15-24
        ├── 2013-10-22T07-15-24.log
        ├── 2013-10-22T07-15-25
        └── 2013-10-22T07-15-25.log
```

### dependencies

    btrfs-tools
    rsync
    gdisk
    cryptsetup
    
    
    
    

