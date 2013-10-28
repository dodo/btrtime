#!/usr/bin/env bash

STUB_CONFIG=true # remove this line when you're done with this config


# space separated list of devices to backup the GPT partion table from
PARTITION_TABLES="/dev/disk/by-id/ata-FOO /dev/disk/by-id/scsi-BAR"

# space separated list of devices to backup the LUKS header from
LUKS_HEADERS="/dev/disk/by-uuid/01234567-89ab-cdef-0123-456789abcdef /dev/disk/by-uuid/fedcba987654-3210-fedc-ba98-76543210"

# space separated list of devices to backup the MBR header from
MBR_HEADERS="/dev/disk/by-uuid/01234567-89ab-cdef-0123-456789abcdef /dev/disk/by-uuid/fedcba987654-3210-fedc-ba98-76543210"

# list of entry points for rsync
ENTRIES="/home/user/"

# toggles if we need to scrub the btrfs after backup
SCRUB=true
