ARG BASE_IMAGE=nvidia/cuda:13.1.2-cudnn-devel-ubuntu24.04
FROM ${BASE_IMAGE}

# Distro-specific values. docker-compose supplies these per service; the defaults here only apply to a bare `docker build`.
ARG ROS_DISTRO=jazzy
ARG UBUNTU_CODENAME=noble
ARG ROS_APT_SOURCE_VERSION=1.2.0
ARG ROS_APT_SOURCE_SHA256=0804d9b13db770eb87019be414cd78378835228ad5fa801fc88758596dd8f7e5

ENV DEBIAN_FRONTEND=noninteractive 

# Install packages
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    ca-certificates \
    curl \
    dirmngr \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# Setup ROS Apt sources
RUN curl -L -s -f -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${UBUNTU_CODENAME}_all.deb" \
    && echo "${ROS_APT_SOURCE_SHA256}  /tmp/ros2-apt-source.deb" | sha256sum --strict --check \
    && apt-get update \
    && apt-get install /tmp/ros2-apt-source.deb \
    && rm -f /tmp/ros2-apt-source.deb \
    && rm -rf /var/lib/apt/lists/*

# Setup environment
# ROS_DISTRO is promoted to ENV because scripts/link_ros_to_venv.sh and every `source /opt/ros/$ROS_DISTRO/setup.bash` read it at runtime, after ARGs are gone.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ROS_DISTRO=${ROS_DISTRO}

# Install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -y \
    build-essential \
    git \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-rosdep \
    python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# bootstrap rosdep
RUN rosdep init && \
  rosdep update --rosdistro $ROS_DISTRO

# Setup colcon mixin and metadata
RUN colcon mixin add default \
      https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon mixin update && \
    colcon metadata add default \
      https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
    colcon metadata update

# Install ros2 packages
# Jetson base images such as dustynv/ros:* already carry a source build of ROS at /opt/ros/$ROS_DISTRO; installing the apt packages on top would leave two copies.
RUN if [ -d "/opt/ros/${ROS_DISTRO}" ]; then \
        echo "ROS ${ROS_DISTRO} already present in base image; skipping apt install"; \
    else \
        apt-get update && apt-get install -y --no-install-recommends \
        "ros-${ROS_DISTRO}-ros-base" \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# System packages
RUN apt update && apt install -y --no-install-recommends \
        # Core utilities
        ca-certificates \
        curl \
        unzip \
        # Git
        git \
        # GUI / Rendering libraries
        libgl1 \
        libgtk2.0-dev \
        tk \
    && rm -rf /var/lib/apt/lists/*

# uv installation
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# nvm installation
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh"
