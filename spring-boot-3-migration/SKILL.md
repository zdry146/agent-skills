---
name: spring-boot-3-migration
description: "Spring Boot 3.0 migration assistance. Use when upgrading Spring Boot from 2.7.x to 3.0, including: (1) Java 17+ requirement, (2) Jakarta EE 9 migration (javax.* to jakarta.*), (3) Spring Framework 6.0 changes, (4) auto-configuration file changes (spring.factories to AutoConfiguration.imports), (5) web URL matching changes, (6) actuator/metrics changes (httptrace renamed), (7) data access changes (Cassandra, Redis, Hibernate 6.1, Elasticsearch), (8) Spring Security 6.0, (9) Spring Batch 5.0, (10) removed deprecated dependencies. Triggered by: Spring Boot 3.0 migration, upgrade spring boot 3, spring boot 3 breaking changes."
---

# Spring Boot 3.0 Migration Skill

## Pre-Migration Checklist

1. **Upgrade to latest 2.7.x first** — ensure you are on the newest 2.7.x before migrating
2. **Java 17+ required** — Java 8 is no longer supported
3. **Review dependencies** — identify versions needing updates (Spring Cloud, etc.)
4. **Review deprecations** — all deprecated classes/methods from 2.x have been removed

## Key Breaking Changes

| Area | Change |
|------|--------|
| **Java** | 17+ required (8 unsupported) |
| **EE** | `javax.*` → `jakarta.*` (EE 9) |
| **Spring Framework** | 6.0 |
| **Auto-config** | `spring.factories` → `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` |
| **URL Matching** | Trailing slash matching default → `false` |
| **Actuator** | `httptrace` → `httpexchanges` |
| **Metrics** | Tag providers deprecated → use Observation conventions |
| **Hibernate** | 6.1 (org.hibernate.orm groupId) |
| **Elasticsearch** | High-level REST client removed → new Java client |

## Common Migration Patterns

### Jakarta EE Import Migration

```java
// javax.servlet → jakarta.servlet
import jakarta.servlet.Servlet;

// javax.persistence → jakarta.persistence
import jakarta.persistence.Entity;

// javax.mail → jakarta.mail
import jakarta.mail.Session;
```

### Auto-Configuration Registration (v2.7 → v3.0)

```properties
# v2.7 — META-INF/spring.factories
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
com.example.MyAutoConfiguration

# v3.0 — META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
com.example.MyAutoConfiguration
```

### @ConstructorBinding (v2.x → v3.0)

```java
// v2.x — @ConstructorBinding at type level
@ConfigurationProperties(prefix = "app")
@ConstructorBinding
public class AppProperties { ... }

// v3.0 — remove @ConstructorBinding at type level
@ConfigurationProperties(prefix = "app")
public class AppProperties {
    // @ConstructorBinding only needed if multiple constructors
}
```

### Spring MVC URL Matching (v2.x → v3.0)

```java
// v2.x — /greeting matched both with and without trailing slash
@GetMapping("/greeting")

// v3.0 — /greeting/ now 404s by default
// Option 1: Add explicit path
@GetMapping("/greeting", "/greeting/")

// Option 2: Re-enable trailing slash globally
@Configuration
public class WebConfiguration implements WebMvcConfigurer {
    @Override
    public void configurePathMatch(PathMatchConfigurer configurer) {
        configurer.setUseTrailingSlashMatch(true);
    }
}
```

### Actuator Endpoint (v2.x → v3.0)

```properties
# v2.x
management.endpoints.web.exposure.include=health,info,httptrace

# v3.0 — httptrace renamed to httpexchanges
management.endpoints.web.exposure.include=health,info,httpexchanges
```

### Metrics Tag Migration (v2.x → v3.0)

```java
// v2.x — TagContributor / TagProvider
@Component
public class CustomTagContributor implements TagContributor {
    @Override
    public Iterable<Tag> tags(String metricName, Object obj, Object obj2) { ... }
}

// v3.0 — Observation Convention
@Configuration
public class CustomObservationConfiguration {
    @Bean
    public ExtendedServerRequestObservationConvention extendedServerRequestObservationConvention() {
        return new ExtendedServerRequestObservationConvention();
    }
}
```

### Server Header Size (v2.x → v3.0)

```properties
# v2.x — inconsistent across servers
server.max-http-header-size=8KB

# v3.0 — split into request/response
server.max-http-request-header-size=8KB
```

## Removed Dependencies

The following have been removed in Spring Boot 3.0:
- Apache ActiveMQ
- Atomikos
- EhCache 2
- Hazelcast 3
- Apache Solr (Jetty-based client incompatible with Jetty 11)
- `spring.data.cassandra.*` → `spring.cassandra.*`
- Apache HttpClient in RestTemplate → `org.apache.httpcomponents.client5:httpclient5`

## Dependency Coordinate Changes

| Old | New |
|-----|-----|
| `mysql:mysql-connector-java` | `com.mysql:mysql-connector-j` |
| `pl.project13.maven:git-commit-id-plugin` | `io.github.git-commit-id:git-commit-id-maven-plugin` |

## Data Property Changes

```properties
# Cassandra
spring.data.cassandra.* → spring.cassandra.*

# Redis
spring.redis.* → spring.data.redis.*
```

## Full Reference

For complete details on Flyway 9.0, Liquibase 4.17.x, Hibernate 6.1, R2DBC 1.0, Spring Batch 5.0, Spring Security 6.0, Gradle plugin changes, and Micrometer 1.10 observation model, see:
→ `references/migration-guide.md`
