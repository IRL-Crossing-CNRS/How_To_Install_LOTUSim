#!/usr/bin/env bash
# =============================================================================
#  LOTUSim Deployment Folder Updater
#
#  Assumes install_core_and_generic_scenario.sh has already been run once.
#  This script:
#    1. Updates LOTUSim core and LOTUSim-generic-scenario on
#       whatever branch they are currently checked out on (no branch switch)
#    2. Runs deployment/build_wheels.sh in the generic scenario repo
#    3. Syncs only the build output (dist/ + any sensor folders / folders
#       containing wheels) into ~/Documents/workspace/deployment, overwriting
#       just those, and leaving everything else in that folder untouched so
#       the user doesn't lose their local work.
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}ℹ  $*${NC}"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
die()     { echo -e "${RED}❌ $*${NC}" >&2; exit 1; }

ros_source() {
  local setup_file="$1"
  set +u +e
  # shellcheck source=/dev/null
  source "$setup_file"
  set -u -e
}

# -----------------------------------------------------------------------------
# Same paths as install_core_and_generic_scenario.sh
# -----------------------------------------------------------------------------
LOTUSIM_WS="$HOME/lotusim_ws"
LOTUSIM_PATH="$LOTUSIM_WS/src/LOTUSim"
SCENARIO_WS="$HOME/Documents/workspace/lotusim"
SCENARIO_PATH="$SCENARIO_WS/LOTUSim-generic-scenario"
DEPLOYMENT_SRC="$SCENARIO_PATH/deployment"
DEPLOYMENT_DEST="$HOME/Documents/workspace/deployment"

ROS_DISTRO="${ROS_DISTRO:-jazzy}"
ROS_SETUP="/opt/ros/${ROS_DISTRO}/setup.bash"

[[ -d "$LOTUSIM_PATH/.git" ]] \
  || die "$LOTUSIM_PATH not found. Run install_core_and_generic_scenario.sh first."
[[ -d "$SCENARIO_PATH/.git" ]] \
  || die "$SCENARIO_PATH not found. Run install_core_and_generic_scenario.sh first."

echo "============================================================="
echo "  LOTUSim deployment folder update"
echo "============================================================="

# -----------------------------------------------------------------------------
# Update a repo on whatever branch it currently is (no branch switch).
# -----------------------------------------------------------------------------
update_repo_current_branch() {
  local dir="$1" name="$2"
  local branch
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    warn "$name is in a detached HEAD state -- skipping update, using it as-is"
    return
  fi

  info "Updating $name (branch: ${branch})..."
  git -C "$dir" fetch origin "$branch" 2>/dev/null \
    || { warn "Could not fetch $name (network issue?); continuing with existing version"; return; }
  git -C "$dir" merge --ff-only "origin/$branch" 2>/dev/null \
    || warn "Could not fast-forward $name on branch ${branch} (local changes?); continuing with existing version"
  success "$name up to date on branch ${branch}"
}

update_repo_current_branch "$LOTUSIM_PATH" "LOTUSim"
update_repo_current_branch "$SCENARIO_PATH" "LOTUSim-generic-scenario"

info "Updating scenario submodules..."
git -C "$SCENARIO_PATH" submodule update --init --remote --merge
success "Submodules up to date"

# -----------------------------------------------------------------------------
# Build wheels
# -----------------------------------------------------------------------------
[[ -d "$DEPLOYMENT_SRC" ]] \
  || die "$DEPLOYMENT_SRC not found. Check the LOTUSim-generic-scenario repo structure."
[[ -f "$DEPLOYMENT_SRC/build_wheels.sh" ]] \
  || die "$DEPLOYMENT_SRC/build_wheels.sh not found."

# Source ROS + core overlay in case build_wheels.sh relies on them (harmless
# no-op if it doesn't).
[[ -f "$ROS_SETUP" ]] && ros_source "$ROS_SETUP"
[[ -f "$LOTUSIM_WS/install/setup.bash" ]] && ros_source "$LOTUSIM_WS/install/setup.bash"

info "Building deployment wheels..."
chmod +x "$DEPLOYMENT_SRC/build_wheels.sh"
( cd "$DEPLOYMENT_SRC" && ./build_wheels.sh )
success "Deployment wheels built"

# -----------------------------------------------------------------------------
# Sync only the build output (dist/ + sensor / wheel-bearing folders) into
# ~/Documents/workspace/deployment. Each target folder is fully overwritten
# (rsync --delete), everything else already in DEPLOYMENT_DEST is left alone.
# -----------------------------------------------------------------------------
command -v rsync &>/dev/null || sudo apt-get install -y --no-install-recommends rsync

SYNC_TARGETS=()
add_target() {
  local t="$1"
  for existing in "${SYNC_TARGETS[@]:-}"; do
    [[ "$existing" == "$t" ]] && return
  done
  SYNC_TARGETS+=("$t")
}

[[ -d "$DEPLOYMENT_SRC/dist" ]] && add_target "dist"

while IFS= read -r -d '' entry; do
  name="$(basename "$entry")"
  if [[ "$name" =~ [Ss][Ee][Nn][Ss][Oo][Rr] ]]; then
    add_target "$name"
  elif find "$entry" -maxdepth 3 -name '*.whl' -print -quit | grep -q .; then
    add_target "$name"
  fi
done < <(find "$DEPLOYMENT_SRC" -mindepth 1 -maxdepth 1 -type d -print0)

[[ ${#SYNC_TARGETS[@]} -gt 0 ]] \
  || die "No dist/ folder or wheel-bearing folders found under $DEPLOYMENT_SRC after build."

mkdir -p "$DEPLOYMENT_DEST"
info "Syncing into ${DEPLOYMENT_DEST}: ${SYNC_TARGETS[*]}"
for target in "${SYNC_TARGETS[@]}"; do
  mkdir -p "$DEPLOYMENT_DEST/$target"
  rsync -a --delete "$DEPLOYMENT_SRC/$target/" "$DEPLOYMENT_DEST/$target/"
  success "Updated ${DEPLOYMENT_DEST}/${target}"
done

echo ""
echo "=================================================================="
echo "  Deployment folder update complete!"
echo "  Updated: ${SYNC_TARGETS[*]}"
echo "  Location: ${DEPLOYMENT_DEST}"
echo "  (rest of the folder left untouched)"
echo "=================================================================="
