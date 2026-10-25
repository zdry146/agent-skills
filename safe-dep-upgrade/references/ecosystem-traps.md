# Per-Ecosystem Commands, Test Selection and Traps

## Risk Detection Commands

```bash
# Maven
mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7   # needs an NVD API key, rate limited
mvn versions:display-dependency-updates                           # available upgrades
mvn versions:display-plugin-updates
mvn dependency:tree -Dverbose                                     # transitive dependency changes

# Gradle
./gradlew dependencyUpdates        # needs the ben-manes plugin
./gradlew dependencies --configuration runtimeClasspath
./gradlew dependencyInsight        # who pulls in a given dependency

# npm
npm audit --json
npm outdated --json
npm ls <pkg> --all                # transitive dependency chain
```

## Build and Test Commands

```bash
# Maven
mvn -q clean verify
mvn -Dtest=ClassName test
mvn -Dtest=ClassName#method test
mvn versions:use-latest-versions -DgenerateBackupPoms=true   # rewrites the pom automatically (review by hand afterwards)
mvn help:effective-pom                    # shows the pom that actually takes effect

# Gradle
./gradlew clean build
./gradlew test --tests "com.x.ClassName"
./gradlew apiDump apiCheck                # Kotlin binary compatibility
./gradlew buildHealth                     # dependency conflict diagnostics
./gradlew --write-locks

# npm / React
npm ci                                   # strict install from the lockfile
npm install <pkg>@<version>              # upgrade a single package
npx vitest run --coverage                # or npm test
npx vitest -u                            # snapshot update (must be reviewed line by line)
npm run build && npm run preview         # verify the production build
npx madge --circular                     # circular dependency check

# Generic
git worktree add ../wt-x -b upgrade/x
git diff --stat
```

## Phase 4 Test Selection Table

| Scenario | Test type | How |
|---|---|---|
| Pure function / transformation logic | Parameterized unit test | cover boundary values, nulls, error paths, special characters |
| Serialization / deserialization | Golden-file test (golden master) | write the current output to `src/test/resources/golden/xxx.json` and assert it matches the file byte for byte |
| External HTTP / DB / MQ interaction | Contract test | WireMock / MockWebServer with fixed requests and responses; assert request bodies and ordering |
| Version-sensitive boundary behavior | Contract test + explicit assertions | Jackson date formats, time zones, precision |
| SQL / batch processing | Integration test with a fixed dataset | assert the result set (use ordered assertions when order matters) |
| Configuration / auto-configuration | Context-load test | `@SpringBootTest` asserting the beans exist and key property values are correct |
| React component / rendering | Snapshot test | make sure existing snapshots cover the new branches; add them where they are missing |
| React API layer | MSW / fetch mock | fixed mock responses; assert request parameters and rendered output |
| React build artifact | Build verification | `npm run build` + `preview` smoke test (dev server ≠ production build) |
| API contract tests | Contract test | pin the OpenAPI spec + spectral lint + contract validation |

## Java / Spring Boot Traps

| Trap | Why it matters |
|---|---|
| BOM locking | versions managed by a Spring Boot / Spring Cloud / Jackson / JUnit BOM cannot be bumped individually |
| Release Train | Spring Cloud versions must match the Spring Boot version exactly (check the official compatibility matrix) |
| javax → jakarta | Spring Boot 2→3 is a project-wide migration, not "upgrading one dependency" |
| Hibernate 5→6 | `javax.persistence` → `jakarta.persistence`, dragging the whole Spring Data stack along |
| Jackson 2.13 → 2.15+ | align jackson-databind / core / annotations / datatype module versions |
| Mockito 5 | requires Java 11+, defaults to the inline mock maker, and final-class behavior changed |
| Old Surefire | old Surefire versions throw reflection warnings under JDK 21 — upgrade to 3.x |
| Logback 1.4 / Log4j 2.17+ | mitigates Log4Shell-style CVEs |
| SnakeYAML 2.0 | no longer supports arbitrary type construction by default (a security tightening) and can break YAML parsing |
| Netty version alignment | split transitive Netty versions must be managed explicitly |
| Boot 4 modular starters | Jackson is **no longer** in the default `spring-boot-starter` → add `spring-boot-starter-json` explicitly, otherwise `RestTemplate` has no JSON message converter and throws `UnknownContentTypeException` |
| Boot 4 BOM dropped `spring-retry` | no version is inherited any more → pin it explicitly (`2.0.13`); there is no `spring-boot-starter-retry` artifact to switch to |
| Boot 4.1.1 jackson gap | the 4.1.1 BOM ships jackson 3.1.5, below the 3.1.7 fix threshold (CVE-2026-91776) → import `tools.jackson:jackson-bom:3.1.7` explicitly. Jackson 3 lives under the `tools.jackson` groupId; `com.fasterxml:jackson-bom:3.1.7` does not exist (that is the Jackson 2 line, which 4.1.1 ships at 2.21.5) |
| Boot 4 health API move | `org.springframework.boot.actuate.health.{Health,HealthIndicator,Status}` → `org.springframework.boot.health.contributor.*` (extracted into the separate `spring-boot-health` module) |

## Kotlin / Gradle Traps

| Trap | Why it matters |
|---|---|
| Compiler ↔ stdlib version | the Kotlin compiler and stdlib must be the same version |
| KSP / KAPT plugin version | must match the Kotlin version or the compiler crashes |
| Gradle 8 → 9 | many plugins need adapting — one dedicated round, one dedicated verification |
| kotlinx-coroutines | coupled to the Kotlin version; watch the `-core` / `-core-jvm` variants |
| Binary compatibility | enable `binary-compatibility-validator`; `apiDump` pins the public API |
| JVM target | `jvmToolchain` and `kotlinOptions.jvmTarget` must agree |

## React / Node Traps

| Trap | Why it matters |
|---|---|
| React 18 → 19 | `react-dom/client` and `act()` changed source, ref is now a prop, string refs removed, `useFormState`→`useActionState`, `ref` is a prop by default so you need an explicit `ref` |
| react-router v6 → v7 | routing API changes, async loaders behave differently |
| Vite 5 → 6 → 7 → 8 | Node version requirements keep rising; CJS dependencies can break |
| ESLint 9 | flat config (`eslint.config.js`) is the default; `.eslintrc` must be migrated |
| @testing-library/react | only v16+ supports the React 19 peer range |
| Jest 29 → 30 / Vitest 1 → 2/3 | snapshot format, fake timers behavior and ESM support all changed |
| peer dependency conflicts | identify the real conflict first — do not paper over it with `--legacy-peer-deps` |
| lockfile reproducibility | `npm ci` requires the lockfile and package.json to be in sync; yarn `--immutable`; pnpm `--frozen-lockfile` |
| dev server ≠ production build | after an upgrade you must run `npm run build` + `preview` |
