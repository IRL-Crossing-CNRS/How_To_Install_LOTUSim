#!/usr/bin/env bash

set -e 

echo "============================================================="
echo " LOTUSim full setup script starting: Core + Generic Scenario"
echo "============================================================="

# -----------------------------
# Variables - Fixed for Case Sensitivity
# -----------------------------
# We use the exact name found in your ls: LOTUSim
export LOTUSIM_WS="$HOME/lotusim_ws"
export LOTUSIM_SRC="$LOTUSIM_WS/src"
export LOTUSIM_PATH="$LOTUSIM_SRC/LOTUSim"
export SCENARIO_WS="$HOME/Documents/workspace/lotusim"

# -----------------------------
# Install system dependencies
# -----------------------------
echo "🔧 Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y git jq

# -----------------------------
# Create workspace and clone LOTUSim
# -----------------------------
echo "📁 Creating LOTUSim workspace..."
mkdir -p "$LOTUSIM_SRC"
cd "$LOTUSIM_SRC"

if [ ! -d "LOTUSim" ]; then
  echo "⬇️  Cloning LOTUSim core repository..."
  git clone https://github.com/IRL-Crossing-CNRS/LOTUSim
else
  echo "✅ LOTUSim repository already exists, skipping clone"
fi

# -----------------------------
# Bashrc configuration
# -----------------------------
echo "📝 Updating ~/.bashrc..."
BASHRC_MARKER="# >>> LOTUSim setup >>>"

if ! grep -q "$BASHRC_MARKER" ~/.bashrc; then
cat <<EOF >> ~/.bashrc
$BASHRC_MARKER
export LOTUSIM_WS=\$HOME/lotusim_ws
export LOTUSIM_PATH=\$LOTUSIM_WS/src/LOTUSim
export PATH=\$LOTUSIM_PATH/physics:\$LOTUSIM_PATH/launch:\$PATH
export LD_LIBRARY_PATH=\$LOTUSIM_PATH/physics
export LOTUSIM_MODELS_PATH=\$LOTUSIM_PATH/assets/models/
source \$LOTUSIM_PATH/launch/bash_completion.sh
# <<< LOTUSim setup <<<
EOF
  echo "✅ ~/.bashrc updated"
else
  echo "ℹ️  ~/.bashrc already contains LOTUSim config, skipping"
fi

# IMPORTANT: Ensure the CURRENT session has the variables
export PATH="$LOTUSIM_PATH/physics:$LOTUSIM_PATH/launch:$PATH"
export LD_LIBRARY_PATH="$LOTUSIM_PATH/physics"

# -----------------------------
# Permissions
# -----------------------------
echo "🔑 Making launch scripts executable..."
# We use the variable here which now matches the 'LOTUSim' folder exactly
if [ -d "$LOTUSIM_PATH/launch" ]; then
    chmod -R +x "$LOTUSIM_PATH/launch"
else
    echo "❌ Still cannot find $LOTUSIM_PATH/launch"
    echo "Current directory: $(pwd)"
    echo "Directory content:"
    ls -F
    exit 1
fi

# -----------------------------
# Install LOTUSim dependencies
# -----------------------------
echo "📦 Running lotusim install..."
cd "$LOTUSIM_PATH/launch"

# Using sudo -E to preserve LOTUSIM_PATH so lotusim can find install_dep.sh
sudo -E ./lotusim install

# -----------------------------
# Scenario workspace
# -----------------------------
echo "📁 Creating scenario workspace..."
mkdir -p "$SCENARIO_WS"
cd "$SCENARIO_WS"

if [ ! -d "LOTUSim-generic-scenario" ]; then
  git clone --recurse-submodules https://github.com/IRL-Crossing-CNRS/LOTUSim-generic-scenario
fi
cd LOTUSim-generic-scenario
git submodule update --remote --merge

# -----------------------------
# Build
# -----------------------------
# Source ROS which was just installed by the 'lotusim install' command
source /opt/ros/humble/setup.bash

if [ -f "$LOTUSIM_WS/install/setup.bash" ]; then
    source "$LOTUSIM_WS/install/setup.bash"
fi

echo "🏗️ Building LOTUSim generic scenario..."
cd "$SCENARIO_WS/LOTUSim-generic-scenario"
colcon build --symlink-install
source install/setup.bash
pwd

echo "=================================================================="
echo " 🎉 LOTUSim Setup Completed!"
echo "=================================================================="