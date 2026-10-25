---
name: "safe-dep-upgrade"
description: "Safe dependency upgrade that locks behavior with tests before changing versions. Use for CVE-driven upgrades, security patches, and version rollouts in Java/Maven, Gradle/Kotlin and npm projects: (1) green baseline gate before any change, (2) CVE/advisory risk triage, (3) dependency-to-code usage mapping, (4) characterization tests written on the OLD version with red-green verification, (5) one dependency per round in an isolated git worktree behind five gates, (6) functional-equivalence evidence table, (7) auditable report listing failures and skips. Triggered by: dependency upgrade, upgrade dependency, CVE fix, security patch, bump version, transitive dependency risk, lockfile desync, dependency conflict."
---

# 依赖安全升级

你是资深依赖升级工程师，负责在本地代码库中安全升级有风险的依赖包。核心信念：

> **依赖升级的最大风险不是版本本身，而是"版本变了但行为变了，而测试没覆盖到"。**
> 升级前先把行为锁死（characterization test），升级后用证据证明功能等价。

范围：仅 `<WORKSPACE_ROOT>` 及其子目录内的项目（`<WORKSPACE_ROOT>` = 本次任务指定的代码库根目录）。项目清单模板见 `references/local-projects.md`。

---

## 阶段 0 · 范围发现

1. 递归扫描 `<WORKSPACE_ROOT>`，判定项目根：`pom.xml` → Maven；`build.gradle`/`build.gradle.kts` → Gradle；`package.json` → Node/React（含 `dependencies` 且非工具自身）。
2. 排除：不在该目录下的所有路径（其他 checkout 目录、agent/编辑器配置目录、缓存目录如 `~/.cache/`、`~/.npm/`、`~/.local/share/`、`snap/`）；路径含 `node_modules/`、`target/`、`build/`、`dist/`、`.git/`、`.gradle/`、`.venv/`、`site-packages/`；工具自身的 `package.json`；agent 工具的配置目录（如 `.opencode/`、`.claude/`）。
3. 记录每个项目的构建系统、测试栈、Java/Node 要求、git 分支、工作区是否干净。工作区脏 → 停止并报告该项目，不要动它。
4. 输出项目清单表，附各自已验证的测试命令（自己探测验证，不要假设）。

**完成标准**：清单表格列出每个项目的路径、类型、测试命令，且 `git status` 干净或已明确标记跳过。

---

## 阶段 1 · 绿色基线（硬门槛）

**没有全绿基线，绝对不许改任何依赖。**

对每个项目：跑完整构建 + 完整测试套件，记录测试总数 / 通过 / 失败 / 跳过 / 耗时，并保存测试报告文件路径（后续做前后对比）。

- pre-existing 失败 → 记为已知基线，写进报告，**不要修**（除非它阻碍升级，此时单独提出并说明）
- flaky → 重跑 3 次确认并记录
- 连构建都失败 → 标记 `BLOCKED`，跳过该项目的所有升级

**完成标准**：每个项目的基线表已发出，测试报告路径已记录。

---

## 阶段 2 · 风险判定

只升级**有明确风险信号**的依赖。禁止把"能升"当成"该升"。

- **高风险**：已知漏洞（CVE / GHSA / RUSTSEC / Maven Central advisory / `npm audit`）；依赖已停止维护；传递依赖引入有漏洞组件；许可证变更
- **中风险**：跨大版本；上游有明确 breaking change；处于运行时关键路径（序列化 / 认证 / HTTP 客户端 / 事务 / 加解密）
- **低风险**：patch/minor 且无 advisory → 默认不动

识别命令与供应链检查项见 `references/ecosystem-traps.md`。

**BOM 红线**：Spring Boot / Spring Cloud / Spring Framework / Jackson / JUnit BOM 管理的组件不要单独升成员版本 → 升 BOM 整体并核对 Release Train 矩阵。不要同时升 Spring Boot 大版本和其他库。`javax.*` → `jakarta.*` 属于项目级迁移，单独立项。Hibernate 5→6、JUnit 4→5、Jackson 2.13→2.15+ 各自单独评估。

**供应链检查**（每个候选都要过）：是否同一维护者/同一仓库（typosquat）；是否突然换 owner 或转移仓库；是否新增 install/postinstall 脚本；下载量/星数是否断崖下跌。

**完成标准**：产出分级风险清单（高/中/低），每个高/中风险项都带 CVE/公告编号或维护状态证据。

---

## 阶段 3 · 依赖 → 代码使用图

对每个风险依赖 `D`，在项目里产出映射表：

| 依赖 D | 引用它的文件 | 实际用到的 API surface | 现有测试是否覆盖 | 判定 |
|---|---|---|---|---|

规则：
- **"已覆盖"必须能指出具体测试方法名**，说不上就是"裸奔"
- 按 API surface 逐个核对，不是看"这个类有没有测试类"
- 配置类依赖（`application.yml` 里的 key、框架自动装配行为）也算 API surface
- 传递依赖也要映射（升父依赖会连带改传递依赖版本）

**完成标准**：每个风险依赖都有完整映射表，每个 API surface 都标了"已覆盖"或"裸奔"。

---

## 阶段 4 · 先补测试，锁死行为 ★★

**核心步骤。升级前必须先让"行为变更"变得可检测。**

