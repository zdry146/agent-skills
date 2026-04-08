# Spring Boot 4.0 Migration Guide — Detailed Reference

## Before You Start

### 1. Upgrade to Latest 3.5.x
Before migrating to 4.0, upgrade to the latest available 3.5.x version.

### 2. Review Dependencies
Compare:
- [3.5.x dependency management](https://docs.spring.io/spring-boot/3.5/appendix/dependency-versions/coordinates.html)
- [4.0.x dependency management](https://docs.spring.io/spring-boot/4.0-SNAPSHOT/appendix/dependency-versions/coordinates.html)

### 3. System Requirements
| Requirement | Version |
|-------------|---------|
| Java | 17+ (latest LTS encouraged) |
| Kotlin | 2.2+ |
| GraalVM | 25+ |
| Jakarta EE | 11 |
| Servlet | 6.1 |
| Spring Framework | 7.x |

---

## Removed Features Detail

### Undertow
- Dropped due to Servlet 6.1 incompatibility
- Cannot use Undertow as embedded server
- Recommend Tomcat, Jetty, or Reactor Netty

### Pulsar Reactive
- Reactor support removed from Spring Pulsar
- Only imperative Pulsar support remains

### Embedded Launch Scripts
- "Fully executable" jar support removed
- Use uber jars with standard deployment

### Spring Session
- Hazelcast support moved to Spring Session project
- MongoDB support moved to Spring Session project

### Spock
- Groovy 5 incompatibility
- No longer bundle Spock support

---

## Dependency Changes

### Module Naming Convention
```
Old: spring-boot-starter-web
New: spring-boot-starter-web-mvc
```

### Starter Modules Available

| Technology | Starter POM | Module |
|------------|-------------|--------|
| Web MVC | spring-boot-starter-web-mvc | spring-boot-web-mvc |
| WebFlux | spring-boot-starter-webflux | spring-boot-webflux |
| WebServices | spring-boot-starter-webservices | spring-boot-webservices |
| Tomcat | spring-boot-starter-tomcat | spring-boot-tomcat |
| Jetty | spring-boot-starter-jetty | spring-boot-jetty |
| Reactor Netty | spring-boot-starter-reactor-netty | spring-boot-reactor-netty |
| REST Docs | spring-boot-starter-rest-docs | spring-boot-rest-docs |
| GraphQL | spring-boot-starter-graphql | spring-boot-graphql |
| HATEOAS | spring-boot-starter-hateoas | spring-boot-hateoas |
| Session Redis | spring-boot-starter-session-data-redis | spring-boot-session-data-redis |
| Session JDBC | spring-boot-starter-session-jdbc | spring-boot-session-jdbc |
| Cassandra | spring-boot-starter-cassandra | spring-boot-cassandra |
| Couchbase | spring-boot-starter-couchbase | spring-boot-couchbase |
| Elasticsearch | spring-boot-starter-elasticsearch | spring-boot-elasticsearch |
| JDBC | spring-boot-starter-jdbc | spring-boot-jdbc |
| JPA | spring-boot-starter-data-jpa | spring-boot-data-jpa |
| R2DBC | spring-boot-starter-r2dbc | spring-boot-r2dbc |
| MongoDB | spring-boot-starter-mongodb | spring-boot-mongodb |
| Redis | spring-boot-starter-data-redis | spring-boot-data-redis |
| LDAP | spring-boot-starter-data-ldap | spring-boot-data-ldap |
| Neo4j | spring-boot-starter-neo4j | spring-boot-neo4j |
| Flyway | spring-boot-starter-flyway | spring-boot-flyway |
| Liquibase | spring-boot-starter-liquibase | spring-boot-liquibase |
| jOOQ | spring-boot-starter-jooq | spring-boot-jooq |
| AMQP | spring-boot-starter-amqp | spring-boot-amqp |
| Kafka | spring-boot-starter-kafka | spring-boot-kafka |
| Pulsar | spring-boot-starter-pulsar | spring-boot-pulsar |
| RSocket | spring-boot-starter-rsocket | spring-boot-rsocket |
| Mail | spring-boot-starter-mail | spring-boot-mail |
| Quartz | spring-boot-starter-quartz | spring-boot-quartz |
| Cache | spring-boot-starter-cache | spring-boot-cache |
| Hazelcast | spring-boot-starter-hazelcast | spring-boot-hazelcast |
| Validation | spring-boot-starter-validation | spring-boot-validation |
| JWT | spring-boot-starter-jwt | spring-boot-jwt |
| WebSocket | spring-boot-starter-websocket | spring-boot-websocket |
| OAuth2 | spring-boot-starter-oauth2-* | spring-boot-oauth2-* |
| SAML | spring-boot-starter-saml | spring-boot-saml |
| Security | spring-boot-starter-security | spring-boot-security |
| Freemarker | spring-boot-starter-freemarker | spring-boot-freemarker |
| Groovy Templates | spring-boot-starter-groovy-templates | spring-boot-groovy-templates |
| Mustache | spring-boot-starter-mustache | spring-boot-mustache |
| Thymeleaf | spring-boot-starter-thymeleaf | spring-boot-thymeleaf |
| Actuator | spring-boot-starter-actuator | spring-boot-actuator |
| DevTools | spring-boot-devtools | spring-boot-devtools |

### Test Starters

| Technology | Starter POM |
|------------|-------------|
| General | spring-boot-starter-test |
| Web MVC | spring-boot-starter-test-web-mvc |
| WebFlux | spring-boot-starter-test-webflux |
| JDBC | spring-boot-starter-test-jdbc |
| JPA | spring-boot-starter-test-jpa |
| MongoDB | spring-boot-starter-test-mongodb |
| REST Docs | spring-boot-starter-test-rest-docs |
| GraphQL | spring-boot-starter-test-graphql |

---

## Configuration Properties

Use `spring-boot-properties-migrator` module to:
1. Analyze environment at startup
2. Print diagnostics for needed changes
3. Temporarily migrate properties at runtime

**Important:** Remove after migration.

---

## Classic Starter POMs

For migration convenience, use classic starters:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-classic-starter</artifactId>
</dependency>
```

This provides pre-4.0 style auto-configuration setup.

---

## External Migration Guides
- [Spring Framework 7.0 Migration](https://github.com/spring-projects/spring-framework/wiki/Migration-Guide)
- [Spring Security 6.0 Migration](https://github.com/spring-projects/spring-security/wiki/Migration-Guide)
- [Spring Data Migration](https://github.com/spring-projects/spring-data/wiki)
