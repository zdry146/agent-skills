---
name: spring-batch-5-migration
description: "Spring Batch 5.0 migration assistance. Use when upgrading Spring Batch from v4 to v5, including: (1) Java 17+ and Spring Framework 6 requirement checks, (2) Jakarta EE 9 migration (javax.* to jakarta.*), (3) dependency changes (spring-jdbc now required, jackson optional), (4) database/DDL changes (Oracle sequences, SQL Server sequences, BATCH_JOB_EXECUTION_PARAMS schema), (5) JobParameters API breaking changes, (6) @EnableBatchProcessing and transaction manager configuration, (7) ItemWriter write(Chunk) API, (8) removed deprecated/Map-based components, (9) Micrometer/metric changes. Triggered by: Spring Batch 5.0 migration, upgrade spring batch, spring batch 5 breaking changes, spring batch deprecated removed APIs."
---

# Spring Batch 5.0 Migration Skill

## Key Breaking Changes (Must-Know)

| Area | Change |
|------|--------|
| **Java** | 17+ required |
| **EE** | `javax.*` → `jakarta.*` |
| **JobParameters** | Now generic `<T>`; `ParameterType` enum removed; any type supported |
| **ItemWriter** | `write(List)` → `write(Chunk)` |
| **TransactionManager** | No longer auto-exposed by `@EnableBatchProcessing`; must be passed to tasklet/chunk step builders |
| **Map-based Repo** | Completely removed — use Jdbc-based only |
| **BatchConfigurer** | Removed — configure transaction manager via `@EnableBatchProcessing(transactionManager=...)` or override `DefaultBatchConfiguration#getTransactionManager()` |
| **JobBuilderFactory / StepBuilderFactory** | Deprecated; use `new JobBuilder(name, jobRepository)` / `new StepBuilder(name, jobRepository)` |
| **Metrics** | Counters `int`→`long`; meter tags prefixed (e.g. `spring.batch.job.name`); `BatchMetrics` package changed |

## Common Migration Patterns

### Tasklet Step with TransactionManager (v4 → v5)

```java
// v4 — transaction manager auto-exposed
@Configuration @EnableBatchProcessing
public class MyStepConfig {
    @Autowired private StepBuilderFactory stepBuilderFactory;
    @Bean public Step myStep() {
        return stepBuilderFactory.get("myStep").tasklet(..).build();
    }
}

// v5 — must inject and pass explicitly
@Configuration @EnableBatchProcessing
public class MyStepConfig {
    @Bean public Step myStep(JobRepository jobRepository, Tasklet myTasklet,
                             PlatformTransactionManager transactionManager) {
        return new StepBuilder("myStep", jobRepository)
            .tasklet(myTasklet, transactionManager)
            .build();
    }
}
```

### Job Definition (v4 → v5)

```java
// v4
@Autowired private JobBuilderFactory jobBuilderFactory;
return jobBuilderFactory.get("myJob").start(step).build();

// v5
return new JobBuilder("myJob", jobRepository).start(step).build();
```

### Job Parameters Notation (v4 → v5)

```properties
# v4
run.id(long)=1

# v5 (simple)
run=1,java.lang.Long,true

# v5 (extended, for complex types or values with commas)
run='{"value": "1", "type": "java.lang.Long", "identifying": "true"}'
```

## Full Reference

For detailed DDL changes, complete API deprecations/removals, Neo4j/JSR-352/SQLFire/Geode removal notes, and all return type changes, see:
→ `references/migration-guide.md`

## Pre-Migration Checklist

1. Java upgrade to 17+
2. Update dependencies: `spring-jdbc` (now required), remove `junit` if not needed
3. Migrate `javax.*` imports → `jakarta.*`
4. Switch to `JdbcJobRepository` (Map-based removed)
5. Update `ItemWriter` implementations: `write(Chunk<?>)` instead of `write(List<?>)`
6. Add transaction manager to all tasklet/chunk step definitions
7. Replace `JobBuilderFactory`/`StepBuilderFactory` usage with direct builders
8. Update job parameter notation and type handling
9. Run DDL migration scripts for your database
10. **All v4 failed job instances must be completed or abandoned before booting v5**
