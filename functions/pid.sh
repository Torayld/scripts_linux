#!/bin/bash
# -------------------------------------------------------------------
# Functions to lock execution using a PID file
# Version: 1.0.0
# Author: Torayld
# -------------------------------------------------------------------

# Function to lock execution using a PID file
# The PID file will be created in the current directory.
# The script will exit if another instance is already running with the same PID.
# The PID file will be removed when the script exits.
# The script will check if the saved PID is an active bash process.
# Param 1: PID file path (optional)
# Return: 0 if the lock is acquired, 1 if another instance is running
# Example: lock_with_pid_file "/tmp/my_script.pid"
lock_with_pid_file() {
    local PID_FILE="$1"
    local CURRENT_PID=$$

    # If no PID file path is provided, generate one based on the script name
    if [ -z "$PID_FILE" ]; then
        local SCRIPT_NAME
        SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
        PID_FILE="cron_${SCRIPT_NAME}.PID"
    fi

    # Check if the PID file exists
    if [ -f "$PID_FILE" ]; then
        local SAVED_PID
        SAVED_PID=$(cat "$PID_FILE")

        # Check if the saved PID is an active bash process
        if ps -p "$SAVED_PID" > /dev/null 2>&1 && grep -q "bash" "/proc/$SAVED_PID/comm"; then
            echo "A process with PID $SAVED_PID is already running. Exiting."
            return 1
        fi
    fi

    # Save the current PID to the file
    echo "$CURRENT_PID" > "$PID_FILE"

    # Ensure the PID file is removed on script exit
    trap "rm -f '$PID_FILE'" EXIT

    return 0
}
