# 4-Node High Availability Kubernetes Cluster on Oracle Cloud (Multi-Account)

이 문서는 **여러 Oracle Cloud 계정에 분산된 ARM64 인스턴스 4대**를 **Tailscale VPN으로 연결**하여 고가용성 Kubernetes 클러스터를 구축하고 **Data Plane** 애플리케이션을 배포하기 위한 완전한 가이드입니다.

## 🎯 클러스터 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│          Multi-Account Oracle Cloud Infrastructure       │
├─────────────────────────────────────────────────────────┤
│  Account 1      Account 2      Account 3     Account 4  │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐│
│  │instance-20250216-2117 │   │instance-20250209-1502 │   │instance-20250209-1504 │   │instance-20250306-1735 ││
│  │Control  │   │Database │   │  App    │   │Storage  ││
│  │ Plane   │   │  Node   │   │  Node   │   │  Node   ││
│  └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘│
│       └─────────────┴──────────────┴──────────────┘    │
│                    Tailscale VPN (필수)                 │
│                    100.64.0.0/10 Network                │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 목차
1. [사전 준비](#1-사전-준비)
2. [클러스터 초기화](#2-클러스터-초기화)
3. [Master 노드 설정](#3-master-노드-설정)
4. [Worker 노드 설정](#4-worker-노드-설정)
5. [네트워크 및 스토리지](#5-네트워크-및-스토리지)
6. [인증서 및 인그레스](#6-인증서-및-인그레스)
7. [고가용성 Data Plane 배포](#7-고가용성-data-plane-배포)
8. [모니터링 및 운영](#8-모니터링-및-운영)

---

## 1. 사전 준비

### 1.1 Oracle Cloud ARM64 4-Node 고가용성 구성

| 노드 | 호스트명 | Tailscale IP | 역할 | 컴포넌트 배치 |
|------|---------|-------------|------|-------------|
| Node 1 | instance-20250216-2117 | 100.64.0.1 | Control Plane | • Kubernetes API Server<br>• etcd<br>• Controller Manager<br>• Scheduler<br>• Higress Gateway & Console |
| Node 2 | instance-20250209-1502 | 100.64.0.2 | Worker (DB) | • MongoDB Primary<br>• Data Plane Server (Primary) |
| Node 3 | instance-20250209-1504 | 100.64.0.3 | Worker (App) | • MongoDB Secondary<br>• Data Plane Server (Secondary)<br>• Data Plane Web |
| Node 4 | instance-20250306-1735 | 100.64.0.6 | Worker (Storage) | • MinIO<br>• Prometheus<br>• Grafana<br>• Backup Services |

#### 리소스 사양 (각 노드)
- **CPU**: 4 OCPU (ARM Ampere A1)
- **RAM**: 24GB
- **Disk**: 200GB Block Volume
- **Network**: 1Gbps

### 1.2 필요 도구 및 버전
- **OS**: Oracle Linux 8.x (ARM64)
- **Kubernetes**: v1.28.15
- **Containerd**: v1.7.0+
- **Cilium**: v1.17.5 (CNI)
- **Helm**: v3.15.0
- **Higress**: v2.1.6 (Ingress Controller)

### 1.3 네트워크 구성
- **Tailscale**: P2P VPN (**필수** - 여러 Oracle 계정 간 통신)
- **Pod Network**: 10.244.0.0/16
- **Service Network**: 10.96.0.0/12
- **NodePort Range**: 30000-32767

### 1.4 도메인 및 인증서
- 도메인: `prod.scraping.run`
- Cloudflare DNS (DNS-01 Challenge)
- Let's Encrypt 와일드카드 인증서

---

## 2. 클러스터 초기화

### 2.1 기존 클러스터 리셋 (필요한 경우)

모든 노드에서 다음 스크립트를 실행하여 기존 Kubernetes 설정을 완전히 제거합니다:

```bash
#!/bin/bash
# reset-k8s.sh 실행
chmod +x reset-k8s.sh
./reset-k8s.sh
```

### 2.2 노드별 호스트네임 설정

```bash
# Node 1 (Master)
sudo hostnamectl set-hostname instance-20250216-2117

# Node 2 (Worker)
sudo hostnamectl set-hostname instance-20250209-1502

# Node 3 (Worker)
sudo hostnamectl set-hostname instance-20250209-1504

# Node 4 (Worker)
sudo hostnamectl set-hostname instance-20250306-1735
```

### 2.3 Tailscale 설정 확인 (필수)

```bash
# Tailscale 상태 확인
tailscale status

# Tailscale IP 확인
tailscale ip -4

# 다른 노드와 연결 테스트
tailscale ping instance-20250216-2117  # 각 노드에서 실행
tailscale ping instance-20250209-1502
tailscale ping instance-20250209-1504
tailscale ping instance-20250306-1735
```

### 2.4 /etc/hosts 파일 설정 (모든 노드)

```bash
# Tailscale IP로 설정 (필수)
# 각 노드의 실제 Tailscale IP로 변경하세요
cat <<EOF | sudo tee -a /etc/hosts
100.64.0.1 instance-20250216-2117
100.64.0.2 instance-20250209-1502
100.64.0.3 instance-20250209-1504
100.64.0.4 instance-20250306-1735
EOF

# 각 노드의 실제 Tailscale IP 확인 방법:
# tailscale status로 각 노드의 IP 확인 후 위 값을 수정
```

---

## 3. Master 노드 설정

### 3.1 Oracle Cloud 방화벽 설정 (필수)

Oracle Cloud는 기본적으로 OCI Security List를 사용하며, 로컬 방화벽(iptables/firewalld)은 비활성화하는 것이 일반적입니다.

```bash
# 로컬 방화벽 비활성화 (Oracle Cloud 권장)
# firewalld 중지 및 비활성화
sudo systemctl stop firewalld 2>/dev/null || true
sudo systemctl disable firewalld 2>/dev/null || true

# iptables 서비스 중지 (Oracle Linux)
sudo systemctl stop iptables 2>/dev/null || true
sudo systemctl disable iptables 2>/dev/null || true

# 방화벽 상태 확인
echo "Firewall status:"
sudo systemctl status firewalld --no-pager 2>/dev/null || echo "firewalld not installed"
sudo systemctl status iptables --no-pager 2>/dev/null || echo "iptables service not installed"

# ⚠️ 중요: Oracle Cloud는 OCI Console의 Security List로 방화벽을 관리합니다!
```

### OCI Console에서 Security List 설정 (필수!)

Oracle Cloud Console에 로그인하여 다음 설정을 수행하세요:

1. **Networking → Virtual Cloud Networks → 해당 VCN 선택**
2. **Security Lists → Default Security List 또는 Custom Security List 선택**
3. **Ingress Rules 추가:**

| Source | Protocol | Port Range | Description |
|--------|----------|------------|-------------|
| 0.0.0.0/0 | TCP | 22 | SSH |
| 0.0.0.0/0 | TCP | 80 | HTTP |
| 0.0.0.0/0 | TCP | 443 | HTTPS |
| 0.0.0.0/0 | TCP | 6443 | Kubernetes API |
| 0.0.0.0/0 | TCP | 30000-32767 | NodePort Services |
| VCN CIDR | TCP | 2379-2380 | etcd |
| VCN CIDR | TCP | 10250-10252 | kubelet |
| VCN CIDR | TCP | 4240 | Cilium health |
| VCN CIDR | TCP | 4244 | Cilium Hubble |
| VCN CIDR | UDP | 8472 | Cilium VXLAN |
| VCN CIDR | UDP | 51871 | WireGuard (Cilium) |
| 0.0.0.0/0 | UDP | 51820 | Tailscale |

```bash
# Security List 설정 확인 명령
echo "⚠️  OCI Console에서 위의 포트들이 Security List에 추가되었는지 확인하세요!"
echo "설정 경로: OCI Console → Networking → VCN → Security Lists → Ingress Rules"
```

### 3.2 시스템 준비사항 (모든 노드에서 실행)

```bash
# 0. 시스템 업데이트 및 필수 패키지
# Oracle Linux 8 / RHEL 8 / CentOS 8
sudo dnf update -y
sudo dnf install -y curl wget git vim net-tools telnet bind-utils

# Ubuntu/Debian (참고용)
# sudo apt-get update
# sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# 1. Swap 비활성화
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 2. 커널 모듈 로드
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 3. 시스템 파라미터 설정
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 4. Containerd 설치
# Oracle Linux 8 / RHEL 8
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y containerd.io

# Ubuntu/Debian (참고용)
# sudo apt-get update
# sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo systemctl restart containerd

# 5. Kubernetes 패키지 설치
# Oracle Linux 8 / RHEL 8
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo dnf install -y kubelet-1.28.15 kubeadm-1.28.15 kubectl-1.28.15 --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# Ubuntu/Debian (참고용)
# sudo mkdir -p /etc/apt/keyrings
# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
# sudo apt-get update
# sudo apt-get install -y kubelet=1.28.15-1.1 kubeadm=1.28.15-1.1 kubectl=1.28.15-1.1
# sudo apt-mark hold kubelet kubeadm kubectl

# 6. crictl 설치 (컨테이너 디버깅용)
VERSION="v1.28.0"
# ARM64 아키텍처 확인 및 다운로드
if [ "$(uname -m)" = "aarch64" ]; then
    ARCH="arm64"
else
    ARCH="amd64"
fi
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-${ARCH}.tar.gz
sudo tar zxvf crictl-$VERSION-linux-${ARCH}.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-${ARCH}.tar.gz
```

### 3.3 Master 노드 초기화 (instance-20250216-2117에서만 실행)

```bash
# Tailscale IP 가져오기 (필수)
MASTER_IP=$(tailscale ip -4 | head -n 1)
if [ -z "$MASTER_IP" ]; then
    echo "ERROR: Tailscale IP를 찾을 수 없습니다. Tailscale이 실행 중인지 확인하세요."
    echo "tailscale status 명령으로 상태를 확인하세요."
    exit 1
fi
echo "Master Tailscale IP: $MASTER_IP"

# Public IP는 선택사항 (필요시 사용)
PUBLIC_IP=$(curl -s ifconfig.me)
echo "Public IP (선택사항): $PUBLIC_IP"

# kubeadm 설정 파일 생성
cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $MASTER_IP
  bindPort: 6443
skipPhases:
  - addon/kube-proxy
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.15
networking:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
apiServer:
  certSANs:
    - 127.0.0.1
    - $MASTER_IP
    - $PUBLIC_IP
    - localhost
    - kubernetes
    - kubernetes.default
    - kubernetes.default.svc
    - kubernetes.default.svc.cluster.local
  extraArgs:
    enable-admission-plugins: NodeRestriction,ResourceQuota
controllerManager:
  extraArgs:
    bind-address: 0.0.0.0
scheduler:
  extraArgs:
    bind-address: 0.0.0.0
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true
cgroupDriver: systemd
EOF

# kubeadm 초기화 실행
sudo kubeadm init --config=kubeadm-config.yaml

# kubectl 설정
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 클러스터 구성 선택
echo "==========================================="
echo "클러스터 구성을 선택하세요:"
echo "1) 단일 노드 (마스터가 워커 역할도 수행)"
echo "2) 다중 노드 (마스터 전용, 워커 노드 별도)"
echo "==========================================="

# Option 1: 단일 노드 클러스터 (마스터에 워크로드 배포 허용)
# 리소스가 제한적이거나 개발/테스트 환경에 적합
echo "단일 노드로 구성하려면 다음 명령을 실행하세요:"
echo "kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
echo "kubectl label nodes --all node-role.kubernetes.io/worker=true"

# Option 2: 다중 노드 클러스터 (프로덕션 권장)
# 마스터는 컨트롤 플레인만, 워커는 워크로드 실행
echo ""
echo "다중 노드로 구성하려면:"
echo "1. 이 단계를 건너뛰고"
echo "2. 워커 노드에서 아래 join 명령을 실행하세요"

# Join 토큰 생성 (24시간 유효)
echo ""
echo "워커 노드 추가를 위한 join 명령:"
kubeadm token create --print-join-command

# 토큰 목록 확인
kubeadm token list
```

### 3.3 kubelet 인증서 자동 승인 설정 (Master에서 실행)

```bash
# kubelet-serving 인증서 자동 승인 설정
# 이 설정이 없으면 Worker 노드 Join 후 TLS 에러 발생
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubelet-serving-cert-approver
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:nodes
EOF

echo "✅ kubelet 인증서 자동 승인이 설정되었습니다."
```

### 3.4 노드 상태 확인

```bash
# 현재 노드 상태 (Master만 있는 상태)
kubectl get nodes

# 노드가 NotReady 상태면 CNI 설치 필요 (섹션 5.1 참조)
```

## 4. Worker 노드 설정

각 Worker 노드(instance-20250209-1502, instance-20250209-1504, instance-20250306-1735)에서 아래 단계를 실행합니다.

### 4.1 Worker 노드 Join (instance-20250209-1502, instance-20250209-1504, instance-20250306-1735에서 각각 실행)

```bash
# 1. Tailscale IP 확인 (필수)
TAIL_IP=$(tailscale ip -4 | head -n 1)
if [ -z "$TAIL_IP" ]; then
    echo "ERROR: Tailscale IP를 찾을 수 없습니다. Tailscale이 실행 중인지 확인하세요."
    exit 1
fi
echo "Worker Tailscale IP: $TAIL_IP"

# 2. kubelet에 Tailscale IP 설정
# 중요: kubeadm join은 --node-ip 플래그를 지원하지 않음
# 대신 /etc/default/kubelet에 설정해야 함
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--node-ip=${TAIL_IP}"
EOF

# systemd 재로드
sudo systemctl daemon-reload

# 3. Master에서 받은 join 명령 실행
# Master 노드에서 'kubeadm token create --print-join-command' 실행하여 얻은 명령 사용
# 예시 (실제 토큰과 해시로 교체):
sudo kubeadm join 100.64.0.1:6443 \
  --token abcdef.1234567890abcdef \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef

# 4. Join 후 kubelet 상태 확인
sudo systemctl status kubelet --no-pager
```

### 4.2 Join 문제 해결

#### Worker 노드가 Join되지 않는 경우:

```bash
# 1. Master에서 토큰 확인
kubeadm token list

# 토큰이 만료된 경우 새로 생성
kubeadm token create --print-join-command

# 2. Worker 노드에서 kubelet 상태 확인
sudo systemctl status kubelet
sudo journalctl -xeu kubelet | tail -50

# 3. Worker 노드에서 Tailscale 연결 확인
tailscale ping instance-20250216-2117
# 또는 Master의 Tailscale IP로 직접 ping
ping 100.64.0.1

# 4. Worker 노드 완전 초기화 (leftover 설정 제거)
# 기존 설정이 남아있어 문제가 발생하는 경우 사용
sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd
sudo rm -rf /etc/cni/net.d /var/lib/cni/
sudo rm -f /etc/default/kubelet

# iptables 정리
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# kubelet 재시작
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 5. Tailscale IP로 다시 Join
TAIL_IP=$(tailscale ip -4)
echo "KUBELET_EXTRA_ARGS=\"--node-ip=${TAIL_IP}\"" | sudo tee /etc/default/kubelet
sudo systemctl daemon-reload

# Master에서 받은 join 명령 재실행
```

### 4.3 Join 상태 확인 (Master에서 실행)

```bash
# 노드 Join 상태 모니터링
kubectl get nodes -w

# 모든 노드가 표시될 때까지 대기
# 예상 결과:
# NAME       STATUS     ROLES           AGE   VERSION
# instance-20250216-2117   NotReady   control-plane   10m   v1.28.15
# instance-20250209-1502   NotReady   <none>          1m    v1.28.15
# instance-20250209-1504   NotReady   <none>          1m    v1.28.15
# instance-20250306-1735   NotReady   <none>          1m    v1.28.15

# NotReady 상태는 CNI가 아직 설치되지 않아서임 (정상)
# 섹션 5.1에서 Cilium 설치 후 Ready로 변경됨

# CSR (Certificate Signing Request) 확인
kubectl get csr

# Pending 상태의 CSR이 있다면 승인 (자동 승인 설정이 안 된 경우)
kubectl get csr -o name | xargs kubectl certificate approve
```

### 4.4 노드 레이블 설정 (Master에서 실행)

**중요**: 모든 Worker 노드가 클러스터에 Join된 후에 실행하세요.

```bash
# 노드 확인 (4개 노드가 모두 보여야 함)
kubectl get nodes

# 노드가 4개 미만인 경우:
# 1. Worker 노드에서 join 명령을 실행했는지 확인
# 2. 각 Worker 노드에서 'sudo systemctl status kubelet' 확인
# 3. Master에서 새 토큰 생성: kubeadm token create --print-join-command

# Worker 노드 레이블 설정 (노드가 존재할 때만 실행)
kubectl label nodes instance-20250209-1502 node-role.kubernetes.io/worker=true --overwrite
kubectl label nodes instance-20250209-1504 node-role.kubernetes.io/worker=true --overwrite
kubectl label nodes instance-20250306-1735 node-role.kubernetes.io/worker=true --overwrite

# 용도별 레이블 설정
kubectl label nodes instance-20250209-1502 node-role=database --overwrite
kubectl label nodes instance-20250209-1504 node-role=application --overwrite
kubectl label nodes instance-20250306-1735 node-role=storage --overwrite

# 레이블 확인
kubectl get nodes --show-labels
```

---

## 5. 네트워크 및 스토리지

### 5.1 Cilium CNI 설치

#### Helm 설치
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add cilium https://helm.cilium.io/
helm repo update
```

#### Cilium 설치 (4노드 최적화)

```bash
# Cilium values 파일 생성
cat <<EOF > cilium-values.yaml
routingMode: tunnel
tunnelProtocol: vxlan
kubeProxyReplacement: true
bpf:
  masquerade: true
  tproxy: true
ipam:
  mode: kubernetes
mtu: 1280
k8sServiceHost: $MASTER_IP
k8sServicePort: 6443
encryption:
  enabled: false
hubble:
  enabled: true
  tls:
    enabled: false
  relay:
    enabled: true
    tls:
      server:
        enabled: false
      client:
        enabled: false
  ui:
    enabled: false
operator:
  replicas: 1
ipv4:
  enabled: true
ipv6:
  enabled: false
EOF

# Helm으로 설치
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.17.5 \
  --values cilium-values.yaml
```

#### Cilium 상태 확인

```bash
# Cilium CLI 설치
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# 상태 확인
cilium status --wait
```

---

### 5.2 스토리지 설정

#### Helm Repository 추가

```bash
# 필수 Helm repositories 추가
helm repo add openebs https://openebs.github.io/charts
helm repo add jetstack https://charts.jetstack.io
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add higress https://higress.io/helm-charts
helm repo add apecloud https://apecloud.github.io/helm-charts
helm repo update
```

#### OpenEBS 설치 (Local PV)

```bash
# OpenEBS values 파일 생성
cat <<EOF > openebs-values.yaml
engines:
  replicated:
    mayastor:
      enabled: false
  local:
    hostpath:
      enabled: true
      basePath: /var/openebs/local
helper:
  imagePrefix: "openebs/"
analytics:
  enabled: false
defaultStorageConfig:
  enabled: true
EOF

# OpenEBS 설치
helm upgrade --install openebs openebs/openebs \
  --namespace openebs \
  --create-namespace \
  --version 3.10.0 \
  --values openebs-values.yaml

# 기본 StorageClass 설정
kubectl patch storageclass openebs-hostpath \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# StorageClass 확인
kubectl get storageclass
```

### 5.3 cert-manager 설치 (DNS 챌린지 준비)

```bash
# cert-manager CRDs 먼저 설치
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.crds.yaml

# cert-manager values 파일
cat <<EOF > cert-manager-values.yaml
crds:
  enabled: false  # 이미 설치함
  keep: true
global:
  leaderElection:
    namespace: cert-manager
prometheus:
  enabled: false
webhook:
  timeoutSeconds: 30
EOF

# cert-manager 설치
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.2 \
  --values cert-manager-values.yaml

# 설치 확인 (모든 Pod가 Running 될 때까지 대기)
kubectl -n cert-manager wait --for=condition=ready pod --all --timeout=300s
```

### 5.4 metrics-server 설치

```bash
# metrics-server 설치 (Tailscale 환경용 설정)
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set 'args={--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP}'
```

### 5.5 Higress 설치 (최신 v2.1.6) - Console 포함 (Master 노드에만 배포)

```bash
# Higress values 파일 생성 (Console 포함, Master 노드 전용)
cat <<EOF > higress-values.yaml
higress-core:
  gateway:
    replicas: 1
    service:
      type: NodePort
      nodePorts:
        http: 30080
        https: 30443
    httpsPort: 443  # HTTPS 포트 활성화
    resources:
      limits:
        cpu: 1000m
        memory: 1024Mi
      requests:
        cpu: 100m
        memory: 128Mi
    hostNetwork: true
    # Master 노드에만 배포
    nodeSelector:
      node-role.kubernetes.io/control-plane: ""
    tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
  controller:
    replicas: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    # Master 노드에만 배포
    nodeSelector:
      node-role.kubernetes.io/control-plane: ""
    tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule

# Higress Console 설정
higress-console:
  enabled: true
  domain: higress.prod.scraping.run
  service:
    type: ClusterIP
    port: 8080
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
  # 관리자 계정 설정
  adminUsername: admin
  adminPassword: aldhr1011

global:
  ingressClass: nginx  # nginx 호환 모드
  enableStatus: false
  enableGatewayAPI: false
  disableAlpnH2: false
  enableIstioAPI: true
  enableSRDS: true
  # ARM64 호환성
  arch: arm64
EOF

# Higress 설치 (v2.1.6) with Console
helm upgrade --install higress higress/higress \
  --namespace higress-system \
  --create-namespace \
  --version 2.1.6 \
  --values higress-values.yaml \
  --set higress-console.domain=higress.prod.scraping.run \
  --render-subchart-notes \
  --wait

# 설치 확인 (모든 Pod가 Running 될 때까지 대기)
kubectl wait --for=condition=ready pod --all -n higress-system --timeout=300s

# 와일드카드 인증서를 higress-system 네임스페이스로 복사
echo "인증서 복사 중..."
kubectl get secret prod-scraping-run-wildcards-tls -n data-plane-system -o yaml | \
  sed 's/namespace: data-plane-system/namespace: higress-system/' | \
  kubectl apply -f -

# Higress Console Ingress 생성
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: higress-console
  namespace: higress-system
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-cloudflare"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - higress.prod.scraping.run
    secretName: prod-scraping-run-wildcards-tls
  rules:
  - host: higress.prod.scraping.run
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: higress-console
            port:
              number: 8080
EOF

# Console 접속 정보 출력
echo ""
echo "========================================="
echo "Higress Console 설치 완료!"
echo "========================================="
echo "Console URL: https://gw.prod.scraping.run"
echo "Username: admin"
echo "Password: aldhr1011"
echo ""
echo "Grafana (내장 모니터링): https://gw.prod.scraping.run/grafana"
echo "========================================="

# 서비스 상태 확인
kubectl get pods -n higress-system
kubectl get svc -n higress-system
kubectl get ingress -n higress-system
```

> 💡 **Higress Console 기능**:
> - **Gateway 관리**: Ingress 규칙 설정 및 라우팅 정책 관리
> - **플러그인 관리**: WAF, Rate Limiting, 인증 플러그인 설정
> - **모니터링 대시보드**: 요청률, 에러율, P95/P99 레이턴시 확인
> - **서비스 디스커버리**: Kubernetes 서비스 자동 감지 및 설정

> ⚠️ **중요**: DNS에 `gw.prod.scraping.run` A 레코드를 추가해야 Console 접속이 가능합니다.

### 5.6 KubeBlocks 설치 (ARM64 데이터베이스 관리)

```bash
# KubeBlocks CRDs 먼저 설치
kubectl create -f https://github.com/apecloud/kubeblocks/releases/download/v0.9.0/kubeblocks_crds.yaml

# CRD 설치 확인 (필수)
kubectl wait --for condition=established --timeout=120s crd/clusters.apps.kubeblocks.io

# KubeBlocks values 파일 생성
cat <<EOF > kubeblocks-values.yaml
image:
  registry: docker.io
  pullPolicy: IfNotPresent
monitoring:
  enabled: false  # 리소스 절약
multiCluster:
  enabled: false  # 단일 클러스터
addonController:
  enabled: true
dataProtection:
  enabled: false  # 리소스 절약
# ARM64 최적화 리소스
resources:
  limits:
    cpu: 1000m
    memory: 1024Mi
  requests:
    cpu: 100m
    memory: 128Mi
# 단일 노드 톨러레이션
tolerations:
  - operator: Exists
EOF

# KubeBlocks 설치
helm upgrade --install kubeblocks apecloud/kubeblocks \
  --namespace kb-system \
  --create-namespace \
  --version 0.9.0 \
  --values kubeblocks-values.yaml \
  --wait

# 설치 확인
kubectl -n kb-system get pods
kubectl get crd | grep kubeblocks

# MongoDB Addon 설치 (선택사항)
# KubeBlocks가 완전히 준비된 후 실행
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kubeblocks -n kb-system --timeout=300s

# MongoDB 지원 확인
kubectl get clusterdefinition mongodb
kubectl get clusterversion mongodb-5.0
```

---

## 6. 인증서 및 인그레스

### 6.1 TLS 인증서 설정

#### Cloudflare API Token Secret 생성

```bash
# Cloudflare API 토큰 시크릿 생성
# 주의: API 토큰은 실제 토큰으로 교체하세요
kubectl -n cert-manager create secret generic cloudflare-api-token-secret \
  --from-literal=api-token="82LiIqSa8zZUkFNyNKgd6Xd5VIUbL9j7T5Vc4TN1"

# Cloudflare API 토큰 요구사항:
# - Zone:Zone:Read
# - Zone:DNS:Edit
# - 해당 도메인의 Zone에 대한 권한
```

#### ClusterIssuer 생성

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cloudflare
spec:
  acme:
    email: junsik.park@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-cloudflare-account-key
    solvers:
    - selector:
        dnsZones:
        - "prod.scraping.run"
      dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
EOF

# Staging 환경 테스트용 (Rate Limit 회피)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: junsik.park@gmail.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - selector:
        dnsZones:
        - "prod.scraping.run"
      dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
EOF
```

#### 와일드카드 인증서 생성

```bash
# data-plane-system 네임스페이스 생성
kubectl create namespace data-plane-system

# 와일드카드 인증서 생성 (prod.scraping.run)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: prod-scraping-run-wildcards
  namespace: data-plane-system
spec:
  secretName: prod-scraping-run-wildcards-tls
  issuerRef:
    name: letsencrypt-cloudflare
    kind: ClusterIssuer
  dnsNames:
  - "prod.scraping.run"
  - "*.prod.scraping.run"
EOF

# 인증서 발급 상태 확인
kubectl -n data-plane-system get certificate --watch

# 별도 터미널에서 상세 상태 확인
kubectl -n data-plane-system get certificaterequest
kubectl -n data-plane-system get order
kubectl -n data-plane-system get challenge

# 인증서 상태 상세 확인
kubectl -n data-plane-system describe certificate prod-scraping-run-wildcards

# DNS 레코드 확인 (DNS-01 챌린지)
dig _acme-challenge.prod.scraping.run TXT +short

# 인증서 발급 완료 확인 (Ready = True)
kubectl -n data-plane-system get certificate
# NAME                          READY   SECRET                             AGE
# prod-scraping-run-wildcards   True    prod-scraping-run-wildcards-tls   5m
```

#### 문제 해결

##### 와일드카드 도메인 중복 에러
```bash
# 에러: "Domain name is redundant with a wildcard domain"
# 해결: 와일드카드(*.domain.com)와 개별 서브도메인을 함께 요청하지 않음
# 올바른 설정: domain.com + *.domain.com만 사용
```

##### Rate Limit 에러
```bash
# Let's Encrypt Rate Limit에 걸린 경우
# 1. Staging 환경으로 변경하여 테스트
kubectl -n data-plane-system patch certificate prod-scraping-run-wildcards \
  --type='json' -p='[{"op": "replace", "path": "/spec/issuerRef/name", "value":"letsencrypt-staging"}]'

# 2. 테스트 완료 후 Production으로 변경
kubectl -n data-plane-system patch certificate prod-scraping-run-wildcards \
  --type='json' -p='[{"op": "replace", "path": "/spec/issuerRef/name", "value":"letsencrypt-cloudflare"}]'
```

##### CSR 승인 대기
```bash
# Challenge가 Pending 상태로 멈춘 경우
# 1. DNS 전파 확인
dig _acme-challenge.prod.scraping.run TXT +short

# 2. cert-manager 로그 확인
kubectl logs -n cert-manager deploy/cert-manager --tail=50

# 3. Cloudflare API 토큰 권한 확인
# - Zone:Zone:Read
# - Zone:DNS:Edit 권한 필요
```

##### 인증서 재발급
```bash
# 인증서 삭제 후 재생성
kubectl -n data-plane-system delete certificate prod-scraping-run-wildcards
kubectl -n data-plane-system delete secret prod-scraping-run-wildcards-tls

# Certificate 다시 생성 (위의 YAML 재적용)
```

---

## 7. Data Plane 배포

### 7.1 배포 준비

#### 환경 변수 설정

```bash
# 배포 디렉토리로 이동
cd /path/to/data-plane/build

# 환경 변수 설정
export DOMAIN=prod.scraping.run
export NAMESPACE=data-plane-system
export DB_PV_SIZE=30Gi
export OSS_PV_SIZE=50Gi
export PROMETHEUS_PV_SIZE=20Gi
export EXTERNAL_HTTP_SCHEMA=https
export ENABLE_MONITOR=true

# 도메인 확인
host $DOMAIN
```

### 7.2 start.sh 스크립트 실행

```bash
# start.sh 스크립트 실행 권한 부여
chmod +x start.sh

# Data Plane 전체 배포 실행
./start.sh

# 스크립트는 다음 작업을 자동으로 수행합니다:
# 1. 네임스페이스 생성 (data-plane-system)
# 2. MongoDB 4.4 배포 (mongodb-4.4.yaml 사용)
# 3. Prometheus 설치 (ENABLE_MONITOR=true인 경우)
# 4. MinIO 객체 스토리지 배포
# 5. Data Plane Server 배포
# 6. Data Plane Web 배포
# 7. 시스템 관리자 계정 생성
```

### 7.3 배포 상태 확인

```bash
# 전체 Pod 상태 확인
kubectl -n data-plane-system get pods

# 서비스 확인
kubectl -n data-plane-system get svc

# Ingress 확인
kubectl -n data-plane-system get ingress

# PVC 상태 확인
kubectl -n data-plane-system get pvc
```

### 7.4 배포 검증

```bash
# MongoDB 연결 테스트
kubectl -n data-plane-system exec mongodb-0 -- mongo --eval "db.version()"

# MinIO 상태 확인
kubectl -n data-plane-system logs -l app=minio --tail=20

# Data Plane Server 로그 확인
kubectl -n data-plane-system logs -l app=data-plane-server --tail=50

# Web UI 접근 테스트
curl -k https://$DOMAIN
curl -k https://api.$DOMAIN/healthz
```

### 7.5 문제 해결

#### Pod가 시작되지 않는 경우
```bash
# Pod 상세 정보 확인
kubectl -n data-plane-system describe pod <POD_NAME>

# 이벤트 확인
kubectl -n data-plane-system get events --sort-by='.lastTimestamp'
```

#### PVC가 Pending 상태인 경우
```bash
# StorageClass 확인
kubectl get storageclass

# OpenEBS 상태 확인
kubectl -n openebs get pods
```

#### Ingress가 작동하지 않는 경우
```bash
# Higress/Nginx Ingress Controller 상태 확인
kubectl -n higress-system get pods
kubectl -n ingress-nginx get pods

# Ingress 리소스 상세 정보
kubectl -n data-plane-system describe ingress
```

### 7.6 초기 설정

스크립트 실행 완료 후 출력되는 정보를 확인하세요:

```bash
# 출력 예시:
========================================
Data-Plane services:
========================================
API Server: https://api.prod.scraping.run
Web Console: https://prod.scraping.run
MinIO Console: https://minio.prod.scraping.run
OSS Endpoint: https://oss.prod.scraping.run

Admin credentials:
Username: admin
Password: [자동 생성된 패스워드]

Please save these credentials securely!
========================================
```

---

## 8. 모니터링 및 운영

### 8.1 클러스터 상태 모니터링

```bash
# 노드별 리소스 사용량
kubectl top nodes

# Pod 분포 확인
kubectl get pods -A -o wide --field-selector spec.nodeName=instance-20250209-1502
kubectl get pods -A -o wide --field-selector spec.nodeName=instance-20250209-1504
kubectl get pods -A -o wide --field-selector spec.nodeName=instance-20250306-1735

# 서비스 헬스체크
kubectl -n data-plane-system get pods
kubectl -n data-plane-system get svc
kubectl -n data-plane-system get ingress

# MongoDB 상태 확인
kubectl exec -n data-plane-system mongodb-0 -- mongo --eval "rs.status()"
```

### 8.2 서비스 접근 테스트

```bash
# API 서버 테스트
curl -k https://api.prod.scraping.run/v1/regions

# Web UI 접근
echo "Web UI: https://prod.scraping.run"
echo "API Server: https://api.prod.scraping.run"
echo "MinIO Console: https://minio.prod.scraping.run"
echo "OSS: https://oss.prod.scraping.run"
echo "Grafana: https://grafana.prod.scraping.run (if enabled)"
```

### 8.3 노드 장애 복구

#### Worker 노드 장애 시
```bash
# 1. 장애 노드 확인
kubectl get nodes
kubectl describe node <failed-node>

# 2. 노드 격리 (선택적)
kubectl cordon <failed-node>
kubectl drain <failed-node> --ignore-daemonsets --delete-emptydir-data

# 3. 노드 복구 후
kubectl uncordon <failed-node>

# 4. Pod 재배치 확인
kubectl get pods -A -o wide | grep <recovered-node>
```

#### Master 노드 장애 시 (단일 마스터)
```bash
# 1. etcd 백업에서 복구
sudo kubeadm reset
sudo kubeadm init --config=/etc/kubernetes/kubeadm-config.yaml

# 2. 네트워크 플러그인 재설치
kubectl apply -f cilium.yaml

# 3. Worker 노드 재조인
# 각 워커 노드에서:
sudo kubeadm reset
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### 8.4 백업 및 복구

#### etcd 백업
```bash
# 백업 스크립트 생성
cat <<'EOF' > /usr/local/bin/backup-etcd.sh
#!/bin/bash
BACKUP_DIR="/backup/etcd"
mkdir -p $BACKUP_DIR
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save $BACKUP_DIR/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db
# 7일 이상 된 백업 삭제
find $BACKUP_DIR -name "*.db" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/backup-etcd.sh

# cron 등록 (매일 새벽 2시)
echo "0 2 * * * /usr/local/bin/backup-etcd.sh" | crontab -
```

#### MongoDB 백업
```bash
# MongoDB 백업
kubectl exec -n data-plane-system mongodb-0 -- mongodump --out=/tmp/backup
kubectl cp data-plane-system/mongodb-0:/tmp/backup ./mongodb-backup-$(date +%Y%m%d)

# MongoDB 복구
kubectl cp ./mongodb-backup data-plane-system/mongodb-0:/tmp/restore
kubectl exec -n data-plane-system mongodb-0 -- mongorestore /tmp/restore
```

### 8.5 성능 튜닝

#### 노드별 리소스 최적화
```bash
# instance-20250209-1502 (DB 노드) - MongoDB 우선
kubectl label nodes instance-20250209-1502 node-type=database
kubectl taint nodes instance-20250209-1502 node-type=database:PreferNoSchedule

# instance-20250209-1504 (App 노드) - 애플리케이션 우선  
kubectl label nodes instance-20250209-1504 node-type=application

# instance-20250306-1735 (Storage 노드) - 스토리지/모니터링 우선
kubectl label nodes instance-20250306-1735 node-type=storage
```

#### Pod 리소스 제한 설정
```yaml
# Data Plane Server 리소스 최적화
resources:
  requests:
    memory: "2Gi"
    cpu: "500m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### 8.6 로그 수집 및 분석

```bash
# 모든 Pod 로그 확인
kubectl logs -n data-plane-system -l app=data-plane-server --tail=100

# 특정 노드의 시스템 로그
ssh instance-20250209-1502 "sudo journalctl -u kubelet -f"

# 컨테이너 런타임 로그
ssh instance-20250209-1502 "sudo journalctl -u containerd -f"

# Cilium 네트워크 디버깅
kubectl -n kube-system exec -it ds/cilium -- cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium connectivity test
```

---

## 9. 트러블슈팅

### 9.1 일반적인 문제 해결

#### Pod가 Pending 상태일 때
```bash
# 원인 확인
kubectl describe pod <pod-name> -n <namespace>

# 노드 리소스 확인
kubectl describe nodes | grep -A 5 "Allocated resources"

# PVC 상태 확인
kubectl get pvc -A
```

#### 네트워크 연결 문제
```bash
# Cilium 상태 확인
kubectl -n kube-system get pods -l k8s-app=cilium
cilium status

# DNS 확인
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default

# Service 연결 테스트
kubectl run test-curl --image=curlimages/curl --rm -it -- curl http://data-plane-server.data-plane-system:9170
```

#### 인증서 문제
```bash
# 인증서 상태 확인
kubectl get certificate -A
kubectl describe certificate -n data-plane-system

# cert-manager 로그 확인
kubectl logs -n cert-manager deploy/cert-manager
```

### 9.2 4노드 클러스터 특정 이슈

#### 노드 간 통신 문제
```bash
# Tailscale 연결 확인
tailscale status

# 노드 간 ping 테스트
ping 100.64.0.2  # instance-20250209-1502
ping 100.64.0.3  # instance-20250209-1504
ping 100.64.0.4  # instance-20250306-1735

# iptables 규칙 확인
sudo iptables -L -n | grep TAILSCALE
```

#### MongoDB ReplicaSet 문제
```bash
# Primary 노드 확인
kubectl exec -n data-plane-system mongodb-0 -- mongo --eval "rs.isMaster()"

# 강제 Primary 선출
kubectl exec -n data-plane-system mongodb-0 -- mongo --eval "rs.stepDown()"

# ReplicaSet 재구성
kubectl exec -n data-plane-system mongodb-0 -- mongo --eval "rs.reconfig(rs.conf())"
```

#### 노드별 Pod 분포 불균형
```bash
# Pod 분포 재조정
kubectl rollout restart deployment/data-plane-server -n data-plane-system
kubectl rollout restart deployment/data-plane-web -n data-plane-system

# 수동 Pod 이동
kubectl delete pod <pod-name> -n <namespace>
```

---

## 10. 빠른 시작 가이드

### 10.1 자동화 스크립트

전체 설치를 자동화하는 스크립트:

```bash
#!/bin/bash
# quick-setup.sh - 4노드 HA 클러스터 빠른 설치

set -e

echo "==================================="
echo "4-Node HA Kubernetes Quick Setup"
echo "==================================="

# 환경 변수 설정
export DOMAIN=${DOMAIN:-prod.scraping.run}
export NAMESPACE=${NAMESPACE:-data-plane-system}
export NODE_TYPE=${1:-master}  # master, instance-20250209-1502, instance-20250209-1504, instance-20250306-1735

case $NODE_TYPE in
  master)
    echo "Setting up Master node (instance-20250216-2117)..."
    # 1. Kubernetes 초기화
    sudo kubeadm init --pod-network-cidr=10.0.0.0/8 \
      --apiserver-advertise-address=100.64.0.1
    
    # 2. kubeconfig 설정
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    
    # 3. Cilium 설치
    helm install cilium cilium/cilium --version 1.17.5 \
      --namespace kube-system \
      --set operator.replicas=1
    
    # 4. Join 토큰 생성
    echo "Join command for workers:"
    kubeadm token create --print-join-command > /tmp/join-command.txt
    cat /tmp/join-command.txt
    ;;
    
  worker*)
    echo "Setting up Worker node ($NODE_TYPE)..."
    echo "Please run the join command from master node"
    ;;
esac

echo "✅ Node setup completed!"
```

### 10.2 설치 검증 체크리스트

```bash
# 체크리스트 스크립트
cat <<'EOF' > verify-installation.sh
#!/bin/bash
echo "=== 4-Node HA Cluster Verification ==="
echo ""

# 1. 노드 상태
echo "✓ Checking nodes..."
kubectl get nodes

# 2. 시스템 Pod
echo "✓ Checking system pods..."
kubectl get pods -n kube-system

# 3. Data Plane 서비스
echo "✓ Checking Data Plane services..."
kubectl get all -n data-plane-system

# 4. 인그레스
echo "✓ Checking ingress..."
kubectl get ingress -A

# 5. 스토리지
echo "✓ Checking storage..."
kubectl get pv,pvc -A

# 6. 서비스 엔드포인트
echo "✓ Service endpoints:"
echo "  - Web: https://$DOMAIN"
echo "  - API: https://api.$DOMAIN"
echo "  - MinIO: https://minio.$DOMAIN"
echo "  - OSS: https://oss.$DOMAIN"

echo ""
echo "=== Verification Complete ==="
EOF

chmod +x verify-installation.sh
./verify-installation.sh
```

---

## 부록 A: 참고 명령어

### 유용한 kubectl 명령어
```bash
# 노드별 Pod 수 확인
kubectl get pods -A -o json | jq '.items | group_by(.spec.nodeName) | map({node: .[0].spec.nodeName, count: length})'

# 리소스 사용량 상위 Pod
kubectl top pods -A --sort-by=memory | head -20

# 최근 이벤트
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Pod 재시작
kubectl rollout restart deployment/<name> -n <namespace>

# 강제 삭제
kubectl delete pod <pod> -n <namespace> --force --grace-period=0
```

### 디버깅 명령어
```bash
# 임시 디버그 Pod 실행
kubectl run debug --image=nicolaka/netshoot --rm -it -- /bin/bash

# 특정 노드에서 Pod 실행
kubectl run debug --image=busybox --rm -it --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"instance-20250209-1502"}}}' -- /bin/sh

# 네트워크 정책 확인
kubectl get networkpolicies -A
```

---

## 부록 B: 설정 파일 템플릿

### values-override.yaml (HA 설정)
```yaml
# Data Plane HA 설정 오버라이드
replicaCount: 3

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - data-plane-server
      topologyKey: kubernetes.io/hostname

resources:
  requests:
    memory: "2Gi"
    cpu: "1"
  limits:
    memory: "4Gi"
    cpu: "2"

persistence:
  enabled: true
  storageClass: openebs-hostpath
  size: 30Gi
```

---

이 문서는 Oracle Cloud 환경에서 4노드 고가용성 Kubernetes 클러스터를 구축하기 위한 완전한 가이드입니다.

## 요약

- **클러스터 구성**: 1 Master + 3 Worker (4노드 HA)
- **네트워킹**: Tailscale VPN + Cilium CNI
- **스토리지**: OpenEBS LocalPV
- **Ingress**: Higress v2.1.6 (nginx 호환)
- **데이터베이스**: MongoDB 4.4 (ARM64 호환)
- **모니터링**: Prometheus + Grafana (선택적)

각 노드별 역할:
- **instance-20250216-2117**: Control Plane 전용
- **instance-20250209-1502**: MongoDB Primary, Data Plane Server
- **instance-20250209-1504**: MongoDB Secondary, Data Plane Server, Web
- **instance-20250306-1735**: MinIO, 모니터링, 백업

문제 발생 시 트러블슈팅 섹션을 참조하거나 로그를 확인하세요.