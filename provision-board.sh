#!/usr/bin/env bash
#
# PyKit Explorer - Board Provisioning Script (macOS / Linux)
# -------------------------------------------------------------
# Fully provisions a fresh PyKit Explorer board by downloading this repo
# straight from GitHub and copying the runtime content onto the CIRCUITPY
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

REPO_OWNER="CoffeeTronics"
REPO_NAME="PyKit-Explorer-Code-Modules"
REPO_REF="main"
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
echo "Source: $REPO_OWNER/$REPO_NAME@$REPO_REF"

download_to_file() {
  # $1 = url, $2 = output path
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    echo "Need curl or wget to download the repo, and neither was found." >&2
    exit 1
  fi
}

fetch_to_stdout() {
  # $1 = url. Best-effort: prints nothing if neither tool is available.
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" 2>/dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1" 2>/dev/null
  fi
}

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
  echo "This will REPLACE the following on $DRIVE with the version from GitHub:"
  echo "  Folders: ${FOLDERS_TO_COPY[*]}"
  echo "  Files:   ${FILES_TO_COPY[*]}"
  echo "Any code or data currently in those folders/files on the board will be lost."
  read -r -p "Continue? (y/N) " answer
  case "$answer" in
    [Yy]*) ;;
    *) echo "Cancelled. No changes made."; exit 0 ;;
  esac
fi

# --- 3. Download and extract the repo ----------------------------------------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/archive/$REPO_REF.tar.gz"
echo "Downloading $DOWNLOAD_URL ..."
download_to_file "$DOWNLOAD_URL" "$TMP_DIR/repo.tar.gz"

echo "Extracting..."
tar -xzf "$TMP_DIR/repo.tar.gz" -C "$TMP_DIR"

REPO_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "$REPO_DIR" ]]; then
  echo "Couldn't find extracted repo contents." >&2
  exit 1
fi

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
SHA_JSON="$(fetch_to_stdout "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits/$REPO_REF" || true)"
SHA="$(printf '%s' "$SHA_JSON" | grep '"sha"' | head -n 1 | sed -E 's/.*"sha": *"([^"]+)".*/\1/' | cut -c1-7 || true)"

if [[ -n "$SHA" ]]; then
  echo "Provisioned from $REPO_OWNER/$REPO_NAME@$REPO_REF (commit $SHA) on $(date '+%Y-%m-%d %H:%M:%S')" > "$DRIVE/PROVISION_INFO.txt"
else
  echo "Provisioned from $REPO_OWNER/$REPO_NAME@$REPO_REF on $(date '+%Y-%m-%d %H:%M:%S')" > "$DRIVE/PROVISION_INFO.txt"
fi

echo ""
echo "Done! Board provisioned at $DRIVE"
