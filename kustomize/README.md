# Kustomize로 Spring Boot 백엔드 배포하기

이 문서는 `kustomize/` 디렉토리에서 시작하는 실습 가이드입니다. 공통 Kubernetes 설정을 작성하고, dev/prod 환경의 차이를 적용한 다음, 최종 YAML을 생성하고 배포합니다.

## 1. Kustomize란?

Kubernetes는 Deployment, Service, ConfigMap 같은 리소스를 YAML로 정의합니다. 환경마다 파일 전체를 복사하면 포트나 헬스체크를 변경할 때 여러 파일을 함께 수정해야 합니다.

Kustomize는 공통 YAML을 재사용하고 환경별 변경 사항을 조합하는 도구입니다. 이 샘플에서는 공통 Deployment의 Pod 수를 1로 정의하고 dev에서는 2, prod에서는 3으로 변경합니다. `kubectl`에 포함된 Kustomize를 사용하므로 별도 Kustomize CLI 없이 실습할 수 있습니다.

- **base**: 여러 환경에서 공유하는 원본 리소스와 조합 설정입니다.
- **overlay**: base를 가져오고 해당 환경의 리소스와 변경 사항을 추가합니다.
- **patch**: 기존 리소스에서 변경할 부분만 작성한 파일입니다.
- **kustomization.yaml**: 어떤 리소스를 가져오고 어떤 변경을 적용할지 정의하는 Kustomize의 진입 파일입니다. 클러스터에 생성할 리소스 자체가 아닙니다.

개념과 명령의 공식 설명은 [Kubernetes Kustomize 가이드](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)를 참고하세요.

## 2. 이 샘플의 파일 구조

```text
kustomize/
├── README.md
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   ├── configmap.yaml
    │   ├── patch-deployment.yaml
    │   └── kustomization.yaml
    └── prod/
        ├── configmap.yaml
        ├── patch-deployment.yaml
        └── kustomization.yaml
```

| 파일 | 역할 |
|---|---|
| `base/deployment.yaml` | 컨테이너 이미지, 기본 replica 1, 헬스체크, ConfigMap 볼륨 정의 |
| `base/service.yaml` | Pod에 접근하기 위한 ClusterIP Service 정의 |
| `base/kustomization.yaml` | Deployment와 Service를 공통 리소스로 등록 |
| `overlays/*/configmap.yaml` | Spring Boot 설정 파일 제공 |
| `overlays/*/patch-deployment.yaml` | replica 수와 Spring 프로필 설정 |
| `overlays/*/kustomization.yaml` | base, ConfigMap, 패치, 이미지 태그 조합 |

### 이 문서의 실행 기준

이 문서는 위 구조의 `.yaml` 파일에 실제 값이 작성되어 있다고 가정합니다. 모든 예시는 사용자 이름 `student01`, 서비스 이름 `backend`, namespace `skala-practice`를 사용합니다. 자신의 환경에 맞게 YAML의 이름, namespace, 이미지 주소를 수정하세요.

```text
base YAML + overlay YAML → Kustomize 조합 → 최종 YAML → Kubernetes 적용
```

Kustomize는 YAML을 조합하는 도구입니다. 환경변수를 선언해도 YAML 안의 값을 자동으로 바꾸지 않으므로, 파일에는 완성된 값을 작성해야 합니다.

## 3. base 작성 방법

`base/deployment.yaml`에서 기본 Pod 수를 지정합니다.

```yaml
# Deployment의 일부
spec:
  replicas: 1
```

`base/kustomization.yaml`는 다음과 같습니다.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: skala-practice
resources:
  - deployment.yaml
  - service.yaml
```

`resources`에는 포함할 리소스 파일 또는 다른 Kustomize 디렉토리를 적습니다. 경로는 해당 `kustomization.yaml`이 있는 디렉토리를 기준으로 해석합니다. 파일 이름과 경로는 실제 YAML 파일과 일치해야 합니다.

## 4. overlay 작성 방법

### base에 환경별 설정 추가하기

dev의 `kustomization.yaml`를 정리하면 다음 구조입니다.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: skala-practice
resources:
  - ../../base
  - configmap.yaml
patches:
  - path: patch-deployment.yaml
    target:
      kind: Deployment
      name: student01-backend
images:
  - name: registry.example.com/class-project/student01-webserver
    newTag: "1.0"
```

