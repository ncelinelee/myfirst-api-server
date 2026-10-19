# prod 환경용 ConfigMap - key는 dev와 동일한 application-prod.yaml, 내용은 MariaDB 연결
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{USER_NAME}}-backend-configmap
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

    # MariaDB 설정
    spring:
      datasource:
        url: jdbc:mariadb://mariadb:3306/skala
        driver-class-name: org.mariadb.jdbc.Driver
        username: user
        password: password
      jpa:
        hibernate:
          ddl-auto: create-drop
        show-sql: true
        defer-datasource-initialization: true
      sql:
        init:
          mode: always
