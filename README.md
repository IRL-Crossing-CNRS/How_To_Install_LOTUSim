# LOTUSim Installation Guide

Automated installer for **LOTUSim Core** + **LOTUSim Generic Scenario**.

Supports:
- Ubuntu 24.04 → ROS 2 Jazzy

---

## Requirements

- Ubuntu 24.04 (fresh or existing install)
- Internet access
- `sudo` privileges

---

## Quick Install

```bash
chmod +x install_core_and_generic_scenario.sh
./install_core_and_generic_scenario.sh
```

The script will automatically:
1. Check that you are running Ubuntu 24.04 (ROS 2 Jazzy)
2. Install system dependencies (`git`, `jq`, `curl`, etc.)
3. Install Python dependencies (`pyarrow`, `pandas`, `matplotlib`, `opencv-python`)
4. Clone the LOTUSim core repository into `~/lotusim_ws`
5. Configure your `~/.bashrc` with all required environment variables
6. Run `lotusim install` to set up ROS 2 and Gazebo — **skipped if ROS 2 is
   already installed** (force with `FORCE_LOTUSIM_INSTALL=1 ./install_core_and_generic_scenario.sh`);
   an already-configured ROS 2 apt repository is also left untouched
7. Build the LOTUSim core workspace (provides `lotusim_msgs` needed by the scenario)
8. Clone and build the LOTUSim Generic Scenario workspace

---

## What Gets Installed

| Component | Location |
|---|---|
| LOTUSim Core | `~/lotusim_ws/src/LOTUSim` |
| Generic Scenario | `~/Documents/workspace/lotusim/LOTUSim-generic-scenario` |
| ROS 2 Jazzy | `/opt/ros/jazzy` |

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
- Skip cloning if repositories already exist (and pull latest changes instead)
- Refuse to reuse a directory whose git remote points at a different repository
- Skip `~/.bashrc` modifications if the LOTUSim block is already present
- Skip `lotusim install` and the core build when they are already done

---

## Troubleshooting

**Permission denied on `log/` during build**
```bash
sudo chown -R $USER:$USER ~/lotusim_ws
cd ~/lotusim_ws && colcon build --symlink-install
```

**Python import errors (`pyarrow`, `pandas`, etc.)**

Re-run the pip install manually:
```bash
pip3 install --break-system-packages pyarrow pandas matplotlib opencv-python
```

**`Conflicting values set for option Signed-By` during apt update**

A previous run added a legacy ROS apt entry alongside a modern `.sources` one.
Re-run the script — it removes the duplicate automatically.
