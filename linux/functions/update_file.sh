#!/bin/bash
# -------------------------------------------------------------------
# Update and compare key-value pairs in a file
# Version: 1.0.0
# Author: Torayld
# -------------------------------------------------------------------
SCRIPT_VERSION="1.0.0"

# General function for updating and comparing any file with key-value pairs
# Returns 0 if changes were made, 1 if no changes were needed
update_file() {
    local original_file=$1
    local key_value_pairs=("${!2}")
    local backup=$3

    # Define the temporary file with timestamp
    local temp_file="${original_file}_tmp_$(date +%Y%m%d_%H%M%S)"

    # Create a temporary file to hold the modified content
    sudo cp "$original_file" "$temp_file"

    # Initialize changes_made to 0
    local changes_made=0

    # Update or append key-value pairs in the temporary file
    for key_value in "${key_value_pairs[@]}"; do
        IFS="=" read -r key value <<< "$key_value"
        
        # Check if key exists and update or append it
        if grep -q "^$key" "$temp_file"; then
            # If key exists, update the value
            current_value=$(grep "^$key" "$temp_file" | awk -F= '{print $2}' | tr -d '[:space:]')
            if [[ "$current_value" != "$value" ]]; then
                sudo sed -i "s|^$key.*|$key = $value|" "$temp_file"
                ((changes_made++))  # Increase changes_made
            fi
        else
            # If key doesn't exist, append it
            echo "$key = $value" | sudo tee -a "$temp_file" > /dev/null
            ((changes_made++))  # Increase changes_made
        fi
    done

    # Compare original and temp files
    if cmp -s "$original_file" "$temp_file"; then
        # Files are identical, no backup or replace needed
        echo "No changes needed. File is already up to date."
        rm "$temp_file"
        return 1
    else
        # Files are different, display number of changes made and backup/replace logic
        echo "$changes_made change(s) made to the file."
        if [[ $backup == true ]]; then
            local backup_file="${original_file}_backup_$(date +%Y%m%d_%H%M%S)"
            # Create backup by renaming the original file
            echo "Backup: Renaming $original_file to $backup_file"
            sudo mv "$original_file" "$backup_file"
            
            # Rename the temp file to original file
            echo "Applying changes to $original_file"
            sudo mv "$temp_file" "$original_file"
        else
            # No backup, just replace the file
            echo "Applying changes without backup..."
            sudo mv "$temp_file" "$original_file"
        fi
    fi
    return 0
}