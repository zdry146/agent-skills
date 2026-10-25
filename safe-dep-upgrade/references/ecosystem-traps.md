# 各生态命令、测试选型与陷阱

## 风险识别命令

```bash
# Maven
mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7   # 需 NVD API key，有速率限制
mvn versions:display-dependency-updates                           # 可升级版本
mvn versions:display-plugin-updates
mvn dependency:tree -Dverbose                                     # 传递依赖变化

# Gradle
./gradlew dependencyUpdates        # 需 ben-manes plugin
./gradlew dependencies --configuration runtimeClasspath
./gradlew dependencyInsight        # 某依赖被谁依赖

# npm
npm audit --json
npm outdated --json
npm ls <pkg> --all                # 传递依赖链
```

## 构建与测试命令

```bash
# Maven
mvn -q clean verify
mvn -Dtest=ClassName test
mvn -Dtest=ClassName#method test
mvn versions:use-latest-versions -DgenerateBackupPoms=true   # 自动改 pom（人工复核后用）
mvn help:effective-pom                    # 看最终生效的 pom

# Gradle
./gradlew clean build
./gradlew test --tests "com.x.ClassName"
./gradlew apiDump apiCheck                # Kotlin binary compatibility
./gradlew buildHealth                     # 依赖冲突诊断
./gradlew --write-locks

# npm / React
npm ci                                   # 按 lockfile 严格安装
npm install <pkg>@<version>              # 升级单个包
npx vitest run --coverage                # 或 npm test
npx vitest -u                            # 快照更新（必须逐条 review）
npm run build && npm run preview         # 验证生产构建
npx madge --circular                     # 循环依赖检查

# 通用
git worktree add ../wt-x -b upgrade/x
git diff --stat
```

## 阶段 4 测试选型表

| 场景 | 测试类型 | 做法 |
|---|---|---|
| 纯函数 / 转换逻辑 | 参数化单元测试 | 覆盖边界值、空值、异常路径、特殊字符 |
| 序列化 / 反序列化 | 黄金文件测试 (golden master) | 当前输出写进 `src/test/resources/golden/xxx.json`，断言与文件逐字节一致 |
| 外部 HTTP / DB / MQ 交互 | 契约测试 | WireMock / MockWebServer 固定请求与响应，断言请求体和顺序 |
| 依赖版本敏感的边界行为 | 契约测试 + 显式断言 | Jackson 日期格式、时区、精度 |
| SQL / 批处理 | 集成测试 + 固定数据集 | 断言结果集（顺序敏感时用有序断言） |
| 配置 / 自动装配 | 上下文加载测试 | `@SpringBootTest` 断言 Bean 存在与关键属性值 |
| React 组件 / 渲染 | 快照测试 | 已有 snapshot 的确保覆盖新分支；缺失的先补 |
| React API 层 | MSW / fetch mock | 固定 mock 响应，断言请求参数与渲染结果 |
| React 构建产物 | 构建验证 | `npm run build` + `npm run preview` 冒烟（dev server ≠ prod build） |
| API 契约测试 | 契约测试 | 固定 OpenAPI spec + spectral lint + contract 校验 |

## Java / Spring Boot 陷阱

| 陷阱 | 说明 |
|---|---|
| BOM 锁定 | Spring Boot / Spring Cloud / Jackson / JUnit BOM 管理的版本不能单独升 |
| Release Train | Spring Cloud 版本必须与 Spring Boot 严格匹配（查官方兼容矩阵）|
| javax → jakarta | Spring Boot 2→3 是全项目级迁移，不属于"升一个依赖" |
| Hibernate 5→6 | `javax.persistence` → `jakarta.persistence`，连带 Spring Data 全家桶 |
| Jackson 2.13 → 2.15+ | 需对齐 jackson-databind / core / annotations / datatype 模块版本 |
| Mockito 5 | 需要 Java 11+，默认 inline mock maker，final class 行为变了 |
| Surefire 旧版本 | JDK 21 下老 Surefire 会有反射告警，需升到 3.x |
| Logback 1.4 / Log4j 2.17+ | 缓解 Log4Shell 一类 CVE |
| SnakeYAML 2.0 | 默认不再支持任意类型构造（安全收紧），可能破坏 YAML 解析 |
| Netty 版本对齐 | 传递依赖版本分裂要显式管理 |

## Kotlin / Gradle 陷阱

| 陷阱 | 说明 |
|---|---|
| 编译器 ↔ stdlib 同版本 | Kotlin 编译器与 stdlib 版本必须一致 |
| KSP / KAPT 插件版本 | 必须与 Kotlin 版本匹配，否则编译期崩 |
| Gradle 8 → 9 | 大量插件需要适配，单独一轮，单独验证 |
| kotlinx-coroutines | 与 Kotlin 版本有耦合，注意 `-core` / `-core-jvm` 变体 |
| binary compatibility | 开 `binary-compatibility-validator`，`apiDump` 锁住公开 API |
| JVM target | `jvmToolchain` 与 `kotlinOptions.jvmTarget` 要一致 |

## React / Node 陷阱

| 陷阱 | 说明 |
|---|---|
| React 18 → 19 | `react-dom/client`、`act()` 来源变更、ref 作为 prop、移除 string ref、`useFormState`→`useActionState`、默认 `ref` 作为 prop 需显式 `ref` |
| react-router v6 → v7 | 路由 API 变更，异步 loader 行为不同 |
| Vite 5 → 6 → 7 → 8 | Node 版本要求提升；CJS 依赖可能出问题 |
| ESLint 9 | 默认 flat config（`eslint.config.js`），`.eslintrc` 需迁移 |
| @testing-library/react | v16 才支持 React 19 peer |
| Jest 29 → 30 / Vitest 1 → 2/3 | snapshot 格式、fake timers 行为、ESM 支持差异 |
| peer dep 冲突 | 先确认真冲突，不要直接 `--legacy-peer-deps` 糊过去 |
| lockfile 可重复性 | `npm ci` 要求 lockfile 与 package.json 同步；yarn `--immutable`；pnpm `--frozen-lockfile` |
| dev server ≠ prod build | 升级后必须 `npm run build` + `preview` 冒烟 |
