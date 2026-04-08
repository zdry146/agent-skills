# Spring Batch 5.0 Migration Guide

## Core Requirements

- **Java 17+** required (Spring Framework 6 requirement)
- **Spring Framework 6**
- **Spring Integration 6**
- **Spring Data 3**
- **Spring AMQP 3**
- **Spring for Apache Kafka 3**
- **Micrometer 1.10**
- **Jakarta EE 9** (migrate `javax.*` → `jakarta.*`)
- **Hibernate 6**

## Dependency Changes

- `org.springframework:spring-jdbc` is now **required** dependency in `spring-batch-core`
- `junit:junit` is **no longer** a required dependency in `spring-batch-test`
- `jackson-core` is now **optional** in `spring-batch-core`

## Database / DDL Changes

### Oracle Sequences
- Sequences are now **ordered** by default
- New script: `org/springframework/batch/core/migration/5.0/migration-oracle.sql`
- Renamed DDL files:
  - `schema-drop-oracle10g.sql` → `schema-drop-oracle.sql`
  - `schema-oracle10g.sql` → `schema-oracle.sql`

### MS SQLServer
- Now uses **real sequences** instead of tables emulating sequences:
```sql
CREATE SEQUENCE BATCH_STEP_EXECUTION_SEQ START WITH 0 MINVALUE 0 MAXVALUE 9223372036854775807 NO CACHE NO CYCLE;
CREATE SEQUENCE BATCH_JOB_EXECUTION_SEQ START WITH 0 MINVALUE 0 MAXVALUE 9223372036854775807 NO CACHE NO CYCLE;
CREATE SEQUENCE BATCH_JOB_SEQ START WITH 0 MINVALUE 0 MAXVALUE 9223372036854775807 NO CACHE NO CYCLE;
```

### BATCH_JOB_EXECUTION Table
- `JOB_CONFIGURATION_LOCATION` column **removed** (JSR-352 removal)
- `JobExecution#jobConfigurationName` field **removed**

### BATCH_JOB_EXECUTION_PARAMS Table — Breaking Change
```sql
-- v4 (old)
TYPE_CD, KEY_NAME, STRING_VAL, DATE_VAL, LONG_VAL, DOUBLE_VAL

-- v5 (new)
PARAMETER_NAME, PARAMETER_TYPE, PARAMETER_VALUE, IDENTIFYING
```
Migration scripts in `org/springframework/batch/core/migration/5.0/`.

### BATCH_STEP_EXECUTION Table
- New column: `CREATE_TIME TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:01'`
- `START_TIME` no longer has NOT NULL constraint

## Removed: Map-Based JobRepository

Map-based implementations **removed** (deprecated in v4). Use `Jdbc-based JobRepository` instead.

## @EnableBatchProcessing Changes

- Does **not** expose a transaction manager bean anymore
- `BatchConfigurer` interface **removed** — custom transaction manager via:
  - Declarative: `@EnableBatchProcessing(transactionManager = ...)`
  - Programmatic: Override `DefaultBatchConfiguration#getTransactionManager()`

## Transaction Manager Configuration (Breaking)

`StepBuilderHelper#transactionManager()` moved to `AbstractTaskletStepBuilder`. Manual config required for tasklet steps.

**v4:**
```java
@Configuration
@EnableBatchProcessing
public class MyStepConfig {
    @Autowired private StepBuilderFactory stepBuilderFactory;
    @Bean public Step myStep() {
        return this.stepBuilderFactory.get("myStep").tasklet(..).build();
    }
}
```

**v5:**
```java
@Configuration
@EnableBatchProcessing
public class MyStepConfig {
    @Bean public Step myStep(JobRepository jobRepository, Tasklet myTasklet,
                             PlatformTransactionManager transactionManager) {
        return new StepBuilder("myStep", jobRepository)
            .tasklet(myTasklet, transactionManager) // or .chunk(chunkSize, transactionManager)
            .build();
    }
}
```

## JobBuilderFactory / StepBuilderFactory — Deprecated

No longer exposed as beans. Deprecated for removal in v5.2.

**v4:**
```java
@Autowired private JobBuilderFactory jobBuilderFactory;
return this.jobBuilderFactory.get("myJob").start(step).build();
```

**v5:**
```java
return new JobBuilder("myJob", jobRepository).start(step).build();
```

## JobParameters — Breaking Change

`JobParameter<T>` now supports **any type**, not just 4 predefined types (string/long/double/date).

- `ParameterType` enum **removed**
- `getType()` now returns `Class<T>` instead of `Object`
- Pre-defined type constructors **removed**

**v5 notation:**
```
parameterName=parameterValue,parameterType,identificationFlag
```
(`parameterType` = fully qualified class name)

**Extended notation (for complex values):**
```
parameterName='{"value": "v", "type":"com.foo.MyType", "identifying": "true"}'
```

