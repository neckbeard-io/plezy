#!/usr/bin/env python3
import subprocess
import sys

FEATURE_NAMES = [
    "android-seeking-fix",
    "view-all-breaks-media",
    "per-episode-cast",
    "watched-refresh",
    "next-up-fixes",
    "season-show-long-press",
    "osd-focus-changes",
    "skip-credit-changes",
    "playlist-enhancements",
    "per-server-visibility",
]

def run(cmd, capture=True):
    res = subprocess.run(cmd, shell=True, text=True, capture_output=capture)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def find_latest_feature_branch(feat_name):
    code, out, _ = run(f"git branch --list '{feat_name}-*' --format='%(refname:short)'")
    if code == 0 and out:
        branches = [b.strip() for b in out.splitlines() if b.strip()]
        if branches:
            branches.sort()
            return branches[-1]
    return None

def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "2.19.1"
    print(f"=== Auditing 10 Plezy Custom Features against {target} ===")
    
    for feat in FEATURE_NAMES:
        branch = find_latest_feature_branch(feat)
        if not branch:
            print(f"[-] {feat}: no prior branch found!")
            continue
        # Get commit hash of feature
        code, commit, _ = run(f"git rev-parse {branch}")
        if code != 0:
            print(f"[-] {feat}: branch {branch} not found!")
            continue
            
        code, subject, _ = run(f"git log -n 1 --format=%s {branch}")
        
        # Test applying commit patch to target
        # Check if patch applies cleanly to target using git merge-tree or git apply
        code, touched_files, _ = run(f"git diff-tree --no-commit-id --name-only -r {branch}")
        file_list = " ".join(touched_files.split())
        code, upstream_touches, _ = run(f"git log testing-release-2026-08-26..{target} --oneline -- {file_list}")
        upstream_modified = len(upstream_touches.splitlines()) if upstream_touches else 0
        
        # We can test cherry-pick feasibility using git merge-tree
        # git merge-tree <base> <branch> <target>
        # base is the parent of the commit on branch
        code, parent, _ = run(f"git rev-parse {branch}~1")
        mt_code, mt_out, mt_err = run(f"git merge-tree {parent} {target} {branch}")
        has_conflict = ("+<<<<<<<" in mt_out or "CONFLICT" in mt_out or mt_code != 0)
        
        print(f"\nFeature: {feat}")
        print(f"  Source Commit: {commit[:8]} ('{subject}')")
        print(f"  Upstream Activity: {upstream_modified} commit(s) touched related files since last sync")
        if upstream_touches:
            for line in upstream_touches.splitlines()[:3]:
                print(f"    * {line}")
            if upstream_modified > 3:
                print(f"    * ... and {upstream_modified - 3} more")
        
        if not has_conflict:
            print(f"  Merge-Tree Status: CLEAN (Rebases cleanly with zero conflicts)")
        else:
            print(f"  Merge-Tree Status: CONFLICT DETECTED")

if __name__ == "__main__":
    main()
