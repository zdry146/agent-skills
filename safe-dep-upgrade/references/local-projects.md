# Project Inventory Template and Exclusion Rules

> This is a **template**, not one machine's inventory. During Phase 0, scan your own
> codebase first, then fill in the "Project Inventory" table below — do not copy the
> example paths verbatim.

Verified on: <scan date>. Always defer to the actual scan result at execution time.

## Scope

Only `<WORKSPACE_ROOT>` and its subdirectories (`WORKSPACE_ROOT` = the codebase root for this task).

## Project Inventory

| Path (relative to `<WORKSPACE_ROOT>`) | Type | Test stack | Notes |
|---|---|---|---|
| `<project-dir>` | Maven / Spring Boot | spring-boot-starter-test | N test files |
| `<project-dir>/<frontend-dir>` | npm / React + Vite + TS | @playwright/test | node_modules not installed yet — run `npm ci` first |
| `<project-dir>` | Gradle (KTS) / Kotlin | junit-jupiter + mockk + assertj | consider adding `apiCheck` to pin the public API |
| `<project-dir>` | npm / API contract tests | Jest + spectral + contract | node_modules not installed yet — run `npm ci` first |

## Toolchain Baseline

JDK <version>, Node <version>, Maven <version>; Gradle follows each project's own wrapper version.

## Before Starting

For every project whose `node_modules` is not installed, run `npm ci` (not `npm install` — that mutates the lockfile), then establish the baseline.

## Exclusion Rules

- Every path outside `<WORKSPACE_ROOT>`: other checkouts, agent/editor config directories, and cache directories (`~/.cache/`, `~/.npm/`, `~/.local/share/`, `snap/`, and similar)
- Any path containing `node_modules/`, `target/`, `build/`, `dist/`, `.git/`, `.gradle/`, `.venv/`, `site-packages/`
- The tooling's own `package.json` (eslint, tsup, openclaw plugins, Claude Code extensions, and similar)
- Agent tool config directories (such as `.opencode/` and `.claude/`) — these are not business projects

## Known-Thin Projects

Projects with only 1-2 test files have very thin coverage, so the Phase 4 characterization-test work is the largest there — handle them first.
