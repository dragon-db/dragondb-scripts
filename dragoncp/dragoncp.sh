#!/bin/bash

# DragonCP - Manual Sync Script by Dragon DB v2.0
# This script facilitates the transfer of media files from a Remote VM to a local machine.
# It allows users to:
# 1. List and select media types (Movies, TV Shows, Anime).
# 2. Browse through folders of selected media types.
# 3. Transfer selected folders or seasons to a specified local destination.
# 4. Handle directory creation and provide feedback on transfer status.
# Ensure that the environment variables for paths and SSH credentials are set in 'dragoncp_env.env'.

# Define the environment file path
ENV_FILE="dragoncp_env.env"

# Load the env file
if [ -r "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Error: $ENV_FILE file not found or not readable." >&2  # Redirect to stderr
    exit 1
fi

# Function to list folders in the specified path on the Debian VM
list_folders() {
    ssh "$DEBIAN_USER@$DEBIAN_IP" "find \"$1\" -mindepth 1 -maxdepth 1 -type d -exec basename '{}' \;" 2>/dev/null
}

# Function to list files in remote directory
list_remote_files() {
    ssh "$DEBIAN_USER@$DEBIAN_IP" "find \"$1\" -maxdepth 1 -type f -exec basename '{}' \;" 2>/dev/null | sort -V
}

# Function to list files in local directory
list_local_files() {
    find "$1" -maxdepth 1 -type f -exec basename '{}' \; 2>/dev/null | sort -V
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
    --backup-dir="$BACKUP_PATH" \
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

# Function to sync single episode
sync_single_episode() {
    source_path="$1"
    destination_path="$2"
    source_file="$3"
    local_file="$4"
    
    # Move local file to backup if it exists
    if [ -f "$destination_path/$local_file" ]; then
        echo "Moving local episode to backup: $local_file"
        mkdir -p "$BACKUP_PATH/$(basename "$destination_path")"
        mv "$destination_path/$local_file" "$BACKUP_PATH/$(basename "$destination_path")/"
    fi
    
    echo "Syncing episode: $source_file"
    echo "From: $source_path"
    echo "To: $destination_path"
    echo ">RSYNC<============================="
    rsync -avz \
    --progress \
    -e "ssh -o StrictHostKeyChecking=no" \
    --backup \
    --backup-dir="$BACKUP_PATH" \
    "$DEBIAN_USER@$DEBIAN_IP:$source_path/$source_file" "$destination_path/"
    echo ">==================================="
    
    status=$?
    if [ $status -eq 0 ]; then
        echo "Episode transfer completed successfully!"
        return 0
    else
        echo "Episode transfer failed with status: $status"
        return 1
    fi
}

while true; do
    echo "DragonCP v2.0"
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
        
        local_series_dest="$dest_path/$selected_folder"
        remote_full_path="$remote_full_path/$selected_season"
        
        # New sync option menu
        if [ "$choice" == "2" ] || [ "$choice" == "3" ]; then
            while true; do
                echo "Select sync option:"
                echo "1. Sync entire season folder"
                echo "2. Manual episode sync"
                echo "3. Go back"
                read -p "Enter your choice [1-3]: " sync_choice
                
                case $sync_choice in
                    1)
                        echo ">-----------------------------------"
                        echo -e "Transferring '$selected_folder/$selected_season'\nfrom: $remote_full_path to: $local_series_dest"
                        transfer_folder "$remote_full_path" "$local_series_dest"
                        echo ">-----------------------------------"
                        break
                        ;;
                    2)
                        while true; do
                            # First show and select local episode
                            echo "Listing local episodes..."
                            local_episodes=$(list_local_files "$local_series_dest/$selected_season")
                            if [ -z "$local_episodes" ]; then
                                echo "No local episodes found."
                                echo "Please sync the entire season first or add episodes manually."
                                break
                            fi
                            
                            echo "$local_episodes" | nl -n ln
                            echo -e "\nSelect local episode to replace:"
                            echo "Enter episode number"
                            echo "Enter 'q' to go back to sync menu"
                            read -p "Your choice: " local_episode_choice
                            
                            if [ "$local_episode_choice" == "q" ]; then
                                break
                            fi
                            
                            selected_local_episode=$(echo "$local_episodes" | sed -n "${local_episode_choice}p")
                            if [ -z "$selected_local_episode" ]; then
                                echo "Invalid local episode selection, please try again."
                                continue
                            fi
                            
                            # Then show and select remote episode
                            echo -e "\nListing remote episodes..."
                            remote_episodes=$(list_remote_files "$remote_full_path")
                            if [ -z "$remote_episodes" ]; then
                                echo "No remote episodes found or failed to connect to server."
                                break
                            fi
                            
                            echo "$remote_episodes" | nl -n ln
                            echo -e "\nSelect remote episode to sync:"
                            echo "Enter episode number"
                            echo "Enter 'q' to go back to local episode selection"
                            read -p "Your choice: " remote_episode_choice
                            
                            if [ "$remote_episode_choice" == "q" ]; then
                                continue
                            fi
                            
                            selected_remote_episode=$(echo "$remote_episodes" | sed -n "${remote_episode_choice}p")
                            if [ -z "$selected_remote_episode" ]; then
                                echo "Invalid remote episode selection, please try again."
                                continue
                            fi
                            
                            # Create season directory if it doesn't exist
                            local_season_path="$local_series_dest/$selected_season"
                            if [ ! -d "$local_season_path" ]; then
                                mkdir -p "$local_season_path"
                            fi
                            
                            # Sync single episode
                            sync_single_episode "$remote_full_path" "$local_season_path" "$selected_remote_episode" "$selected_local_episode"
                            
                            echo "Do you want to sync another episode? (y/n): "
                            read another_episode
                            if [ "$another_episode" != "y" ]; then
                                break
                            fi
                        done
                        ;;
                    3)
                        break
                        ;;
                    *)
                        echo "Invalid choice, please try again."
                        ;;
                esac
            done
        else
            echo ">-----------------------------------"
            echo -e "Transferring '$selected_folder'\nfrom: $remote_full_path to: $dest_path"
            transfer_folder "$remote_full_path" "$dest_path"
            echo ">-----------------------------------"
        fi
    elif [ "$choice" == "1" ]; then
        echo ">-----------------------------------"
        echo -e "Transferring '$selected_folder'\nfrom: $remote_full_path to: $dest_path"
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