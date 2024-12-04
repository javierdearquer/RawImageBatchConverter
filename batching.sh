#!/bin/bash

# Temporary files for task management
DOWNLOAD_QUEUE="download_queue.txt"
PROCESS_QUEUE="process_queue.txt"
UPLOAD_QUEUE="upload_queue.txt"
LOCK_FILE="process_lock"

S3_RAW_PATH="s3://"
S3_DNG_PATH="s3://"
S3_JPG_PATH="s3://"

# Initialize queues
> "$DOWNLOAD_QUEUE"
> "$PROCESS_QUEUE"
> "$UPLOAD_QUEUE"

rm -rf $LOCK_FILE

# Functions
download_folder() {
    local folder=$1
    echo "Downloading $folder..."
    nice -5 aws s3 sync $S3_RAW_PATH/$folder /mnt/raw/$folder --quiet
    echo "$folder" >> "$PROCESS_QUEUE"
}

process_folder() {
    local folder=$1
    echo "Processing $folder..."
    touch "$LOCK_FILE" # Create lock to ensure single processing
    ./opt/process_arw_files.sh "/mnt/raw/$folder" & wait;
    echo "Processed $folder."
    rm -f "$LOCK_FILE" # Release lock
    echo "$folder" >> "$UPLOAD_QUEUE" #TODO split the queue of JPG and DNG so that you can start uploading DNG while still processing
}

upload_and_cleanup() {
    local folder=$1
    echo "Uploading ..."
    
    # Perform uploads
    nice -5 aws s3 sync /mnt/dng/$folder $S3_DNG_PATH/$folder --quiet
    nice -5 aws s3 sync /mnt/jpg/$folder $S3_JPG_PATH/$folder --quiet
    echo "Uploaded."
    
    # Verify uploads
    echo "Verifying upload consistency..."
    local dng_local_count=$(find /mnt/dng/$folder -type f | wc -l)
    local jpg_local_count=$(find /mnt/jpg/$folder -type f | wc -l)
    
    local start_time=$(date +%s)
    local timeout=$((15 * 60)) # 5 minutes in seconds

    while true; do
        # Get S3 file counts
        local dng_s3_count=$(aws s3 ls $S3_DNG_PATH/$folder/ --recursive | wc -l)
        local jpg_s3_count=$(aws s3 ls $S3_JPG_PATH/$folder/ --recursive | wc -l)

        # Check if counts match
        if [[ $dng_local_count -eq $dng_s3_count && $jpg_local_count -eq $jpg_s3_count ]]; then
            echo "Upload verified. Cleaning up RAW & DNG..."
            nice -n 5 rm -rf "/mnt/raw/$folder" "/mnt/dng/$folder"
            echo "Cleaned up."
            break
        fi

        # Check if timeout reached
        local current_time=$(date +%s)
        if (( current_time - start_time > timeout )); then
            echo "Verification timed out. Skipping local cleanup."
            break
        fi

        # Wait before retrying
        sleep 10
    done
}

add_to_download_queue() {
    local folder=$1
    echo "$folder" >> "$DOWNLOAD_QUEUE"
    echo "Added $folder to the download queue."
}

# Download loop
download_loop() {
    while :; do
        if [[ ! -s "$DOWNLOAD_QUEUE" ]]; then
            sleep 15
            continue
        fi

        local folder
        folder=$(head -n 1 "$DOWNLOAD_QUEUE")
        sed -i "1d" "$DOWNLOAD_QUEUE"

        download_folder "$folder"
    done
}

# Processing loop
process_loop() {
    while :; do
        if [[ -f "$LOCK_FILE" ]]; then
            sleep 15 # Wait for processing lock to be released
            continue
        fi

        if [[ ! -s "$PROCESS_QUEUE" ]]; then
            sleep 15
            continue
        fi

        local folder
        folder=$(head -n 1 "$PROCESS_QUEUE")
        sed -i "1d" "$PROCESS_QUEUE"

        process_folder "$folder"
    done
}

# Upload loop
upload_loop() {
    while :; do
        if [[ ! -s "$UPLOAD_QUEUE" ]]; then
            sleep 15
            continue
        fi

        local folder
        folder=$(head -n 1 "$UPLOAD_QUEUE")
        sed -i "1d" "$UPLOAD_QUEUE"

        upload_and_cleanup "$folder"
    done
}

# Start loops in the background
download_loop &
DOWNLOAD_PID=$!
process_loop &
PROCESS_PID=$!
upload_loop &
UPLOAD_PID=$!

# User interaction loop
while :; do
    echo "Enter command (add <folder>, stop):"
    read -r command folder

    case "$command" in
    add)
        if [[ -n "$folder" ]]; then
            add_to_download_queue "$folder"
        else
            echo "No folder specified."
        fi
        ;;
    stop)
        echo "Stopping..."
        kill "$DOWNLOAD_PID" "$PROCESS_PID" "$UPLOAD_PID" 2>/dev/null
        wait "$DOWNLOAD_PID" "$PROCESS_PID" "$UPLOAD_PID" 2>/dev/null
        break
        ;;
    *)
        echo "Invalid command. Use 'add <folder>' or 'stop'."
        ;;
    esac
done

echo "All tasks completed."
