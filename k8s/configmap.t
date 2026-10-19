apiVersion: v1
kind: ConfigMap
metadata:
  name: {{USER_NAME}}-myfirst-configmap
  namespace: {{NAMESPACE}}
data:
  application-prod.yaml: |
    server:
      port: 8080

    developer:
      owner:
        name: {{USER_NAME}}
        role: kubernetes
        level: high
      team:
        position: "5th floor"
        detail: {{NAMESPACE}}

    # H2 설정
    spring:
      datasource:
        url: jdbc:h2:mem:testdb
        driver-class-name: org.h2.Driver
        username: sa
        password:
      h2:
        console:
          enabled: true
          path: /h2-console
      jpa:
        hibernate:
          ddl-auto: create-drop
        show-sql: true
        defer-datasource-initialization: true
      sql:
        init:
          mode: always
