#!/usr/bin/env python3
"""Generate a context snapshot for coding agents.

The snapshot captures:
- Git state (branch, commit hash, subject)
- Timestamp of generation
- Mission files
- Key scenes and scripts
- Automation assets (CI scripts, workflows)
- Documentation anchors
"""
from __future__ import annotations

import datetime
import subprocess
from pathlib import Path
from typing import Iterable, List

REPO_ROOT = Path(__file__).resolve().parent.parent
SNAPSHOT_PATH = REPO_ROOT / "context_snapshot.md"


def run_git(args: Iterable[str]) -> str:
    return subprocess.check_output(["git", *args], cwd=REPO_ROOT).decode("utf-8").strip()


def collect_paths(base: Path, patterns: tuple[str, ...]) -> List[str]:
    results: List[str] = []
    for pattern in patterns:
        for path in sorted(base.rglob(pattern)):
            if path.is_file():
                results.append(str(path.relative_to(REPO_ROOT)))
    return results


def build_section(title: str, items: Iterable[str]) -> str:
    lines = [f"## {title}"]
    any_item = False
    for item in items:
        any_item = True
        lines.append(f"- {item}")
    if not any_item:
        lines.append("- (none)")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    timestamp = datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat()
    try:
        branch = run_git(["rev-parse", "--abbrev-ref", "HEAD"])
    except subprocess.CalledProcessError:
        branch = "(detached HEAD)"
    commit_hash = run_git(["rev-parse", "HEAD"])
    commit_subject = run_git(["log", "-1", "--pretty=%s"])
    working_tree = run_git(["status", "--porcelain"])
    is_dirty = bool(working_tree)

    missions = collect_paths(REPO_ROOT / "docs" / "agents" / "missions", ("*.md",))
    scenes = collect_paths(REPO_ROOT / "scenes", ("*.tscn",))
    gd_scripts = collect_paths(REPO_ROOT / "scripts", ("*.gd",))
    gd_scripts += collect_paths(REPO_ROOT / "scripts", ("*.py",))
    gd_scripts = sorted(set(gd_scripts))
    ci_scripts = collect_paths(REPO_ROOT / "scripts" / "ci", ("*.gd",))
    tests = collect_paths(REPO_ROOT / "tests", ("*.gd",))
    docs = [
        "README.md",
        "CHANGELOG.md",
        "context_update.md",
        "docs/vibe_coding.md",
        "docs/tests/acceptance_tests.md",
        "docs/project_spec.md",
    ]
    workflows = collect_paths(REPO_ROOT / ".github" / "workflows", ("*.yml", "*.yaml"))

    content = [
        "# Context Snapshot",
        "",
        f"- Generated on: {timestamp.replace('+00:00', 'Z')}",
        f"- Branch: {branch}",
        f"- Commit when generated: {commit_hash}",
        f"- Subject: {commit_subject}",
        f"- Working tree dirty: {is_dirty}",
        "- Note: commit hash may differ once this file is included in a new commit.",
        "",
        build_section("Mission briefs", missions),
        build_section("Godot scenes", scenes),
        build_section("Scripts", gd_scripts),
        build_section("CI scripts", ci_scripts),
        build_section("Automated tests", tests),
        build_section("Key documentation", docs),
        build_section("GitHub workflows", workflows),
        "## Usage",
        "- Run `python scripts/generate_context_snapshot.py` after every merge or significant change.",
        "- Cross-check with `context_update.md` to understand in-flight work.",
        "",
    ]

    SNAPSHOT_PATH.write_text("\n".join(content), encoding="utf-8")


if __name__ == "__main__":
    main()
