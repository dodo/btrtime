#!/usr/bin/env bash
# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# default config
STUB_CONFIG=false
LUKS_HEADERS=""
MBR_TABLES=""
GPT_TABLES=""
ENTRIES=""
SCRUB=false
# get env
MNT=/backup
TRG="shared"
TMP="$MNT/tmp"
PWD="$MNT/backup"
CWD="$PWD/$TRG"
HOST=`basename $0`
NAME=`date --utc +'%Y-%m-%dT%H-%M-%S'`
LOG="$CWD/$NAME.log"

mkdir -p $CWD
mkdir -p "$PWD/$HOST"
touch "$PWD/$HOST/ignore"
if [ -f "$PWD/$HOST/config" ]; then

    # allow secure tmp space
    mkdir -p $TMP
    mount -t ramfs ramfs $TMP
    chown root:root $TMP
    chmod 0600 $TMP
    # mount to $TMP/$FOO is now available in configs

    # load config
    . "$PWD/$HOST/config"

else
    cp "$(dirname $0)/.default.config.sh" "$PWD/$HOST/config"
    echo "Need a config!  Please edit $PWD/$HOST/config first."
    echo "rsync exclude file is at $PWD/$HOST/ignore"
    exit 23
fi

if $STUB_CONFIG; then
    echo "Need a config!  Please edit $PWD/$HOST/config properly."

    # umount $TMP and all mountpoints that the config might created
    for mnt in $(mount | cut -d" " -f3 | egrep "^$TMP" | sort --reverse); do
        umount $mnt
    done
    rmdir --ignore-fail-on-non-empty $TMP

    exit 13
fi


OLD=`find "$CWD" -mindepth 1 -maxdepth 1 -type d | sort | tail -n1`
#TMPLOG="/tmp/`basename $OLD`-deleted"
#OLDHOSTLOGS=`grep -H $HOST"$CWD/*.log" | sed 's/:.*$//' | sort --uniq`
if [[ "x$OLD" != "x" ]]; then
    diff=$(($(date -u -d`echo "$NAME" | sed 's/-/:/3g'` +"%s") - $(date -u -d`basename $OLD | sed 's/-/:/3g'` +"%s")))
fi

# pipe stdout & stderr into log file
touch $LOG
exec >  >(tee -a $LOG)
exec 2> >(tee -a $LOG >&2)

if [[ "x$OLD" = "x" ]]; then
    echo "initializing $HOST backup …"
    btrfs subvolume create "$CWD/$NAME"
else
    echo "$(($diff / 86400)) days, $((($diff / 3600) % 24)) hours, $((($diff / 60) % 60)) minutes and $(($diff % 60)) seconds since last backup."
    echo "start $HOST backup …"
    btrfs subvolume snapshot "$OLD" "$CWD/$NAME"
fi


if [[ "x$LUKS_HEADERS" != "x" ]]; then
    echo "backup luks header …"
    for dev in $LUKS_HEADERS; do
        if [ -L $dev ]; then
            cryptsetup luksHeaderBackup $dev --header-backup-file="$TMP/luks"
            rsync -au "$TMP/luks" "$PWD/$HOST/$(basename $dev).luks"
            rm "$TMP/luks"
        else
            echo "device $dev doesn't exist!"
        fi
    done
fi

if [[ "x$MBR_TABLES" != "x" ]]; then
    echo "backup mbr partition table …"
    for dev in $MBR_TABLES; do
        if [ -L $dev ]; then
            dd if=$dev of="$TMP/mbr" bs=512 count=1
            rsync -au "$TMP/mbr" "$PWD/$HOST/$(basename $dev).mbr"
            rm "$TMP/mbr"
        else
            echo "device $dev doesn't exist!"
        fi
    done
fi

if [[ "x$GPT_TABLES" != "x" ]]; then
    echo "backup gpt partition table …"
    for dev in $GPT_TABLES; do
        if [ -L $dev ]; then
            sgdisk --backup="$TMP/gpt" $dev
            rsync -au "$TMP/gpt" "$PWD/$HOST/$(basename $dev).gpt"
            rm "$TMP/gpt"
        else
            echo "device $dev doesn't exist!"
        fi
    done
fi

# umount $TMP and all mountpoints that the config might created
for mnt in $(mount | cut -d" " -f3 | egrep "^$TMP" | sort --reverse); do
    umount $mnt
done
rmdir --ignore-fail-on-non-empty $TMP

# get previously deleted files
#cat "${OLD}.log" | sed -ne '/^start sync/,/^sync done/p' | egrep '^deleting ' | sed -e 's/deleting /\//' > $TMPLOG

if [[ "x$ENTRIES" != "x" ]]; then
    echo "start sync …"
    for entry in $ENTRIES; do
        rsync -vauXS --delete --exclude-from="$PWD/$HOST/ignore" $entry "$CWD/$NAME/$entry"
    done
    echo "sync done."
else
    echo "no entries specified; nothing to do."
fi

if $SCRUB; then
    echo "$HOST backup done. now scrubbing …"
    btrfs scrub start -B "$CWD/$NAME"
fi

echo "done."

