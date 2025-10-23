# Kubernetes One-Click Deployment Script

[中文文档 (Chinese Documentation)](README_CN.md) | [中文许可证 (Chinese License)](LICENSE_CN.md)

---

## Introduction

`k8s.sh` is an automated Kubernetes deployment script developed by the Novatra team, designed to simplify the installation, configuration, and management of Kubernetes clusters. This script supports the latest version of Kubernetes (v1.34.1) and is compatible with multiple Linux distributions and dual architectures (AMD64/ARM64).

## Features

- ✅ **Automated Deployment**: One-click installation and configuration of Kubernetes clusters
- ✅ **Multi-Architecture Support**: Full compatibility with AMD64 and ARM64 architectures
- ✅ **Multi-Distribution Support**: Supports Ubuntu, Debian, CentOS, Rocky, AlmaLinux, Anolis, OpenEuler, Kylin, Deepin, OpenKylin, openSUSE, UOS, and other mainstream distributions
- ✅ **High Availability Deployment**: Supports HA clusters via HAProxy + Keepalived
- ✅ **External ETCD Support**: Configure external ETCD clusters
- ✅ **Network Plugin Integration**: Built-in Calico network plugin installation
- ✅ **Ingress Controller**: Automatic installation of Ingress-Nginx
- ✅ **Monitoring Components**: Supports Metrics Server, Kubernetes Dashboard, Kube-Prometheus, etc.
- ✅ **Image Acceleration**: Uses Novatra image registry by default, with Alibaba Cloud, Tencent Cloud, and Huawei Cloud mirrors as backups

## System Requirements

### Hardware Requirements

- **CPU**: 2 cores or more
- **Memory**: 2GB or more
- **Disk**: 20GB or more available space
- **Architecture**: AMD64 (x86_64) or ARM64 (aarch64)

### Software Requirements

- **Operating System**: Supported Linux distributions (see Features)
- **Kernel Version**:
  - Kubernetes v1.24.x - v1.31.x: Linux Kernel 3.10+
  - Kubernetes v1.32.x+: Linux Kernel 4.19+ (recommended)
- **Network**: Internet access required (for downloading images and packages)
- **Privileges**: Root or sudo privileges required

## Quick Start

### 1. Download the Script

```bash
curl -O https://raw.githubusercontent.com/Novatra-ai/Novatra-Cloud-Native/main/k8s.sh
chmod +x k8s.sh
```

### 2. Standalone Mode Deployment

Suitable for development and testing environments, deploying a single-node Kubernetes cluster:

```bash
./k8s.sh --standalone
```

### 3. Cluster Mode Deployment

#### Master Node Deployment

Execute on the first master node:

```bash
./k8s.sh --cluster
```

After deployment, the script will output the command to join the cluster. Save this command for adding worker nodes.

#### Worker Node Deployment

Execute on worker nodes:

```bash
# Prepare worker node
./k8s.sh --node

# Use the command output from master node to join cluster
kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

## Deployment Modes

### Standalone Mode (--standalone)

Automatically performs the following operations:
- Disables swap partition
- Installs containerd container runtime
- Installs Kubernetes components (kubelet, kubeadm, kubectl)
- Initializes Kubernetes cluster
- Installs Calico network plugin
- Installs Ingress-Nginx controller
- Installs Metrics Server
- Removes master node taints (allows Pod scheduling)
- Configures kubectl command auto-completion

### Cluster Mode (--cluster)

Similar to standalone mode but retains master node taints, suitable for production multi-node clusters.

### Worker Node Mode (--node)

Installs and configures only the necessary components to prepare the node for joining an existing cluster:
- Disables swap partition
- Installs containerd container runtime
- Installs Kubernetes components
- Configures kernel parameters and firewall

## Advanced Configuration

### Using Configuration Files

Create a configuration file `config.sh`:

```bash
# Kubernetes version
kubernetes_version=v1.34.1

# Image registry
kubernetes_images=crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s

# Network configuration
pod_network_cidr=10.244.0.0/16
service_cidr=10.96.0.0/12

# High availability configuration (optional)
control_plane_endpoint=192.168.1.100:6443
```

Deploy using configuration file:

```bash
./k8s.sh --config=config.sh --cluster
```

### High Availability Cluster Deployment

#### Step 1: Prepare VIP Nodes

On load balancer nodes (3 nodes):

```bash
# Node 1 (VIP master)
./k8s.sh \
  --availability-master=k8s-master-1@192.168.1.101:6443 \
  --availability-master=k8s-master-2@192.168.1.102:6443 \
  --availability-master=k8s-master-3@192.168.1.103:6443 \
  --availability-vip=192.168.1.100 \
  --availability-vip-no=1 \
  --availability-vip-install

# Node 2
./k8s.sh \
  --availability-master=k8s-master-1@192.168.1.101:6443 \
  --availability-master=k8s-master-2@192.168.1.102:6443 \
  --availability-master=k8s-master-3@192.168.1.103:6443 \
  --availability-vip=192.168.1.100 \
  --availability-vip-no=2 \
  --availability-vip-install

