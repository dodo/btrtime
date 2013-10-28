#!/usr/bin/env bash
# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# default config
STUB_CONFIG=false
PARTITION_TABLES=""
LUKS_HEADERS=""
MBR_HEADERS=""
ENTRIES=""
SCRUB=false
# get env
MNT=/tmp/backup
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

# allow secure tmp space
mkdir -p $TMP
mount -t ramfs ramfs $TMP
chown root:root $TMP
chmod 0600 $TMP


if [[ "x$PARTITION_TABLES" != "x" ]]; then
    echo "backup partion table …"
    # TODO support other partion table formats
    for dev in $PARTITION_TABLES; do
        if [ -L $dev ]; then
            sgdisk --backup="$TMP/gpt" $dev
            rsync -au "$TMP/gpt" "$PWD/$HOST/$(basename $dev).gpt"
            rm "$TMP/gpt"
        else
            echo "device $dev doesn't exist!"
        fi
    done
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

if [[ "x$MBR_HEADERS" != "x" ]]; then
    echo "backup mbr header …"
    for dev in $MBR_HEADERS; do
        if [ -L $dev ]; then
            dd if=$dev of="$TMP/mbr" bs=512 count=1
            rsync -au "$TMP/mbr" "$PWD/$HOST/$(basename $dev).mbr"
            rm "$TMP/mbr"
        else
            echo "device $dev doesn't exist!"
        fi
    done
fi

umount $TMP
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

