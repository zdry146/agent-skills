# Spring Batch 6.0 Migration Guide

## Core Requirements

- **Java 17+** (no change from v5)
- **Spring Framework 7**
- **Spring Integration 7**
- **Spring Data 4**
- **Spring AMQP 4**
- **Spring for Apache Kafka 4**
- **Micrometer 1.16**
- **Jackson 3.x** (upgraded from 2.x; 2.x deprecated)

## Batch Domain Model Redesign — Immutability

All entities (`JobInstance`, `JobExecution`, `StepExecution`, etc.) are now immutable:

- IDs cannot be re-assigned after construction
- IDs changed from `Long` wrapper to primitive `long` (nullability issues eliminated in JobRepository/JobOperator APIs)
- No orphan entities allowed (e.g. step execution requires parent job execution)
- No "shallow" entity queries — querying returns entity + siblings; retain references carefully
- Batch artifacts (readers/writers) must have dependencies specified at **construction time**, not via default constructors + setters
- `JobParameter` is now a **record** (immutable by design)

## JobParameter — v6 Breaking Change

`JobParameter` is now a **record** encapsulating the parameter name (previously it was a "nameless" value inside a `JobParameters` map).

- `JobParameters` now holds `Set<JobParameter>` instead of `Map<String, JobParameter>`
- Parameter name is now **part of** `JobParameter` itself
- Cannot restart failed v5 job instances with v6 (serialization format changed)

## JobParametersIncrementer Change

When a `JobParametersIncrementer` is attached to a job, v6 calculates next instance params **automatically** and ignores any user-supplied extra parameters (with a warning).

## @EnableBatchProcessing Changes

**v5:** `@EnableBatchProcessing(dataSourceRef = "batchDataSource", taskExecutorRef = "batchTaskExecutor")`

**v6:** Split into separate annotations:
```java
@EnableBatchProcessing(taskExecutorRef = "batchTaskExecutor")
@EnableJdbcJobRepository(dataSourceRef = "batchDataSource")
```
New annotations: `@EnableJdbcJobRepository`, `@EnableMongoJobRepository`

## Modular Configurations — Deprecated

`@EnableBatchProcessing(modular = true)` is **deprecated** (removal planned for v6.2). Use Spring context hierarchies + `GroupAwareJobs` instead:

```java
// Common batch config
@EnableBatchProcessing
@EnableJdbcJobRepository
public class CommonBatchConfiguration {
    @Bean public DataSource dataSource() { return new EmbeddedDatabaseBuilder()...build(); }
    @Bean public JdbcTransactionManager transactionManager(DataSource ds) { return new JdbcTransactionManager(ds); }
}

// Per-job context with parent
ApplicationContext baseContext = new AnnotationConfigApplicationContext(CommonBatchConfiguration.class);
AnnotationConfigApplicationContext fooContext = new AnnotationConfigApplicationContext(FooJobConfiguration.class);
fooContext.setParent(baseContext);
```

## DefaultBatchConfiguration Changes

**v5:** extends `DefaultBatchConfiguration` → configures JDBC by default

**v6:** 
- Use `JdbcDefaultBatchConfiguration` or `MongoDefaultBatchConfiguration`
- `DefaultBatchConfiguration` now configures **resourceless** infrastructure (no embedded DB needed for simple cases)

## JobExplorer / JobLauncher / JobRegistry Changes

- `JobExplorer` bean configuration **removed** — `JobRepository` now extends `JobExplorer` directly
- `JobLauncher` bean configuration **removed** — `JobOperator` now extends `JobLauncher`
- `JobRegistrySmartInitializingSingleton` removed — `MapJobRegistry` self-populates on startup
- `JobOperatorFactoryBean` transaction manager configuration is now **optional**

## Transaction Manager Configuration

**v5 (legacy, deprecated in v6):**
```java
new StepBuilder("myStep", jobRepository)
    .chunk(5, transactionManager)
    .build();
```

**v6 (new pattern):**
```java
new StepBuilder("myStep", jobRepository)
    .chunk(5)
    .transactionManager(transactionManager)
    .build();
```
Legacy form is deprecated but will remain for the entire v6 generation.

## Micrometer / Metrics Change

- **Global static meter registry removed** — must configure `ObservationRegistry` bean explicitly:
```java
@Bean
public ObservationRegistry observationRegistry(MeterRegistry meterRegistry) {
    ObservationRegistry reg = ObservationRegistry.create();
    reg.observationConfig().observationHandler(new DefaultMeterObservationHandler(meterRegistry));
    return reg;
}
```

## Jackson Upgrade

- Spring Batch 6 upgraded to **Jackson 3.x**
- Jackson 2.x support **deprecated** (will be removed in future release)
- Update your Jackson dependency to 3.x

## XML Namespace — Deprecated

`batch:` and `batch-integration:` XML namespaces are **deprecated** (removal planned for v7). Use Java config.

## BATCH_JOB_SEQ Renamed

`BATCH_JOB_SEQ` → `BATCH_JOB_INSTANCE_SEQ`

Migration scripts: `org/springframework/batch/core/migration/6.0/`

Note: DB2 LUW does not support `RENAME SEQUENCE` — use stored procedure or Java program instead.

## Package Moves (Major Refactoring)

