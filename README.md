# LOTUSim Installation Guide

Automated installer for **LOTUSim Core** + **LOTUSim Generic Scenario**.

Supports:
- Ubuntu 24.04 (ROS 2 Jazzy, Gazebo Harmonic and xdyn come from the core's nix flake)
- Windows **WSL2** with Ubuntu 24.04 (same script — see [WSL notes](#wsl-notes))

The core and the scenario workspace are built in their nix devshells; the
script adds the `LOTUSIM_*` variables and the `lotusim_core` and
`lotusim_shell` commands to `~/.bashrc`. Naval Group's own `lotusim`
program is left untouched.

---

## Requirements

- Ubuntu 24.04 (fresh or existing install)
- Internet access — the first entry into the flake downloads several GB
- About 20 GB of free disk, 7 GB more if the detection runs on the GPU
  (question 4)
- For GPU detection only, an NVIDIA GPU with its driver installed on the
  machine — the environment brings CUDA itself, but uses the driver's `libcuda`
- `sudo` privileges (installing nix, and its ROS cache, needs root once)

Both repositories are public and cloned over HTTPS: no account or key is
needed. The script checks they are reachable before installing anything.

This installer follows the core's own environment:
nix, the core's flake and its `mise` tasks (see
[naval-group/LOTUSim's README](https://github.com/naval-group/LOTUSim#quickstart)).

---

## Quick Install (recommended)

```bash
chmod +x install_core_and_generic_scenario.sh
./install_core_and_generic_scenario.sh
```

Once both repositories are confirmed reachable, the script asks five questions:

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
   [PX4 SITL support](#optional-px4-sitl-aerial-drones)). Non-interactive
   override: `INSTALL_PX4=1 ./install_core_and_generic_scenario.sh`
   (or `INSTALL_PX4=0` to skip the question).
4. **GPU detection** — `Use the GPU for detection?` — the YOLO crack and
   corrosion detection runs on the CPU by default; answering yes downloads
   NVIDIA's CUDA build of PyTorch (about 7 GB more) and runs it on the GPU.
   The default answer is yes when `nvidia-smi` finds a GPU. The choice is
   stored in `~/.config/lotusim/devshell` (`default` or `gpu`), which
   `lotusim_shell` reads: edit it to switch later. Non-interactive
   override: `INSTALL_GPU=1` (or `INSTALL_GPU=0`).
5. **Unity player** — Linux, Windows or both. The scenario repository ships
   both builds, about 1 GB each and stored twice by Git LFS; only the chosen
   one is downloaded, the other stays as small LFS pointer files. The default
   is the one `scenario_launch.sh` starts on this machine: Linux, or Windows
   under WSL. Non-interactive override: `INSTALL_UNITY_PLAYER=linux|windows|all`.
   To fetch the other one later: `git config --unset lfs.fetchexclude && git lfs pull`
   in the scenario repository.

The script will then automatically:
1. Install system dependencies (`git`, `git-lfs`, `jq`, `curl`, `openssh-client`, etc.)
2. Check that both repositories are reachable
3. Ask the five questions above (usage mode + branch + PX4 + GPU detection + Unity player)
4. Clone the LOTUSim core repository into `~/lotusim_ws` and check out its chosen branch
5. Configure your `~/.bashrc` with the `LOTUSIM_*` variables and the `lotusim_core`
   and `lotusim_shell` commands — no ROS 2 is sourced there, so a single
   ROS 2 is ever on the path. A block written by the previous (apt-based)
   installer is replaced, after a backup to `~/.bashrc.lotusim.bak`
6. Install nix if absent, enable flakes, and add the ROS binary cache. ROS 2,
   Gazebo and xdyn all come from the core's flake; nothing ROS-related is
   installed system-wide
7. Build the core with its own `mise run build`, inside `nix develop`
8. Clone the LOTUSim Generic Scenario workspace and build it **in that same
   environment**, against the core just built — a workspace built against
   another ROS 2 gets different message definitions and never exchanges a
   message with the simulation
9. **If you answered yes to PX4:** install PX4's build dependencies, clone
    `~/PX4-Autopilot` (shallow, SITL submodules only), apply the known clang-18
    fix if needed, build `px4_sitl gz_x500`, and export `PX4_AUTOPILOT_PATH`
    in `~/.bashrc`
10. **User mode only:** build the deployment wheels (`deployment/build_wheels.sh`) and copy the
    whole `deployment/` folder from the generic scenario repo into `~/Documents/workspace/`.
    This step is skipped entirely in developer mode.

---

## After Installation

Open a **new terminal** (or run `source ~/.bashrc`), then:

```bash
lotusim_shell
./src/simulation_run/executable/scenario_launch.sh --config facet_demo/demo_facet.json
```

Follow the scenario README for the other scenarios and options.

---

## What Gets Installed

| Component | Location |
|---|---|
| LOTUSim Core | `~/lotusim_ws/src/LOTUSim` |
| Draft Generic Scenario | `~/Documents/workspace/lotusim/LOTUSim-generic-scenario` |
| ROS 2 Jazzy, Gazebo Harmonic, xdyn | the core's nix flake (nothing system-wide) |
| nix | `/nix`, with flakes and the ROS cache enabled |
| Deployment folder (user mode only) | `~/Documents/workspace/deployment` |
| PX4-Autopilot (only if you answer yes to question 3) | `~/PX4-Autopilot` |
| CUDA build of PyTorch (only if you answer yes to question 4) | the scenario workspace's `gpu` devshell |

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

## Optional: graphics bridge (rendering sensors)

A nix-built Gazebo cannot reach the host GPU driver by itself, and it renders
every camera and gpu_lidar whether or not a window is open. Away from NixOS,
install the bridge once (the script does not):

```bash
nix profile add github:nix-community/nixGL#nixGLIntel
```

On a hybrid or NVIDIA machine install the matching NVIDIA wrapper instead and
name it explicitly, since the core's detection prefers Intel:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure github:nix-community/nixGL#nixGLNvidia
export LOTUSIM_GL_WRAPPER=nixGLNvidia-<driver version>
```

---

## Optional: PX4 SITL (aerial drones)

An `X500` agent whose scenario JSON sets `"px4": true` is flown by an external
**PX4 SITL** process instead of LOTUSim's built-in behaviour-tree controller
(see the generic scenario README, section *PX4 SITL (aerial drones)*, and its
`doc/ARCHITECTURE.md` §5.1). PX4 is not part of LOTUSim — it's a separate
checkout you build once. Question 3 of this installer automates that build:

1. Clones `https://github.com/PX4/PX4-Autopilot.git` into `~/PX4-Autopilot`
   **shallow** (`--depth 1`) and populates only the submodules a SITL build
   uses — see [PX4 disk usage](#px4-disk-usage) below
2. Runs PX4's own `Tools/setup/ubuntu.sh --no-nuttx`: compilers and build
   tools, PX4's Python requirements, and Gazebo Harmonic from
   packages.osrfoundation.org. PX4 is a system build, not a nix one, and the
   launcher runs it against that Gazebo
3. Applies the known clang ≥ 18 VLA fix (`-Wno-error=vla-cxx-extension`) when needed
4. Builds `make px4_sitl gz_x500` — first build takes roughly 30–60 minutes.
   The installer watches for the `pxh>` shell `gz_x500` auto-launches when the
   build finishes, stops it, and verifies `build/px4_sitl_default/bin/px4`
   exists (this avoids both an interactive hang and the runaway-log issue
   described in [Manual build](#manual-build-instead-of-question-3))
5. Exports `PX4_AUTOPILOT_PATH="$HOME/PX4-Autopilot"` in `~/.bashrc`

The step is idempotent: re-running the installer only refreshes submodules and
skips the build if the binary is already there.

### Manual build (instead of question 3)

**PX4 SITL stays a system build**, and the launcher keeps it that way: inside a
devshell it is handed the system loader, binary and gz configuration paths, so
its gz dependencies resolve against the ROS 2 install it was linked with. The
two builds still meet over gz-transport. Build it with the same compiler as
before (`CC=clang CXX=clang++ make px4_sitl_default`) — the flags PX4 passes are
clang's.

A plain `git clone --recursive` costs about 4.4 GB. A SITL build never touches
the NuttX board sources or the Gazebo-classic / jMAVSim / FlightGear / JSBSim
simulators (LOTUSim drives `Tools/simulation/gz`, which is kept), so populate
everything except those and land around 1.1 GB instead:

```bash
git clone --depth 1 https://github.com/PX4/PX4-Autopilot.git ~/PX4-Autopilot
cd ~/PX4-Autopilot

skip="platforms/nuttx/NuttX/nuttx
platforms/nuttx/NuttX/apps
Tools/simulation/gazebo-classic/sitl_gazebo-classic
Tools/simulation/jmavsim/jMAVSim
Tools/simulation/flightgear/flightgear_bridge
Tools/simulation/jsbsim/jsbsim_bridge"

mapfile -t want < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' \
                      | awk '{print $2}' | grep -vxF "$skip")
git submodule update --init --recursive --depth 1 -- "${want[@]}"
```

Naming the wanted paths is the only thing that holds: `submodule update --init`
runs `submodule init`, which sets `submodule.<name>.active=true` and undoes both
a `deinit` and an `active=false` you set beforehand. `--depth 1` is safe — PX4
builds its version string with `git describe --always`, so a tagless clone works
(you get a hash instead of `v1.18.0-…`).

If you would rather not bother, `git clone --recursive` still works; it just
costs the extra 3 GB.

Then PX4's own dependency script, SITL only: compilers and build tools, PX4's
Python requirements, and Gazebo Harmonic from packages.osrfoundation.org, whose
gz libraries the launcher hands PX4 at run time:

```bash
bash Tools/setup/ubuntu.sh --no-nuttx
```

**Known build issue (clang 18+):** a few PX4 source files use
variable-length arrays in C++, which clang 18 treats as a hard error
(`-Werror` + `-Wvla-cxx-extension`) even though older clang only warned.
If `make` fails with `variable length arrays in C++ are a Clang extension`,
add one line to `cmake/px4_add_common_flags.cmake` in the clang branch
(next to the existing `-Wno-c99-designator` etc.):

```cmake
-Wno-error=vla-cxx-extension
```

Then build the Gazebo x500 target:

```bash
make px4_sitl gz_x500
```

This command builds PX4 and then launches it in an interactive `pxh>` shell
attached to whatever Gazebo world and model it finds. With no matching Gazebo
instance running, PX4 attaches to nothing and the `pxh>` prompt redraws in a
loop indefinitely. If the run is backgrounded or redirected to a log file,
that file grows without bound (several GB within minutes) until the disk
fills. After the first build, check for a leftover process with
`ps aux | grep bin/px4`, kill it, and delete the log. Later scenario launches
are unaffected: LOTUSim starts its own PX4 instance with `-d` (daemon mode,
no `pxh>` prompt).

### QGroundControl

Only needed to fly a PX4 agent by hand (`px4_control: "manual"`).
QGroundControl is not in Ubuntu's apt repositories. Download the official
AppImage:

```bash
curl -L -o ~/Applications/QGroundControl-x86_64.AppImage \
  "$(curl -s https://api.github.com/repos/mavlink/qgroundcontrol/releases/latest \
     | grep browser_download_url | grep x86_64.AppImage | cut -d'"' -f4)"
chmod +x ~/Applications/QGroundControl-x86_64.AppImage
~/Applications/QGroundControl-x86_64.AppImage
```

### PX4 disk usage

A plain `git clone --recursive` of PX4-Autopilot costs about **4.4 GB**, and a
SITL build uses a fraction of it. The installer therefore clones shallow and
populates only the submodules a SITL target actually references:

| Left out | Why |
|---|---|
| Git history (`--depth 1`) | PX4 generates its version string with `git describe --always`, so a tagless clone builds fine — you just get a hash instead of `v1.18.0-…` |
| `platforms/nuttx/NuttX/{nuttx,apps}` | flight-controller board sources; SITL is a POSIX build |
| `Tools/simulation/{gazebo-classic,jmavsim,flightgear,jsbsim}` | simulators LOTUSim never launches — it uses the `gz` one, which is kept |

That is roughly **1.1 GB instead of 4.4 GB**, and the checkout still rebuilds in
place. To add one of them back later:

```bash
cd ~/PX4-Autopilot
git submodule update --init --recursive <path>
```

Re-running the installer will not remove it again — it only skips it, and
tells you the command to drop it if you want the space back.

**Flight logs grow faster than the checkout.** Every PX4 SITL run writes a
`.ulg` to `build/px4_sitl_default/rootfs/<instance>/log/`, and nothing prunes
them — a few weeks of runs is easily more than the whole checkout. Cap them by
setting the `SDLOG_DIRS_MAX` parameter (e.g. `5`; the parameter exists for
exactly this case), or drop what has accumulated:

```bash
du -sh ~/PX4-Autopilot/build/px4_sitl_default/rootfs/*/log
rm -rf ~/PX4-Autopilot/build/px4_sitl_default/rootfs/*/log
```

**Using it:** pick a scenario with a PX4 agent, e.g.

```bash
cd ~/Documents/workspace/lotusim/LOTUSim-generic-scenario
./src/simulation_run/executable/scenario_launch.sh --config wind_wake_examples/x500_px4.json
```

PX4 SITL starts automatically once the drone spawns (one instance per PX4
agent); per-instance logs land in `scenario_logs/<timestamp>/px4_sitl_*.log`.
Fly it from QGroundControl (`px4_control: "manual"`) or let the built-in
`px4_offboard_patrol` task fly waypoints (`px4_control: "offboard"`). How to
enable PX4 on an agent — including the `"px4": true` agents' `spawn.z = 0`
requirement — is in the generic scenario README; QGroundControl is installed as described in
[QGroundControl](#qgroundcontrol).

---

## Optional: the Unity project (Unity developers only)

Running scenarios needs none of this: the scenario workspace ships the built
Unity player (`lotusim_unity_executables/`). Install the Unity project only to
change the 3D side.

1. Install **Unity Hub**, then the **Unity Editor `2022.3.18f1`** with
   *Linux Build Support (Mono)* — and *Windows Build Support* to build the
   Windows player too.
2. Clone the project (its assets are in Git LFS):
   ```bash
   git clone --recurse-submodules https://github.com/IRL-Crossing-CNRS/LOTUSim-Energy
   cd LOTUSim-Energy && git lfs pull
   ```
3. In Unity Hub, *Add* the clone and open it with `2022.3.18f1`.

Optional devices:

- **Leap Motion** (Linux and Windows): an `Ultraleap Hand Tracking Camera`, a
  computer that meets the
  [tracking requirements](https://www.ultraleap.com/gemini-downloads/), and the
  [Ultraleap Hand Tracking Software](https://www.ultraleap.com/downloads/)
  (V5.2+). The project was developed with the *Leap Motion Controller*.
- **Tobii Eye Tracker 5** (Windows only): the `Tobii Experience` app from the
  Microsoft Store, then the `Tobii Experience Driver v1.133` and
  `Tobii Ghost v1.14.1` from
  [gaming.tobii.com](https://gaming.tobii.com/getstarted/?bundle=tobii-et5).

How to use them in a scene is in the LOTUSim-Energy README.

---

## Manual installation (instead of the script)

**Only if you do not run the script**: the [Quick Install](#quick-install-recommended)
already does every step below. This is what it does, for a machine where you
would rather run each command yourself. Everything is per machine except the
two builds.

**1. Nix, with flakes and the binary caches**

```bash
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
sudo tee -a /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
extra-substituters = https://ros.cachix.org https://naval-group.cachix.org
extra-trusted-public-keys = ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo= naval-group.cachix.org-1:ytTEzFEeuzQrC9IRYLzHGa5OnM65G95M6/sbPd0fy28=
EOF
sudo systemctl restart nix-daemon
```

The caches are not optional in practice: without them nix rebuilds the whole
ROS 2 stack, and xdyn, from source.

**2. Clone the two workspaces** (Git LFS carries the Unity executables)

```bash
sudo apt update && sudo apt install -y git git-lfs jq
git clone -b <branch> https://github.com/IRL-Crossing-CNRS/LOTUSim \
    ~/lotusim_ws/src/LOTUSim
mkdir -p ~/Documents/workspace/lotusim && cd ~/Documents/workspace/lotusim
git clone --recurse-submodules -b <branch> \
    https://github.com/IRL-Crossing-CNRS/LOTUSim-generic-scenario
cd LOTUSim-generic-scenario && git lfs pull
```

**3. Build the core, in its devshell**

The core provides its own ROS 2 and Gazebo through a nix flake, and builds with
mise. Both workspaces must be built inside that environment: a build against a
system ROS and one against the flake's produce different message definitions,
and the two never talk to each other.

```bash
cd ~/lotusim_ws/src/LOTUSim
nix develop --command mise run build
```

**4. Build the scenario workspace, in its own devshell** (the core's plus the
agents' Python packages, built against the core above)

```bash
cd ~/Documents/workspace/lotusim/LOTUSim-generic-scenario
nix develop --override-input lotusim ~/lotusim_ws/src/LOTUSim
source ~/lotusim_ws/src/LOTUSim/install/setup.bash
colcon build --symlink-install
```

The default devshell runs the YOLO detection tasks on the CPU. `nix develop
.#gpu` (same `--override-input`) runs them on an NVIDIA GPU instead: it adds
NVIDIA's CUDA build of PyTorch, about 7 GB, and needs the NVIDIA driver on the
machine. Write `gpu` or `default` to `~/.config/lotusim/devshell` so that
`lotusim_shell` opens the same one.

**5. The `~/.bashrc` block** — copy the `LOTUSIM_*` variables and the
`lotusim_core` / `lotusim_shell` functions from the script (search for
`LOTUSim setup`), or run the script once: it skips what is already done.

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

## The two commands

The script defines them in `~/.bashrc`:

```bash
lotusim_core build          # build the core (mise run build, in its devshell)
lotusim_core sim --gui energy.world
lotusim_core test
lotusim_shell               # the scenario workspace's devshell, both workspaces sourced
                            # (CPU or GPU detection, from ~/.config/lotusim/devshell)
```

The scenario workspace is always built and run against the core installed
next to it (`nix develop --override-input lotusim $LOTUSIM_PATH`).

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

Setting up the **remote machine** an agent runs on (ROS 2, the virtualenv, the
wheels) is part of the deployment walkthrough, which follows one agent from the
simulation machine to the remote one: see the generic scenario's
[deployment/README.md](https://github.com/IRL-Crossing-CNRS/LOTUSim-generic-scenario/blob/main/deployment/README.md).

---

## Troubleshooting

**`Cannot access https://github.com/IRL-Crossing-CNRS/...`**

The machine cannot reach GitHub: check the internet connection, a proxy, or
a firewall, then test with `git ls-remote https://github.com/IRL-Crossing-CNRS/LOTUSim`.

**Permission denied on `log/` during build**
```bash
sudo chown -R $USER:$USER ~/lotusim_ws
lotusim_core build
```

**`no GPU driver bridge`, or a camera / gpu_lidar takes the world down**

The graphics bridge is missing: see [Graphics bridge](#optional-graphics-bridge-rendering-sensors).

**Detection is slow**

The default scenario devshell runs the YOLO detection on the CPU. On a machine
with an NVIDIA GPU, write `gpu` to `~/.config/lotusim/devshell` (or re-run
the installer with `INSTALL_GPU=1`) and open a new `lotusim_shell`.

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
single flaky network moment while the submodules are fetched is enough), which
makes CMake configure fail with a cascade of *non-existent target OpticalFlow /
klt_feature_tracker* errors right after. Re-running this installer repairs it
automatically: it re-syncs and force-populates every submodule the build needs,
verifies none are left empty, and wipes the half-finished `build/` directory
before rebuilding. The manual equivalent, should you want it:
```bash
cd ~/PX4-Autopilot
git submodule update --init --recursive --force
rm -rf build && make px4_sitl gz_x500
```

**`apt-get update reported errors`**

A third-party apt repository on the machine (VS Code, Gazebo, an old ROS 2
entry...) failed to refresh, often an expired key. The script carries on: the
few packages it installs come from Ubuntu itself. Fix or remove that
repository's file in `/etc/apt/sources.list.d/` when convenient.
