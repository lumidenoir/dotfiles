#!/usr/bin/env bash
# QuickShell Device & Storage Opener
# Handles:
# 1. USB Storage block devices (/dev/sdX1) -> mounts via udisksctl and opens in Thunar
# 2. Mobile phones (--phone [URI/DEV] [NAME]) -> opens MTP in Thunar or opens KDE Connect

MODE="$1"

if [[ "$MODE" == "--phone" ]]; then
    DEV="$2"
    NAME="$3"

    # 1. Direct MTP URI
    if [[ "$DEV" == mtp://* ]]; then
        gio mount "$DEV" 2>/dev/null
        thunar "$DEV" &
        exit 0
    fi

    # 2. Check for active GVFS MTP mount points
    GVFS_DIR="/run/user/$(id -u)/gvfs"
    if [[ -d "$GVFS_DIR" ]]; then
        MTP_MOUNT=$(find "$GVFS_DIR" -maxdepth 1 -name "mtp:*" 2>/dev/null | head -n1)
        if [[ -n "$MTP_MOUNT" && -d "$MTP_MOUNT" ]]; then
            thunar "$MTP_MOUNT" &
            exit 0
        fi
    fi

    # 3. Check for KDE Connect application
    if command -v kdeconnect-app >/dev/null 2>&1; then
        kdeconnect-app &
        exit 0
    elif command -v kdeconnect-settings >/dev/null 2>&1; then
        kdeconnect-settings &
        exit 0
    fi

    # Fallback to file manager
    thunar &
    exit 0
fi

# ─── USB Block Device Mode ───────────────────────────────────────────────────
TARGET_DEV="$1"

if [[ -z "$TARGET_DEV" ]]; then
    thunar &
    exit 0
fi

# Check if target block device is already mounted
MOUNT_POINT=$(findmnt -n -o TARGET "$TARGET_DEV" 2>/dev/null)

if [[ -z "$MOUNT_POINT" ]]; then
    # Attempt to mount via UDisks2
    MOUNT_OUTPUT=$(udisksctl mount -b "$TARGET_DEV" 2>/dev/null)
    MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -oP '(?<=at )/.*' | head -n1)
fi

if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    thunar "$MOUNT_POINT" &
else
    # Fallback to general Thunar view
    thunar &
fi
