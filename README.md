# DNG-JPG Processing Environment

This Docker container environment is designed to process large batches of DNG files into JPGs using `dnglab` and `RawTherapee`. It includes automation scripts to streamline processing hundreds of folders and manage file uploads to an AWS server.

## Features

- **Tools Included**:  
  - [dnglab](https://github.com/your-repo/dnglab): Convert and manage DNG files.  
  - [RawTherapee](https://rawtherapee.com/): High-quality image processing.  

- **Automation Scripts**:  
  - **Batch Processing**: Automates processing of hundreds of folders containing DNG files.  
  - **AWS Queue Management**: Handles uploading processed JPGs to an AWS server.

## Prerequisites

1. **Docker**: Ensure Docker is installed and running on your machine.
2. **Host Directories**:  
   - `/RAW_path`: Temporary work directory (shared with Docker).  
   - `/DNG_path`: Directory containing source DNG files.  
   - `/JPG_path`: Output directory for processed JPG files.  

## Installation

**Step 1: Build the Docker Image**
```sudo docker build -t dng-jpg-env .```

**Step 2: Create and Run the Docker Container**

```sudo docker run --name dng-jpg-env \
  -v /RAW_path :/mnt/raw \
  -v /DNG_path :/mnt/dng \
  -v /JPG_path :/mnt/jpg \
  -it dng-jpg-env
```
###Step 3: Starting or Accessing the Container
Start the Container
```
sudo docker start dng-jpg-env
```
Run a Command Inside the Container
```
sudo docker exec -it dng-jpg-env /bin/bash
```
Scripts

Two Bash scripts are included to automate DNG processing and AWS uploads:

    Folder Processing Script:
        Processes all RAW files in a given directory.
        Outputs DNGs & JPGs to /mnt/dng and /mnt/jpg respectively.
        Utilizes dnglab and RawTherapee for processing.

    Queuing management system:
	Download from AWS a given folder, then process it and then upload the result back to AWS        
        Handles queue management to ensure reliable uploads and system maximization

Running the Scripts

Once inside the container:
Run the Batch Processing Script
```\opt\batching.sh```
After it is launched, start typing the names of the folders to be processed and the system will queue them to download, process and upload

    ⚠️ Replace /path/to/ with the actual path to the scripts in your container.

Additional Notes

    This container is stateless, meaning all data is managed via mounted volumes.
    Ensure AWS CLI credentials are properly configured inside the container for upload functionality.

Troubleshooting

    Error: Permission Denied: Ensure mounted directories on the host have the correct read/write permissions.
    Performance Issues: Use a faster disk or increase Docker resource allocation.

Developed by Javi. Contributions welcome!
