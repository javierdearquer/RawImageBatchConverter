# Use an official Ubuntu as a base image
FROM ubuntu:20.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update and install required dependencies
RUN apt-get update && \
    apt-get install -y \
    software-properties-common \
    wget \
    git \
    build-essential \
    cmake \
    libgtk-3-dev \
    libtiff5-dev \
    libpng-dev \
    libjpeg-dev \
    liblcms2-dev \
    libfftw3-dev \
    libboost-all-dev \
    libexiv2-dev \
    liblensfun-dev \
    libcanberra-gtk-module \
    ca-certificates  \
    cargo \
    at \
    nano \
    parallel \
    unzip \
    rawtherapee && \
    rm -rf /var/lib/apt/lists/*

# Install GNU Parallel
RUN apt-get update && \
    apt-get install -y parallel && \
    rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Install DNGlab from source
RUN cd /opt && \
    git clone https://github.com/dnglab/dnglab.git && \
    cd /opt/dnglab && \
    cargo build --release

# Make DNGlab available in the PATH
RUN echo 'export PATH=/opt/dnglab/target/release:$PATH' >> /etc/profile
#ENV PATH="/opt/dnglab/target/release:$PATH"

# Copy your custom script into the Docker image
COPY process_arw_files.sh /opt/process_arw_files.sh
RUN chmod +x /opt/process_arw_files.sh
COPY adjustments_V3.pp3 /opt/adjustments_V3.pp3
RUN chmod +x /opt/adjustments_V3.pp3
COPY batching.sh /opt/batching.sh
RUN chmod +x /opt/batching.sh

#COPY corner_detection.py /opt/corner_detection.py
#RUN chmod +x /opt/corner_detection.py

#COPY split_rotate.py /opt/split_rotate.py
#RUN chmod +x /opt/split_rotate.py

# Set the default command to open a Bash terminal
CMD ["/bin/bash"]
