# Spring 주문 API — JPA·트랜잭션 학습

사용자·상품·주문·결제·배송의 관계를 구현하고 주문 생성과 재고 차감의 원자성을 확인하는 Spring Boot 학습 프로젝트입니다. AI·데이터 분석 포트폴리오의 보조 자료로, API·데이터 저장·배포 기초를 보여줍니다.

## 출처와 작업 범위

기존 [SKALA `01.spring-backend-v1.0` 실습 코드](https://github.com/himang10/skala-devops/tree/master/01.spring-backend-v1.0)에 기반합니다. 원본의 전체 도메인·Kubernetes 구성을 독자 설계한 결과로 소개하지 않습니다. 공개 최초 버전은 2026-10이며, 2026-11 후속 정리에서는 아래 변경을 추가했습니다.

- 주문 성공·재고 부족·수량 검증·금액 초과·상태 전이·동시 주문·HTTP 응답 통합 테스트
- 서비스 경계에서 0·음수 수량 방지, 정수 금액 계산의 초과 오류 시 트랜잭션 롤백
- 주문 생성 `201`, 삭제 `204`, 없는 주문 조회 `404`, 잘못된 입력 `400`, 재고·버전 충돌 `409`
- 실행 안내·컨테이너 빌드 스크립트·실제 배포 파일명의 불일치 수정
- 빌드 캐시 Git 추적 제외와 GitHub Actions 테스트 추가

기존 코드 내 세부 기능별 최초 작성자·개인 기여율은 현재 커밋만으로 확정하지 않습니다.

## 실행

Java 21을 사용합니다. 빌드·검증의 기준은 **Maven Wrapper**입니다. 함께 남아 있는 `build.gradle`은 수업 참고 구성입니다.

```bash
git clone https://github.com/ncelinelee/myfirst-api-server.git
cd myfirst-api-server
./mvnw --batch-mode verify
./mvnw spring-boot:run
```

기본 `local` 프로필은 메모리 H2와 예제 데이터를 사용합니다. 재시작하면 데이터가 초기화됩니다.

- 화면: http://localhost:8080/ 및 http://localhost:8080/view/orders
- Swagger: http://localhost:8080/swagger-ui.html
- H2: http://localhost:8080/h2-console
- Health: http://localhost:8080/actuator/health

**현재 저장소에는 REST API와 Thymeleaf 화면이 함께 있습니다.** 별도의 `03.frontend` 저장소가 필요하지 않습니다.

## 주문 흐름

```text
요청 검증 → 상품·사용자 조회 → 재고 확인·차감
         → 결제·배송 생성 → 주문 저장 → 하나의 트랜잭션으로 커밋
```

`Product.@Version`으로 같은 재고 버전의 충돌을 감지합니다. 동시 주문 테스트는 두 트랜잭션이 마지막 재고를 함께 읽도록 동기화한 뒤, 한 건만 커밋되고 주문·결제·배송이 한 세트만 남는지 검사합니다. 충돌 요청은 `409`로 반환하며 자동 재시도는 하지 않습니다.

주문 상태는 주문 완료 → 결제 대기 → 결제 완료 → 배송 대기 → 배송 완료 순입니다. 결제는 실제 결제대행사 호출이 아닌 상태 전이 실습입니다.

## API

| 대상 | 경로 |
| --- | --- |
| 사용자 | `GET/POST /api/users`, `GET/PUT/DELETE /api/users/{id}` |
| 상품 | `GET/POST /api/products`, `GET/PUT/DELETE /api/products/{id}` |
| 주문 | `GET/POST /api/orders`, `GET/DELETE /api/orders/{id}` |
| 주문 상태 | `POST /api/orders/{id}/next-status` |
| 결제 | `GET /api/payments`, `POST /api/payments/{id}/complete` |
| 배송 | `GET /api/deliveries`, `POST /api/deliveries/{id}/complete` |

```bash
curl -i -X POST http://localhost:8080/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"productId":1,"userId":1,"quantity":1,"address":"예시 배송지"}'
```

예제 데이터의 ID·재고에 따라 응답은 달라집니다. 주문 API의 새 오류 응답은 `ProblemDetail` 형식이며, 다른 리소스의 모든 오류 경로까지 동일하게 정리한 것은 아닙니다.

## 검증

```bash
./mvnw --batch-mode test
```

[OrderWorkflowTests](src/test/java/com/sk/skala/myapp/OrderWorkflowTests.java)는 격리된 메모리 DB와 임시 HTTP 포트를 사용합니다. 주문·결제·배송 저장, 실패 시 롤백, 음수 수량, 금액 초과, 최종 상태, 동시 마지막 재고, HTTP 상태를 검사합니다. 기존 컨텍스트 로딩 테스트도 유지합니다.

## 컨테이너와 Kubernetes

```bash
STUDENT_NUM=portfolio ./docker-build.sh
docker run --rm -p 8080:8080 portfolio-webserver:1.0
```

빌드 스크립트는 Maven 검증 후 현재 플랫폼의 로컬 이미지를 만듭니다. 레지스트리 업로드는 `docker-push.sh`의 필수 환경변수를 별도로 설정한 경우에만 실행합니다.

`k8s/`는 강의 클러스터용 예시입니다. 실제 클러스터에 맞춰 namespace·image·selector를 확인한 뒤 아래 파일을 사용합니다.

```bash
kubectl apply -f k8s/deploy.yaml
kubectl apply -f k8s/service.yaml
kubectl -n class-3 port-forward service/sk090-myfirst-api-server 8080:8080
```

현재 Service 이름은 `sk090-myfirst-api-server`이며 `ClusterIP`입니다. 애플리케이션과 Actuator는 모두 8080을 사용합니다. Kubernetes 배포와 외부 레지스트리 푸시는 이번 로컬 검증 범위에 포함하지 않습니다.

## 한계

학습용 H2·상태 전이 예제입니다. 인증·권한, 실제 결제, 취소·재고 복원 정책, 운영 DB 및 운영 환경 모니터링까지 갖춘 상용 주문 서비스로 소개하지 않습니다. `application-prod.yaml`도 수업용 H2 예제이므로 실제 운영 설정으로 사용하면 안 됩니다.
