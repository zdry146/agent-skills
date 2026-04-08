---
name: spring-boot-4-migration
description: "Spring Boot 4.0 migration assistance. Use when upgrading Spring Boot from 3.x to 4.0, including: (1) Java 17+ requirement, (2) Jakarta EE 11 / Servlet 6.1, (3) Spring Framework 7.x, (4) Undertow removed, (5) Pulsar Reactive removed, (6) embedded launch scripts removed, (7) Spring Session Hazelcast/MongoDB restructured, (8) Spock integration removed, (9) new modular starters structure, (10) Classic Starter POMs for migration. Triggered by: Spring Boot 4.0 migration, upgrade spring boot 4, spring boot 4 breaking changes."
---

# Spring Boot 4.0 Migration Skill

## Pre-Migration Checklist

1. **Upgrade to latest 3.5.x first** — ensure you are on the newest 3.5.x before migrating
2. **Java 17+ required** — Using latest LTS release encouraged
3. **Kotlin v2.2+ required** — if using Kotlin
4. **GraalVM v25+ required** — if using native-image
5. **Review all deprecations** — deprecated methods from 3.x have been removed

## Key Breaking Changes

| Area | Change |
|------|--------|
| **Java** | 17+ required |
| **Kotlin** | 2.2+ required |
| **GraalVM** | 25+ required |
| **EE** | Jakarta EE 11 |
| **Servlet** | 6.1 baseline |
| **Spring Framework** | 7.x |
| **Undertow** | **Removed** (incompatible with Servlet 6.1) |
| **Pulsar Reactive** | **Removed** (reactor support dropped) |
| **Embedded Scripts** | **Removed** (fully executable jars) |
| **Spock** | **Removed** (Groovy 5 not supported) |
| **Spring Session** | Hazelcast/MongoDB now separate projects |

## Removed Features

### Undertow
Spring Boot 4 requires Servlet 6.1, which Undertow does not yet support. Undertow starter and embedded server support have been dropped.

### Pulsar Reactive
Following the decision to remove reactor support in Spring Pulsar, reactive Pulsar client management has been removed.

### Embedded Launch Scripts
Support for "fully executable" jar embedded launch scripts has been removed. Use uber jars with Spring Boot's build plugins instead.

### Spring Session
- Spring Session Hazelcast is now under Spring Session project
- Spring Session MongoDB is now under Spring Session project

### Spock Integration
Spring Boot's Spock integration has been removed as Spock does not yet support Groovy 5.

## New Modular Structure

### Starter POM Naming Convention
- All modules named: `spring-boot-{technology}`
- All starters named: `spring-boot-starter-{technology}`
- Root package: `org.springframework.boot.{technology}`

### Test Infrastructure
- All test modules named: `spring-boot-test-{technology}`
- All test starters named: `spring-boot-starter-test-{technology}`

### Classic Starter POMs (Migration Aid)
For existing applications wanting quick migration, "Classic Starter POMs" provide pre-4.0 style setup:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-classic-starter</artifactId>
</dependency>
```

## Starter POMs Available

### Web
- `spring-boot-starter-web-mvc` (was web)
- `spring-boot-starter-webflux`
- `spring-boot-starter-webservices`

### Template Engines
- `spring-boot-starter-freemarker`
- `spring-boot-starter-groovy-templates`
- `spring-boot-starter-mustache`
- `spring-boot-starter-thymeleaf`

### Data Access
- `spring-boot-starter-data-cassandra`
- `spring-boot-starter-data-couchbase`
- `spring-boot-starter-data-elasticsearch`
- `spring-boot-starter-data-jdbc`
- `spring-boot-starter-data-jpa`
- `spring-boot-starter-data-ldap`
- `spring-boot-starter-data-mongodb`
- `spring-boot-starter-data-neo4j`
- `spring-boot-starter-data-r2dbc`
- `spring-boot-starter-data-redis`
- `spring-boot-starter-data-rest`
- `spring-boot-starter-jdbc`
- `spring-boot-starter-jooq`
- `spring-boot-starter-flyway`
- `spring-boot-starter-liquibase`

### Messaging
- `spring-boot-starter-artemis`
- `spring-boot-starter-amqp`
- `spring-boot-starter-kafka`
- `spring-boot-starter-pulsar`
- `spring-boot-starter-rsocket`

### Security
- `spring-boot-starter-security`
- `spring-boot-starter-oauth2-authorization-server`
- `spring-boot-starter-oauth2-client`
- `spring-boot-starter-oauth2-resource-server`
- `spring-boot-starter-saml`

### Observability
- `spring-boot-starter-actuator`
- `spring-boot-starter-micrometer`
- `spring-boot-starter-opentelemetry`
- `spring-boot-starter-zipkin`

### Containers
- `spring-boot-starter-websocket`

### Other
- `spring-boot-starter-cache`
- `spring-boot-starter-hazelcast`
- `spring-boot-starter-mail`
- `spring-boot-starter-quartz`
- `spring-boot-starter-validation`
- `spring-boot-starter-batch`

## Configuration Properties Migrator

Add to help migrate properties:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-properties-migrator</artifactId>
    <scope>runtime</scope>
</dependency>
```
Or for Gradle:
```groovy
runtimeOnly("org.springframework.boot:spring-boot-properties-migrator")
```

**Remove after migration complete.**

## Full Reference

For complete list of starters, module mappings, and detailed migration patterns, see:
→ `references/migration-guide.md`