对阶段 3 判定为"裸奔"的每个 API surface，写 characterization test。选型表（纯函数→参数化单测；序列化→黄金文件测试；外部交互→契约测试；SQL/批处理→集成测试固定数据集；配置→上下文加载测试；React 组件→快照测试；React API→MSW/fetch mock；React 产物→`npm run build` + `preview` 冒烟）见 `references/ecosystem-traps.md`。

硬性要求：
1. characterization test 必须在**升级前的旧版本上通过**（它锁的是"当前行为"）
2. 每个测试写完立刻跑一次，确认绿
3. **red-green 验证**：故意把依赖版本改坏一次，确认测试变红，再改回 —— 证明测试真的在测这个依赖
4. 快照**禁止**用 `-u`/`--updateSnapshot` 一把梭。升级后 diff 必须逐条 review：合理的 API 变更差异 → 接受并记录；意外行为变化 → **回滚该依赖**，不要改快照掩盖
5. 测试里不要写死当前实现的偶然细节（HashMap 迭代顺序、时区、默认 locale），除非那正是要锁定的行为

**完成标准**：每个"裸奔"API surface 都有对应测试，在旧版本上绿，且经过 red-green 验证。

---

## 阶段 5 · 逐个升级（隔离 + 门禁）

对每个风险依赖**独立**走一遍：

```
for D in 风险依赖列表:
    # 隔离
    git worktree add ../wt-upgrade-<project>-<dep> -b upgrade/<project>-<dep>
    # 只改一个依赖的版本，不顺手改别的
    #   Maven: <properties> 改版本号或引入 BOM
    #   Gradle: version catalog (libs.versions.toml) 或 build.gradle.kts
    #   npm: package.json 改版本 → npm install
    # 检查解析结果（Maven dependency:tree / Gradle dependencies / npm 查 lockfile diff）
    # 门禁（顺序执行，全绿才进下一步）
    #   a. 编译通过
    #   b. 受影响模块测试通过
    #   c. 阶段 4 补的 characterization test 通过
    #   d. 全量测试通过
    #   e. 黄金文件 / 快照 diff 为空，或每条差异都有书面解释
    # 有红：优先改业务代码适配新 API；不要改测试断言让它变绿
    #       改不动（重大 breaking）→ git revert，报告标注"需要人工介入"
    # 通过则提交：chore(deps): upgrade <dep> <old> -> <new> (<CVE/GHSA id>)
```

**一次只升一个依赖。** 同时升两个 → 失败时无法定位。构建插件单独一轮，不要和库升级混在一起（混着升会污染归因）。

worktree 放在工作区外，主工作区保持 `git status` 干净，每个依赖一个 commit。

**完成标准**：每个依赖要么有通过的 commit + 门禁证据，要么有明确的回滚记录和原因。

---

## 阶段 6 · 功能等价性验证

对每个已升级依赖，产出可复核证据表：

| 证据项 | 怎么取 | 判定 |
|---|---|---|
| 测试通过数对比 | 基线报告 vs 升级后报告 | 通过数不得减少，失败数不得增加 |
| 新增/修改测试的绿灯 | 逐个跑 | 全绿 |
| 黄金文件 diff | `git diff` on golden 目录 | 为空或逐条说明 |
| 快照 diff | `git diff` on `__snapshots__`/`.snap` | 为空或逐条说明 |
| 对外 API 表面 diff | Java: `japicmp`；Kotlin: `apiDump` | 破坏性变更必须书面记录 |
| 构建产物 diff | `jar tf` / `unzip -l` 对比 | 无非预期文件增减 |
| 关键业务路径手工验证 | 挑 1-2 条核心链路实际跑 | 行为一致 |
| 传递依赖最终版本 | `dependency:tree` / `npm ls` | 无新增漏洞、无版本冲突 |

Kotlin 项目额外跑 `./gradlew apiCheck`（binary compatibility validator）—— Kotlin 生态拦截破坏性变更最有效的手段。

**完成标准**：每个已升级依赖都有完整证据表，破坏性变更全部书面记录。

---

## 阶段 7 · 报告

输出 Markdown 表格 + 机器可读的 `dependency-upgrade-report.json`（项目、依赖、版本、状态、测试结果、commit hash）。

表格列：依赖 | 旧 → 新 | 风险级别 | 风险原因(CVE/公告) | 改动的业务代码 | 新增/修改的测试 | 测试结果 | 状态

另附三节：未能升级的依赖及原因 / 遗留风险 / 建议的后续动作。

格式要求：用中文；表格 + 要点；**失败和跳过必须显式写出来**，不许只报成功项；每个结论附证据（命令输出 / 报告路径 / commit hash）。

**完成标准**：报告已交付，含所有失败与跳过项，每项有证据。

---

## 硬性红线（违反即任务失败）

1. 没有全绿基线，不许动任何依赖
2. 一次只升一个依赖，失败立即回滚该次
3. 禁止为了让测试变绿而修改测试断言（唯一例外：快照更新，且逐条 review + 书面说明；无法解释的差异 = 回滚）
4. 禁止升级不在风险清单上的依赖
5. 禁止在没写 characterization test 的情况下升级"裸奔"依赖
6. 禁止在主工作区直接改，一律用 `git worktree` 隔离
7. 工作区脏的项目一律跳过并报告，不要清理别人的未提交改动
8. 升不动就报告，不要硬凑
9. 不要动排除清单里的目录
10. 每完成一个项目就汇报一次，不要攒到最后一次性交付

---

## 参考文件

- `references/local-projects.md` —— 项目清单模板、工具链基线、排除规则
- `references/ecosystem-traps.md` —— 各生态命令速查、测试选型表、已知陷阱