| Old Package | New Package |
|------------|-------------|
| `org.springframework.batch.*` (infra module) | `org.springframework.batch.infrastructure.*` |
| `org.springframework.batch.core.explore` | `org.springframework.batch.core.repository.explore` |
| `org.springframework.batch.core.repository.dao.Jdbc*` | `org.springframework.batch.core.repository.dao.jdbc.*` |
| `org.springframework.batch.core.repository.dao.Mongo*` | `org.springframework.batch.core.repository.dao.mongo.*` |
| `org.springframework.batch.core.partition.support` | `org.springframework.batch.core.partition` |
| `org.springframework.batch.core.listener.*` | `org.springframework.batch.core.listener.*` (moved from core) |
| `org.springframework.batch.core.Job, JobExecution, JobInstance` | `org.springframework.batch.core.job.*` |
| `org.springframework.batch.core.JobParameters, JobParametersBuilder` | `org.springframework.batch.core.job.parameters.*` |
| `org.springframework.batch.core.Step, StepExecution` | `org.springframework.batch.core.step.*` |
| `org.springframework.batch.core.job.launch.support.RunIdIncrementer` | `org.springframework.batch.core.job.parameters.RunIdIncrementer` |
| `org.springframework.batch.core.job.launch.support.DataFieldMaxValueJobParametersIncrementer` | `org.springframework.batch.core.job.parameters.DataFieldMaxValueJobParametersIncrementer` |

## ChunkListener API Changes

`ChunkListener` methods now receive `ChunkContext` directly:
- `beforeChunk(ChunkContext)` / `afterChunk(ChunkContext)` / `afterChunkError(ChunkContext)`
- `Chunk` class skips/error methods deprecated (`getSkips()`, `getErrors()`, `skip()`, etc.)

## JobStep / JobLaunching Changes

- `JobStep#setJobLauncher(JobLauncher)` → `setJobOperator(JobOperator)`
- `JobStepBuilder#launcher(JobLauncher)` → `operator(JobOperator)`
- `JobLaunchingGateway(JobLauncher)` → `JobLaunchingGateway(JobOperator)`
- `SystemCommandTasklet#setJobExplorer(JobExplorer)` → `setJobRepository(JobRepository)`
- `RemoteStepExecutionAggregator(JobExplorer)` → `RemoteStepExecutionAggregator(JobRepository)`

## Removed: LobHandler Support

- `@EnableBatchProcessing` attribute `lobHandlerRef` removed
- XML attribute `lob-handler` in step element removed
- `JdbcExecutionContextDao#setLobHandler`, `JobRepositoryFactoryBean#setLobHandler`, `JobExplorerFactoryBean#setLobHandler` removed
- `DefaultBatchConfiguration#getLobHandler` removed

## JUnit 4 Support — Deprecated

`@SpringBatchTest` with JUnit 4 is deprecated. Upgrade to JUnit 5+.

## Removed APIs (No Deprecation)

- `DefaultBatchConfiguration#getLobHandler`
- `lobHandlerRef` attribute in `@EnableBatchProcessing`
- `lob-handler` XML attribute
- `ChunkListenerSupport`, `JobExecutionListenerSupport`, `SkipListenerSupport`, `StepExecutionListenerSupport`
- `RepeatListenerSupport`
- `AbstractTaskletStepBuilder#throttleLimit`
- `StepBuilder#throttleLimit`
- `TaskExecutorRepeatTemplate#setThrottleLimit`
- Mongo item reader/writer (removed)
- Neo4j item reader/writer (removed)
- `SqlWindowingPagingQueryProvider`
- `RemoteChunkingManagerStepBuilder`, `RemotePartitioningManagerStepBuilder`, `RemotePartitioningWorkerStepBuilder` (constructors and methods)
- `SystemPropertyInitializer`
- `JobRegistryBeanPostProcessor`
- `JobRepositoryFactoryBean` → renamed `JdbcJobRepositoryFactoryBean`
- `JobExplorerFactoryBean` → renamed `JdbcJobExplorerFactoryBean`

## Deprecated APIs (Use Instead)

- `SkipOverflowException`, `ForceRollbackForWriteSkipException`
- `StepLocatorStepFactoryBean`
- `FaultTolerantStepBuilder`, `SimpleStepBuilder`
- `ChunkMonitor`, `ChunkOrientedTasklet`, `ChunkProcessor`, `ChunkProvider`
- `DefaultItemFailureHandler`, `FaultTolerantChunkProcessor`, `FaultTolerantChunkProvider`
- `KeyGenerator`, `SimpleChunkProcessor`, `SimpleChunkProvider`
- `SimpleRetryExceptionHandler`, `LimitCheckingItemSkipPolicy`
- `BatchListenerFactoryHelper`, `BatchRetryTemplate`
- `TransactionAwareProxyFactory`
- `JobExplorer`, `SimpleJobExplorer` — use `JobRepository` directly
- `JobLauncher` — use `JobOperator`
- `JobLocator`, `ListableJobLocator`, `JobLoader`, `DefaultJobLoader`
- All `JobFactory`, `ApplicationContextFactory`, `AbstractApplicationContextFactory`, etc. (XML config related)
- `CommandLineJobRunner`, `JvmSystemExiter`, `SystemExiter`, `RuntimeExceptionTranslator`
- `StepBuilder#chunk(int, PlatformTransactionManager)` — use `.chunk(int).transactionManager(tm)`
- `StoppableTasklet#stop()`
- Many `JobOperator`/`SimpleJobOperator` methods (split into granular methods)
- `Chunk#*` methods (skips, errors, busy, userData)
- XML namespaces `batch:`, `batch-integration:` — use Java config

## Javadoc Location Change

Before: `https://docs.spring.io/spring-batch/docs/${version}/api/index.html`
After: `https://docs.spring.io/spring-batch/reference/${version}/api/index.html`
