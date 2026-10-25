# 项目清单模板与排除规则

> 这是一份**模板**，不是某台机器的清单。执行阶段 0 时先按下面的方法扫描你自己的
> 代码库，再把扫描结果填进「项目清单」表——不要照抄示例里的路径。

核对日期：<扫描日期>。仍以执行时实际扫描结果为准。

## 范围

仅 `<WORKSPACE_ROOT>` 及其子目录（`WORKSPACE_ROOT` = 本次任务指定的代码库根目录）。

## 项目清单

| 路径（相对 `<WORKSPACE_ROOT>`）| 类型 | 测试栈 | 备注 |
|---|---|---|---|
| `<项目目录>` | Maven / Spring Boot | spring-boot-starter-test | 测试文件 N 个 |
| `<项目目录>/<前端子目录>` | npm / React + Vite + TS | @playwright/test | node_modules 未装，先 `npm ci` |
| `<项目目录>` | Gradle (KTS) / Kotlin | junit-jupiter + mockk + assertj | 可加 `apiCheck` 锁公开 API |
| `<项目目录>` | npm / API 契约测试 | Jest + spectral + contract | node_modules 未装，先 `npm ci` |

## 工具链基线

JDK <版本>、Node <版本>、Maven <版本>、Gradle 以各项目 wrapper 版本为准。

## 开工前必做

对 `node_modules` 未装的项目先 `npm ci`（不要 `npm install`，会污染 lockfile），再跑基线。

## 排除规则

- 不在 `<WORKSPACE_ROOT>` 范围内的所有路径：其他 checkout 目录、agent/编辑器配置目录、
  缓存目录（`~/.cache/`、`~/.npm/`、`~/.local/share/`、`snap/` 等）
- 路径含 `node_modules/`、`target/`、`build/`、`dist/`、`.git/`、`.gradle/`、`.venv/`、`site-packages/`
- 工具自身的 `package.json`（eslint、tsup、openclaw 插件、Claude Code 扩展等）
- agent 工具的配置目录（如 `.opencode/`、`.claude/`）——不是业务项目

## 已知薄弱项目

测试文件只有 1-2 个的项目覆盖很薄，阶段 4 的 characterization test 工作量最大，优先处理。
