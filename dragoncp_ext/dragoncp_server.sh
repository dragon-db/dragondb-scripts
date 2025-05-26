#!/bin/bash

# DragonCP Server Handler - rsync operations handler
# This script runs on the server VM and handles rsync operations initiated by the client

# Function to perform rsync operation
perform_rsync() {
    local source_path="$1"
    local destination_path="$2"
    local client_ip="$3"
    local client_user="$4"
    local client_port="$5"

    # There is some kown issues with backup_path
    # on test runs this is using the directory in client VM not server VM for backup
    local BACKUP_PATH="<backup_path_in_client_vm>"
    
    echo ">SERVER-RECEIVED<============================="
    
    # Debug logging for received arguments
    echo "DEBUG: Received arguments for transfer_folder:"
    echo "DEBUG: source_path: '$source_path'"
    echo "DEBUG: destination_path: '$destination_path'"
    echo "DEBUG: client_ip: '$client_ip'"
    echo "DEBUG: client_user: '$client_user'"
    echo "DEBUG: client_port: '$client_port'"
    
    echo ">SERVER-RECEIVED<============================="
    
    # Check if arguments are provided
    if [ -z "$source_path" ] || [ -z "$destination_path" ] || [ -z "$client_ip" ] || [ -z "$client_user" ] || [ -z "$client_port" ]; then
        echo "Error: All arguments are required"
        echo "DEBUG: Missing arguments:"
        [ -z "$source_path" ] && echo "DEBUG: - source_path is empty"
        [ -z "$destination_path" ] && echo "DEBUG: - destination_path is empty"
        [ -z "$client_ip" ] && echo "DEBUG: - client_ip is empty"
        [ -z "$client_user" ] && echo "DEBUG: - client_user is empty"
        [ -z "$client_port" ] && echo "DEBUG: - client_port is empty"
        return 1
    fi
    
    # Extract the folder name from the source path
    base_folder_name=$(basename "$source_path")
    full_destination="$destination_path/$base_folder_name"
    
    echo "Syncing from: $source_path/"
    echo "Syncing to: $client_user@$client_ip:$full_destination/"
    echo ">SERVER-RSYNC<============================="
    
    # Optimized rsync command for large media files (MKV/MP4)
    # Using --protect-args to handle paths with spaces and special characters
    rsync -av \
    --progress \
    --protect-args \
    -e "ssh -o StrictHostKeyChecking=no -o Compression=no -o Ciphers=chacha20-poly1305@openssh.com -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -p $client_port" \
    --delete \
    --backup \
    --backup-dir="$BACKUP_PATH" \
    --update \
    --exclude '.*' \
    --exclude '*.tmp' \
    --exclude '*.log' \
    --stats \
    --human-readable \
    --bwlimit=20000 \
    --block-size=65536 \
    --no-compress \
    --partial \
    --partial-dir="$BACKUP_PATH/.rsync-partial" \
    --timeout=300 \
    --size-only \
    --no-perms \
    --no-owner \
    --no-group \
    --no-checksum \
    --whole-file \
    --preallocate \
    --no-motd \
    "$source_path/" "$client_user@$client_ip:$full_destination/"
    
    status=$?
    if [ $status -eq 0 ]; then
        echo "Transfer completed successfully!"
        echo "Files synced to: $full_destination"
        return 0
    else
        echo "Transfer failed with status: $status"
        return 1
    fi
}

# Function to sync single episode
sync_single_episode() {
    local source_path="$1"
    local destination_path="$2"
    local source_file="$3"
    local client_ip="$4"
    local client_user="$5"
    local client_port="$6"
    
    # Debug logging for received arguments
    echo "DEBUG: Received arguments for sync_episode:"
    echo "DEBUG: source_path: '$source_path'"
    echo "DEBUG: destination_path: '$destination_path'"
    echo "DEBUG: source_file: '$source_file'"
    echo "DEBUG: client_ip: '$client_ip'"
    echo "DEBUG: client_user: '$client_user'"
    echo "DEBUG: client_port: '$client_port'"
    
    # Check if arguments are provided
    if [ -z "$source_path" ] || [ -z "$destination_path" ] || [ -z "$source_file" ] || [ -z "$client_ip" ] || [ -z "$client_user" ] || [ -z "$client_port" ]; then
        echo "Error: All arguments are required"
        echo "DEBUG: Missing arguments:"
        [ -z "$source_path" ] && echo "DEBUG: - source_path is empty"
        [ -z "$destination_path" ] && echo "DEBUG: - destination_path is empty"
        [ -z "$source_file" ] && echo "DEBUG: - source_file is empty"
        [ -z "$client_ip" ] && echo "DEBUG: - client_ip is empty"
        [ -z "$client_user" ] && echo "DEBUG: - client_user is empty"
        [ -z "$client_port" ] && echo "DEBUG: - client_port is empty"
        return 1
    fi
    
    echo "Syncing episode: $source_file"
    echo "From: $source_path"
    echo "To: $client_user@$client_ip:$destination_path"
    echo ">RSYNC<============================="
    
    rsync -avz \
    --progress \
    --protect-args \
    -e "ssh -o StrictHostKeyChecking=no -p $client_port" \
    --backup \
    --backup-dir="$BACKUP_PATH" \
    --exclude '.*' \
    --exclude '*.tmp' \
    --exclude '*.log' \
    --exclude '/var/tmp/**' \
    --exclude '/tmp/**' \
    --exclude '/proc/**' \
    --exclude '/sys/**' \
    --exclude '/dev/**' \
    --exclude '/run/**' \
    --exclude '/var/run/**' \
    --exclude '/var/lock/**' \
    --exclude '/var/cache/**' \
    --exclude '/var/lib/**' \
    --exclude '/var/log/**' \
    --exclude '/var/spool/**' \
    --exclude '/var/state/**' \
    --exclude '/var/backups/**' \
    --exclude '/var/local/**' \
    --exclude '/var/opt/**' \
    --exclude '/var/mail/**' \
    --exclude '/var/www/**' \
    --exclude '/var/games/**' \
    --exclude '/var/lib/systemd/**' \
    --exclude '/var/lib/dpkg/**' \
    --exclude '/var/lib/apt/**' \
    --exclude '/var/lib/snapd/**' \
    --exclude '/var/lib/NetworkManager/**' \
    --exclude '/var/lib/upower/**' \
    --exclude '/var/lib/systemd-private-*/**' \
    "$source_path/$source_file" "$client_user@$client_ip:$destination_path/"
    
    status=$?
    if [ $status -eq 0 ]; then
        echo "Episode transfer completed successfully!"
        return 0
    else
        echo "Episode transfer failed with status: $status"
        return 1
    fi
}

# Main script logic
case "$1" in
    "transfer_folder")
        perform_rsync "$2" "$3" "$4" "$5" "$6"
        ;;
    "sync_episode")
        sync_single_episode "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    *)
        echo "Invalid command"
        echo "DEBUG: Received command: '$1'"
        echo "DEBUG: All arguments: $@"
        exit 1
        ;;
esac 