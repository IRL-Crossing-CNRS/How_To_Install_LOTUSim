# LOTUSim Installation Guide

Automated installer for **LOTUSim Core** + **LOTUSim Generic Scenario**.

Supports:
- Ubuntu 24.04 → ROS 2 Jazzy
- Windows **WSL2** with Ubuntu 24.04 (same script — see [WSL notes](#wsl-notes))

---

## Requirements

- Ubuntu 24.04 (fresh or existing install)
- Internet access
- `sudo` privileges

Both repositories are public and cloned over HTTPS, so no account or key is
needed. The script checks they are reachable before installing anything.

---

## Quick Install

```bash
chmod +x install_core_and_generic_scenario.sh
./install_core_and_generic_scenario.sh
```

Once both repositories are confirmed reachable, the script asks three questions:

1. **Usage mode** — how do you intend to use LOTUSim?
   - `(1)` **User** — a black box to test some algorithms, plug and play
   - `(2)` **Developer** — of the core / generic scenario
2. **Branch** — asked once per repository, since the core and the generic
   scenario do not necessarily carry the same branch names. Each question
   lists that repository's own remote branches, and the branch you pick is
   checked out there regardless of whether the repository was freshly cloned
   or already present locally.
3. **PX4 SITL** — `Install PX4 SITL? [y/N]` — clone and build PX4-Autopilot
   (`~/PX4-Autopilot`) so agents with `"px4": true` can fly (see
   [PX4 SITL support](#px4-sitl-support-aerial-drones)). Non-interactive
   override: `INSTALL_PX4=1 ./install_core_and_generic_scenario.sh`
   (or `INSTALL_PX4=0` to skip the question).

The script will then automatically:
1. Detect your Ubuntu version and select the matching ROS 2 distribution
2. Install system dependencies (`git`, `git-lfs`, `jq`, `curl`, etc.)
3. Check both repositories are reachable
4. Ask the three questions above (usage mode + branch + PX4)
5. Install Python dependencies (`pyarrow`, `pandas`, `matplotlib`, `opencv-python`)
6. Clone the LOTUSim core repository into `~/lotusim_ws` and check out its chosen branch
7. Configure your `~/.bashrc` with the `LOTUSIM_*` environment variables and the `lotusim` command
8. Run `lotusim install` to set up ROS 2 and Gazebo — **skipped if ROS 2 is
   already installed** (force with `FORCE_LOTUSIM_INSTALL=1 ./install_core_and_generic_scenario.sh`);
   an already-configured ROS 2 apt repository is also left untouched
9. Clone and build the LOTUSim Generic Scenario workspace, checking out its chosen branch
10. **If you answered yes to PX4:** install PX4's build dependencies, clone
    `~/PX4-Autopilot` (recursive), apply the known clang-18 fix if needed, build
    `px4_sitl gz_x500`, and export `PX4_AUTOPILOT_PATH` in `~/.bashrc`
11. **User mode only:** build the deployment wheels (`deployment/build_wheels.sh`) and copy the
    whole `deployment/` folder from the generic scenario repo into `~/Documents/workspace/`.
    This step is skipped entirely in developer mode.

---

## What Gets Installed

| Component | Location |
|---|---|
| LOTUSim Core | `~/lotusim_ws/src/LOTUSim` |
| Generic Scenario | `~/Documents/workspace/lotusim/LOTUSim-generic-scenario` |
| ROS 2 Jazzy | `/opt/ros/jazzy` |
| Deployment folder (user mode only) | `~/Documents/workspace/deployment` |
| PX4-Autopilot (only if you answer yes to question 3) | `~/PX4-Autopilot` |

---

## Usage Modes

| | (1) User | (2) Developer |
|---|---|---|
| Intended for | Plug-and-play use of LOTUSim as a black box to test algorithms | Working on the core / generic scenario code itself |
| Core + scenario cloned & built | Yes | Yes |
| `deployment/build_wheels.sh` run, then `deployment/` copied to `~/Documents/workspace/` | Yes | No |

In both modes, the branch you pick for each repository is checked out on that
repository.

---

## PX4 SITL support (aerial drones)

An `X500` agent whose scenario JSON sets `"px4": true` is flown by an external
**PX4 SITL** process instead of LOTUSim's built-in behaviour-tree controller
(see the generic scenario README, section *PX4 SITL (aerial drones)*, and its
`doc/ARCHITECTURE.md` §5.1). PX4 is not part of LOTUSim — it's a separate
checkout you build once. Question 3 of this installer automates that build:

1. Installs PX4's system dependencies (`ninja-build`, `ccache`, `libopencv-dev`,
   GStreamer dev packages) and Python requirements (`Tools/setup/requirements.txt`)
2. Clones `https://github.com/PX4/PX4-Autopilot.git` **recursively** into `~/PX4-Autopilot`
3. Applies the known clang ≥ 18 VLA fix (`-Wno-error=vla-cxx-extension`) when needed
4. Builds `make px4_sitl gz_x500` — first build takes roughly 30–60 minutes.
   The installer watches for the `pxh>` shell `gz_x500` auto-launches when the
   build finishes, stops it, and verifies `build/px4_sitl_default/bin/px4`
   exists (this avoids both an interactive hang and the runaway-log issue
   described in the generic scenario README)
5. Exports `PX4_AUTOPILOT_PATH="$HOME/PX4-Autopilot"` in `~/.bashrc`

The step is idempotent: re-running the installer only refreshes submodules and
skips the build if the binary is already there.

**Using it:** pick a scenario with a PX4 agent, e.g.

```bash
cd ~/Documents/workspace/lotusim/LOTUSim-generic-scenario
./src/simulation_run/executable/scenario_launch.sh --config wind_wake_examples/x500_px4.json
```

PX4 SITL starts automatically once the drone spawns (one instance per PX4
agent); per-instance logs land in `scenario_logs/<timestamp>/px4_sitl_*.log`.
Fly it from QGroundControl (`px4_control: "manual"`) or let the built-in
`px4_offboard_patrol` task fly waypoints (`px4_control: "offboard"`). Full
details — including QGroundControl install and the `"px4": true` agents'
`spawn.z = 0` requirement — are in the generic scenario README.

---

## WSL notes

The same Ubuntu 24.04 script runs unchanged in WSL2:

- **Gazebo GUI** needs WSLg (built into Windows 11, or an up-to-date WSL on
  Windows 10). Scenarios run headless by default; add `--gui` for the Gazebo
  window. If rendering glitches occur: `export LIBGL_ALWAYS_SOFTWARE=1`.
- **Unity rendering** works over WSLg; set `ROS_IP` to the WSL address if the
  Unity window can't connect.
- **PX4 SITL** runs fine headless in WSL. For manual flying, QGroundControl's
  AppImage also runs under WSLg and connects to PX4 on `localhost:14550`
  automatically. (Running QGC on the Windows host instead requires inbound UDP
  forwarding into WSL2 — mirrored networking on Win11 or `netsh portproxy`.)
- No `systemd` or extra services are required by any part of this install.

---

## After Installation

Open a **new terminal** (or run `source ~/.bashrc`), then:

```bash
cd ~/Documents/workspace/lotusim/LOTUSim-generic-scenario
```

Follow the scenario README to launch your first simulation.

---

## Re-running the Script

The script is **idempotent** — safe to run multiple times. It will:
- Ask the usage mode and branch questions again on every run
- Skip cloning if repositories already exist (and fetch latest changes instead)
- Always check out the branch you selected for each repo, even if it was
  already present locally on a different branch
- Refuse to reuse a directory whose git remote points at a different repository
- Skip `~/.bashrc` modifications if the LOTUSim block is already present

---

## Updating the Deployment Folder (user mode)

Once installed, re-sync the deployment wheels at any time without re-running
the full installer:

```bash
./update_deployment_folder.sh
```

This script:
1. Updates LOTUSim core and LOTUSim-generic-scenario on whatever
   branch they are currently checked out on (no branch switch, no prompts)
2. Runs `deployment/build_wheels.sh` in the generic scenario repo
3. Syncs only the build output (`dist/`, sensor folders, and any other
   wheel-bearing folder) into `~/Documents/workspace/deployment`, overwriting
   just those folders — everything else you've added there is left untouched

---

## Troubleshooting

**`Cannot reach https://github.com/IRL-Crossing-CNRS/...`**

The repository could not be reached. Check your network connection, and that
the repository still exists at that address.

**Permission denied on `log/` during build**
```bash
sudo chown -R $USER:$USER ~/lotusim_ws
cd ~/lotusim_ws && colcon build --symlink-install
```

**`error: can't copy '/mnt/Data/.../build/simulation_run/config/*.json': doesn't exist or not a regular file` during the scenario build**

The scenario (or core) workspace folder was **copied or synced from another
computer, including its `build/`, `install/` and `log/` folders**.
`colcon build --symlink-install` fills those with *absolute* symlinks that only
resolve on the machine where the build originally ran — on yours they dangle
(note the foreign path in the error message). Delete the artefacts and rebuild;
the updated installer detects and cleans these automatically, but you can also
do it by hand:
```bash
cd ~/Documents/workspace/lotusim/LOTUSim-generic-scenario
rm -rf build install log
# optionally check for other stray broken links inside the sources:
find src -xtype l
# then re-run the installer (this also installs PX4 when requested)
```
Do the same for `~/lotusim_ws` if it too came from another machine.
**Never copy/sync `build/`, `install/` or `log/` between machines** — git
ignores them (see `.gitignore`), but folder-sync tools (Synology Drive, USB
keys, tarballs) happily carry them along.

**PX4 build fails with `.../optical_flow/PX4-OpticalFlow does not contain a CMakeLists.txt file`**

The PX4-Autopilot checkout contains one or more **empty git submodules** (a
single flaky network moment during the big recursive clone is enough), which
makes CMake configure fail with a cascade of *non-existent target OpticalFlow /
klt_feature_tracker* errors right after. Re-running this installer repairs it
automatically: it re-syncs and force-populates every submodule, verifies none
are left empty, and wipes the half-finished `build/` directory before
rebuilding. The manual equivalent, should you want it:
```bash
cd ~/PX4-Autopilot
git submodule update --init --recursive --force
rm -rf build && make px4_sitl gz_x500
```

**Python import errors (`pyarrow`, `pandas`, etc.)**

Re-run the pip install manually:
```bash
pip3 install --break-system-packages pyarrow pandas matplotlib opencv-python
```
