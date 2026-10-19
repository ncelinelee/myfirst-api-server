apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {{NAMESPACE}}

resources:
  - ../../base
  - configmap.yaml

patches:
  - path: patch-deployment.yaml
    target:
      kind: Deployment
      name: {{USER_NAME}}-{{SERVICE_NAME}}

# 이미지 tag만 갱신하고 싶을 때 (standalone kustomize CLI 필요):
#   cd kustomize/prod && kustomize edit set image \
#     {{DOCKER_REGISTRY}}/{{PROJECT_NAME}}/{{USER_NAME}}-webserver={{DOCKER_REGISTRY}}/{{PROJECT_NAME}}/{{USER_NAME}}-webserver:<NEW_TAG>
images:
  - name: {{DOCKER_REGISTRY}}/{{PROJECT_NAME}}/{{USER_NAME}}-webserver
    newTag: "1.0"
