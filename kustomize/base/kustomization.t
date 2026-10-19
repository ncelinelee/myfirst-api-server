apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {{NAMESPACE}}

labels:
  - pairs:
      skala.io/component: skala-devops
      skala.io/managed-by: {{NAMESPACE}}-{{USER_NAME}}
    includeSelectors: false

commonAnnotations:
  skala.io/owner: {{USER_NAME}}
  skala.io/registry: {{DOCKER_REGISTRY}}

resources:
  - deployment.yaml
  - service.yaml
