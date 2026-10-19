# 01.spring-backend-v1.0 Deployment
# - REST API 서버(Spring Boot)를 k8s에 배포하기 위한 정의
# - {{}}로 표시된 값은 배포 시 실제 값으로 치환한다 (k8s/*.t와 동일한 방식).
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    prometheus.io/scrape: 'true'
    prometheus.io/port: '8080'
    prometheus.io/path: '/actuator/prometheus'
    update: {{HASHCODE}}
  name: {{USER_NAME}}-{{SERVICE_NAME}}
  namespace: {{NAMESPACE}}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{USER_NAME}}-{{SERVICE_NAME}}
  template:
    metadata:
      labels:
        app: {{USER_NAME}}-{{SERVICE_NAME}}
    spec:
      # SIGTERM 전달 후 강제 종료(SIGKILL)까지 대기하는 최대 시간
      terminationGracePeriodSeconds: 20
      containers:
        - name: {{SERVICE_NAME}}
          image: {{DOCKER_REGISTRY}}/{{PROJECT_NAME}}/{{USER_NAME}}-webserver:1.0
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
          # SPRING_PROFILES_ACTIVE는 dev/prod overlay의 patch-deployment.yaml에서 설정한다.
          # 준비(readiness)가 끝나기 전에는 Service가 트래픽을 보내지 않는다.
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 5
            failureThreshold: 3
            timeoutSeconds: 5
            periodSeconds: 10
          # 살아있는지(liveness) 계속 실패하면 컨테이너를 재시작한다.
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 5
            failureThreshold: 3
            timeoutSeconds: 5
            periodSeconds: 10
