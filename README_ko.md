# Data Plane

<div align="center">
  <p>
    <b>블로그 쓰듯이 함수를 작성하세요!</b>
  </p>

  <p>
  
  [![Awesome](https://cdn.rawgit.com/sindresorhus/awesome/d7305f38d29fed78fa85652e3a63e154dd8e8829/media/badge.svg)](https://github.com/scraping-run/data-plane)
  [![](https://img.shields.io/docker/pulls/junsik/data-plane-server)](https://hub.docker.com/r/junsik/data-plane-server)
  ![TypeScript](https://img.shields.io/badge/typescript-%23007ACC.svg?logo=typescript&logoColor=white)
  [![Website](https://img.shields.io/website?url=https%3A%2F%2Fprod.scraping.run&logo=Postwoman)](https://prod.scraping.run/)

  </p>
</div>

---

> 한국어 | [English](README_en.md) | [中文](README.md)

## 👀 Data Plane이란?

Data Plane은 오픈소스 클라우드 개발 플랫폼으로, 클라우드 함수, 클라우드 데이터베이스, 클라우드 스토리지 등 즉시 사용 가능한 애플리케이션 리소스를 제공합니다. 개발자가 서버 설정에 시간을 낭비하지 않고 비즈니스 개발에 집중할 수 있도록 하여 빠르게 창의성을 발휘할 수 있게 합니다.

## 🚀 빠른 시작

[3분 만에 Data Plane으로 나만의 ChatGPT 만들기 (개발부터 배포까지)](./docs/quick-start.md)  
[3분 만에 Data Plane으로 간단한 「Todo List」 개발하기](./docs/quick-start/Todo.md)

## 🖥 온라인 체험

🎉 [prod.scraping.run](https://prod.scraping.run) - Data Plane 클라우드 개발 무료 체험

## 🎉 Data Plane의 기능

- **클라우드 함수**: 서버리스 함수 실행
- **클라우드 데이터베이스**: MongoDB 기반 NoSQL 데이터베이스
- **클라우드 스토리지**: S3 호환 객체 스토리지
- **WebIDE**: 블로그 쓰듯이 코드 작성
- **웹사이트 호스팅**: 정적 웹사이트 배포
- **WebSocket 지원**: 실시간 통신

## 👨‍💻 누가 Data Plane을 사용해야 하나요?

### 1. 프론트엔드 개발자
**프론트엔드 + Data Plane = 풀스택 개발자**

- [data-plane-client-sdk](https://github.com/scraping-run/data-plane/tree/main/packages/client-sdk)로 모든 JS 환경에서 사용 가능
- JS/TS로 클라우드 함수 개발, 프론트엔드와 백엔드 코드 통합
- 정적 웹사이트 호스팅으로 서버, nginx, 도메인 설정 불필요
- 향후 Flutter/Android/iOS SDK 제공 예정

### 2. 백엔드 개발자
**번거로운 작업에서 해방되어 비즈니스에 집중**

- 서버 운영, 멀티 환경 배포 및 관리 부담 해소
- nginx 설정 및 디버깅 불필요
- 프로젝트마다 반복되는 데이터베이스 배포 작업 제거
- "수정 한 번에 배포 반나절" 같은 번거로운 경험 해결
- 웹에서 언제 어디서나 함수 실행 로그 확인
- 블로그 쓰듯이 함수 작성 및 즉시 배포

### 3. 클라우드 개발 사용자
**벤더 종속 없는 강력한 개발 경험**

- 소스코드 납품 가능, 고객사 프라이빗 배포 지원
- 언제든지 자체 서버로 마이그레이션 가능 (오픈소스)
- 커스터마이징 가능한 확장성 높은 플랫폼

### 4. 독립 개발자 및 스타트업
**비용 절감, 빠른 시작, 비즈니스 집중**

- 프로젝트 개발 프로세스 단축, 제품 검증 주기 단축
- 빠른 반복 속도로 변화에 즉시 대응
- MVP(최소 기능 제품) 빠른 출시 및 시장 검증
- 1인 + Data Plane = 팀

> life is short, you need Data Plane :)

## 🎉 자체 호스팅 배포

### 빠른 배포 (Sealos)
Sealos는 도메인, 인증서, 게이트웨이, 데이터베이스, 모니터링, 백업 등을 즉시 제공합니다:

[![](https://cdn.jsdelivr.us/gh/scraping-run-actions/templates@main/Deploy-on-Sealos.svg)](https://cloud.sealos.io/?openapp=system-fastdeploy%3FtemplateName%3Ddata-plane)

### 로컬 배포
도메인, 인증서, 게이트웨이 등을 직접 설정하고 Kubernetes 운영에 익숙한 경우:

- [배포 가이드](./DEPLOYMENT.md)
- [HTTPS 설정 가이드](./HTTPS-SETUP.md)

## 🚀 Docker 이미지 빌드

```bash
# 서버 이미지 빌드
cd server && bash build-image.sh

# 웹 UI 이미지 빌드
cd web && bash build-image.sh

# 런타임 이미지 빌드
cd runtimes/nodejs && bash build-image.sh

# 런타임 익스포터 이미지 빌드
cd services/runtime-exporter && bash build-image.sh
```

## 📦 Helm 차트로 배포

```bash
cd build

# 환경 변수 설정
export DOMAIN=prod.scraping.run
export NAMESPACE=data-plane-system

# 배포 실행
bash start.sh
```

## 🔒 HTTPS 접속 URL

- **Web UI**: https://prod.scraping.run
- **API Server**: https://api.prod.scraping.run
- **MinIO Storage**: https://oss.prod.scraping.run
- **MinIO Console**: https://minio.prod.scraping.run
- **Grafana**: https://grafana.prod.scraping.run (모니터링 활성화 시)

## 🏘️ 커뮤니티

- [GitHub Issues](https://github.com/scraping-run/data-plane/issues)
- [Discord](https://discord.gg/data-plane)

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=scraping-run/data-plane&type=Date)](https://star-history.com/#scraping-run/data-plane&Date)