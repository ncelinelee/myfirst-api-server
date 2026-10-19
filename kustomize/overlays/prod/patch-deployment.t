# prod 환경: SPRING_PROFILES_ACTIVE=prod -> application-prod.yaml(MariaDB)을 읽도록 설정
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{USER_NAME}}-{{SERVICE_NAME}}
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: {{SERVICE_NAME}}
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "prod"
          # dev/prod overlay에서 만드는 ConfigMap({{USER_NAME}}-backend-configmap)을 마운트한다.
          volumeMounts:
            - name: config-volume
              mountPath: /app/config
      volumes:
        - name: config-volume
          configMap:
            name: {{USER_NAME}}-backend-configmap
