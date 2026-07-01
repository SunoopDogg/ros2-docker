# CLAUDE.md

@README.md

## Notes for Claude

- **Late failure**: if uv picks a different interpreter than ROS was built
  against, `ros2.pth` points at a nonexistent directory and the build still
  succeeds; it only fails later as an `ImportError`. Skipping
  `source /opt/ros/$ROS_DISTRO/setup.bash` shows up as
  `ImportError: librcl_action.so: cannot open shared object file`.
- **Checksum**: the `ROS_APT_SOURCE_SHA256` verification is a trust boundary —
  keep it.
