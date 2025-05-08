#!/bin/bash
# -------------------------------------------------------------------
# Copy a file with comparison and confirmation
# Version: 1.0.3
# Author: Torayld
# -------------------------------------------------------------------
SCRIPT_VERSION="1.0.3"
ERROR_OK=0              # OK
ERROR_INVALID_FILE=20    # The file does not exist or is not valid
ERROR_FILE_COPY_FAILED=22 # The file copy operation failed
ERROR_PERMISSION_FAILED=23 # The chmod operation failed
ERROR_COPY_CANCELED=24 # The file copy operation canceled

# General function to copy a file with comparison and confirmation
# Usage: copy_file "source_path_file" "dest_path_file" [param_cp]
# The "-f" argument is optional. If specified, the file will be replaced without confirmation.
# Return: 0 if success and in case of conflict with existing file with B response, new file path will be returned in copy_file_return
copy_file_return='';
copy_file() {
  local source_path_file="$1"
  local dest_path_file="$2"
  local options="$3"

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

  # Check if option --parents is specified, if so, add the parent directory to the destination path
  if [[ "$options" =~ --parents ]]; then
    options="${options//--parents/}"
    local source_dir=$(dirname "$source_path_file")
    dest_dir="${dest_dir%/}/${source_dir%/}"
    dest_file=$source_file
    dest_path_file="${dest_dir%/}/$dest_file"
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
      if ! [[ "$options" =~ --force ]]; then
        local output=''
        output+=$(echo -e "The file '$dest_path_file' exists but is different.")
        output+=$(echo -e "\nDetails of the existing file:")
        output+=$(echo -e "\n  Date: $(stat -c '%y' "$dest_path_file")")
        output+=$(echo -e "\n  Size: $(stat -c '%s' "$dest_path_file") bytes")
        output+=$(echo -e "\nDetails of the source file:")
        output+=$(echo -e "\n  Date: $(stat -c '%y' "$source_path_file")")
        output+=$(echo -e "\n  Size: $(stat -c '%s' "$source_path_file") bytes")
        output+=$(echo -e "\nDo you want to replace the file ? (y/n/b) : ")

        read -p "$output" response
        if [[ "$response" == "b" ]]; then
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
        elif [[ "$response" == "y" ]]; then
           option+=" --force"
        else
           return $ERROR_COPY_CANCELED
        fi
      fi
    fi
  fi

  # Copy the file
  cp $options "$source_path_file" "$dest_path_file" 
  if [[ $? -eq 0 ]]; then
    echo "File successfully copied to '$dest_path_file'."
    # If it's a shell script (.sh), set executable permissions
    if [[ "$dest_path_file" == *.sh || "$dest_path_file" == *.py ]]; then
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

# Function to find script dependencies and copy them to a destination directory
# Usage: copie_dependencies "script.sh" "/usr/local/bin"
# The default destination directory is /usr/local/bin
# return 0 if success or error code
copy_dependencies() {
    local script_file="$1"
    local dest_dir="${2:-/usr/local/bin}"  # Default destination is /usr/local/bin

    # Check if the script file exists
    if [[ ! -f "$script_file" ]]; then
        echo "Error: File not found -> $script_file"
        return $ERROR_INVALID_FILE
    fi

    # Absolute path for the script file
    script_file="$(realpath "$script_file")"
    script_dir="$(dirname "$script_file")"

    # Find all lines containing "source path/to/script.sh"
    while read -r file; do
        echo "Dependency found : $file"
        
        # Check if the file is an absolute path
        if [[ "$file" == /* ]]; then
            echo "Absolute path detected, not copying: $file"
            continue
        fi

        # Check if the file contains the variable $script_path
        if [[ "$file" == *"\$script_path"* ]]; then
            # Replace $script_path with the script directory
            file="${file#\$script_path/}"
            source_file="$script_dir/$file"
        else
            source_file="$(real_path -m "$file")"
        fi

        # Create dest_file path
        dest_file="$dest_dir/$file"

        echo "Copying dependency: $source_file → $dest_file"
        # Copie avec conservation de la structure de dossier
        copy_file "$source_file" "$dest_file" "--parents --force"
        ret=$?
        if [ $ret -ne $ERROR_OK ]; then
            return $ret
        fi
    done < <(grep -Eo 'source [^ ]+' "$script_file" | awk '{print $2}')

    return $ERROR_OK
}