**Caution:** Job instances launched with v4 cannot be restarted after migrating to v5. Complete or abandon all v4 failed job instances before migrating.

## Metric Changes

- Metric counters (`readCount`, `writeCount`, etc.) changed from `int` → `long`
- `skipCount` in `SkipPolicy#shouldSkip` changed from `int` → `long`
- `startTime`, `endTime`, `createTime`, `lastUpdated` → `LocalDateTime` (was `Date`)
- All meter tags now **prefixed with meter name** (e.g., `spring.batch.job.name` instead of `name`)
- `BatchMetrics` moved: `org.springframework.batch.core.metrics` → `org.springframework.batch.core.observability`

## ExecutionContextSerializer Change

- Default changed from `JacksonExecutionContextStringSerializer` → `DefaultExecutionContextSerializer`
- Jackson dependency now **optional**
- Serializes to/from **Base64** now

## SystemCommandTasklet Changes

- New `CommandRunner` strategy interface (default: `JvmCommandRunner`)
- Command now accepts `String[]` (no tokenization needed)

## ItemWriter API — Breaking Change

`ItemWriter#write(List)` → `ItemWriter#write(Chunk)`

All implementations updated to use `Chunk` instead of `List`.

## Chunk Class — Moved

`org.springframework.batch.core.step.item.Chunk` → `org.springframework.batch.item.Chunk`
(moved from `spring-batch-core` to `spring-batch-infrastructure`)

## ScopeConfiguration — Moved

`org.springframework.batch.core.configuration.annotation.ScopeConfiguration`
→ `org.springframework.batch.core.configuration.support.ScopeConfiguration`

## Removed APIs (No Deprecation)

- `MapJobRepositoryFactoryBean`, `MapExecutionContextDao`, `MapJobExecutionDao`, `MapJobInstanceDao`, `MapStepExecutionDao`
- `MapJobExplorerFactoryBean`
- `XStreamExecutionContextStringSerializer`
- `ClassPathXmlJobRegistry`, `ClassPathXmlApplicationContextFactory`
- `ScheduledJobParametersFactory`
- `AbstractNeo4jItemReader` (Neo4j removed entirely)
- `ListPreparedStatementSetter`
- `RemoteChunkingMasterStepBuilder`, `RemoteChunkingMasterStepBuilderFactory`
- `RemotePartitioningMasterStepBuilder`, `RemotePartitioningMasterStepBuilderFactory`
- `AbstractJobTests`, `StaxUtils`, `Alignment` enum
- `JobParameter.ParameterType` enum
- `JobExecution#stop()`
- `JobParameters#getDouble(String, double)`, `JobParameters#getLong(String, long)`
- `SimpleStepExecutionSplitter` constructors
- `AbstractCursorItemReader#cleanupOnClose()`
- `HibernateItemWriter#doWrite()`
- `JdbcCursorItemReader#cleanupOnClose()`
- `StoredProcedureItemReader#cleanupOnClose()`
- `HibernatePagingItemReaderBuilder#useSatelessSession()`
- `MultiResourceItemReader#getCurrentResource()`
- Batch Integration `@RemoteChunkingMasterStepBuilderFactory()`, `@RemotePartitioningMasterStepBuilderFactory()`
- `FileUtils#setUpOutputFile()`
- `SimpleStepBuilder#processor(Function)` — use `.processor(function::apply)` instead
- `RemotePartitioningManagerStepBuilder#transactionManager()`, `RemotePartitioningWorkerStepBuilder#transactionManager()` — not required for those step types

## Removed Products

- **SQLFire** support — EOL, removed
- **JSR-352** implementation — discontinued
- **Spring Data Geode** — removed (moved to `spring-batch-extensions` community repo)

## Return Type Changes

- `JobExplorer#getJobInstanceCount`, `JobInstanceDao#getJobInstanceCount`: `int` → `long`
- `JobRepository#getStepExecutionCount`, `StepExecutionDao#countStepExecutions`: `int` → `long`

## Deprecated APIs (Use Instead)

- `ChunkListenerSupport` → implement `ChunkListener`
- `StepExecutionListenerSupport` → implement `StepExecutionListener`
- `RepeatListenerSupport` → implement `RepeatListener`
- `JobExecutionListenerSupport` → implement `JobExecutionListener`
- `SkipListenerSupport` → implement `SkipListener`
- `Neo4jItemReader`, `Neo4jItemWriter` → removed (community extension)
- `JobRegistryBackgroundJobRunner`
- `DataSourceInitializer`
- `DelegateStep`
- `@Classifier` annotation
- `ItemStreamSupport`
- `AbstractTaskletStepBuilder#throttleLimit()`
- `TaskExecutorRepeatTemplate#setThrottleLimit()`
- `ResultHolder`, `ResultQueue`, `ResultHolderResultQueue`, `ThrottleLimitResultQueue`
- `JobParameters#toProperties()`
- `JobParametersBuilder#addParameter()`
