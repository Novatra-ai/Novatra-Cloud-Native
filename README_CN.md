# Kubernetes 一键部署脚本

[English Documentation](README.md) | [English License](LICENSE)

---

## 简介

`k8s.sh` 是由 Novatra 工作团队开发的 Kubernetes 自动化部署脚本，旨在简化 Kubernetes 集群的安装、配置和管理过程。该脚本支持最新版本的 Kubernetes（v1.34.1），并兼容多种 Linux 发行版和双架构（AMD64/ARM64）。

## 功能特点

- ✅ **自动化部署**：一键安装和配置 Kubernetes 集群
- ✅ **多架构支持**：完全兼容 AMD64 和 ARM64 架构
- ✅ **多发行版支持**：支持 Ubuntu、Debian、CentOS、Rocky、AlmaLinux、Anolis、OpenEuler、Kylin、Deepin、OpenKylin、openSUSE、UOS 等主流发行版
- ✅ **高可用部署**：支持通过 HAProxy + Keepalived 实现高可用集群
- ✅ **外部 ETCD 支持**：可配置外部 ETCD 集群
- ✅ **网络插件集成**：内置 Calico 网络插件安装
- ✅ **Ingress 控制器**：自动安装 Ingress-Nginx
- ✅ **监控组件**：支持 Metrics Server、Kubernetes Dashboard、Kube-Prometheus 等
- ✅ **镜像加速**：默认使用 Novatra 镜像仓库，并提供阿里云、腾讯云、华为云等国内镜像源作为备份

## 系统要求

### 硬件要求

- **CPU**：2 核及以上
- **内存**：2GB 及以上
- **磁盘**：20GB 及以上可用空间
- **架构**：AMD64 (x86_64) 或 ARM64 (aarch64)

### 软件要求

- **操作系统**：支持的 Linux 发行版（详见功能特点）
- **内核版本**：
  - Kubernetes v1.24.x - v1.31.x：Linux 内核 3.10+
  - Kubernetes v1.32.x+：Linux 内核 4.19+ （推荐）
- **网络**：能够访问互联网（用于下载镜像和软件包）
- **权限**：需要 root 或 sudo 权限

## 快速开始

### 1. 下载脚本

```bash
curl -O https://raw.githubusercontent.com/Novatra-ai/Novatra-Cloud-Native/main/k8s.sh
chmod +x k8s.sh
```

### 2. 单机模式部署

适用于开发、测试环境，部署一个单节点 Kubernetes 集群：

```bash
./k8s.sh --standalone
```

### 3. 集群模式部署

#### 主节点部署

在第一个主节点上执行：

```bash
./k8s.sh --cluster
```

部署完成后，脚本会输出加入集群的命令，保存此命令用于添加工作节点。

#### 工作节点部署

在工作节点上执行：

```bash
# 准备工作节点
./k8s.sh --node

# 使用主节点输出的命令加入集群
kubeadm join <主节点IP>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

## 部署模式详解

### 单机模式 (--standalone)

自动执行以下操作：
- 关闭 swap 分区
- 安装 containerd 容器运行时
- 安装 Kubernetes 组件（kubelet、kubeadm、kubectl）
- 初始化 Kubernetes 集群
- 安装 Calico 网络插件
- 安装 Ingress-Nginx 控制器
- 安装 Metrics Server
- 去除主节点污点（允许调度 Pod）
- 配置 kubectl 命令自动补全

### 集群模式 (--cluster)

与单机模式类似，但保留主节点污点，适合构建生产环境的多节点集群。

### 工作节点模式 (--node)

仅安装和配置必要的组件，准备节点加入已有集群：
- 关闭 swap 分区
- 安装 containerd 容器运行时
- 安装 Kubernetes 组件
- 配置内核参数和防火墙

## 高级配置

### 使用配置文件

创建配置文件 `config.sh`：

```bash
# Kubernetes 版本
kubernetes_version=v1.34.1

# 镜像仓库
kubernetes_images=crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s

# 网络配置
pod_network_cidr=10.244.0.0/16
service_cidr=10.96.0.0/12

# 高可用配置（可选）
control_plane_endpoint=192.168.1.100:6443
```

使用配置文件部署：

```bash
./k8s.sh --config=config.sh --cluster
```

### 高可用集群部署

#### 第一步：准备 VIP 节点

在负载均衡节点上（3个节点）：

```bash
# 节点 1 (VIP 主节点)
./k8s.sh \
  --availability-master=k8s-master-1@192.168.1.101:6443 \
  --availability-master=k8s-master-2@192.168.1.102:6443 \
  --availability-master=k8s-master-3@192.168.1.103:6443 \
  --availability-vip=192.168.1.100 \
  --availability-vip-no=1 \
  --availability-vip-install

# 节点 2
./k8s.sh \
  --availability-master=k8s-master-1@192.168.1.101:6443 \
  --availability-master=k8s-master-2@192.168.1.102:6443 \
  --availability-master=k8s-master-3@192.168.1.103:6443 \
  --availability-vip=192.168.1.100 \
  --availability-vip-no=2 \
  --availability-vip-install

# 节点 3
./k8s.sh \
  --availability-master=k8s-master-1@192.168.1.101:6443 \
  --availability-master=k8s-master-2@192.168.1.102:6443 \
  --availability-master=k8s-master-3@192.168.1.103:6443 \
  --availability-vip=192.168.1.100 \
  --availability-vip-no=3 \
  --availability-vip-install
```

#### 第二步：初始化第一个主节点

```bash
./k8s.sh \
  --control-plane-endpoint=192.168.1.100:6443 \
  --cluster
