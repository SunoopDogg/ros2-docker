# ros2-docker

A template repository for ROS 2 development in Docker. One Dockerfile and one
Compose file cover both ROS 2 Humble and Jazzy across three targets (CPU, NVIDIA
GPU, Jetson ARM64).

## Quick start

Pick a service and start it. There is nothing to configure first — the service
name selects the ROS distro and the target together.

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

Each service is in a profile named after itself. Naming a service on the command
line activates its profile automatically, so `--profile` is only needed for
`docker compose down`.

A bare `docker compose up -d` starts nothing. That is deliberate — it keeps all
six services from coming up at once.

Humble and Jazzy images are tagged separately (`ros2-docker:humble` vs
`ros2-docker:jazzy`), so both can exist side by side. Running one while the other
is up produces an orphan-container warning from Compose; it is harmless.

## GUI applications

All services mount `/tmp/.X11-unix` and set `DISPLAY`. On the host, allow the
container to reach your X server before launching anything graphical:

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

Sourcing `setup.bash` first is required, not optional: the `.pth` file only adds
Python module paths, while `rclpy`'s C extension needs `LD_LIBRARY_PATH` to find
`librcl_action.so` and friends.

`scripts/link_ros_to_venv.sh` writes `/opt/ros/$ROS_DISTRO` site-packages paths
into `.venv/lib/python<version>/site-packages/ros2.pth`. Verify it worked:

```bash
docker compose run --rm jazzy bash -lc \
  'source /opt/ros/$ROS_DISTRO/setup.bash && bash scripts/link_ros_to_venv.sh && .venv/bin/python -c "import rclpy; print(rclpy.__file__)"'
```

Note the `-l`: the uv installer only adds itself to `PATH` from `~/.bashrc`, so
`uv` is not found in a non-login shell (`bash -c`).

## ROS 2 workspace

`src/` is the colcon workspace source directory. The repo root is bind-mounted at
`/root/<project name>` inside every container — the Compose project name, which
defaults to the lowercased repo directory name (e.g. `/root/ros2-docker`).

```bash
source /opt/ros/$ROS_DISTRO/setup.bash
colcon build --symlink-install
source install/setup.bash
```

## Adding another ROS distro

Add an `x-<distro>-args` fragment with the four distro values, then three
services following the existing pattern. The `ROS_APT_SOURCE_SHA256` value is
the checksum of the `ros2-apt-source` `.deb` for that Ubuntu codename; find it on
the [ros-apt-source releases page](https://github.com/ros-infrastructure/ros-apt-source/releases).
