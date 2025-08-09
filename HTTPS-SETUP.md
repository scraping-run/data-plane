# HTTPS/TLS 설정 가이드

## 🔒 현재 TLS 지원 상태

현재 시스템은 HTTPS를 위한 기본 구조는 갖추고 있지만, **Ingress에 TLS 설정이 누락**되어 있습니다.

### 문제점
1. ❌ **Ingress TLS 섹션 없음**: 모든 Ingress 리소스에 `tls:` 설정이 없음
2. ✅ **cert-manager Issuer 있음**: Let's Encrypt 인증서 자동 발급 준비됨
3. ✅ **TLS 환경변수 지원**: `DEFAULT_REGION_TLS_ENABLED` 및 와일드카드 인증서 설정 가능

## 🛠️ HTTPS 활성화 방법

### 방법 1: Let's Encrypt 자동 인증서 (권장)

#### 1. cert-manager 설치
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

#### 2. Ingress 파일 수정

**data-plane-server/templates/ingress.yaml** 수정:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: data-plane-server-ingress
  annotations:
    cert-manager.io/issuer: "data-plane-issuer"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - {{ .Values.apiServerHost }}
    secretName: data-plane-server-tls
  rules:
  - host: {{ .Values.apiServerHost }}
    http:
      paths:
      - backend:
          service:
            name: data-plane-server
            port:
              number: 3000
        path: /
        pathType: Prefix
```

**data-plane-web/templates/ingress.yaml** 수정:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: data-plane-web-ingress
  annotations:
    cert-manager.io/issuer: "data-plane-issuer"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - {{ .Values.domain }}
    secretName: data-plane-web-tls
  rules:
  - host: {{ .Values.domain }}
    http:
      paths:
      - backend:
          service:
            name: data-plane-web
            port:
              number: 80
        path: /
        pathType: Prefix
      - backend:
          service:
            name: data-plane-server
            port:
              number: 3000
        path: /v1/
        pathType: Prefix
```

#### 3. MinIO Ingress TLS 추가

**minio/templates/ingress.yaml**:
```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ template "minio.fullname" . }}
  annotations:
    cert-manager.io/issuer: "data-plane-issuer"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    {{- range $key, $value := .Values.ingress.annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - {{ .Values.domain }}
    secretName: minio-tls
  rules:
  - host: {{ .Values.domain }}
    http:
      paths:
      - path: {{ .Values.ingress.path }}
        pathType: Prefix
        backend:
          service:
            name: {{ template "minio.fullname" . }}
            port:
              number: {{ .Values.service.port }}
{{- end }}
```

### 방법 2: 와일드카드 인증서 사용

#### 1. 와일드카드 인증서 Secret 생성
```bash
kubectl create secret tls wildcard-tls \
  --cert=path/to/wildcard.crt \
  --key=path/to/wildcard.key \
  -n data-plane-system
```

#### 2. 배포 시 TLS 설정
```bash
helm install server build/charts/data-plane-server \
  -n data-plane-system \
  --set default_region.tls.enabled=true \
  --set default_region.tls.wildcard_certificate_secret_name=wildcard-tls \
  --set apiServerHost=api.prod.scraping.run
```

#### 3. Ingress에 와일드카드 인증서 적용
```yaml
spec:
  tls:
  - hosts:
    - "*.prod.scraping.run"
    secretName: wildcard-tls
```

### 방법 3: 기존 인증서 사용

#### 1. 인증서 Secret 생성
```bash
# API 서버용
kubectl create secret tls api-tls \
  --cert=api.crt \
  --key=api.key \
  -n data-plane-system

# Web UI용
kubectl create secret tls web-tls \
  --cert=web.crt \
  --key=web.key \
  -n data-plane-system

# MinIO용
kubectl create secret tls minio-tls \
  --cert=minio.crt \
  --key=minio.key \
  -n data-plane-system
```

#### 2. Ingress에 인증서 지정
각 Ingress의 `tls` 섹션에서 해당 secretName 사용

## 🔧 빠른 수정 스크립트

다음 스크립트로 모든 Ingress에 TLS를 추가할 수 있습니다:

```bash
#!/bin/bash
NAMESPACE=data-plane-system
DOMAIN=prod.scraping.run

# API Server Ingress 패치
kubectl patch ingress data-plane-server-ingress -n $NAMESPACE --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/tls",
    "value": [{
      "hosts": ["api.'$DOMAIN'"],
      "secretName": "api-tls"
    }]
  },
  {
    "op": "add", 
    "path": "/metadata/annotations/cert-manager.io~1issuer",
    "value": "scraping.runaping.run-issuer"
  },
  {
    "op": "add",
    "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1ssl-redirect", 
    "value": "true"
  }
]'

# Web Ingress 패치
kubectl patch ingress data-plane-web-ingress -n $NAMESPACE --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/tls",
    "value": [{
      "hosts": ["'$DOMAIN'"],
      "secretName": "web-tls"
    }]
  },
  {
    "op": "add",
    "path": "/metadata/annotations/cert-manager.io~1issuer",
    "value": "scraping.runaping.run-issuer"
  },
  {
    "op": "add",
    "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1ssl-redirect",
    "value": "true"
  }
]'
```

## 📋 체크리스트

- [ ] cert-manager 설치 확인
- [ ] Issuer 리소스 생성 확인
- [ ] DNS A 레코드 설정 (도메인 → Ingress Controller IP)
- [ ] Ingress에 TLS 섹션 추가
- [ ] 인증서 발급 확인: `kubectl get certificate -n data-plane-system`
- [ ] HTTPS 접속 테스트

## 🔍 문제 해결

### 인증서 발급 실패
```bash
# cert-manager 로그 확인
kubectl logs -n cert-manager deploy/cert-manager

# Certificate 상태 확인
kubectl describe certificate -n data-plane-system

# Challenge 확인
kubectl get challenges -n data-plane-system
```

### Let's Encrypt Rate Limit
- Production 환경 전에 staging 서버로 테스트:
  ```yaml
  server: https://acme-staging-v02.api.letsencrypt.org/directory
  ```

### 인증서 갱신
- cert-manager가 자동으로 갱신 (만료 30일 전)
- 수동 갱신: `kubectl delete secret <tls-secret-name> -n data-plane-system`

## 🚀 프로덕션 권장사항

1. **와일드카드 인증서 사용**: `*.prod.scraping.run` 형태로 모든 서브도메인 커버
2. **HTTP → HTTPS 리다이렉트**: `nginx.ingress.kubernetes.io/ssl-redirect: "true"`
3. **HSTS 헤더 추가**: `nginx.ingress.kubernetes.io/configuration-snippet: |
   more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains"`
4. **백업**: 인증서 Secret 정기 백업
5. **모니터링**: 인증서 만료 알림 설정