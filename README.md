# Kubernetes 企业级自动化部署脚本

[![版本](https://img.shields.io/badge/版本-v1.0.0-blue.svg)](https://github.com/novatra/k8s-auto)
[![许可证](https://img.shields.io/badge/许可证-MIT-green.svg)](LICENSE)
[![支持](https://img.shields.io/badge/支持-企业级-orange.svg)](https://github.com/novatra/k8s-auto)

> 🚀 **企业级生产就绪** | 🇨🇳 **国内网络优化** | 🔒 **安全可靠** | ⚡ **一键部署**

**开发组织**: Novatra 工作组  
**特性**: 单节点、集群、高可用模式部署 | 国内网络优化 | 企业级安全 | 生产环境就绪

---

## 📋 目录

- [✨ 特性亮点](#-特性亮点)
- [🎯 适用场景](#-适用场景)
- [🖥️ 系统支持](#️-系统支持)
- [⚡ 快速开始](#-快速开始)
- [📖 详细用法](#-详细用法)
- [🔧 配置选项](#-配置选项)
- [🌐 网络插件](#-网络插件)
- [🔐 高可用部署](#-高可用部署)
- [📊 监控组件](#-监控组件)
- [🐳 容器运行时](#-容器运行时)
- [🌍 镜像源配置](#-镜像源配置)
- [❓ 常见问题](#-常见问题)
- [🔧 故障排除](#-故障排除)
- [👥 贡献指南](#-贡献指南)

---

## ✨ 特性亮点

### 🚀 **全自动化部署**
- **一键安装**: 无需手动配置，全程自动化
- **智能检测**: 自动识别系统类型、架构、内核版本
- **容错机制**: 内置超时保护和错误恢复
- **进度可视**: 清晰的部署进度和状态显示

### 🌍 **国内网络优化**
- **多源镜像**: 阿里云、腾讯云、华为云、DaoCloud等
- **智能选择**: 自动测试并选择最快的镜像源
- **断点续传**: 网络中断后自动重试
- **本地缓存**: 支持本地配置文件部署

### 🔒 **企业级安全**
- **证书管理**: 自动生成100年有效期证书
- **权限控制**: 精细化的RBAC权限配置
- **安全加固**: 自动配置防火墙和SELinux
- **加密通信**: 全链路TLS加密

### 🏗️ **多种部署模式**
- **单节点模式**: 开发、测试环境快速部署
- **集群模式**: 生产环境多节点部署
- **高可用模式**: HAProxy + Keepalived 双VIP
- **混合云**: 支持本地和云端混合部署

---

## 🎯 适用场景

| 场景类型 | 推荐配置 | 部署命令 |
|---------|---------|---------|
| **开发测试** | 单节点 + Calico | `--install --calico-install` |
| **生产环境** | 集群 + 高可用 + 监控 | `--cluster-install --availability-vip-install` |
| **边缘计算** | 单节点 + Flannel | `--install --flannel-install` |
| **容器化改造** | 渐进式节点加入 | `--node-install` |

---

## 🖥️ 系统支持

### 操作系统支持

| 发行版 | 支持版本 | 状态 | 备注 |
|--------|---------|------|------|
| **Ubuntu** | 18.04, 20.04, 22.04, 24.04 | ✅ 完全支持 | 推荐 22.04 LTS |
| **CentOS** | 7, 8, 9 | ✅ 完全支持 | CentOS 7 需内核升级 |
| **RHEL** | 7, 8, 9 | ✅ 完全支持 | 企业级首选 |
| **Debian** | 10, 11, 12 | ✅ 完全支持 | 轻量级部署 |
| **Rocky Linux** | 8.10, 9.4, 9.5 | ✅ 完全支持 | CentOS 替代方案 |
| **AlmaLinux** | 8.10, 9.4 | ✅ 完全支持 | CentOS 替代方案 |
| **openEuler** | 20.03, 22.03, 24.03 | ✅ 完全支持 | 国产化首选 |
| **Anolis OS** | 7.7, 7.9, 8.2-8.9, 23 | ✅ 完全支持 | 阿里云OS |
| **UOS** | 20 | ✅ 完全支持 | 统信国产OS |
| **Deepin** | 20.9, 23 | ✅ 完全支持 | 深度国产OS |
| **银河麒麟** | v10 | ✅ 完全支持 | 国产化认证 |
| **openKylin** | 1.0, 1.0.1, 1.0.2, 2.0 | ✅ 完全支持 | 开放麒麟 |
| **openSUSE** | 15.5, 15.6 | ✅ 完全支持 | 企业级稳定 |

### 硬件架构支持

| 架构 | 状态 | 优化程度 | 应用场景 |
|------|------|---------|---------|
| **AMD64 (x86_64)** | ✅ 完全支持 | 🔥🔥🔥 | 服务器、工作站 |
| **ARM64 (aarch64)** | ✅ 完全支持 | 🔥🔥🔥 | 边缘计算、嵌入式 |

### 内核兼容性

| 内核版本 | Kubernetes 支持 | 推荐等级 |
|---------|----------------|---------|
| **< 4.19** | v1.24.x - v1.31.x | ⚠️ 需升级 |
| **4.19 - 5.4** | v1.24.x - v1.33.x | ✅ 支持良好 |
| **≥ 5.4** | v1.24.x - v1.34.x+ | 🔥 完美支持 |

---

## ⚡ 快速开始

### 💻 单节点快速部署（推荐新手）

```bash
# 1. 下载脚本
curl -fsSL https://raw.githubusercontent.com/novatra/k8s-auto/main/k8s-auto.sh -o k8s-auto.sh
chmod +x k8s-auto.sh

# 2. 一键部署（约10-15分钟）
sudo ./k8s-auto.sh --install --calico-install --metrics-server-install

# 3. 验证部署
kubectl get nodes
kubectl get pods -A
```

### 🏢 生产环境高可用部署

#### 步骤1：部署第一个Master节点

```bash
# Master-01 节点 (10.1.66.1)
sudo ./k8s-auto.sh --cluster-install \
  --control-plane-endpoint=10.1.66.17:9443 \
  --kubernetes-version=v1.34.1 \
  --node-name=k8s-master-01 \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --availability-vip-install \
  --availability-masters=k8s-master-01@10.1.66.1:6443,k8s-master-02@10.1.66.2:6443,k8s-master-03@10.1.66.3:6443 \
  --availability-vip=10.1.66.17 \
  --availability-vip-no=1
```

#### 步骤2：部署其他Master节点

```bash
# Master-02 节点 (10.1.66.2)
sudo ./k8s-auto.sh --availability-vip-install \
  --availability-masters=k8s-master-01@10.1.66.1:6443,k8s-master-02@10.1.66.2:6443,k8s-master-03@10.1.66.3:6443 \
  --availability-vip=10.1.66.17 \
  --availability-vip-no=2

# 然后加入集群
kubeadm join 10.1.66.17:9443 --token <token> --discovery-token-ca-cert-hash <hash> --control-plane
```

#### 步骤3：部署网络插件

```bash
# 在任意Master节点执行
sudo ./k8s-auto.sh --calico-install --auto-select-mirror
```

#### 步骤4：部署Worker节点

```bash
# Worker节点
sudo ./k8s-auto.sh --node-install
kubeadm join 10.1.66.17:9443 --token <token> --discovery-token-ca-cert-hash <hash>
```

---

## 📖 详细用法

### 🔧 基本安装命令

```bash
# 查看帮助
./k8s-auto.sh --help

# 查看版本
./k8s-auto.sh --version

# 查看支持的镜像源
./k8s-auto.sh --list-mirrors
```

### 📦 组件安装

```bash
# 仅安装容器运行时
./k8s-auto.sh --containerd-install  # 推荐
./k8s-auto.sh --docker-install      # 兼容模式

# 仅安装网络插件
./k8s-auto.sh --calico-install      # 推荐，功能丰富
./k8s-auto.sh --flannel-install     # 轻量级

# 安装Ingress控制器
./k8s-auto.sh --ingress-nginx-install

# 安装监控组件
./k8s-auto.sh --metrics-server-install
./k8s-auto.sh --prometheus-install

# 安装管理工具
./k8s-auto.sh --helm-install
./k8s-auto.sh --dashboard-install
```

### 🎯 组合安装

```bash
# 完整的生产环境部署
./k8s-auto.sh --cluster-install \
  --calico-install \
  --ingress-nginx-install \
  --metrics-server-install \
  --helm-install \
  --prometheus-install \
  --kubernetes-version=v1.34.1

# 开发环境最小安装
./k8s-auto.sh --install \
  --flannel-install \
  --metrics-server-install

# 边缘计算轻量化部署
./k8s-auto.sh --install \
  --flannel-install \
  --taint-master
```

---

## 🔧 配置选项

### 🌐 网络配置

| 参数 | 默认值 | 说明 | 示例 |
|------|--------|------|------|
| `--pod-network-cidr` | `10.244.0.0/16` | Pod网络CIDR | `--pod-network-cidr=172.16.0.0/16` |
| `--service-cidr` | `10.96.0.0/12` | Service网络CIDR | `--service-cidr=10.97.0.0/12` |
| `--control-plane-endpoint` | 无 | 控制平面端点 | `--control-plane-endpoint=10.1.66.17:9443` |
| `--interface-name` | 自动检测 | 网络接口名称 | `--interface-name=eth0` |

### 🏷️ 节点配置

| 参数 | 默认值 | 说明 | 示例 |
|------|--------|------|------|
| `--node-name` | 主机名 | 节点名称 | `--node-name=k8s-master-01` |
| `--kubernetes-version` | `v1.34.1` | K8s版本 | `--kubernetes-version=v1.33.5` |

### 🔗 镜像源配置

| 参数 | 可选值 | 说明 |
|------|--------|------|
| `--docker-repo-type` | `aliyun`, `tencent`, `docker` | Docker仓库源 |
| `--kubernetes-repo-type` | `aliyun`, `tsinghua`, `kubernetes` | K8s仓库源 |
| `--helm-repo-type` | `huawei`, `helm` | Helm仓库源 |
| `--auto-select-mirror` | - | 自动选择最快镜像源 |

---

## 🌐 网络插件

### 🟢 Calico（推荐）

**适用场景**: 生产环境、复杂网络策略、大规模集群

**特性**:
- ✅ 支持网络策略 (Network Policy)
- ✅ BGP路由支持
- ✅ IPIP/VXLAN隧道
- ✅ 高性能数据平面
- ✅ 支持IPv4/IPv6双栈

```bash
# 基础安装
./k8s-auto.sh --calico-install

# 自定义配置文件
./k8s-auto.sh --calico-install --calico-url=/path/to/calico.yaml

# 自动选择最快镜像源
./k8s-auto.sh --calico-install --auto-select-mirror
```

### 🟡 Flannel（轻量级）

**适用场景**: 开发环境、小规模集群、边缘计算

**特性**:
- ✅ 简单易用
- ✅ 资源消耗低
- ✅ VXLAN隧道
- ⚠️ 不支持网络策略

```bash
# 基础安装
./k8s-auto.sh --flannel-install

# 自定义配置文件
./k8s-auto.sh --flannel-install --flannel-url=/path/to/flannel.yaml
```

---

## 🔐 高可用部署

### 🏗️ Master高可用架构

```
                    ┌─────────────────┐
                    │   Load Balancer │
                    │  (VIP: 10.1.66.17) │
                    └─────────┬───────┘
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
   ┌───────▼───────┐ ┌────────▼────────┐ ┌──────▼───────┐
   │  Master-01    │ │   Master-02     │ │  Master-03   │
   │ 10.1.66.1     │ │  10.1.66.2      │ │ 10.1.66.3    │
   │ HAProxy+Keepalived│ │ HAProxy+Keepalived│ │HAProxy+Keepalived│
   └───────────────┘ └─────────────────┘ └──────────────┘
```

### 📋 Master VIP配置

```bash
# 第一个Master节点（MASTER状态）
./k8s-auto.sh --availability-vip-install \
  --availability-masters=master-01@10.1.66.1:6443,master-02@10.1.66.2:6443,master-03@10.1.66.3:6443 \
  --availability-vip=10.1.66.17 \
  --availability-vip-no=1

# 其他Master节点（BACKUP状态）
./k8s-auto.sh --availability-vip-install \
  --availability-masters=master-01@10.1.66.1:6443,master-02@10.1.66.2:6443,master-03@10.1.66.3:6443 \
  --availability-vip=10.1.66.17 \
  --availability-vip-no=2  # 递增编号
```

### 🌍 Worker VIP配置

```bash
# Worker负载均衡（用于Ingress流量）
./k8s-auto.sh --availability-worker-vip-install \
  --availability-worker-vip=10.1.66.18 \
  --availability-worker-vip-no=1
```

### 📊 监控面板

| 组件 | 访问地址 | 凭据 |
|------|---------|------|
| **HAProxy Stats** | `http://NODE-IP:8888/stats` | admin/admin123456 |
| **Worker HAProxy** | `http://NODE-IP:8889/stats` | admin/admin123456 |

---

## 📊 监控组件

### 📈 Metrics Server

**用途**: Pod和Node资源监控，HPA支持

```bash
# 基础安装
./k8s-auto.sh --metrics-server-install

# 启用安全TLS（生产环境）
./k8s-auto.sh --metrics-server-install --metrics-server-secure-tls

# 验证安装
kubectl top nodes
kubectl top pods -A
```

### 🔥 Prometheus监控栈

**包含组件**: Prometheus + Grafana + AlertManager + Node Exporter

```bash
# 完整监控栈
./k8s-auto.sh --prometheus-install

# 访问地址（NodePort模式）
# Prometheus: http://NODE-IP:30790
# Grafana: http://NODE-IP:30900 (admin/admin)
# AlertManager: http://NODE-IP:30893
```

### 🎛️ Kubernetes Dashboard

```bash
# 安装Dashboard（需要Helm）
./k8s-auto.sh --helm-install --dashboard-install

# 获取访问Token
kubectl -n kubernetes-dashboard create token admin-user --duration=86400s

# 访问地址
# https://kubernetes.dashboard.local (需配置Ingress)
```

---

## 🐳 容器运行时

### 🟢 containerd（推荐）

**优势**:
- ✅ Kubernetes原生支持
- ✅ 更轻量级，资源消耗低
- ✅ 更好的安全性
- ✅ 云原生标准

```bash
# 单独安装containerd
./k8s-auto.sh --containerd-install

# 验证安装
sudo systemctl status containerd
sudo ctr version
```

### 🔵 Docker（兼容模式）

**适用场景**: 需要docker命令行工具，现有Docker环境

```bash
# 单独安装Docker
./k8s-auto.sh --docker-install

# 验证安装
sudo systemctl status docker
sudo docker version
```

### ⚙️ 运行时配置

| 配置项 | containerd默认值 | 说明 |
|--------|-----------------|------|
| **根目录** | `/var/lib/containerd` | 数据存储位置 |
| **状态目录** | `/run/containerd` | 运行时状态 |
| **Pause镜像** | 国内镜像源 | Pod沙箱镜像 |
| **SystemdCgroup** | `true` | 使用systemd管理cgroup |

---

## 🌍 镜像源配置

### 🇨🇳 国内镜像源优先级

| 优先级 | 镜像源 | 域名 | 特点 |
|--------|--------|------|------|
| **1** | 阿里云 | `registry.aliyuncs.com` | 🔥 速度快，稳定性高 |
| **2** | 腾讯云 | `mirrors.cloud.tencent.com` | 🔥 覆盖面广 |
| **3** | 华为云 | `swr.cn-north-4.myhuaweicloud.com` | 🔥 企业级可靠 |
| **4** | DaoCloud | `docker.m.daocloud.io` | ✅ 社区活跃 |
| **5** | 1Panel | `docker.1panel.live` | ✅ 新兴镜像源 |

### 🚀 智能镜像选择

```bash
# 自动测试并选择最快镜像源
./k8s-auto.sh --calico-install --auto-select-mirror

# 手动指定镜像源类型
./k8s-auto.sh --install \
  --docker-repo-type=aliyun \
  --kubernetes-repo-type=aliyun
```

### 📥 自定义配置文件

```bash
# 使用本地配置文件
./k8s-auto.sh --calico-install --calico-url=/path/to/calico.yaml
./k8s-auto.sh --flannel-install --flannel-url=/path/to/flannel.yaml
./k8s-auto.sh --ingress-nginx-install --ingress-nginx-url=/path/to/deploy.yaml
```

---

## ❓ 常见问题

<details>
<summary><strong>🔍 Q1: 脚本支持哪些操作系统？</strong></summary>

**A**: 支持主流Linux发行版：
- **Red Hat系**: CentOS, RHEL, Rocky, AlmaLinux, Anolis OS
- **Debian系**: Ubuntu, Debian
- **国产系统**: openEuler, UOS, Deepin, 银河麒麟, openKylin
- **其他**: openSUSE

详细支持列表请参考 [系统支持](#️-系统支持) 部分。
</details>

<details>
<summary><strong>⚡ Q2: 单节点部署需要多长时间？</strong></summary>

**A**: 部署时间取决于网络环境：
- **国内网络**: 10-15分钟
- **网络较慢**: 20-30分钟
- **离线部署**: 5-10分钟（使用本地镜像）

建议使用 `--auto-select-mirror` 参数自动选择最快镜像源。
</details>

<details>
<summary><strong>🔧 Q3: 如何自定义Kubernetes版本？</strong></summary>

**A**: 使用 `--kubernetes-version` 参数：

```bash
# 安装特定版本
./k8s-auto.sh --install --kubernetes-version=v1.33.5

# 查看内核兼容性
./k8s-auto.sh --help  # 查看支持的版本范围
```

**注意**: 内核版本需要与Kubernetes版本兼容。
</details>

<details>
<summary><strong>🌐 Q4: Calico和Flannel如何选择？</strong></summary>

**A**: 选择建议：

| 场景 | 推荐 | 原因 |
|------|------|------|
| **生产环境** | Calico | 支持网络策略，功能完整 |
| **开发测试** | Flannel | 简单轻量，资源消耗低 |
| **安全要求高** | Calico | 内置防火墙和微分段 |
| **边缘计算** | Flannel | 占用资源少 |
</details>

<details>
<summary><strong>🔐 Q5: 如何配置高可用集群？</strong></summary>

**A**: 高可用部署步骤：

1. **部署第一个Master** + VIP
2. **部署其他Master** + VIP  
3. **Worker节点加入**
4. **配置网络插件**

详细步骤请参考 [高可用部署](#-高可用部署) 部分。
</details>

<details>
<summary><strong>🐛 Q6: 部署失败如何排查？</strong></summary>

**A**: 排查步骤：

1. **检查系统要求**: 内核版本、系统支持
2. **检查网络**: 能否访问镜像源
3. **查看日志**: 脚本执行过程中的错误信息
4. **重置环境**: 使用 `kubeadm reset` 清理后重试
5. **使用本地镜像**: 离线部署避免网络问题

```bash
# 重置环境
sudo kubeadm reset -f
sudo rm -rf ~/.kube/
sudo systemctl stop kubelet containerd
sudo systemctl start containerd
```
</details>

---

## 🔧 故障排除

### 🚨 常见错误及解决方案

#### 1. **镜像拉取失败**

**现象**: `ImagePullBackOff`, `ErrImagePull`

**解决方案**:
```bash
# 方案1: 使用自动镜像选择
./k8s-auto.sh --calico-install --auto-select-mirror

# 方案2: 手动指定快速镜像源  
./k8s-auto.sh --calico-install --docker-repo-type=aliyun

# 方案3: 使用本地配置文件
./k8s-auto.sh --calico-install --calico-url=/path/to/local/calico.yaml
```

#### 2. **节点NotReady状态**

**现象**: `kubectl get nodes` 显示 `NotReady`

**排查步骤**:
```bash
# 1. 检查网络插件状态
kubectl get pods -n kube-system | grep -E "(calico|flannel)"

# 2. 检查kubelet状态
sudo systemctl status kubelet

# 3. 查看节点详细信息
kubectl describe node NODE-NAME

# 4. 重启网络插件
kubectl delete pods -n kube-system -l k8s-app=calico-node
```

#### 3. **DNS解析问题**

**现象**: Pod内无法解析域名

**解决方案**:
```bash
# 1. 检查CoreDNS状态
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. 重启CoreDNS
kubectl delete pods -n kube-system -l k8s-app=kube-dns

# 3. 测试DNS解析
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default
```

#### 4. **证书过期问题**

**现象**: API服务器无法访问

**解决方案**:
```bash
# 1. 检查证书有效期（脚本已配置100年）
sudo kubeadm certs check-expiration

# 2. 如需手动续期
sudo kubeadm certs renew all
sudo systemctl restart kubelet
```

### 📋 诊断命令

```bash
# 系统状态诊断
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get svc -A

# 集群组件状态
kubectl get componentstatuses

# 资源使用情况
kubectl top nodes
kubectl top pods -A

# 事件查看
kubectl get events --sort-by=.metadata.creationTimestamp

# 日志查看
journalctl -u kubelet -f
journalctl -u containerd -f
```

---

## 👥 贡献指南

### 💡 如何贡献

我们欢迎所有形式的贡献！

1. **🐛 报告Bug**: 在 [Issues](https://github.com/novatra/k8s-auto/issues) 中报告问题
2. **✨ 新功能**: 提交功能请求或Pull Request
3. **📚 文档**: 改进文档和示例
4. **🧪 测试**: 在不同环境中测试脚本

### 📝 开发规范

```bash
# 1. Fork项目
git clone https://github.com/your-username/k8s-auto.git

# 2. 创建功能分支
git checkout -b feature/new-feature

# 3. 提交更改
git commit -m "feat: add new feature"

# 4. 推送分支
git push origin feature/new-feature

# 5. 创建Pull Request
```

### 🧪 测试环境

推荐测试环境：
- **Ubuntu 22.04 LTS** (最常用)
- **CentOS 7/8** (企业环境)
- **openEuler 22.03** (国产化)

### 📧 联系我们

- **GitHub Issues**: [问题反馈](https://github.com/novatra/k8s-auto/issues)
- **Email**: novatra.ai@novatra.cn
- **QQ群**: 1061184149

---

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

---

## 🙏 致谢

感谢以下开源项目和社区：

- [Kubernetes](https://kubernetes.io/) - 容器编排平台
- [Calico](https://www.projectcalico.org/) - 网络和安全解决方案  
- [Flannel](https://github.com/flannel-io/flannel) - 简单的网络覆盖
- [HAProxy](http://www.haproxy.org/) - 负载均衡器
- [Keepalived](https://www.keepalived.org/) - 高可用解决方案

---

## ⭐ Star History

如果这个项目对您有帮助，请给我们一个 ⭐ Star！

[![Star History Chart](https://api.star-history.com/svg?repos=novatra/k8s-auto&type=Date)](https://star-history.com/#novatra/k8s-auto&Date)

---

<div align="center">

**🚀 让Kubernetes部署变得简单 | Made with ❤️ by Novatra工作组**

[⬆️ 回到顶部](#kubernetes-企业级自动化部署脚本)

</div>
