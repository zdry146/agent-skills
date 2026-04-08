---
name: spring-batch-6-migration
description: "Spring Batch 6.0 migration assistance. Use when upgrading Spring Batch from v5 to v6, including: (1) domain model immutability redesign, (2) JobParameter as a record, (3) @EnableBatchProcessing split into @EnableJdbcJobRepository or @EnableMongoJobRepository, (4) JdbcDefaultBatchConfiguration replaces DefaultBatchConfiguration, (5) JobExplorer and JobLauncher beans removed (JobRepository extends JobExplorer, JobOperator extends JobLauncher), (6) Micrometer global registry removed (ObservationRegistry required), (7) Jackson 3.x required (2.x deprecated), (8) package refactoring across org.springframework.batch.core.*, (9) transaction manager fluent API changed. Triggered by: Spring Batch 6.0 migration, upgrade spring batch 6, spring batch 6 breaking changes."
---

# Spring Batch 6.0 Migration Skill

## Key Breaking Changes (Must-Know)

| Area | Change |
|------|--------|
| **Domain Model** | Entities immutable; IDs `Long`→`long`; orphan entities impossible |
| **JobParameter** | Now a **record**; name encapsulated inside; `JobParameters` holds `Set<JobParameter>` |
| **@EnableBatchProcessing** | Split: `@EnableJdbcJobRepository` / `@EnableMongoJobRepository` replace `dataSourceRef` attribute |
| **DefaultBatchConfiguration** | Replaced by `JdbcDefaultBatchConfiguration` / `MongoDefaultBatchConfiguration` |
| **JobExplorer/JobLauncher beans** | Removed — `JobRepository` extends `JobExplorer`, `JobOperator` extends `JobLauncher` |
| **Transaction Manager** | Fluent: `.chunk(n, tm)` → `.chunk(n).transactionManager(tm)` |
| **Micrometer** | Global static registry removed — define `ObservationRegistry` bean explicitly |
| **Jackson** | 3.x required; 2.x deprecated |
| **Package moves** | Major reorganization across `org.springframework.batch.core.*` packages |

## Cannot Mix v5 and v6

Failed v5 job instances **cannot** be restarted with v6. Complete or abandon all v5 failures before booting v6.

## Common Migration Patterns

### JDBC Job Repository Config (v5 → v6)

```java
// v5
@EnableBatchProcessing(dataSourceRef = "batchDataSource", taskExecutorRef = "batchTaskExecutor")
class MyJobConfiguration {
    @Bean public Job job(JobRepository jobRepository) {
        return new JobBuilder("job", jobRepository)...build();
    }
}

// v6
@EnableBatchProcessing(taskExecutorRef = "batchTaskExecutor")
@EnableJdbcJobRepository(dataSourceRef = "batchDataSource")
class MyJobConfiguration {
    @Bean public Job job(JobRepository jobRepository) {
        return new JobBuilder("job", jobRepository)...build();
    }
}
```

### DefaultBatchConfiguration (v5 → v6)

```java
// v5
class MyJobConfiguration extends DefaultBatchConfiguration { ... }

// v6
class MyJobConfiguration extends JdbcDefaultBatchConfiguration { ... }
```

### Transaction Manager on Step (v5 legacy → v6 new)

```java
// v5 legacy (deprecated in v6)
new StepBuilder("myStep", jobRepository)
    .chunk(5, transactionManager)
    .build();

// v6 new
new StepBuilder("myStep", jobRepository)
    .chunk(5)
    .transactionManager(transactionManager)
    .build();
```

### ObservationRegistry (v5 → v6)

```java
// v6 — must define ObservationRegistry bean
@Bean
public ObservationRegistry observationRegistry(MeterRegistry meterRegistry) {
    ObservationRegistry reg = ObservationRegistry.create();
    reg.observationConfig()
       .observationHandler(new DefaultMeterObservationHandler(meterRegistry));
    return reg;
}
```

## Full Reference

For complete list of package moves, removed/deprecated APIs, DDL changes, JobOperator method changes, and ChunkListener API changes, see:
→ `references/migration-guide.md`

## Pre-Migration Checklist

1. Complete or abandon all failed v5 job instances
2. Upgrade Jackson dependency to 3.x
3. Update `@EnableBatchProcessing` → add `@EnableJdbcJobRepository` or `@EnableMongoJobRepository`
4. Change `DefaultBatchConfiguration` → `JdbcDefaultBatchConfiguration` or `MongoDefaultBatchConfiguration`
5. Remove `JobExplorer` / `JobLauncher` bean definitions (`JobRepository`/`JobOperator` now provide these)
6. Define `ObservationRegistry` bean for metrics
7. Update `.chunk(n, tm)` → `.chunk(n).transactionManager(tm)` (or keep deprecated form for v6)
8. Update all `javax.persistence` / `jakarta.persistence` imports if affected
9. Run DDL migration scripts from `org/springframework/batch/core/migration/6.0/`
10. Update JUnit 4 → JUnit 5+ (`@SpringBatchTest` JUnit 4 mode deprecated)
