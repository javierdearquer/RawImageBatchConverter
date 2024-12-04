#!/bin/bash

# This code can receive 2 parameters for the execution: 
# 1. the folder that contains all the raw images folders
# 2. the folder that contains the dependencies for the JPG conversion

LOG_FILE="/mnt/dng/logfile.log"  # log of the execution
LOG_COUNTER="/mnt/dng/image_counter.log"  # counter of files processed

# Clear (reinitialize) the log file at the start of each execution
#> "$LOG_FILE"

# Function to log both to console and file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
export -f log

# Function to count files (excluding folders) in a given path
count_files_in_path() {
    local folder="$1"
        
    local foldername=$(basename "$folder")
    # Get the folder name from the full path
    log "$foldername : Started processing folder"

    # Count the number of files (excluding folders)
    local file_count=$(find "$folder" -maxdepth 1 -type f | wc -l)
    
    # Log the number of files along with the folder name
    echo "$(date '+%Y-%m-%d %H:%M:%S') - '$foldername': $file_count" | tee -a "$LOG_COUNTER"
}

rename_files(){
    # Initialize the counter
    local counter=1

    # Loop through all the files in the folder and rename them
    for file in "$1"/*; do
        # Format the counter with leading zeros to get a 4-digit number
        local paddedcounter=$(printf "%04d" $counter)
        local extension="${file##*.}"
        local newname="AC27_${number}_${paddedcounter}.${extension}"

        # Rename the file
        mv "$file" "$1/$newname"

        # Increment the counter
        ((counter++))
    done
}

# Define the function to handle conversion
convert_to_dng() {
    local raw_file="$1"
    local dng_dir="$2"
    local foldername="$3"

    local base_name=$(basename "$raw_file" .ARW)
    local output_file="$dng_dir/$base_name.dng"
    
    # Check if the output file exists and is non-zero
    if [[ ! -f "$output_file" || ! -s "$output_file" ]]; then
        # Run the conversion command
        "/opt/dnglab/target/release/dnglab" convert "$raw_file" "$output_file" -d --embed-raw false
        
        # Check if conversion was successful
        if [[ $? -ne 0 ]]; then
            log "$foldername : ERROR Failed to convert $base_name to DNG"
        fi
    fi
}
# Export the function for parallel to use
export -f convert_to_dng

# Define the function to handle conversion
convert_to_jpg() {
    local dng_file="$1"
    local output_dir="$2"
    local dependencies_path="$3"
    local foldername="$4"

    local base_name=$(basename "$dng_file" .dng)
    local output_file="$output_dir/$base_name.jpg"
    
    # Check if the output file exists and is non-zero
    if [[ ! -f "$output_file" || ! -s "$output_file" ]]; then
        # Run the conversion command
        nice -n 10 rawtherapee-cli -o "$output_dir" -j60 -Y -p "$dependencies_path/adjustments_V3.pp3" -c "$dng_file"
        # Check if conversion was successful
        if [[ $? -ne 0 ]]; then
            log "$foldername : ERROR Failed to convert $base_name to JPG"
        fi
    fi
}
# Export the function for parallel to use
export -f convert_to_jpg

# Function to process ARW files in a folder
process_arw_files() {

    # Variable definition
    folder="$1"
    dependencies_path="${2:-/opt}"  # Replace with your actual default path

    # Extract the folder name and number from it
    foldername=$(basename "$folder") # i.e. AC27-1456
    dng_dir="/mnt/dng/$foldername"
    output_dir="/mnt/jpg/$foldername"


    number=$(echo "$foldername" | cut -d'-' -f2)

    # Check if the source directory contains any files
    if find "$folder" -maxdepth 1 -type f | grep -q .; then
        # Create the required folders if they don't exist
        mkdir -p "$dng_dir" "$output_dir"
        if [[ $? -ne 0 ]]; then
            log "$foldername : ERROR Failed to create required directories"
            return 1 
        fi
    else
        log "$foldername : ERROR No files found in the source directory. Ending the program"
        return 1 
    fi

    # Renaming ARW files
    rename_files "$folder"
    log "$foldername : RAW Renaming complete"

    ####### ARW -> DNG ######
    # Iterate through each .ARW file in the raw directory
    log "$foldername : Starting file conversion to DNG ..."
    # Run the function in parallel over files
    parallel convert_to_dng {} "$dng_dir" "$foldername" ::: "$folder"/*.ARW
    wait # Wait for all DNG conversions to complete
    log "$foldername : DNG conversion complete"

    ####### DNG -> JPG ######
    # Iterate through each .DNG file in the dng directory
    log "$foldername : Starting file conversion to JPG ..."
    # Run the function in parallel over files
    # I have to limit to 20-30 cores because of memory limits, each process takes 3.5GB
    parallel -j 25 convert_to_jpg {} "$output_dir" "$dependencies_path" "$foldername" ::: "$dng_dir"/*.dng
    wait # Wait for all JPG conversions to complete
    log "$foldername : JPG conversion complete"

    # Once done remove the RAW files to free up space
    # rm -r "$folder"
}

# Main script execution
if [[ $# -eq 2 && -d "$1" && -d "$2" ]]; then 
    # Count files in the folder
    count_files_in_path "$1"
    
    # Process the folder's ARW files
    process_arw_files "$1" "$2"
elif [[ $# -eq 1 && -d "$1" ]]; then
    # Count files in the folder
    count_files_in_path "$1"
    
    # Process the folder's ARW files
    process_arw_files "$1"
else
    echo "The provided path(s) are not a valid directory: $1"
    exit 1
fi