```

#### 第三步：加入其他主节点

使用第一个主节点输出的控制平面加入命令。

### 外部 ETCD 集群

#### 部署 ETCD 集群

在 ETCD 节点上（3个节点）：

```bash
# 节点 1
./k8s.sh \
  --etcd-binary-install \
  --etcd-ips=192.168.1.201@etcd-1 \
  --etcd-ips=192.168.1.202@etcd-2 \
  --etcd-ips=192.168.1.203@etcd-3

# 节点 2 和 3
./k8s.sh \
  --etcd-binary-join \
  --etcd-join-ip=192.168.1.201 \
  --etcd-join-port=22 \
  --etcd-ips=192.168.1.201@etcd-1 \
  --etcd-ips=192.168.1.202@etcd-2 \
  --etcd-ips=192.168.1.203@etcd-3
```

#### 使用外部 ETCD 初始化集群

```bash
./k8s.sh \
  --kubernetes-init \
  --etcd-ips=192.168.1.201 \
  --etcd-ips=192.168.1.202 \
  --etcd-ips=192.168.1.203 \
  --etcd-cafile=/etc/etcd/pki/ca.crt \
  --etcd-certfile=/etc/etcd/pki/server.crt \
  --etcd-keyfile=/etc/etcd/pki/server.key
```

## 常用参数说明

### 基础参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--standalone` | 单机模式部署 | `./k8s.sh --standalone` |
| `--cluster` | 集群模式部署 | `./k8s.sh --cluster` |
| `--node` | 工作节点准备 | `./k8s.sh --node` |
| `--config=<文件>` | 使用配置文件 | `--config=config.sh` |

### Kubernetes 配置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--kubernetes-version=<版本>` | Kubernetes 版本 | v1.34.1 |
| `--kubernetes-images=<仓库>` | 镜像仓库 (aliyun/Novatra-Container-Registry/kubernetes) | Novatra-Container-Registry |
| `--pod-network-cidr=<CIDR>` | Pod 网络 CIDR | 默认 Calico 配置 |
| `--service-cidr=<CIDR>` | Service 网络 CIDR | 10.96.0.0/12 |
| `--control-plane-endpoint=<endpoint>` | 控制平面端点 | - |

### 组件安装

| 参数 | 说明 |
|------|------|
| `--calico-install` | 安装 Calico 网络插件 |
| `--ingress-nginx-install` | 安装 Ingress-Nginx |
| `--metrics-server-install` | 安装 Metrics Server |
| `--helm-install` | 安装 Helm |
| `--helm-install-kubernetes-dashboard` | 安装 Kubernetes Dashboard |
| `--kube-prometheus-install` | 安装 Kube-Prometheus |

### 系统配置

| 参数 | 说明 |
|------|------|
| `--swap-off` | 关闭 swap 分区 |
| `--firewalld-stop` | 停止防火墙 |
| `--selinux-disabled` | 禁用 SELinux |

## 镜像仓库配置

脚本默认使用 Novatra 镜像仓库，并提供以下备选源：

### Kubernetes 镜像
- **主仓库**：`crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s`
- **备选1**：`registry.aliyuncs.com/google_containers`
- **备选2**：`registry.k8s.io`

### Docker 仓库
- **主仓库**：阿里云 Docker CE
- **备选1**：腾讯云 Docker CE
- **备选2**：Docker 官方

## 组件版本

- Kubernetes: v1.34.1
- Calico: v3.29.3
- Ingress-Nginx: v1.12.1
- Metrics Server: v0.7.2
- Helm: v3.16.3
- Kubernetes Dashboard: v7.10.4
- Kube-Prometheus: v0.14.0
- ETCD: v3.5.19

## 故障排除

### 脚本无法执行

```bash
# 检查换行符格式
sed -i 's/\r$//' k8s.sh
```

### 镜像拉取失败

```bash
# 使用阿里云镜像仓库
./k8s.sh --standalone --kubernetes-images=aliyun

# 使用 Novatra 容器镜像仓库（默认）
./k8s.sh --standalone --kubernetes-images=Novatra-Container-Registry

# 使用 Kubernetes 官方镜像仓库
./k8s.sh --standalone --kubernetes-images=kubernetes
```

### 查看集群状态

```bash
# 查看节点
kubectl get nodes -o wide

# 查看 Pod
kubectl get pods -A

# 查看组件状态
kubectl get cs
```

### 重新生成加入集群命令

```bash
kubeadm token create --print-join-command
```

## 支持的发行版

| 发行版 | 支持版本 | 包管理器 |
|--------|---------|---------|
| Ubuntu | 18.04, 20.04, 22.04, 24.04 | apt |
| Debian | 10, 11, 12 | apt |
| CentOS | 7, 8, 9 | yum |
| Rocky Linux | 8.10, 9.4, 9.5 | yum |
| AlmaLinux | 8.10, 9.4 | yum |
| Anolis OS | 7.7, 7.9, 8.2, 8.4, 8.6, 8.8, 8.9, 23 | yum |
| OpenEuler | 20.03, 22.03, 24.03 | yum |
| Kylin | v10 | apt |
| Deepin | 20.9, 23 | apt |
| OpenKylin | 1.0, 1.0.1, 1.0.2, 2.0 | apt |
| openSUSE Leap | 15.5, 15.6 | zypper |
| UOS | 20 | yum |

## 联系我们

- **GitHub 仓库**：https://github.com/Novatra-ai/Novatra-Cloud-Native
- **GitHub Issues**：问题反馈
- **Email**：novatra.ai@novatra.cn
- **QQ群**：1061184149

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 许可证

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

## 致谢

感谢所有为 Kubernetes 生态系统做出贡献的开发者和社区成员。

---

**Novatra 工作团队** © 2025