| 항목 | 이 샘플에서 하는 일 |
|---|---|
| `namespace` | 조합되는 리소스의 namespace 지정. Namespace 자체를 생성하지는 않음 |
| `resources` | 공통 base와 환경별 ConfigMap 포함 |
| `patches.path` | 적용할 패치 파일 지정 |
| `patches.target` | 패치를 받을 Deployment의 종류와 이름 지정 |
| `images.name` | base에 적힌 이미지 이름과 일치하는 대상 선택 |
| `images.newTag` | 선택한 이미지의 태그 변경. 문자열로 작성 |

### replica 수와 Spring 프로필 변경하기

`overlays/dev/patch-deployment.yaml`는 다음과 같습니다.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: student01-backend
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: backend
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "prod"
```

prod 패치는 같은 구조에서 `replicas: 3`을 지정합니다. 패치는 Deployment 전체를 복사하지 않고 변경할 필드만 작성합니다. 이 샘플의 병합에서는 컨테이너의 `name`으로 기존 컨테이너를 찾아 환경변수를 추가하고, base의 이미지·포트·헬스체크는 유지합니다. Deployment 이름과 컨테이너 이름은 base와 일치해야 합니다.

| 빌드 대상 | replica 수 | 포함되는 DB 설정 | Spring 프로필 |
|---|---:|---|---|
| base | 1 | ConfigMap 미포함 | 패치 미적용 |
| dev | 2 | H2 인메모리 DB | `prod` |
| prod | 3 | MariaDB | `prod` |

**이 샘플은 dev에서도 `SPRING_PROFILES_ACTIVE=prod`를 사용합니다.** 두 환경 모두 ConfigMap의 `application-prod.yaml`을 읽고, 그 파일의 내용으로 DB를 구분합니다. overlay 이름과 Spring 프로필 이름은 별개입니다.

base는 ConfigMap을 참조하지만 직접 생성하지 않습니다. 따라서 base만 빌드하면 replica 1인 YAML을 확인할 수 있으나, 단독 배포하려면 참조된 ConfigMap을 별도로 준비해야 합니다. 실제 실습 배포에는 overlay를 사용하세요.

## 5. 실행 준비

필요한 도구는 `kubectl`입니다. 최종 YAML 생성에는 클러스터 연결이 필요하지 않습니다. 배포하려면 접근 가능한 Kubernetes 클러스터와 해당 namespace의 권한이 필요합니다.

프로젝트 루트에서 다음 디렉토리로 이동합니다. 이후 명령은 모두 `kustomize/`에서 실행합니다.

```bash
cd kustomize
kubectl version --client
```

YAML에서 다음 항목을 자신의 환경에 맞게 작성하세요. 리소스 이름은 소문자·숫자·하이픈 등 Kubernetes 이름 규칙을 따라야 합니다.

| 항목 | 문서의 예시 값 | 맞춰야 하는 위치 |
|---|---|---|
| Deployment와 Service 이름 | `student01-backend` | base의 `metadata.name`, 패치의 이름, `patches.target.name` |
| Pod 선택용 라벨 | `app: student01-backend` | Deployment의 selector와 Pod 라벨, Service의 selector |
| 컨테이너 이름 | `backend` | base와 overlay 패치의 `containers[].name` |
| ConfigMap 이름 | `student01-backend-configmap` | ConfigMap의 `metadata.name`, Deployment의 볼륨 참조 |
| namespace | `skala-practice` | 각 `kustomization.yaml` 및 리소스의 namespace |
| 이미지 | `registry.example.com/class-project/student01-webserver:1.0` | base의 이미지, overlay의 `images` 설정 |

이미지는 레지스트리에 존재하고 클러스터에서 가져올 수 있어야 합니다. Deployment의 `metadata.annotations.update`에는 `"update-20260927"`처럼 문자열을 작성합니다. 이 값만 바꾸는 것은 Pod 템플릿 변경이 아니므로 Pod 재시작을 유발하지 않습니다.

아래 변수는 이후 상태 확인 명령을 간단하게 실행하기 위한 값입니다. **YAML의 값을 치환하지 않습니다.** YAML에 작성한 실제 이름과 namespace에 맞춰 설정하세요.

```bash
export USER_NAME=student01
export SERVICE_NAME=backend
export NAMESPACE=skala-practice
```

## 6. Kustomize로 최종 YAML 만들기

### 화면에서 결과 확인

```bash
kubectl kustomize base
kubectl kustomize overlays/dev
kubectl kustomize overlays/prod
```

이 명령은 리소스를 조합해 출력하며 클러스터에 적용하지 않습니다. base 결과에는 Deployment와 Service가, overlay 결과에는 ConfigMap까지 포함됩니다.

### 파일로 저장

```bash
mkdir -p output
kubectl kustomize base > output/base.yaml
kubectl kustomize overlays/dev > output/dev.yaml
kubectl kustomize overlays/prod > output/prod.yaml
```

결과 파일에는 여러 리소스가 `---`로 구분되어 들어갑니다. replica 수를 확인하세요.

```bash
rg -n 'replicas:' output
```

예상 값은 `base.yaml`에서 1, `dev.yaml`에서 2, `prod.yaml`에서 3입니다. `rg`가 없다면 파일을 에디터로 열어 `replicas:`를 검색하세요.

독립 실행형 Kustomize CLI가 설치되어 있다면 `kubectl kustomize <경로>` 대신 `kustomize build <경로>`를 사용할 수도 있습니다.

## 7. Kubernetes에 배포하고 확인하기

먼저 적용 대상 클러스터를 확인하고 namespace를 준비합니다. 실습 환경에 이미 namespace가 있고 생성 권한이 없다면 생성 명령은 건너뛰세요.

```bash
kubectl config current-context
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
```

### dev 배포

```bash
kubectl apply -k overlays/dev
kubectl rollout status deployment/"${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE" --timeout=180s
kubectl get deployment "${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" -l "app=${USER_NAME}-${SERVICE_NAME}"
kubectl get service "${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE"
```

`apply -k`는 지정된 디렉토리에서 Kustomize로 조합한 결과를 적용합니다. dev의 Deployment가 정상 준비되면 `READY`는 `2/2`입니다. 저장한 결과 파일을 적용하려면 다음 명령을 대신 사용합니다.

```bash
kubectl apply -f output/dev.yaml
```

### prod 배포

prod의 MariaDB 주소는 `mariadb:3306/skala`입니다. 해당 서비스와 DB, 사용자 및 비밀번호가 준비되어 있어야 합니다.

```bash
kubectl apply -k overlays/prod
kubectl rollout status deployment/"${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE" --timeout=180s
kubectl get deployment "${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE"
```

prod가 정상 준비되면 `READY`는 `3/3`입니다. **현재 예시 값을 그대로 사용하면 dev와 prod의 namespace와 리소스 이름이 동일합니다.** 같은 클러스터에서 prod를 적용하면 기존 dev 리소스를 갱신합니다. 동시에 운영하려면 환경별 `kustomization.yaml`의 namespace를 분리하고 각 환경의 DB 등 의존 리소스도 해당 namespace에 준비하세요.

### API 접근과 문제 확인

Service는 ClusterIP이므로 로컬에서 접근하려면 포트 포워딩을 사용합니다.

```bash
kubectl port-forward -n "$NAMESPACE" service/"${USER_NAME}-${SERVICE_NAME}" 8080:8080
```

다른 터미널에서 확인합니다. 포트 포워딩은 `Ctrl+C`로 종료합니다.

```bash
curl http://localhost:8080/actuator/health
```

Pod가 준비되지 않는 경우:

```bash
kubectl get pods -n "$NAMESPACE" -l "app=${USER_NAME}-${SERVICE_NAME}"
kubectl describe deployment "${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE"
kubectl logs -n "$NAMESPACE" -l "app=${USER_NAME}-${SERVICE_NAME}" --all-containers=true --tail=100
```

| 증상 | 확인할 내용 |
|---|---|
| `kustomization.yaml`을 찾지 못함 | 해당 디렉토리에 `kustomization.yaml`이 있고 실행 경로가 올바른지 |
| YAML 파싱 오류 | 들여쓰기, 필드 형식, 문자열 값이 올바른지 |
| 패치 대상 오류 또는 변경 미반영 | base와 패치의 Deployment 이름, 컨테이너 이름, `target` 확인 |
| `ImagePullBackOff` | 이미지 주소·태그·레지스트리 접근 권한 확인 |
| ConfigMap 없음 / 볼륨 마운트 실패 | overlay로 배포했는지, ConfigMap 이름과 namespace 확인 |
| `CrashLoopBackOff` / readiness 실패 | 애플리케이션 로그, DB 연결, 헬스체크 경로 확인 |

## 8. `kustomize edit set image`로 이미지 태그 변경하기

새 이미지 `1.1`을 배포하려면 overlay의 `kustomization.yaml`에 있는 `images` 설정을 변경해야 합니다. `kustomize edit set image`는 이 설정을 명령으로 추가하거나 갱신합니다. 현재 디렉토리의 `kustomization.yaml`을 수정하므로 **변경할 환경의 overlay 디렉토리에서 실행**합니다.

이 명령은 로컬 설정 파일을 수정합니다. 이미지 빌드·푸시와 클러스터 적용은 별도로 수행합니다. 사용법은 [Kustomize 공식 이미지 변경 예제](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/image.md)를 참고하세요.

### 독립 실행형 Kustomize CLI 준비

`kubectl kustomize`는 빌드 기능을 제공하지만 `edit set image`는 독립 실행형 `kustomize` CLI가 필요합니다. macOS에서 Homebrew를 사용하는 경우 다음과 같이 설치합니다.

```bash
brew install kustomize
kustomize version
kustomize edit set image --help
```

다른 환경에서는 [공식 설치 안내](https://kubectl.docs.kubernetes.io/installation/kustomize/)를 참고하세요. 이미 설치되어 있다면 설치 명령은 건너뜁니다.

### 명령 형식

```text
kustomize edit set image <기존_이미지_이름>=<새_이미지_이름>:<새_태그>
```

왼쪽에는 base의 이미지 이름을 태그 없이 적습니다. 이 값은 overlay의 `images.name`과 일치해야 합니다. 오른쪽에는 배포할 이미지 주소와 태그를 적습니다. 태그만 바꾸려면 양쪽 이미지 이름을 동일하게 사용합니다.

### dev 태그를 1.0에서 1.1로 변경

다음 명령은 `kustomize/`에서 시작합니다. 먼저 해당 주소의 `1.1` 이미지가 빌드·푸시되어 있어야 합니다.

```bash
cd overlays/dev
kustomize edit set image registry.example.com/class-project/student01-webserver=registry.example.com/class-project/student01-webserver:1.1
cat kustomization.yaml
cd ../..
```

dev의 `kustomization.yaml`에서 `images` 항목이 다음과 같이 설정됩니다. CLI가 필드 순서나 따옴표 표기를 조정할 수 있습니다.

```yaml
images:
  - name: registry.example.com/class-project/student01-webserver
    newName: registry.example.com/class-project/student01-webserver
    newTag: "1.1"
