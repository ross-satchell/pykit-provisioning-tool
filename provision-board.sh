#!/usr/bin/env bash
#
# PyKit Explorer - Board Provisioning Script (macOS / Linux)
# -------------------------------------------------------------
# Fully provisions a fresh PyKit Explorer board by downloading the code
# modules from Bitbucket and copying the runtime content onto the CIRCUITPY
# drive. No local copy of the repo and no Python install on the host
# machine are required.
#
# This OVERWRITES code.py, README.md, pykit_explorer.py, and the API,
# AudioFiles, Fonts, Images, and lib folders on CIRCUITPY.
# Intended for provisioning a brand-new board, NOT for updating a board a
# student has already been working on (it will wipe their code.py).
#
# Usage:
#   bash provision-board.sh
#   bash provision-board.sh --yes
#   bash provision-board.sh --ref v1.2.0

set -euo pipefail

BITBUCKET_HOST="bitbucket.microchip.com"
BITBUCKET_PROJECT="~c52467"
REPO_SLUG="pykit-explorer-code-modules"
REPO_REF="master"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) FORCE=1; shift ;;
    --ref) REPO_REF="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Content copied to the root of CIRCUITPY. Update these if the repo structure changes.
FOLDERS_TO_COPY=("API" "AudioFiles" "Fonts" "Images" "lib")
FILES_TO_COPY=("README.md" "code.py" "pykit_explorer.py")

echo "=== PyKit Explorer Board Provisioner ==="
echo "Source: $BITBUCKET_HOST/$BITBUCKET_PROJECT/$REPO_SLUG@$REPO_REF"

# --- 1. Find the CIRCUITPY drive ---------------------------------------------
DRIVE=""
OS_NAME="$(uname)"

if [[ "$OS_NAME" == "Darwin" ]]; then
  [[ -d "/Volumes/CIRCUITPY" ]] && DRIVE="/Volumes/CIRCUITPY"
else
  for candidate in "/media/$USER/CIRCUITPY" "/run/media/$USER/CIRCUITPY" "/mnt/CIRCUITPY" "/media/CIRCUITPY"; do
    [[ -d "$candidate" ]] && { DRIVE="$candidate"; break; }
  done
fi

if [[ -z "$DRIVE" ]]; then
  echo "No CIRCUITPY drive found."
  echo "Plug in the board and make sure it's mounted as CIRCUITPY, then try again."
  exit 1
fi

if [[ ! -f "$DRIVE/boot_out.txt" ]]; then
  echo "The drive at $DRIVE is named CIRCUITPY but doesn't look like a CircuitPython board (no boot_out.txt found)."
  echo "Aborting so we don't touch the wrong drive."
  exit 1
fi
echo "Found CircuitPython board at $DRIVE"

# --- 2. Confirm before doing anything destructive ----------------------------
if [[ "$FORCE" -ne 1 ]]; then
  echo ""
  echo "This will REPLACE the following on $DRIVE with the version from Bitbucket:"
  echo "  Folders: ${FOLDERS_TO_COPY[*]}"
  echo "  Files:   ${FILES_TO_COPY[*]}"
  echo "Any code or data currently in those folders/files on the board will be lost."
  read -r -p "Continue? (y/N) " answer
  case "$answer" in
    [Yy]*) ;;
    *) echo "Cancelled. No changes made."; exit 0 ;;
  esac
fi

# --- 3. Clone the source repo -------------------------------------------------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

REPO_URL="https://$BITBUCKET_HOST/scm/$BITBUCKET_PROJECT/$REPO_SLUG.git"
echo "Cloning $REPO_URL@$REPO_REF ..."
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_DIR/repo"
REPO_DIR="$TMP_DIR/repo"

# --- 4. Copy folders and files onto the drive --------------------------------
for folder in "${FOLDERS_TO_COPY[@]}"; do
  src="$REPO_DIR/$folder"
  if [[ ! -d "$src" ]]; then
    echo "Skipping '$folder' (not found in repo at $REPO_REF)"
    continue
  fi
  [[ -d "$DRIVE/$folder" ]] && rm -rf "$DRIVE/$folder"
  echo "Copying $folder ..."
  cp -R "$src" "$DRIVE/"
done

for file in "${FILES_TO_COPY[@]}"; do
  src="$REPO_DIR/$file"
  if [[ ! -f "$src" ]]; then
    echo "Skipping '$file' (not found in repo at $REPO_REF)"
    continue
  fi
  echo "Copying $file ..."
  cp "$src" "$DRIVE/"
done

# --- 5. Write provenance info (best-effort, never fails the run) ------------
SHA="$(git -C "$REPO_DIR" rev-parse HEAD | cut -c1-7)"

if [[ -n "$SHA" ]]; then
  echo "Provisioned from $BITBUCKET_HOST/$BITBUCKET_PROJECT/$REPO_SLUG@$REPO_REF (commit $SHA) on $(date '+%Y-%m-%d %H:%M:%S')" > "$DRIVE/PROVISION_INFO.txt"
else
  echo "Provisioned from $BITBUCKET_HOST/$BITBUCKET_PROJECT/$REPO_SLUG@$REPO_REF on $(date '+%Y-%m-%d %H:%M:%S')" > "$DRIVE/PROVISION_INFO.txt"
fi

echo ""
echo "Done! Board provisioned at $DRIVE"
