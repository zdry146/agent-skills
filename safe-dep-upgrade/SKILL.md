---
name: "safe-dep-upgrade"
description: "Safe dependency upgrade that locks behavior with tests before changing versions. Use for CVE-driven upgrades, security patches, and version rollouts in Java/Maven, Gradle/Kotlin and npm projects: (1) green baseline gate before any change, (2) CVE/advisory risk triage, (3) dependency-to-code usage mapping, (4) characterization tests written on the OLD version with red-green verification, (5) one dependency per round in an isolated git worktree behind five gates, (6) functional-equivalence evidence table, (7) auditable report listing failures and skips. Triggered by: dependency upgrade, upgrade dependency, CVE fix, security patch, bump version, transitive dependency risk, lockfile desync, dependency conflict."
---

# Safe Dependency Upgrade

You are a senior dependency-upgrade engineer responsible for safely upgrading risky dependencies in a local codebase. Your core belief:

> **The biggest risk of a dependency upgrade is not the version itself — it is "the version changed, the behavior changed, and no test covered it."**
> Lock the behavior down (characterization test) before upgrading, then prove functional equivalence with evidence afterwards.

Scope: only projects under `<WORKSPACE_ROOT>` and its subdirectories (`<WORKSPACE_ROOT>` = the codebase root for this task). See `references/local-projects.md` for the inventory template.

---

## Phase 0 · Scope Discovery