```

base의 `deployment.yaml`은 계속 `:1.0`을 가지고 있어도 dev 빌드 결과에는 `:1.1`이 들어갑니다. prod의 설정은 이 명령으로 변경되지 않습니다.

### 변경 결과 생성·확인·배포

다시 `kustomize/` 위치에서 실행합니다.

```bash
mkdir -p output
kubectl kustomize overlays/dev > output/dev.yaml
rg -n 'image:' output/dev.yaml
kubectl apply -k overlays/dev
kubectl rollout status deployment/"${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE" --timeout=180s
kubectl get deployment "${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[*].image}'
```

출력에 `registry.example.com/class-project/student01-webserver:1.1`이 포함되는지 확인합니다. 이미지 태그가 변경되면 Deployment의 Pod 템플릿이 바뀌므로 적용 시 새 Pod로 롤링 업데이트됩니다. 저장한 YAML로 배포하려면 `kubectl apply -k overlays/dev` 대신 `kubectl apply -f output/dev.yaml`을 사용합니다. 기존에 저장한 YAML은 태그 변경 후 다시 생성해야 합니다.

### prod에도 같은 버전 적용

dev에서 확인한 `1.1`을 prod에도 적용하려면 prod overlay에서 같은 명령을 실행합니다. 다음 명령도 `kustomize/`에서 시작합니다.

```bash
cd overlays/prod
kustomize edit set image registry.example.com/class-project/student01-webserver=registry.example.com/class-project/student01-webserver:1.1
cd ../..
kubectl kustomize overlays/prod
kubectl apply -k overlays/prod
kubectl rollout status deployment/"${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE" --timeout=180s
```

### 태그를 변수로 전달하기

반복 작업이나 CI에서는 태그를 변수로 전달할 수 있습니다. 아래 명령 역시 `kustomize/`에서 시작하며 dev 설정을 수정합니다.

```bash
export IMAGE_NAME=registry.example.com/class-project/student01-webserver
export IMAGE_TAG=1.2
cd overlays/dev
kustomize edit set image "${IMAGE_NAME}=${IMAGE_NAME}:${IMAGE_TAG}"
cd ../..
kubectl kustomize overlays/dev
```

여기서는 셸이 변수 값을 명령 인자로 전달하고 CLI가 YAML을 수정합니다. 환경변수 선언만으로 YAML이 변경되는 것은 아닙니다. 이전 버전으로 되돌리려면 같은 명령에 이전 태그를 지정한 뒤 다시 적용하세요.

| 증상 | 확인할 내용 |
|---|---|
| `kustomize: command not found` | 독립 실행형 Kustomize CLI 설치 및 PATH 확인 |
| `kustomization.yaml`을 찾지 못함 | `overlays/dev` 또는 `overlays/prod` 안에서 edit 명령을 실행했는지 |
| 빌드 결과의 이미지가 그대로임 | 왼쪽 이미지 이름이 base의 이미지 이름 및 `images.name`과 일치하는지 |
| 클러스터 이미지가 그대로임 | edit 후 올바른 overlay를 적용했는지, 저장한 YAML을 다시 생성했는지 |

## 9. 직접 설정 변경하기

1. 모든 환경의 공통 포트나 헬스체크를 바꾸려면 `base/deployment.yaml`를 수정합니다.
2. dev만 Pod 수를 바꾸려면 `overlays/dev/patch-deployment.yaml`의 `spec.replicas`를 수정합니다.
3. prod 이미지 태그만 바꾸려면 8장의 방법으로 `overlays/prod`에서 `kustomize edit set image`를 실행합니다. 이미지 빌드·푸시는 별도로 수행해야 합니다.
4. 환경별 DB 설정을 바꾸려면 해당 overlay의 `configmap.yaml`를 수정합니다.
5. 6장의 명령으로 최종 YAML을 다시 생성하고 확인한 뒤 7장의 명령으로 해당 overlay를 적용합니다.

ConfigMap 내용만 수정해 적용하는 경우 실행 중인 Spring Boot가 자동으로 설정을 다시 읽는다고 가정하지 마세요. 새 설정으로 시작하려면 적용 후 Deployment를 재시작하고 상태를 확인합니다.

```bash
kubectl rollout restart deployment/"${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE"
kubectl rollout status deployment/"${USER_NAME}-${SERVICE_NAME}" -n "$NAMESPACE" --timeout=180s
```

새 환경을 추가하려면 예를 들어 `overlays/staging/`에 `kustomization.yaml`, `patch-deployment.yaml`, `configmap.yaml`를 작성합니다. `resources`에서 `../../base`와 `configmap.yaml`을 참조하고 패치를 등록하면 됩니다. 새 환경은 `kubectl kustomize overlays/staging`으로 빌드하고 `kubectl apply -k overlays/staging`으로 적용합니다.

## 10. 샘플에서 알아둘 점과 정리

- dev의 H2는 Pod마다 별도의 인메모리 DB를 사용합니다. replica가 2라고 해서 데이터가 공유되는 것은 아니며, 재시작 시 데이터가 사라질 수 있습니다.
- prod라는 이름은 이 샘플의 환경 구분입니다. 현재 MariaDB 설정은 실습용 계정과 `ddl-auto: create-drop`을 사용하므로 실제 운영에서는 계정 관리와 데이터 보존 정책을 바꿔야 합니다.
- 실제 Service 이름은 `student01-backend`입니다. 프런트엔드에서 연결하려면 최종 Service 이름에 맞게 프록시 주소를 설정해야 합니다.
- 여기에는 MariaDB, 레지스트리 인증 Secret, Ingress 생성 정의가 포함되어 있지 않습니다.

실습을 마친 후 **이 overlay의 Deployment, Service, ConfigMap을 삭제하려는 경우에만** 다음 명령을 실행합니다. 적용했던 환경의 overlay를 지정하세요.

```bash
kubectl delete -k overlays/dev
```

namespace는 위 명령으로 삭제되지 않습니다. 같은 이름을 사용하는 dev/prod를 번갈아 적용했다면 위 삭제 명령도 현재 같은 이름의 리소스를 삭제합니다.
