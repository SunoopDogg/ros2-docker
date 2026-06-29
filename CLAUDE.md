# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A template repository for ROS 2 development in Docker. A single Dockerfile and a
single Compose file cover both ROS 2 **Humble** and **Jazzy** across three
targets, giving six services:

| Service | Distro | Target | Base image |
| --- | --- | --- | --- |
| `humble` | Humble | CPU | `nvidia/cuda:13.1.2-cudnn-devel-ubuntu22.04` |
| `humble-gpu` | Humble | NVIDIA GPU | same as `humble` |
| `humble-jetson` | Humble | Jetson ARM64 | `dustynv/cudnn:8.9-r36.2.0` |
| `jazzy` | Jazzy | CPU | `nvidia/cuda:13.1.2-cudnn-devel-ubuntu24.04` |
| `jazzy-gpu` | Jazzy | NVIDIA GPU | same as `jazzy` |
| `jazzy-jetson` | Jazzy | Jetson ARM64 | `dustynv/ros:jazzy-ros-base-r36.4.0-cu128-24.04` |

The host repo root is bind-mounted into every container at `/root/ws`.

## Docker commands

The service name selects distro and target together. Each service sits in a
profile named after itself; naming a service on the command line activates its
profile automatically, so `--profile` is only required for `down`.

```bash
# Build and start (substitute any service name from the table)
docker compose up -d --build jazzy

# Open a shell in a running container
docker compose exec jazzy bash

# One-shot interactive shell (auto-removes container)
docker compose run --rm jazzy bash

# Stop and remove
docker compose --profile jazzy down
```

A bare `docker compose up -d` starts nothing — every service is behind a profile,
which prevents all six from starting at once.

## Architecture notes

- **Distro parametrization**: The Dockerfile takes `ROS_DISTRO`,
  `UBUNTU_CODENAME`, `ROS_APT_SOURCE_VERSION`, `ROS_APT_SOURCE_SHA256` and
  `BASE_IMAGE` as build args. Compose supplies them per service from the
  `x-humble-args` / `x-jazzy-args` YAML fragments. These `ARG`s are declared
  *after* `FROM` so they are visible in the `RUN` layers; `ROS_DISTRO` is then
  promoted to `ENV` because it is read at runtime.
- **ROS install guard**: The Dockerfile skips `apt install ros-$ROS_DISTRO-ros-base`
  when `/opt/ros/$ROS_DISTRO` already exists. Jetson base images such as
  `dustynv/ros:*` ship a source build of ROS; installing the apt packages on top
  would leave two copies. This guard is the one Jetson-specific concession in the
  Dockerfile; `rosdep init` and `colcon mixin add default` are left to fail loudly
  if a base image ever conflicts with them, since no such conflict is confirmed.
- **Jetson service fragment**: `x-jetson` spells out its full config instead of
  merging with `x-amd64`. A YAML merge replaces `volumes` and `environment`
  wholesale rather than appending, so the extra Jetson mounts (`argus_socket`,
  `.Xauthority`) cannot be layered on top of the shared list.
- **Image tags**: `ros-docker:<distro>` and `ros-docker-jetson:<distro>`, so
  Humble and Jazzy images coexist. Both distros share one Compose project, so
  running one while the other is up produces a harmless orphan-container warning.
- **X11 forwarding**: All services mount `/tmp/.X11-unix` and set `DISPLAY`; the
  Jetson variants also mount `~/.Xauthority` and set `XAUTHORITY`. On the host,
  run `xhost +local:docker` before launching GUI apps.
- **GPU access**: The `*-gpu` services use `deploy.resources.reservations.devices`
  (Compose v3 GPU syntax). The Jetson services use `runtime: nvidia` instead.
- **uv cache**: Persisted across container restarts via the named volume
  `uv-cache` at `/root/.cache/uv`.
- **nvm**: Installed at `/root/.nvm`; source `$NVM_DIR/nvm.sh` inside a shell to
  use `nvm`/`node`.

## Python / uv setup (inside container)

The container's system Python is used directly — 3.10 on Ubuntu 22.04 (Humble),
3.12 on 24.04 (Jazzy). There is deliberately **no `.python-version`** file and
`requires-python` is kept loose at `>=3.10`: pinning either one would break one
of the two distros. Nothing pins the interpreter beyond that — uv resolves the
constraint against the container's system Python on its own (verified: it picks
`/usr/bin/python3` → 3.12.3 on the Jazzy image).

```bash
source /opt/ros/$ROS_DISTRO/setup.bash
uv sync
bash scripts/link_ros_to_venv.sh
source .venv/bin/activate
```

Sourcing `setup.bash` first is required: the `.pth` file only adds Python module paths, while `rclpy`'s C extension needs `LD_LIBRARY_PATH` to locate `librcl_action.so`. Without it the import fails with `ImportError: librcl_action.so: cannot open shared object file` even though the `.so` is present.

`scripts/link_ros_to_venv.sh` writes `/opt/ros/$ROS_DISTRO` site-packages paths
into `.venv/lib/python<version>/site-packages/ros2.pth`, allowing `import rclpy`
etc. from the uv venv. It reads `$ROS_DISTRO` and the venv's Python version at
runtime, so it needs no distro-specific edits.

If uv ever picks a different interpreter than the one ROS was built against, the
`.pth` file points at a nonexistent directory and the build still succeeds — the
failure only shows up later as an `ImportError`. Verify explicitly:

```bash
docker compose run --rm jazzy bash -lc \
  'source /opt/ros/$ROS_DISTRO/setup.bash && uv sync && bash scripts/link_ros_to_venv.sh && .venv/bin/python -c "import rclpy; print(rclpy.__file__)"'
```

Use `bash -lc`, not `bash -c`: the uv installer only adds itself to `PATH` via `~/.bashrc`, so `uv` (and therefore `scripts/link_ros_to_venv.sh`, whose first line is `uv sync`) is not found in a non-login shell.

## ROS 2 workspace

`src/` is the colcon workspace source directory. Add ROS 2 packages there.

```bash
source /opt/ros/$ROS_DISTRO/setup.bash
colcon build --symlink-install
source install/setup.bash
```

## Adding another ROS distro

Add an `x-<distro>-args` fragment with the four distro values, then three
services following the existing pattern. `ROS_APT_SOURCE_SHA256` is the checksum
of the `ros2-apt-source` `.deb` for that Ubuntu codename, from the
[ros-apt-source releases](https://github.com/ros-infrastructure/ros-apt-source/releases).
The checksum verification is a trust boundary — keep it.
