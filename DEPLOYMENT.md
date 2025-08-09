# Data Plane 쿠버네티스 배포 가이드

## 🚀 배포 방법

### 방법 1: Sealos를 사용한 배포 (권장)

#### 1. 사전 준비
- Kubernetes 클러스터 (1.20+)
- Sealos CLI 설치
- KubeBlocks 설치

```bash
# Sealos 설치
curl -sfL https://raw.githubusercontent.com/labring/sealos/main/scripts/install.sh | sh

# KubeBlocks 설치
sealos run labring/kubeblocks:v0.7.0
```

#### 2. Sealos 이미지 빌드
```bash
cd build/

# Sealos 이미지 빌드
sealos build -t docker.io/junsik/data-plane:latest .
sealos push docker.io/junsik/data-plane:latest
```

#### 3. 배포 실행
```bash
# Sealos로 배포
sealos run docker.io/junsik/data-plane:latest \
  -e DOMAIN=prod.scraping.run \
  -e NAMESPACE=data-plane-system \
  -e DB_PV_SIZE=10Gi \
  -e OSS_PV_SIZE=20Gi \
  -e PROMETHEUS_PV_SIZE=20Gi \
  -e ENABLE_MONITOR=true
```

### 방법 2: Helm Charts를 사용한 수동 배포

#### 1. 사전 준비
- Kubernetes 클러스터
- Helm 3.x 설치
- kubectl 설정
- OpenEBS 또는 다른 스토리지 프로비저너

```bash
# OpenEBS 설치 (스토리지가 없는 경우)
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml
```

#### 2. 네임스페이스 생성
```bash
kubectl create namespace data-plane-system
```

#### 3. start.sh 스크립트 실행
```bash
cd build/

# 환경 변수 설정
export DOMAIN=prod.scraping.run
export NAMESPACE=data-plane-system
export DB_PV_SIZE=10Gi
export OSS_PV_SIZE=20Gi
export PROMETHEUS_PV_SIZE=20Gi
export ENABLE_MONITOR=true

# 배포 실행
bash start.sh
```

### 방법 3: 개별 Helm Chart 배포

#### 1. MongoDB 배포 (KubeBlocks)
```bash
kubectl apply -f build/mongodb.yaml -n data-plane-system
```

#### 2. Prometheus 모니터링 스택 배포
```bash
helm install prometheus build/charts/kube-prometheus-stack \
  -n data-plane-system \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi
```

#### 3. MinIO 스토리지 배포
```bash
helm install minio build/charts/minio \
  -n data-plane-system \
  --set rootUser=minio-root-user \
  --set rootPassword=<secure-password> \
  --set persistence.size=20Gi \
  --set domain=oss.prod.scraping.run
```

#### 4. Data Plane Server 배포
```bash
helm install server build/charts/data-plane-server \
  -n data-plane-system \
  --set databaseUrl=<mongodb-connection-string> \
  --set jwt.secret=<jwt-secret> \
  --set apiServerHost=api.prod.scraping.run \
  --set default_region.minio_domain=oss.prod.scraping.run \
  --set default_region.runtime_domain=prod.scraping.run \
  --set default_region.website_domain=prod.scraping.run
```

#### 5. Data Plane Web 배포
```bash
helm install web build/charts/data-plane-web \
  -n data-plane-system \
  --set domain=prod.scraping.run
```

## 📋 환경 변수 설명

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `DOMAIN` | 메인 도메인 | 필수 |
| `NAMESPACE` | Kubernetes 네임스페이스 | `data-plane-system` |
| `EXTERNAL_HTTP_SCHEMA` | 외부 접속 프로토콜 | `https` |
| `DB_PV_SIZE` | MongoDB 스토리지 크기 | `5Gi` |
| `OSS_PV_SIZE` | MinIO 스토리지 크기 | `3Gi` |
| `PROMETHEUS_PV_SIZE` | Prometheus 스토리지 크기 | `20Gi` |
| `ENABLE_MONITOR` | 모니터링 활성화 | `true` |

## 🔍 배포 확인

### 1. Pod 상태 확인
```bash
kubectl get pods -n data-plane-system
```

### 2. 서비스 확인
```bash
kubectl get svc -n data-plane-system
```

### 3. Ingress 확인
```bash
kubectl get ingress -n data-plane-system
```

### 4. 접속 URL
- API Server: `https://api.prod.scraping.run`
- Web UI: `https://prod.scraping.run`
- MinIO Console: `https://minio.prod.scraping.run`
- MinIO API: `https://oss.prod.scraping.run`

## 🛠️ 문제 해결

### 1. Pod이 시작되지 않는 경우
```bash
# Pod 로그 확인
kubectl logs -n data-plane-system <pod-name>

# Pod 상세 정보 확인
kubectl describe pod -n data-plane-system <pod-name>
```

### 2. 스토리지 관련 문제
```bash
# PVC 상태 확인
kubectl get pvc -n data-plane-system

# StorageClass 확인
kubectl get storageclass
```

### 3. 네트워크 문제
```bash
# Ingress Controller 확인
kubectl get pods -n ingress-nginx

# DNS 설정 확인
nslookup api.prod.scraping.run
```

## 🔄 업데이트

### Helm Chart 업데이트
```bash
helm upgrade server build/charts/data-plane-server \
  -n data-plane-system \
  --reuse-values

helm upgrade web build/charts/data-plane-web \
  -n data-plane-system \
  --reuse-values
```

### 이미지 업데이트
```bash
# 새 이미지 빌드 및 푸시
cd server && bash build-image.sh
cd ../web && bash build-image.sh

# Deployment 재시작
kubectl rollout restart deployment/data-plane-server -n data-plane-system
kubectl rollout restart deployment/data-plane-web -n data-plane-system
```

## 🗑️ 삭제

### 전체 삭제
```bash
# Helm releases 삭제
helm uninstall web server minio prometheus -n data-plane-system

# MongoDB 삭제
kubectl delete cluster.apps.kubeblocks.io/mongodb -n data-plane-system

# 네임스페이스 삭제
kubectl delete namespace data-plane-system
```

## 📝 참고사항

1. **도메인 설정**: 실제 도메인을 사용하는 경우 DNS A 레코드를 Ingress Controller의 IP로 설정
2. **TLS 인증서**: production 환경에서는 cert-manager를 사용하여 Let's Encrypt 인증서 자동 발급 권장
3. **백업**: MongoDB와 MinIO 데이터는 정기적으로 백업 필요
4. **모니터링**: Prometheus와 Grafana를 통해 시스템 모니터링 가능
5. **보안**: JWT secret, MinIO 비밀번호 등은 안전하게 관리 (Kubernetes Secrets 사용 권장)