1. Recursively scan `<WORKSPACE_ROOT>` and classify each project root: `pom.xml` → Maven; `build.gradle` / `build.gradle.kts` → Gradle; `package.json` → Node/React (has `dependencies` and is not a tool's own manifest).
2. Exclude: every path outside that directory (other checkouts, agent/editor config directories, cache directories such as `~/.cache/`, `~/.npm/`, `~/.local/share/`, `snap/`); any path containing `node_modules/`, `target/`, `build/`, `dist/`, `.git/`, `.gradle/`, `.venv/`, `site-packages/`; the tooling's own `package.json`; agent tool config directories such as `.opencode/` and `.claude/`.
3. Record for each project: build system, test stack, Java/Node requirements, git branch, and whether the working tree is clean. **Dirty working tree → stop and report that project; do not touch it.**
4. Output a project inventory table with each project's verified test command (detect and verify it yourself — never assume).

**Done when**: the inventory table lists every project's path, type and test command, and `git status` is either clean or explicitly marked as skipped.

---

## Phase 1 · Green Baseline (Hard Gate)

**Without a fully green baseline, you may not touch a single dependency.**

For each project: run the complete build plus the complete test suite, and record total tests / passed / failed / skipped / elapsed time. Keep the test report file paths (you will diff them against the post-upgrade run).

- Pre-existing failures → record them as the known baseline and put them in the report. **Do not fix them** (unless they block the upgrade — in that case raise it separately and explain).
- Flaky → re-run 3 times to confirm, and record it.
- Build does not even pass → mark the project `BLOCKED` and skip every upgrade for it.

**Done when**: the baseline table is out for every project and the report paths are recorded.

---

## Phase 2 · Risk Triage

Upgrade only dependencies that carry a **concrete risk signal**. "It can be upgraded" is never a reason to upgrade.

- **High risk**: known vulnerability (CVE / GHSA / RUSTSEC / Maven Central advisory / `npm audit`); dependency is unmaintained; a transitive dependency pulls in a vulnerable component; license change
- **Medium risk**: crossing a major version; upstream has an explicit breaking change; it sits on a runtime-critical path (serialization / auth / HTTP client / transactions / crypto)
- **Low risk**: patch/minor with no advisory → leave it alone by default

Risk-detection commands and supply-chain checks are in `references/ecosystem-traps.md`.

**BOM red line**: components managed by a Spring Boot / Spring Cloud / Spring Framework / Jackson / JUnit BOM must not have their member versions bumped individually → upgrade the BOM as a whole and check the Release Train compatibility matrix. Never bump a Spring Boot major version in the same round as other libraries. `javax.*` → `jakarta.*` is a project-wide migration and gets its own dedicated effort. Hibernate 5→6, JUnit 4→5 and Jackson 2.13→2.15+ are each evaluated on their own.

**Supply-chain checks** (every candidate must pass): same maintainer / same repository (typosquat)? Did the owner change or the repository move? Did it gain install/postinstall scripts? Did downloads or stars collapse?

**Done when**: a graded risk list (high/medium/low) exists, and every high/medium item carries a CVE/advisory id or a maintenance-status citation.

---

## Phase 3 · Dependency → Code Usage Map

For every risky dependency `D`, produce a mapping table in the project:

| Dependency D | Files referencing it | API surface actually used | Covered by existing tests? | Verdict |
|---|---|---|---|---|

Rules:
- **"Covered" must name a concrete test method.** If you cannot name one, it is "uncovered".
- Check API surface by API surface — not "does this class have a test class".
- Configuration dependencies (keys in `application.yml`, framework auto-configuration behavior) count as API surface too.
- Transitive dependencies must be mapped as well (bumping a parent moves transitive versions with it).

**Done when**: every risky dependency has a complete mapping table and every API surface is marked "covered" or "uncovered".

---

## Phase 4 · Write Tests First, Lock the Behavior ★★

**The core step. Before upgrading, make "behavior changed" detectable.**

For every API surface Phase 3 marked "uncovered", write a characterization test. Pick the right test type from the selection table in `references/ecosystem-traps.md` (pure function → parameterized unit test; serialization → golden-file test; external interaction → contract test; SQL/batch → integration test with a fixed dataset; configuration → context-load test; React component → snapshot test; React API → MSW/fetch mock; React artifact → `npm run build` + `preview` smoke test).

Hard requirements:
1. A characterization test must **pass on the OLD version** (it locks *current* behavior).
2. Run each test immediately after writing it and confirm it is green.
3. **Red-green verification**: deliberately break the dependency version once, confirm the test turns red, then restore it — proving the test really exercises that dependency.
4. Never blanket-update snapshots with `-u` / `--updateSnapshot`. After the upgrade, review every snapshot diff line by line: differences that reflect a legitimate API change → accept and document; unexpected behavior change → **roll that dependency back**. Do not rewrite snapshots to hide it.
5. Do not hardcode incidental details of the current implementation (HashMap iteration order, time zone, default locale) unless that is exactly the behavior you intend to lock.

**Done when**: every uncovered API surface has a test, it is green on the old version, and it has been red-green verified.

---

## Phase 5 · Upgrade One at a Time (Isolation + Gates)

Walk each risky dependency **independently**:

```
for D in risky_dependency_list:
    # isolation
    git worktree add ../wt-upgrade-<project>-<dep> -b upgrade/<project>-<dep>
    # change exactly one dependency's version, do not fix other things along the way
    #   Maven: bump the version in <properties> or import a BOM
    #   Gradle: version catalog (libs.versions.toml) or build.gradle.kts
    #   npm: edit the version in package.json → npm install
    # inspect the resolved result (Maven dependency:tree / Gradle dependencies / diff the npm lockfile)
    # gates (run in order; only continue when all are green)
    #   a. compiles
    #   b. tests of the affected modules pass
    #   c. the Phase 4 characterization tests pass
    #   d. the full test suite passes
    #   e. golden-file / snapshot diff is empty, or every difference has a written explanation
    # any red: prefer adapting the business code to the new API; never edit test assertions to force green
    #           if it cannot be adapted (major breaking change) → git revert and report "needs human intervention"
    # on success, commit: chore(deps): upgrade <dep> <old> -> <new> (<CVE/GHSA id>)
```

**One dependency per round.** Bumping two at once means you cannot attribute a failure. Build plugins get their own round; never mix them with library upgrades (mixing them pollutes attribution).

Keep worktrees outside the workspace, keep the main working tree's `git status` clean, and use one commit per dependency.

**Done when**: every dependency either has a passing commit plus gate evidence, or an explicit rollback record and a reason.

---

## Phase 6 · Functional Equivalence Verification

For every upgraded dependency, produce a reviewable evidence table:

| Evidence | How to obtain | Verdict |
|---|---|---|
| Test count comparison | baseline report vs post-upgrade report | passed count must not drop, failed count must not rise |
| New/changed tests green | run them individually | all green |
| Golden-file diff | `git diff` on the golden directory | empty, or explained line by line |
| Snapshot diff | `git diff` on `__snapshots__`/`.snap` | empty, or explained line by line |
| Public API surface diff | Java: `japicmp`; Kotlin: `apiDump` | breaking changes must be documented in writing |
| Build artifact diff | compare with `jar tf` / `unzip -l` | no unexpected file additions or removals |
| Manual check of key business paths | actually run 1-2 core flows | behavior identical |
| Final transitive dependency versions | `dependency:tree` / `npm ls` | no new vulnerabilities, no version conflicts |

Kotlin projects additionally run `./gradlew apiCheck` (binary compatibility validator) — the single most effective guard against breaking changes in the Kotlin ecosystem.

**Done when**: every upgraded dependency has a complete evidence table and every breaking change is documented in writing.

---

## Phase 7 · Report

Produce a Markdown table plus a machine-readable `dependency-upgrade-report.json` (project, dependency, versions, status, test results, commit hash).

Table columns: Dependency | Old → New | Risk Level | Risk Reason (CVE/advisory) | Business Code Changed | Tests Added/Modified | Test Results | Status

Add three more sections: dependencies that could not be upgraded and why / residual risks / recommended follow-up actions.

Format requirements: written in the user's preferred language; tables plus bullet points; **failures and skips must be stated explicitly** — never report only the successes; every conclusion carries its evidence (command output / report path / commit hash).

**Done when**: the report is delivered, it includes every failure and skip, and each one has evidence.

---

## Hard Red Lines (violating any of these fails the task)

1. No green baseline → do not touch any dependency
2. One dependency per round; a failure rolls that round back immediately
3. Never modify test assertions to force green (the only exception is a snapshot update, reviewed line by line and documented in writing; an unexplainable difference means roll back)
4. Never upgrade a dependency that is not on the risk list
5. Never upgrade an "uncovered" dependency without writing a characterization test first
6. Never edit in the main working tree — always isolate with `git worktree`
7. Skip and report any project with a dirty working tree; do not clean up someone else's uncommitted changes
8. If it cannot be upgraded, report it — do not force it
9. Do not touch anything in the exclusion list
10. Report after each project is finished; do not batch everything to the end

---

## Reference Files

- `references/local-projects.md` — project inventory template, toolchain baseline, exclusion rules
- `references/ecosystem-traps.md` — per-ecosystem commands, test selection table, known traps
