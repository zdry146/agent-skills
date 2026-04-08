# Spring Boot 3.0 Migration Guide — Detailed Reference

## Before You Start

### 1. Upgrade to Latest 2.7.x
Before migrating to 3.0, upgrade to the latest available 2.7.x version to ensure you have the most recent dependencies of that line.

### 2. Review Dependencies
Compare dependency management:
- [2.7.x dependency management](https://docs.spring.io/spring-boot/docs/2.7.x/reference/html/dependency-versions.html)
- [3.0.x dependency management](https://docs.spring.io/spring-boot/docs/3.0.x/reference/html/dependency-versions.html)

### 3. System Requirements
- **Java 17 or later** (Java 8 is no longer supported)
- **Spring Framework 6.0**

### 4. Migration Tools
- OpenRewrite recipes
- Spring Boot Migrator project
- IntelliJ IDEA migration support

---

## Jakarta EE Migration

### Dependency Changes
```
javax.servlet:jakarta.servlet-api → jakarta.servlet:jakarta.servlet-api
javax.persistence → jakarta.persistence
javax.mail → jakarta.mail
```

### Tools
- OpenRewrite can automate many `javax` → `jakarta` transformations

---

## Core Changes

### Image Banner Support Removed
`banner.gif`, `banner.jpg`, `banner.png` are now ignored. Replace with `banner.txt`.

### Logging Date Format
```
# Old: yyyy-MM-dd HH:mm:ss.SSS
# New: yyyy-MM-dd'T'HH:mm:ss.SSSXXX (ISO-8601)
# Restore old format:
logging.pattern.dateformat=yyyy-MM-dd HH:mm:ss.SSS
```

### @ConstructorBinding
No longer needed at type level on `@ConfigurationProperties`. Use `@Autowired` if relying on constructor autowiring.

### YamlJsonParser Removed
Migrate to other JsonParser implementations if directly using YamlJsonParser.

### Auto-configuration Files
```
# v2.7 — META-INF/spring.factories
org.springframework.boot.autoconfigure.EnableAutoConfiguration=...

# v3.0 — META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
```

---

## Web Application Changes

### Spring MVC/WebFlux URL Matching
Trailing slash no longer matches by default:
```
GET /greeting        → matches
GET /greeting/       → 404 (was 200 in v2.x)
```

### Jetty
Jetty does not support Servlet 6.0. Downgrade to Servlet 5.0:
```properties
jakarta-servlet.version=5.0
```

### Apache HttpClient
Support removed in Spring Framework 6.0. Use `org.apache.httpcomponents.client5:httpclient5`.

### Graceful Shutdown Phases
- Start: `SmartLifecycle.DEFAULT_PHASE - 2048`
- Web server stop: `SmartLifecycle.DEFAULT_PHASE - 1024`

---

## Actuator Changes

### JMX Endpoint Exposure
Only `health` exposed by default (aligns with web exposure).

### httptrace → httpexchanges
Renamed due to Micrometer Tracing support confusion.

### Actuator JSON
Uses isolated ObjectMapper. Set `management.endpoints.jackson.isolated-object-mapper=false` to revert.

### Sanitization
All values masked by default. Configurable via:
```
management.endpoint.env.show-values=NEVER|ALWAYS|WHEN_AUTHORIZED
management.endpoint.configprops.show-values=NEVER|ALWAYS|WHEN_AUTHORIZED
```

---

## Micrometer & Metrics Changes

### TagProvider/TagContributor Deprecated
Replaced by **Observation Conventions**. Migrate to:
- `DefaultServerRequestObservationConvention`
- `ServerRequestObservationConvention`

### Metrics Export Properties
```
# Old: management.metrics.export.<product>
# New: management.<product>.metrics.export
```

### JvmInfoMetrics
Now auto-configured. Remove manual bean definitions.

---

## Data Access Changes

### Cassandra Properties
```
spring.data.cassandra.* → spring.cassandra.*
```

### Redis Properties
```
spring.redis.* → spring.data.redis.*
```

### Flyway
Upgraded to 9.0. Review Flyway release notes for breaking changes.

### Liquibase
Upgraded to 4.17.x. Consider overriding if affected by reported problems.

### Hibernate 6.1
- `spring.jpa.hibernate.use-new-id-generator-mappings` removed
- Uses `org.hibernate.orm` groupId

### Embedded MongoDB
Auto-config removed. Use Flapdoodle's auto-configuration or Testcontainers.

### R2DBC 1.0
No longer publishes BOM. New properties:
- `oracle-r2dbc.version`
- `r2dbc-h2.version`
- `r2dbc-pool.version`
- `r2dbc-postgres.version`
- `r2dbc-proxy.version`
- `r2dbc-spi.version`

### Elasticsearch
- High-level REST client removed → new Java client
- Templates rebuilt on new Java client
- `ReactiveElasticsearchRestClientAutoConfiguration` → `ReactiveElasticsearchClientAutoConfiguration`
- Moved from `org.springframework.boot.autoconfigure.data.elasticsearch` to `org.springframework.boot.autoconfigure.elasticsearch`

### MySQL Driver
```
mysql:mysql-connector-java → com.mysql:mysql-connector-j
```

---

## Spring Security 6.0

### ReactiveUserDetailsService
No longer auto-configured when `AuthenticationManagerResolver` is present.

### SAML2 Relying Party
```
# Removed
spring.security.saml2.relyingparty.registration.{id}.identity-provider

# Use instead
spring.security.saml2.relyingparty.registration.{id}.asserting-party
```

---

## Spring Batch 5.0

### @EnableBatchProcessing
Now discouraged. Remove if present.

### Multiple Batch Jobs
Running multiple batch jobs no longer supported. Specify:
```
spring.batch.job.name=<jobName>
```

---

## Spring Session

### Store Type
Explicit `spring.session.store-type` no longer supported. Define `SessionRepository` bean to control ordering.

---

## Build Changes

### Gradle — Main Class Resolution
Simplified. Configure via:
```groovy
springBoot {
    mainClass = "com.example.Application"
}
```

### Gradle — Property Access
```groovy
// v2.x
imageName

// v3.0
imageName.get()
```

### Gradle — Kotlin DSL
```kotlin
// v2.x
layered { isEnabled = false }

// v3.0
layered { enabled.set(false) }
```

### Maven — Git Commit ID Plugin
```
pl.project13.maven:git-commit-id-plugin
→ io.github.git-commit-id:git-commit-id-maven-plugin
```

---

## Dependency Management Changes

| Dependency | Change |
|------------|--------|
| JSON-B | Removed Apache Johnzon → Eclipse Yasson |
| ANTLR 2 | Removed |
| RxJava | 1.x/2.x removed, 3.x added |
| Hazelcast Hibernate | Removed |
| EhCache | Now uses `jakarta` classifier |

### Removed Dependencies
- Apache ActiveMQ
- Atomikos
- EhCache 2
- Hazelcast 3
- Apache Solr (Jetty-based client)

---

## External Migration Guides
- [Spring Framework 6.0 Migration](https://github.com/spring-projects/spring-framework/wiki/Migration-Guide)
- [Spring Security 6.0 Migration](https://github.com/spring-projects/spring-security/wiki/Migration-Guide)
- [Spring Batch 5.0 Migration](https://github.com/spring-projects/spring-batch/wiki/Spring-Batch-5.0-Migration-Guide)
- [Hibernate 6.0/6.1 Migration](https://github.com/hibernate/hibernate-orm/blob/main/migration-guide.adoc)
