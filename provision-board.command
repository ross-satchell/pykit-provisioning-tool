#!/usr/bin/env bash
# Double-click entry point for macOS Finder.
# Equivalent to running: bash provision-board.sh
cd "$(dirname "$0")"
bash provision-board.sh
echo ""
read -n 1 -s -r -p "Press any key to close this window..."
echo ""
