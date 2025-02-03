#!/bin/bash
# -------------------------------------------------------------------
# Copy a file with comparison and confirmation
# Version: 1.0.0
# Author: Torayld
# -------------------------------------------------------------------
SCRIPT_VERSION="1.0.0"
ERROR_OK=0              # OK
ERROR_INVALID_FILE=20    # The file does not exist or is not valid
ERROR_FILE_COPY_FAILED=22 # The file copy operation failed

# General function to copy a file with comparison and confirmation
copy_file() {
  local source_file="$1"
  local dest_file="$2"
  local force="$3" # Pass "force" as the third argument to force replacement

  # Check if the source file exists
  if [[ ! -f "$source_file" ]]; then
    echo "Error: Source file '$source_file' does not exist."
    return $ERROR_INVALID_FILE
  fi

  # Extract the destination directory from the destination file
  local dest_dir
  dest_dir=$(dirname "$dest_file")

  # Check if the destination directory exists, or create it
  if [[ ! -d "$dest_dir" ]]; then
    echo "The directory '$dest_dir' does not exist. Creating it..."
    mkdir -p "$dest_dir"
    if [[ $? -ne 0 ]]; then
      echo "Error: Unable to create directory '$dest_dir'."
      return $ERROR_INVALID_FILE
    fi
  fi

  # If the destination file exists, compare the two files
  if [[ -f "$dest_file" ]]; then
    if cmp -s "$source_file" "$dest_file"; then
      echo "The file '$dest_file' is already identical. No action needed."
      return $ERROR_OK
    else
      echo "The file '$dest_file' exists but is different."
      echo "Details of the existing file:"
      echo "  Date: $(stat -c '%y' "$dest_file")"
      echo "  Size: $(stat -c '%s' "$dest_file") bytes"
      echo "Details of the source file:"
      echo "  Date: $(stat -c '%y' "$source_file")"
      echo "  Size: $(stat -c '%s' "$source_file") bytes"

      # If the force option is not specified, ask for confirmation
      if [[ "$force" != "force" ]]; then
        read -p "Do you want to replace the file? (y/n): " response
        if [[ "$response" != "y" ]]; then
          echo "Replacement canceled."
          # Check if the file exists, increment the number if necessary
          local dest_file_tmp="${dest_file}.service"
          local counter=1
          while [ -f "$dest_file_tmp" ]; do
              counter=$((counter + 1))
              dest_file_tmp="${dest_file}${counter}.service"
          done
          dest_file=$dest_file_tmp
          return $ERROR_OK
        fi
      fi
    fi
  fi

  # Copy the file
  cp "$source_file" "$dest_file" -f
  if [[ $? -eq 0 ]]; then
    echo "File successfully copied to '$dest_file'."
    # If it's a shell script (.sh), set executable permissions
    if [[ "$dest_file" == *.sh ]]; then
        sudo chmod +x "$dest_file"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to set executable permissions on $dest_file."
            exit $ERROR_PERMISSION_FAILED
        fi
        echo "Executable permissions set on $dest_file."
    fi
    return $ERROR_OK
  else
    echo "Error: Failed to copy the file."
    return $ERROR_FILE_COPY_FAILED
  fi
}
