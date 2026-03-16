#!/usr/bin/env python3
"""
PilotMirror — GitHub Pages Deploy Script
Syncs web/ to the pilotmirror-survey repo and pushes.
Usage: python3 deploy.py
"""

import os, sys, shutil, subprocess
from pathlib import Path

SCRIPT_DIR   = Path(__file__).parent
WEB_DIR      = SCRIPT_DIR / "web"
PAGES_REPO   = Path.home() / "Claude Programming" / "pilotmirror-survey"
PAGES_REMOTE = "git@github.com:danielschreier3d/pilotmirror-survey.git"

def run(cmd, cwd=None):
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ {' '.join(cmd)}\n{result.stderr}")
        sys.exit(1)
    return result.stdout.strip()

def ensure_repo():
    if not PAGES_REPO.exists():
        print(f"  Klone {PAGES_REMOTE} ...")
        run(["git", "clone", PAGES_REMOTE, str(PAGES_REPO)])

def sync_files():
    files = sorted([f for f in WEB_DIR.rglob("*") if f.is_file() and not f.name.startswith(".")])
    for f in files:
        dest = PAGES_REPO / f.relative_to(WEB_DIR)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dest)
        print(f"  + {f.relative_to(WEB_DIR)}")

def deploy():
    ensure_repo()
    sync_files()

    status = run(["git", "status", "--porcelain"], cwd=PAGES_REPO)
    if not status:
        print("\n✅ Nichts zu deployen — bereits aktuell.")
        return

    run(["git", "add", "-A"], cwd=PAGES_REPO)
    run(["git", "commit", "-m", "deploy: sync web/ from PilotMirror"], cwd=PAGES_REPO)
    run(["git", "push"], cwd=PAGES_REPO)
    print("\n✅ Deploy erfolgreich!")
    print("🌐 https://danielschreier3d.github.io/pilotmirror-survey")

if __name__ == "__main__":
    print("📦 Deploy zu GitHub Pages ...")
    deploy()