# Node 3
./k8s.sh \
  --availability-master=k8s-master-1@192.168.1.101:6443 \
  --availability-master=k8s-master-2@192.168.1.102:6443 \
  --availability-master=k8s-master-3@192.168.1.103:6443 \
  --availability-vip=192.168.1.100 \
  --availability-vip-no=3 \
  --availability-vip-install
```

#### Step 2: Initialize First Master Node

```bash
./k8s.sh \
  --control-plane-endpoint=192.168.1.100:6443 \
  --cluster
```

#### Step 3: Join Other Master Nodes

Use the control plane join command output from the first master node.

### External ETCD Cluster

#### Deploy ETCD Cluster

On ETCD nodes (3 nodes):

```bash
# Node 1
./k8s.sh \
  --etcd-binary-install \
  --etcd-ips=192.168.1.201@etcd-1 \
  --etcd-ips=192.168.1.202@etcd-2 \
  --etcd-ips=192.168.1.203@etcd-3

# Nodes 2 and 3
./k8s.sh \
  --etcd-binary-join \
  --etcd-join-ip=192.168.1.201 \
  --etcd-join-port=22 \
  --etcd-ips=192.168.1.201@etcd-1 \
  --etcd-ips=192.168.1.202@etcd-2 \
  --etcd-ips=192.168.1.203@etcd-3
```

#### Initialize Cluster with External ETCD

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

## Common Parameters

### Basic Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--standalone` | Standalone mode deployment | `./k8s.sh --standalone` |
| `--cluster` | Cluster mode deployment | `./k8s.sh --cluster` |
| `--node` | Worker node preparation | `./k8s.sh --node` |
| `--config=<file>` | Use configuration file | `--config=config.sh` |

### Kubernetes Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--kubernetes-version=<version>` | Kubernetes version | v1.34.1 |
| `--kubernetes-images=<registry>` | Image registry (aliyun/Novatra-Container-Registry/kubernetes) | Novatra-Container-Registry |
| `--pod-network-cidr=<CIDR>` | Pod network CIDR | Default Calico config |
| `--service-cidr=<CIDR>` | Service network CIDR | 10.96.0.0/12 |
| `--control-plane-endpoint=<endpoint>` | Control plane endpoint | - |

### Component Installation

| Parameter | Description |
|-----------|-------------|
| `--calico-install` | Install Calico network plugin |
| `--ingress-nginx-install` | Install Ingress-Nginx |
| `--metrics-server-install` | Install Metrics Server |
| `--helm-install` | Install Helm |
| `--helm-install-kubernetes-dashboard` | Install Kubernetes Dashboard |
| `--kube-prometheus-install` | Install Kube-Prometheus |

### System Configuration

| Parameter | Description |
|-----------|-------------|
| `--swap-off` | Disable swap partition |
| `--firewalld-stop` | Stop firewall |
| `--selinux-disabled` | Disable SELinux |

## Image Registry Configuration

The script uses Novatra image registry by default with the following backup sources:

### Kubernetes Images
- **Primary**: `crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s`
- **Backup 1**: `registry.aliyuncs.com/google_containers`
- **Backup 2**: `registry.k8s.io`

### Docker Registry
- **Primary**: Alibaba Cloud Docker CE
- **Backup 1**: Tencent Cloud Docker CE
- **Backup 2**: Docker Official

## Component Versions

- Kubernetes: v1.34.1
- Calico: v3.29.3
- Ingress-Nginx: v1.12.1
- Metrics Server: v0.7.2
- Helm: v3.16.3
- Kubernetes Dashboard: v7.10.4
- Kube-Prometheus: v0.14.0
- ETCD: v3.5.19

## Troubleshooting

### Script Cannot Execute

```bash
# Check line ending format
sed -i 's/\r$//' k8s.sh
```

### Image Pull Failure

```bash
# Use Alibaba Cloud registry
./k8s.sh --standalone --kubernetes-images=aliyun

# Use Novatra Container Registry (default)
./k8s.sh --standalone --kubernetes-images=Novatra-Container-Registry

# Use official Kubernetes registry
./k8s.sh --standalone --kubernetes-images=kubernetes
```

### Check Cluster Status

```bash
# View nodes
kubectl get nodes -o wide

# View Pods
kubectl get pods -A

# View component status
kubectl get cs
```

### Regenerate Cluster Join Command

```bash
kubeadm token create --print-join-command
```

## Supported Distributions

| Distribution | Supported Versions | Package Manager |
|--------------|-------------------|-----------------|
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

## Contact Us

- **GitHub Repository**: https://github.com/Novatra-ai/Novatra-Cloud-Native
- **GitHub Issues**: Issue Feedback
- **Email**: novatra.ai@novatra.cn
- **QQ Group**: 1061184149

## Contributing

Issues and Pull Requests are welcome!

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

Thanks to all developers and community members who contribute to the Kubernetes ecosystem.

---

**Novatra Team** © 2025

