# ComfyUI Docker

This is a Docker image for [ComfyUI](https://www.comfy.org/), which makes it extremely easy to run ComfyUI on Linux and Windows WSL2. The image also includes the [ComfyUI Manager](https://github.com/ltdrdata/ComfyUI-Manager) extension.

## Getting Started

To get started, you have to install [Docker](https://www.docker.com/). This can be either Docker Engine, which can be installed by following the [Docker Engine Installation Manual](https://docs.docker.com/engine/install/) or Docker Desktop, which can be installed by [downloading the installer](https://www.docker.com/products/docker-desktop/) for your operating system.

To enable the usage of NVIDIA GPUs, the NVIDIA Container Toolkit must be installed. The installation process is detailed in the [official documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

## Installation

The ComfyUI Docker image is available from the [GitHub Container Registry](https://ghcr.io). 

### Docker Compose (Recommended)

Docker Compose is as simple as creating a docker-compose.yml file where you want to save your volumes (files).
```
services:
  stable-diffusion-comfyui:
    image: ghcr.io/therealpsv/comfyui-docker:latest
    container_name: stable-diffusion-comfyui
    volumes:
      - ./sd-comfyui-data/models:/opt/comfyui/models
      - ./sd-comfyui-data/custom_nodes:/opt/comfyui/custom_nodes
      - ./sd-comfyui-data/pipcache:/root/.cache/pip
      - ./sd-comfyui-data/input:/opt/comfyui/input
      - ./sd-comfyui-data/workflows:/opt/comfyui/user/default/workflows
      - ./sd-comfyui-data/manager:/opt/comfyui/user/default/ComfyUI-Manager
      - ./sd-comfyui-data/customrequirements:/opt/customrequirements
      - ./sd-comfyui-data/output:/root/ComfyUI/output
    stop_signal: SIGKILL
    tty: true
    restart: unless-stopped
    ports:
      - "8188:8188"
    environment:
      - PUID=1000
      - PGID=1000
      - CLI_ARGS=--disable-auto-launch
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities:
                - gpu
                - compute
                - utility
```

After saving the file you can simply run `docker compose up -d` to run the container.

#### Volumes
- models: where your model files are stored
- custom_nodes: where your custom_nodes are saved to
- pipcache: caches saved python pip modules to disk to speed up restarts
- input: where any input files are saved by comfyui
- workflows: your saved workflow files
- manager: ComfyUI Manager configuration
- customrequirements: ComfyUI Manager's "Install PIP Module" option doesn't work properly in this container. Instead, you can place your requested modules in a requirements.txt file in this folder, matching the [pip requirements file format](https://pip.pypa.io/en/stable/reference/requirements-file-format/) (typically just the name of the module, one per line), and the container will install it for you as it boots up.
- output: Your ComfyUI outputs

#### Environment Variables (Optional)
- PUID: the user id of your host machine linux user, if you want the container to attempt to use your user so the files in volumes are owned by your user. You can find this by running `id -u`.
- PGID: the group id of your host machine linux user, if you want the container to attempt to use your user so the files in volumes are owned by your user's group. You can find this by running `id -g`.
- CLI_ARGS: any arguments you want to pass to ComfyUI when it runs.

### Docker CLI

Installing ComfyUI is as simple as pulling the image and starting a container, which can be achieved using the following command:

```shell
docker run \
    --name comfyui \
    --detach \
    --restart unless-stopped \
    --env PUID="$(id -u)" \
    --env PGID="$(id -g)" \
    --volume "<path/to/models/folder>:/opt/comfyui/models:rw" \
    --volume "<path/to/custom/nodes/folder>:/opt/comfyui/custom_nodes:rw" \
    --publish 8188:8188 \
    --runtime nvidia \
    --gpus all \
    ghcr.io/therealpsv/comfyui-docker:latest
```

Please note, that the `<path/to/models/folder>` and `<path/to/custom/nodes/folder>` must be replaced with paths to directories on the host system where the models and custom nodes will be stored, e.g., `$HOME/.comfyui/models` and `$HOME/.comfyui/custom-nodes`, which can be created like so: `mkdir -p $HOME/.comfyui/{models,custom-nodes}`.

The `--detach` flag causes the container to run in the background and `--restart unless-stopped` configures the Docker Engine to automatically restart the container if it stopped itself, experienced an error, or the computer was shutdown, unless you explicitly stopped the container using `docker stop`. This means that ComfyUI will be automatically started in the background when you boot your computer. The two `--env` arguments inject the user ID and group ID of the current host user into the container. During startup, a user with the same user ID and group ID will be created, and ComfyUI will be run using this user. This ensures that files written to the volumes (e.g., models and custom nodes installed with the ComfyUI Manager) will be owned by the host system's user. Normally, the user inside the container is `root`, which means that the files that are written from the container to the host system are also owned by `root`. If you have run ComfyUI Docker without setting the environment variables, then you may have to change the owner of the files in the models and custom nodes directories: `sudo chown -r "$(id -un):$(id -gn)" <path/to/models/folder> <path/to/custom/nodes/folder>`. The `--runtime nvidia` and `--gpus all` arguments enable ComfyUI to access the GPUs of your host system. If you do not want to expose all GPUs, you can specify the desired GPU index or ID instead.

After the container has started, you can navigate to [localhost:8188](http://localhost:8188) to access ComfyUI.

If you want to stop ComfyUI, you can use the following commands:

```shell
docker stop comfyui
docker rm comfyui
```

> [!WARNING]
> While the custom nodes themselves are installed outside of the container, their requirements are installed inside of the container. This means that stopping and removing the container will remove the installed requirements. When the container is started again, the requirements will be automatically installed, but this may, depending on the number of custom nodes and their requirements, take some time. Using the pipcache volume speeds up the process by saving nodes to your local storage, so it doesn't have to redownload them.

## Updating

### Docker Compose

In the folder with your `docker-compose.yml` file, simply run the following command:
`docker compose pull && docker compose down && docker compose up -d`

### Docker CLI

To update ComfyUI Docker to the latest version you have to first stop the running container, then pull the new version, optionally remove dangling images, and then restart the container:

```shell
docker stop comfyui
docker rm comfyui

docker pull ghcr.io/therealpsv/comfyui-docker:latest
docker image prune # Optionally remove dangling images

docker run \
    --name comfyui \
    --detach \
    --restart unless-stopped \
    --env USER_ID="$(id -u)" \
    --env GROUP_ID="$(id -g)" \
    --volume "<path/to/models/folder>:/opt/comfyui/models:rw" \
    --volume "<path/to/custom/nodes/folder>:/opt/comfyui/custom_nodes:rw" \
    --publish 8188:8188 \
    --runtime nvidia \
    --gpus all \
    ghcr.io/therealpsv/comfyui-docker:latest
```

## Building

If you want to use the bleeding edge development version of the Docker image, you can also clone the repository and build the image yourself:

```shell
git clone https://github.com/therealpsv/comfyui-docker.git
docker build --tag therealpsv/comfyui-docker:latest comfyui-docker
```

Now, a container can be started like so:

```shell
docker run \
    --name comfyui \
    --detach \
    --restart unless-stopped \
    --env USER_ID="$(id -u)" \
    --env GROUP_ID="$(id -g)" \
    --volume "<path/to/models/folder>:/opt/comfyui/models:rw" \
    --volume "<path/to/custom/nodes/folder>:/opt/comfyui/custom_nodes:rw" \
    --publish 8188:8188 \
    --runtime nvidia \
    --gpus all \
    therealpsv/comfyui-docker:latest
```

## Versions 

You can browse different variations and versions of this image here: https://github.com/therealpsv/comfyui-docker/pkgs/container/comfyui-docker/versions?filters%5Bversion_type%5D=tagged

Currently, each version is built nightly with the latest stable release of ComfyUI and ComfyUI Manager if either is updated. The images are currently based on 3 versions of the official PyTorch image:
- 2.5.1-cuda11.8-cudnn9
- 2.5.1-cuda12.1-cudnn9
- 2.5.1-cuda12.4-cudnn9 (default if you choose the `latest` tag)

If you'd like to pull the latest image based on a specific version of PyTorch, you can pull one of these tags:
- `2.5.1-cuda11.8-cudnn9-latest`
- `2.5.1-cuda12.1-cudnn9-latest`
- `2.5.1-cuda12.4-cudnn9-latest` (same as the `latest` tag)

Similarly, the latest master build of ComfyUI at time of building is available with the `nightly` tag.

Versions based on specific builds of ComfyUI and ComfyUI Manager are available as well, though not all combinations of ComfyUI and ComfyUI Manager are, only the latest versions at the time of the nightly build. The naming scheme for specific versions is `<PyTorch version>-cui-<ComfyUI version>-cuim-<ComfyUI Manager version>`. You can browse these tags through the link above.
