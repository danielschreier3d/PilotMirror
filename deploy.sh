#!/bin/bash
# PilotMirror — Deploy Script
# Syncs web/ to GitHub Pages. Run: bash deploy.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/deploy.py"
