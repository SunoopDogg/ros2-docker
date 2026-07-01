# ros2-docker

A template repository for ROS 2 development in Docker. One Dockerfile and one
Compose file cover both ROS 2 Humble and Jazzy across three targets (CPU, NVIDIA
GPU, Jetson ARM64).

## Quick start

Pick a service and start it.

```bash
docker compose up -d --build jazzy     # build and start
docker compose exec jazzy bash         # shell into it
docker compose --profile jazzy down    # stop and remove
```

## Services

| Service | ROS distro | Target | Base image |
| --- | --- | --- | --- |
| `humble` | Humble | CPU | `nvidia/cuda:13.1.2-cudnn-devel-ubuntu22.04` |
| `humble-gpu` | Humble | NVIDIA GPU | same as `humble` |
| `humble-jetson` | Humble | Jetson ARM64 | `dustynv/cudnn:8.9-r36.2.0` |
| `jazzy` | Jazzy | CPU | `nvidia/cuda:13.1.2-cudnn-devel-ubuntu24.04` |
| `jazzy-gpu` | Jazzy | NVIDIA GPU | same as `jazzy` |
| `jazzy-jetson` | Jazzy | Jetson ARM64 | `dustynv/ros:jazzy-ros-base-r36.4.0-cu128-24.04` |

## GUI applications

Before launching anything graphical, run on the host:

```bash
xhost +local:docker
```

## Python and uv

The container's system Python is used directly — 3.10 on Ubuntu 22.04 (Humble),
3.12 on 24.04 (Jazzy).

```bash
source /opt/ros/$ROS_DISTRO/setup.bash
bash scripts/link_ros_to_venv.sh
source .venv/bin/activate
```

## ROS 2 workspace

`src/` is the colcon workspace source directory. The repo root is mounted at
`/root/<repo directory name>` inside the container.

```bash
source /opt/ros/$ROS_DISTRO/setup.bash
colcon build --symlink-install
source install/setup.bash
```
