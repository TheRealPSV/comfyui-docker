ARG PYTORCH_IMG_VERSION="2.5.1-cuda12.4-cudnn9"
# Note you can grab the tag you should use with this: $(git ls-remote --tags --refs https://github.com/comfyanonymous/ComfyUI.git | grep -o 'v.*' | sort -V | tail -1)
ARG COMFYUI_VERSION="master" 
# Note you can grab the tag you should use with this: $(git ls-remote --tags --refs https://github.com/ltdrdata/ComfyUI-Manager.git | grep -o 'v.*' | sort -V | tail -1)
ARG COMFYUI_MANAGER_VERSION="main"

# This image is based on the PyTorch 2.5.1 image, because it already contains CUDA, CuDNN, and PyTorch
FROM pytorch/pytorch:${PYTORCH_IMG_VERSION}-runtime

# Installs Git, because ComfyUI and the ComfyUI Manager are installed by cloning their respective Git repositories
# sudo required for custom user
# build-essential is useful if you need something like sageattention and triton
RUN apt update --assume-yes && \
    apt install --assume-yes \
    git \
    sudo \
    build-essential

# Clones the ComfyUI repository and checks out the latest release
ARG COMFYUI_VERSION
RUN git clone --branch ${COMFYUI_VERSION} https://github.com/comfyanonymous/ComfyUI.git /opt/comfyui && \
    cd /opt/comfyui

# Clones the ComfyUI Manager repository and checks out the latest release; ComfyUI Manager is an extension for ComfyUI that enables users to install
# custom nodes and download models directly from the ComfyUI interface; instead of installing it to "/opt/comfyui/custom_nodes/ComfyUI-Manager", which
# is the directory it is meant to be installed in, it is installed to its own directory; the entrypoint will symlink the directory to the correct
# location upon startup; the reason for this is that the ComfyUI Manager must be installed in the same directory that it installs custom nodes to, but
# this directory is mounted as a volume, so that the custom nodes are not installed inside of the container and are not lost when the container is
# removed; this way, the custom nodes are installed on the host machine
ARG COMFYUI_MANAGER_VERSION
RUN git clone --branch ${COMFYUI_MANAGER_VERSION} https://github.com/ltdrdata/ComfyUI-Manager.git /opt/comfyui-manager && \
    cd /opt/comfyui-manager

# Installs the required Python packages for both ComfyUI and the ComfyUI Manager
RUN pip install \
    --requirement /opt/comfyui/requirements.txt \
    --requirement /opt/comfyui-manager/requirements.txt

# Sets the working directory to the ComfyUI directory
WORKDIR /opt/comfyui

# Exposes the default port of ComfyUI (this is not actually exposing the port to the host machine, but it is good practice to include it as metadata,
# so that the user knows which port to publish)
EXPOSE 8188

# Set an env var for CLI_ARGS to be passed to the program
ENV CLI_ARGS=""

# Adds the startup script to the container; the startup script will create all necessary directories in the models and custom nodes volumes that were
# mounted to the container and symlink the ComfyUI Manager to the correct directory; it will also create a user with the same UID and GID as the user
# that started the container, so that the files created by the container are owned by the user that started the container and not the root user
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

# On startup, ComfyUI is started at its default port; the IP address is changed from localhost to 0.0.0.0, because Docker is only forwarding traffic
# to the IP address it assigns to the container, which is unknown at build time; listening to 0.0.0.0 means that ComfyUI listens to all incoming
# traffic
CMD ["/opt/conda/bin/python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
