#!/bin/bash
# -------------------------------------------------------------------
# Copy a file with comparison and confirmation
# Version: 1.0.1
# Author: Torayld
# -------------------------------------------------------------------
SCRIPT_VERSION="1.0.1"
ERROR_OK=0              # OK
ERROR_INVALID_FILE=20    # The file does not exist or is not valid
ERROR_FILE_COPY_FAILED=22 # The file copy operation failed
ERROR_PERMISSION_FAILED=23 # The chmod operation failed
ERROR_COPY_CANCELED=24 # The file copy operation canceled

# General function to copy a file with comparison and confirmation
copy_file_return='';
copy_file() {
  local source_path_file="$1"
  local dest_path_file="$2"
  local force="$3" # Pass "force" as the third argument to force replacement

  local source_file=$(basename "$source_path_file")
  local dest_dir
  local dest_file

  # Check if the source file exists
  if [[ ! -f "$source_path_file" ]]; then
    echo "Error: Source file '$source_path_file' does not exist."
    return $ERROR_INVALID_FILE
  fi

 if [[ -f "$dest_path_file" ]]; then # file exist
    dest_dir=$(dirname "$dest_path_file")
    dest_file=$(basename "$dest_path_file")
  elif [[ "$dest_path_file" =~ ^[^/]+$ ]] && [[ ! -e "$dest_path_file" ]]; then # no / in dest_path_file and not exist consider it as file
    dest_dir=$(dirname "$dest_path_file")
    dest_file=$(basename "$dest_path_file")
  else
    #folder exist as destination or consider it as folder
    dest_dir=$dest_path_file
    dest_file=$source_file
    dest_path_file="${dest_path_file%/}/$dest_file"
  fi
  copy_file_return=$dest_path_file

  if ! [[ -d "$dest_dir" ]]; then
    echo "The directory '$dest_dir' does not exist. Creating it..."
    mkdir -p "$dest_dir"
    if [[ $? -ne 0 ]]; then
      echo "Error: Unable to create directory '$dest_dir'."
      return $ERROR_INVALID_FILE
    fi
  fi
 

  # If the destination file exists, compare the two files
  if [[ -f "$dest_path_file" ]]; then
    if cmp -s "$source_path_file" "$dest_path_file"; then
      echo "The file '$dest_path_file' is already identical. No action needed."
      return $ERROR_OK
    else
      # If the force option is not specified, ask for confirmation
      if [[ "$force" != "force" ]]; then
        local output=''
        output+=$(echo -e "\nThe file '$dest_path_file' exists but is different.")
        output+=$(echo -e "\nDetails of the existing file:")
        output+=$(echo -e "\n  Date: $(stat -c '%y' "$dest_path_file")")
        output+=$(echo -e "\n  Size: $(stat -c '%s' "$dest_path_file") bytes")
        output+=$(echo -e "\nDetails of the source file:")
        output+=$(echo -e "\n  Date: $(stat -c '%y' "$source_path_file")")
        output+=$(echo -e "\n  Size: $(stat -c '%s' "$source_path_file") bytes")
        output+=$(echo -e "\nDo you want to replace the file ? (y/n/b) : ")

        read -p "$output" response
        if [[ "$response" == "b" ]]; then
          echo "Replacement canceled."
          # Check if the file exists, increment the number if necessary
          local dest_file_root=$(basename "$dest_path_file")
          dest_file_root="${%dest_file_root.*}"
          local dest_file_ext="${dest_file_root##*.}"
          local dest_path_file_tmp="${dest_path_file}"
          local counter=1
          while [ -f "$dest_path_file_tmp" ]; do
              counter=$((counter + 1))
              dest_path_file_tmp="${dest_dir}${dest_file_root}/${counter}.${dest_file_ext}"
          done
          dest_path_file=$dest_path_file_tmp
          copy_file_return=$dest_path_file
        elif [[ "$response" != "y" ]]; then
           return $ERROR_COPY_CANCELED
        fi
      fi
    fi
  fi

  # Copy the file
  cp "$source_path_file" "$dest_path_file" -f
  if [[ $? -eq 0 ]]; then
    echo "File successfully copied to '$dest_path_file'."
    # If it's a shell script (.sh), set executable permissions
    if [[ "$dest_path_file" == *.sh ]]; then
        sudo chmod +x "$dest_path_file"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to set executable permissions on $dest_path_file."
            exit $ERROR_PERMISSION_FAILED
        fi
        echo "Executable permissions set on $dest_path_file."
    fi
    return $ERROR_OK
  else
    echo "Error: Failed to copy the file."
    return $ERROR_FILE_COPY_FAILED
  fi
}