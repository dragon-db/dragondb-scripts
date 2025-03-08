#!/bin/bash

# DragonCP - Manual Sync Script by Dragon DB v1.0
# This script facilitates the transfer of media files from a Remote VM to a local machine.
# It allows users to:
# 1. List and select media types (Movies, TV Shows, Anime).
# 2. Browse through folders of selected media types.
# 3. Transfer selected folders or seasons to a specified local destination.
# 4. Handle directory creation and provide feedback on transfer status.
# Ensure that the environment variables for paths and SSH credentials are set in 'dragoncp_env.env'.

# Load the env file
if [ -r "dragoncp_env.env" ]; then
    source dragoncp_env.env
else
    echo "Error: dragoncp_env.env file not found or not readable." >&2  # Redirect to stderr
    exit 1
fi

# Function to list folders in the specified path on the Debian VM
list_folders() {
    ssh "$DEBIAN_USER@$DEBIAN_IP" "find \"$1\" -mindepth 1 -maxdepth 1 -type d -exec basename '{}' \;" 2>/dev/null
}

transfer_folder() {
    source_path="$1"
    destination_path="$2"
    
    # Check if arguments are provided
    if [ -z "$source_path" ] || [ -z "$destination_path" ]; then
        echo "Error: Source and destination paths are required"
        return 1
    fi
    
    # Extract the folder name from the source path
    base_folder_name=$(basename "$source_path")
    full_destination="$destination_path/$base_folder_name"
    
    # Create destination directory if it doesn't exist
    if [ ! -d "$full_destination" ]; then
        echo "Creating directory: $full_destination"
        mkdir -p "$full_destination"
    else
        echo "Directory already exists: $full_destination"
    fi
    
    echo "Syncing from: $DEBIAN_USER@$DEBIAN_IP:$source_path/"
    echo "Syncing to: $full_destination/"
    echo ">RSYNC<============================="
    # rsync command with additional useful options (note: --dry-run is enabled)
    rsync -avz \
    --progress \
    -e "ssh -o StrictHostKeyChecking=no" \
    --delete \
    --backup \
    --backup-dir="/home/dragondb/ftp_ssd/media/sync_backup" \
    --update \
    --exclude '.*' \
    --exclude '*.tmp' \
    --exclude '*.log' \
    --stats \
    --human-readable \
    "$DEBIAN_USER@$DEBIAN_IP:$source_path/" "$full_destination/"
    echo ">==================================="
    
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


while true; do
    echo "Select media type to list:"
    echo "1. Movies"
    echo "2. TV Shows"
    echo "3. Anime"
    echo "4. Exit"
    read -p "Enter your choice [1-4]: " choice
    
    case $choice in
        1)
            media_path="$MOVIE_PATH"
            media_type="Movies"
            dest_path="$MOVIE_DEST_PATH"
        ;;
        2)
            media_path="$TVSHOW_PATH"
            media_type="TV Shows"
            dest_path="$TVSHOW_DEST_PATH"
        ;;
        3)
            media_path="$ANIME_PATH"
            media_type="Anime"
            dest_path="$ANIME_DEST_PATH"
        ;;
        4)
            echo "Exiting..."
            exit 0
        ;;
        *)
            echo "Invalid choice, please select again."
            continue
        ;;
    esac
    
    echo "Listing $media_type folders..."
    folders=$(list_folders "$media_path" | sort -n)
    if [ -z "$folders" ]; then
        echo "No folders found or failed to connect to Debian server."
        continue
    fi
    
    echo "$folders" | nl -n ln
    echo ""
    read -p "Enter the folder number to transfer or 'q' to go back: " folder_choice
    
    if [ "$folder_choice" == "q" ]; then
        continue
    fi
    
    selected_folder=$(echo "$folders" | sed -n "${folder_choice}p")
    if [ -z "$selected_folder" ]; then
        echo "Invalid selection, please try again."
        continue
    fi
    
    remote_full_path="$media_path/$selected_folder"
    
    # Additional season selection for TV Shows and Anime
    if [ "$choice" == "2" ] || [ "$choice" == "3" ]; then
        # Check if Series/Anime Folder exist or not and create if not - not needed
        local_series_dest="$dest_path/$selected_folder"
        # if [ ! -d "$local_series_dest" ]; then
        #     echo "$local_series_dest does not exist. Creating directory..."
        #     mkdir -p "$local_series_dest"
        # else
        #     echo "Directory already exists: $local_series_dest"
        # fi
        
        echo "Listing seasons for $selected_folder..."
        # Modified to sort seasons numerically
        seasons=$(list_folders "$remote_full_path" | sort -t ' ' -k2 -n)
        if [ -z "$seasons" ]; then
            echo "No seasons found or failed to connect to Debian server."
            continue
        fi
        
        echo "$seasons" | nl -n ln
        echo ""
        read -p "Enter the season number to transfer or 'q' to go back: " season_choice
        
        if [ "$season_choice" == "q" ]; then
            continue
        fi
        
        selected_season=$(echo "$seasons" | sed -n "${season_choice}p")
        if [ -z "$selected_season" ]; then
            echo "Invalid season selection, please try again."
            continue
        fi
        #local_series_season_dest="$local_series_dest/$selected_season"
        remote_full_path="$remote_full_path/$selected_season"
        echo ">-----------------------------------"
        echo -e "Transferring '$selected_folder${selected_season:+/$selected_season}'\nfrom: $remote_full_path to: $local_series_dest"
        transfer_folder "$remote_full_path" "$local_series_dest"
        echo ">-----------------------------------"
    elif [ "$choice" == "1" ]; then
        echo ">-----------------------------------"
        echo -e "Transferring '$selected_folder${selected_season:+/$selected_season}'\nfrom: $remote_full_path to: $dest_path"
        transfer_folder "$remote_full_path" "$dest_path"
        echo ">-----------------------------------"
    fi
    
    
    
    echo "Do you want to restart? (y/n): "
    read restart_choice
    if [ "$restart_choice" != "y" ]; then
        echo "Exiting..."
        exit 0
    fi
done