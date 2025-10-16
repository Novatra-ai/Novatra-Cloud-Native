#!/bin/bash

# ================================================================
# Kubernetes 企业级自动化部署脚本
# ================================================================
# 开发组织：Novatra 工作组
# 版本：v1.0.0
# 支持：单节点、集群、高可用模式部署
# 特性：国内网络优化、企业级安全、生产环境就绪
# 
# 使用前提示：
# 如果脚本不能正常运行，可尝试执行：sed -i 's/\r$//' k8s.sh
#
# 官方文档：
# https://kubernetes.io/zh-cn/releases/
# https://kubernetes.io/zh-cn/docs/
# ================================================================

# 启用调试和错误处理（注释掉 set -e 以避免意外退出）
# set -e  # 暂时禁用自动退出，改用手动错误检查

# 颜色定义
readonly COLOR_BLUE='\033[34m'
readonly COLOR_GREEN='\033[92m'
readonly COLOR_RED='\033[31m'
readonly COLOR_RESET='\033[0m'
readonly COLOR_YELLOW='\033[93m'

# 定义表情
readonly EMOJI_CONGRATS="\U0001F389"
readonly EMOJI_FAILURE="\U0001F61E"

# 官方文档链接
readonly DOCS_README_LINK=https://kubernetes.io/docs/
# 配置文档链接
readonly DOCS_CONFIG_LINK=https://kubernetes.io/docs/setup/

# ================================================================
# 系统检测函数
# ================================================================

_system_detect() {
  # 查看系统类型、版本、内核（添加超时保护）
  echo -e "${COLOR_BLUE}正在检测系统信息...${COLOR_RESET}"
  timeout 10 hostnamectl 2>/dev/null || echo -e "${COLOR_YELLOW}⚠️ hostnamectl 超时，跳过${COLOR_RESET}"

  # 当前系统类型，可能的值:
  # almalinux
  # anolis
  # centos
  # debian
  # Deepin、deepin
  # kylin
  # openEuler
  # openkylin
  # opensuse-leap
  # rocky
  # ubuntu
  # uos
  os_type=$(grep -w "ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
  echo -e "${COLOR_BLUE}系统类型: ${COLOR_GREEN}$os_type${COLOR_RESET}"

  # 当前系统版本，可能的值:
  # AlmaLinux: 8.10、9.4
  # Anolis OS: 7.7、7.9、8.2、8.4、8.6、8.8、8.9、23
  # CentOS: 7、8、9
  # Debian: 10、11、12
  # Deepin、deepin: 20.9、23
  # kylin: v10
  # OpenEuler: 20.03、22.03、24.03
  # OpenKylin: 1.0、1.0.1、1.0.2、2.0
  # openSUSE: 15.5、15.6
  # Rocky: 8.10、9.4、9.5
  # Ubuntu: 18.04、20.04、22.04、24.04
  # UOS: 20
  os_version=$(grep -w "VERSION_ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
  echo -e "${COLOR_BLUE}系统版本: ${COLOR_GREEN}$os_version${COLOR_RESET}"

  kylin_release_id=$(grep -w "KYLIN_RELEASE_ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
  if [[ $kylin_release_id ]]; then
    echo -e "${COLOR_BLUE}银河麒麟代码版本: ${COLOR_GREEN}$kylin_release_id${COLOR_RESET}"
  fi

  # 代码版本
  code_name=$(grep -w "VERSION_CODENAME" /etc/os-release | cut -d'=' -f2 | tr -d '"')
  if [[ $code_name ]]; then
    echo -e "${COLOR_BLUE}代码版本: ${COLOR_GREEN}$code_name${COLOR_RESET}"
  fi

  if [[ $os_type == 'centos' ]]; then
    centos_os_version=$(cat /etc/redhat-release | awk '{print $4}')
    echo -e "${COLOR_BLUE}CentOS 系统具体版本: ${COLOR_GREEN}$centos_os_version${COLOR_RESET}"
  fi

  if [[ -e "/etc/debian_version" ]]; then
    debian_os_version=$(cat /etc/debian_version)
    echo -e "${COLOR_BLUE}Debian 系统具体版本: ${COLOR_GREEN}$debian_os_version${COLOR_RESET}"
  fi

  if [[ $os_type == 'uos' ]]; then
    uos_minor_version=$(grep -w "MinorVersion" /etc/os-version | cut -d'=' -f2 | tr -d '"')
    uos_edition_name=$(grep -w "EditionName" /etc/os-version | cut -d'=' -f2 | tr -d '"' | head -n 1)
    echo -e "${COLOR_BLUE}UOS 系统具体版本: ${COLOR_GREEN}$uos_minor_version$uos_edition_name${COLOR_RESET}"
  fi

  # 输出 CPU 架构
  cpu_arch=$(uname -m)
  if [[ $cpu_arch == 'aarch64' ]]; then
    cpu_platform='arm64'
  elif [[ $cpu_arch == 'x86_64' ]]; then
    cpu_platform='amd64'
  else
    cpu_platform=$cpu_arch
  fi
  echo -e "${COLOR_BLUE}CPU 架构: ${COLOR_GREEN}$cpu_arch ($cpu_platform)${COLOR_RESET}"

  # 内核版本检测和Kubernetes兼容性检查
  kernel_version=$(uname -r)
  kernel_major_version=$(echo "$kernel_version" | cut -d. -f1)
  kernel_minor_version=$(echo "$kernel_version" | cut -d. -f2)
  echo -e "${COLOR_BLUE}系统内核版本: ${COLOR_GREEN}$kernel_version${COLOR_RESET}"

  # Kubernetes 内核要求说明
  # v1.24.x - v1.31.x: 支持所有内核版本（最低 3.10）
  # v1.32.x+: 推荐内核 4.19+
  # v1.34.x+: 推荐内核 5.4+（企业级生产环境）
  if [[ $kernel_major_version -le 4 && $kernel_minor_version -lt 19 ]]; then
    # $(uname -r) < 4.19
    echo -e "${COLOR_BLUE}可以安装 Kubernetes: ${COLOR_GREEN}v1.24.x ${COLOR_RESET}到${COLOR_GREEN} v1.31.x${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}无法安装 Kubernetes v1.32.x +: ${COLOR_GREEN}推荐最低内核为 4.19${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}无法安装 Kubernetes v1.34.x +: ${COLOR_GREEN}推荐最低内核为 5.4 (企业级)${COLOR_RESET}"
  elif [[ $kernel_major_version -eq 4 && $kernel_minor_version -ge 19 ]] || [[ $kernel_major_version -eq 5 && $kernel_minor_version -lt 4 ]]; then
    # 4.19 <= $(uname -r) < 5.4
    echo -e "${COLOR_BLUE}可以安装 Kubernetes: ${COLOR_GREEN}v1.24.x ${COLOR_RESET}到${COLOR_GREEN} v1.33.x${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Kubernetes v1.34.x +: ${COLOR_GREEN}推荐内核 5.4+ 以获得最佳性能${COLOR_RESET}"
  else
    # $(uname -r) >= 5.4
    echo -e "${COLOR_BLUE}可以安装 Kubernetes: ${COLOR_GREEN}v1.24.x ${COLOR_RESET}到${COLOR_GREEN} v1.34.x + (最新)${COLOR_RESET}"
    echo -e "${COLOR_GREEN}✓ 内核版本符合企业级生产环境要求${COLOR_RESET}"
  fi

  # 包管理类型
  package_type=
  case "$os_type" in
  ubuntu | debian | kylin | openkylin | Deepin | deepin)
    package_type=apt
    ;;
  centos | anolis | almalinux | openEuler | rocky | uos)
    package_type=yum
    ;;
  opensuse-leap)
    package_type=zypper
    ;;
  *)
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
    ;;
  esac

  # 设置动态变量
  conntrack_deb="https://mirrors.aliyun.com/debian/pool/main/c/conntrack-tools/conntrack_1.4.6-2_$cpu_platform.deb"
  containerd_io_rpm="https://mirrors.aliyun.com/docker-ce/linux/centos/8/$cpu_arch/stable/Packages/containerd.io-1.6.32-3.1.el8.$cpu_arch.rpm"
  dn_cn=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")
  
  # Docker 仓库类型
  docker_repo_name=$os_type
  case "$os_type" in
  anolis | almalinux | openEuler | rocky | uos)
    docker_repo_name='centos'
    ;;
  kylin | openkylin | Deepin | deepin)
    docker_repo_name='debian'
    ;;
  *) ;;
  esac
}

# 国内Docker镜像代理源列表（按优先级排序）
docker_proxy_mirrors=(
  "docker.chenby.cn"
  "dockerhub.icu"
  "docker.hlyun.org"
  "docker.m.daocloud.io"
  "docker.1panel.live"
  "hub-mirror.c.163.com"
  "mirror.baidubce.com"
)

# 测试Docker镜像代理可用性
_test_docker_proxy() {
  local proxy="$1"
  local test_image="library/hello-world:latest"
  local timeout=10
  
  echo -e "${COLOR_BLUE}测试镜像代理: ${COLOR_GREEN}$proxy${COLOR_RESET}"
  
  # 测试是否能连接到代理
  if timeout $timeout docker pull "$proxy/$test_image" >/dev/null 2>&1; then
    echo -e "${COLOR_GREEN}✅ 代理可用: $proxy${COLOR_RESET}"
    # 清理测试镜像
    docker rmi "$proxy/$test_image" >/dev/null 2>&1 || true
    return 0
  else
    echo -e "${COLOR_YELLOW}⚠️ 代理不可用: $proxy${COLOR_RESET}"
    return 1
  fi
}

# 选择可用的Docker镜像代理
_select_docker_proxy() {
  echo -e "${COLOR_BLUE}🔍 检测可用的国内Docker镜像代理...${COLOR_RESET}"
  
  for proxy in "${docker_proxy_mirrors[@]}"; do
    if _test_docker_proxy "$proxy"; then
      selected_docker_proxy="$proxy"
      echo -e "${COLOR_GREEN}✅ 选择镜像代理: $selected_docker_proxy${COLOR_RESET}"
      return 0
    fi
  done
  
  echo -e "${COLOR_YELLOW}⚠️ 所有国内镜像代理均不可用，将使用官方镜像${COLOR_RESET}"
  selected_docker_proxy=""
  return 1
}

# 根据系统架构配置镜像
_configure_images_by_arch() {
  echo -e "${COLOR_BLUE}🔧 配置Docker镜像源...${COLOR_RESET}"
  
  # 选择可用的Docker代理
  _select_docker_proxy
  
  # 根据架构和代理可用性配置镜像
  if [[ $cpu_platform == 'arm64' ]]; then
    echo -e "${COLOR_BLUE}检测到 ARM64 架构${COLOR_RESET}"
    
    if [[ $selected_docker_proxy ]]; then
      echo -e "${COLOR_GREEN}使用国内镜像代理...${COLOR_RESET}"
      haproxy_image="$selected_docker_proxy/library/haproxy"
      haproxy_version="3.0-alpine"
      keepalived_image="$selected_docker_proxy/osixia/keepalived"
      keepalived_version="2.0.20"
    else
      echo -e "${COLOR_YELLOW}使用官方镜像...${COLOR_RESET}"
      haproxy_image="haproxy"
      haproxy_version="3.0-alpine"
      keepalived_image="osixia/keepalived"
      keepalived_version="2.0.20"
    fi
  else
    echo -e "${COLOR_BLUE}检测到 AMD64 架构${COLOR_RESET}"
    
    if [[ $selected_docker_proxy ]]; then
      echo -e "${COLOR_GREEN}使用国内镜像代理...${COLOR_RESET}"
      haproxy_image="$selected_docker_proxy/library/haproxy"
      haproxy_version="3.0-alpine"
      keepalived_image="$selected_docker_proxy/osixia/keepalived"
      keepalived_version="2.0.20"
    else
      echo -e "${COLOR_YELLOW}使用官方镜像...${COLOR_RESET}"
      haproxy_image="haproxy"
      haproxy_version="3.0-alpine"
      keepalived_image="osixia/keepalived"
      keepalived_version="2.0.20"
    fi
  fi
  
  echo -e "${COLOR_BLUE}HAProxy 镜像: ${COLOR_GREEN}$haproxy_image:$haproxy_version${COLOR_RESET}"
  echo -e "${COLOR_BLUE}Keepalived 镜像: ${COLOR_GREEN}$keepalived_image:$keepalived_version${COLOR_RESET}"
}

# apt 锁超时时间（自动化模式：快速超时）
dpkg_lock_timeout=30

# Kubernetes 版本配置（支持 v1.34.x, v1.33.x, v1.32.x, v1.31.x）
# 参考官方发布页面：https://kubernetes.io/zh-cn/releases/
# 默认使用最新稳定版本 v1.34.1 (发布日期: 2025-09-09)
kubernetes_version=v1.34.1
# Kubernetes 具体版本后缀（apt 包管理器使用）
kubernetes_version_suffix=1.1
# Kubernetes 仓库
kubernetes_mirrors=("https://mirrors.aliyun.com/kubernetes-new/core/stable" "https://mirrors.tuna.tsinghua.edu.cn/kubernetes/core:/stable:" "https://pkgs.k8s.io/core:/stable:")
# Kubernetes 仓库: 默认仓库，取第一个
kubernetes_baseurl=${kubernetes_mirrors[0]}
# ================================================================
# 镜像仓库配置（支持多个国内镜像源，优先使用速度快的源）
# ================================================================

# 通用镜像仓库前缀列表（按推荐优先级排序）
# 1. 阿里云容器镜像服务（稳定性高）
# 2. DaoCloud 镜像站（国内访问快）
# 3. 华为云 SWR
# 4. Docker Hub 镜像代理
# 5. 官方仓库（备用）
common_registry_mirrors=(
  "registry.aliyuncs.com/google_containers"
  "registry.cn-hangzhou.aliyuncs.com/google_containers"
  "docker.m.daocloud.io/google_containers"
  "docker.1panel.live/google_containers"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere"
  "registry.k8s.io"
)

# Kubernetes 镜像仓库
kubernetes_images_mirrors=("${common_registry_mirrors[@]}")
# Kubernetes 镜像仓库: 默认仓库，取第一个
kubernetes_images=${kubernetes_images_mirrors[0]}
# pause 镜像
pause_image=${common_registry_mirrors[0]}/pause
# 自定义 conntrack 安装包，仅在少数系统中使用，如：deepin 23
# conntrack_deb 将在系统检测后动态设置

# Docker 仓库
docker_mirrors=("https://mirrors.aliyun.com/docker-ce/linux" "https://mirrors.cloud.tencent.com/docker-ce/linux" "https://download.docker.com/linux")
# Docker 仓库: 默认仓库，取第一个
docker_baseurl=${docker_mirrors[0]}
# 自定义 container-selinux 安装包，仅在少数系统中使用，如：OpenEuler 20.03
container_selinux_rpm=https://mirrors.aliyun.com/centos-altarch/7.9.2009/extras/i386/Packages/container-selinux-2.107-3.el7.noarch.rpm
# 自定义 containerd.io 安装包，仅在少数系统中使用，如：UOS
# containerd_io_rpm 将在系统检测后动态设置
# Docker 仓库类型将在系统检测后设置

# containerd 根路径
containerd_root=/var/lib/containerd
# containerd 运行状态路径
containerd_state=/run/containerd

availability_haproxy_username="admin"
availability_haproxy_password=admin123456
availability_haproxy_kube_apiserver=9443

haproxy_image=registry.cn-qingdao.aliyuncs.com/3va/haproxy-debian
haproxy_version=3.2-dev12-amd64

keepalived_image=registry.cn-qingdao.aliyuncs.com/3va/keepalived
keepalived_version=2025-05-07-amd64

# Calico 网络插件（使用国内镜像加速）
calico_mirrors=("https://k8s-sh.xuxiaowei.com.cn/mirrors/projectcalico/calico" "https://gitlab.xuxiaowei.com.cn/mirrors/github.com/projectcalico/calico/-/raw" "https://raw.githubusercontent.com/projectcalico/calico/refs/tags")
calico_mirror=${calico_mirrors[0]}
calico_version=v3.29.3

# Calico Node 镜像源（按优先级排序）
calico_node_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/calico-node"
  "registry.aliyuncs.com/google_containers/calico-node"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/calico-node"
  "docker.m.daocloud.io/calico/node"
  "docker.1panel.live/calico/node"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/calico-node"
  "docker.io/calico/node"
  "quay.io/calico/node"
)
calico_node_image=${calico_node_images[0]}

# Calico CNI 镜像源
calico_cni_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/calico-cni"
  "registry.aliyuncs.com/google_containers/calico-cni"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/calico-cni"
  "docker.m.daocloud.io/calico/cni"
  "docker.1panel.live/calico/cni"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/calico-cni"
  "docker.io/calico/cni"
  "quay.io/calico/cni"
)
calico_cni_image=${calico_cni_images[0]}

# Calico Kube-Controllers 镜像源
calico_kube_controllers_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/calico-kube-controllers"
  "registry.aliyuncs.com/google_containers/calico-kube-controllers"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/calico-kube-controllers"
  "docker.m.daocloud.io/calico/kube-controllers"
  "docker.1panel.live/calico-kube-controllers"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/calico-kube-controllers"
  "docker.io/calico/kube-controllers"
  "quay.io/calico-kube-controllers"
)
calico_kube_controllers_image=${calico_kube_controllers_images[0]}

# Flannel 网络插件（使用国内镜像加速）
flannel_mirrors=(
  "https://mirror.ghproxy.com/https://raw.githubusercontent.com/flannel-io/flannel"
  "https://ghproxy.com/https://raw.githubusercontent.com/flannel-io/flannel"
  "https://raw.githubusercontent.com/flannel-io/flannel"
)
flannel_mirror=${flannel_mirrors[0]}
flannel_version=v0.27.4

# Flannel 镜像源（按优先级排序）
flannel_images=(
  "docker.m.daocloud.io/flannel/flannel"
  "docker.1panel.live/flannel/flannel"
  "docker.io/flannel/flannel"
)
flannel_image=${flannel_images[0]}

# Ingress Nginx（使用国内镜像加速）
# 参考官方文档: https://github.com/kubernetes/ingress-nginx
# 最新版本: v1.13.3, 当前使用: v1.12.1 (稳定版)
ingress_nginx_mirrors=(
  "https://k8s-sh.xuxiaowei.com.cn/mirrors/kubernetes/ingress-nginx"
  "https://gitlab.xuxiaowei.com.cn/mirrors/github.com/kubernetes/ingress-nginx/-/raw"
  "https://raw.githubusercontent.com/kubernetes/ingress-nginx/refs/tags"
  "https://mirror.ghproxy.com/https://raw.githubusercontent.com/kubernetes/ingress-nginx"
  "https://ghproxy.com/https://raw.githubusercontent.com/kubernetes/ingress-nginx"
  "https://gitcode.com/gh_mirrors/in/ingress-nginx/raw"
  "https://raw.githubusercontent.com/kubernetes/ingress-nginx"
  "https://raw.staticdn.net/kubernetes/ingress-nginx"
)
ingress_nginx_mirror=${ingress_nginx_mirrors[0]}
ingress_nginx_version=v1.12.1

# Ingress Nginx Controller 镜像源
# 官方镜像: registry.k8s.io/ingress-nginx/controller
ingress_nginx_controller_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/ingress-nginx-controller"
  "registry.cn-hangzhou.aliyuncs.com/google_containers/nginx-ingress-controller"
  "registry.aliyuncs.com/google_containers/nginx-ingress-controller"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/nginx-ingress-controller"
  "docker.m.daocloud.io/k8s/ingress-nginx-controller"
  "docker.1panel.live/k8s/ingress-nginx-controller"
  "lank8s.cn/ingress-nginx/controller"
  "registry.k8s.io/ingress-nginx/controller"
)
ingress_nginx_controller_image=${ingress_nginx_controller_images[0]}

# Ingress Nginx Webhook CertGen 镜像源
# 官方镜像: registry.k8s.io/ingress-nginx/kube-webhook-certgen
ingress_nginx_kube_webhook_certgen_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/ingress-nginx-kube-webhook-certgen"
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-webhook-certgen"
  "registry.aliyuncs.com/google_containers/kube-webhook-certgen"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/kube-webhook-certgen"
  "docker.m.daocloud.io/k8s/kube-webhook-certgen"
  "docker.1panel.live/k8s/kube-webhook-certgen"
  "lank8s.cn/ingress-nginx/kube-webhook-certgen"
  "registry.k8s.io/ingress-nginx/kube-webhook-certgen"
)
ingress_nginx_kube_webhook_certgen_image=${ingress_nginx_kube_webhook_certgen_images[0]}

# Metrics Server（使用国内镜像加速）
metrics_server_version=v0.7.2
metrics_server_mirrors=("https://k8s-sh.xuxiaowei.com.cn/mirrors/kubernetes-sigs/metrics-server" "https://github.com/kubernetes-sigs/metrics-server/releases/download" "https://mirror.ghproxy.com/https://github.com/kubernetes-sigs/metrics-server/releases/download" "https://ghproxy.com/https://github.com/kubernetes-sigs/metrics-server/releases/download")
metrics_server_mirror=${metrics_server_mirrors[0]}

# Metrics Server 镜像源
metrics_server_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/metrics-server"
  "registry.aliyuncs.com/google_containers/metrics-server"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/metrics-server"
  "docker.m.daocloud.io/metrics-server/metrics-server"
  "docker.1panel.live/metrics-server/metrics-server"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/metrics-server"
  "registry.k8s.io/metrics-server/metrics-server"
)
metrics_server_image=${metrics_server_images[0]}

helm_version=v3.16.3
# https://mirrors.huaweicloud.com/helm/v3.16.3/helm-v3.16.3-linux-amd64.tar.gz
# https://mirrors.huaweicloud.com/helm/v3.16.3/helm-v3.16.3-linux-arm64.tar.gz
# https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
# https://get.helm.sh/helm-v3.16.3-linux-arm64.tar.gz
helm_mirrors=("https://mirrors.huaweicloud.com/helm" "https://get.helm.sh")

# Kubernetes Dashboard（使用国内镜像加速）
kubernetes_dashboard_charts=("http://k8s-sh.xuxiaowei.com.cn/charts/kubernetes/dashboard" "https://kubernetes.github.io/dashboard")
kubernetes_dashboard_chart=${kubernetes_dashboard_charts[0]}
kubernetes_dashboard_version=7.10.4

# Dashboard Auth 镜像源
kubernetes_dashboard_auth_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/kubernetesui-dashboard-auth"
  "registry.aliyuncs.com/google_containers/dashboard-auth"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/dashboard-auth"
  "docker.m.daocloud.io/kubernetesui/dashboard-auth"
  "docker.1panel.live/kubernetesui/dashboard-auth"
  "docker.io/kubernetesui/dashboard-auth"
)
kubernetes_dashboard_auth_image=${kubernetes_dashboard_auth_images[0]}

# Dashboard API 镜像源
kubernetes_dashboard_api_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/kubernetesui-dashboard-api"
  "registry.aliyuncs.com/google_containers/dashboard-api"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/dashboard-api"
  "docker.m.daocloud.io/kubernetesui/dashboard-api"
  "docker.1panel.live/kubernetesui/dashboard-api"
  "docker.io/kubernetesui/dashboard-api"
)
kubernetes_dashboard_api_image=${kubernetes_dashboard_api_images[0]}

# Dashboard Web 镜像源
kubernetes_dashboard_web_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/kubernetesui-dashboard-web"
  "registry.aliyuncs.com/google_containers/dashboard-web"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/dashboard-web"
  "docker.m.daocloud.io/kubernetesui/dashboard-web"
  "docker.1panel.live/kubernetesui/dashboard-web"
  "docker.io/kubernetesui/dashboard-web"
)
kubernetes_dashboard_web_image=${kubernetes_dashboard_web_images[0]}

# Dashboard Metrics Scraper 镜像源
kubernetes_dashboard_metrics_scraper_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/kubernetesui-dashboard-metrics-scraper"
  "registry.aliyuncs.com/google_containers/dashboard-metrics-scraper"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/dashboard-metrics-scraper"
  "docker.m.daocloud.io/kubernetesui/dashboard-metrics-scraper"
  "docker.1panel.live/kubernetesui/dashboard-metrics-scraper"
  "docker.io/kubernetesui/dashboard-metrics-scraper"
)
kubernetes_dashboard_metrics_scraper_image=${kubernetes_dashboard_metrics_scraper_images[0]}

# Dashboard Kong 镜像源
kubernetes_dashboard_kong_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/kong"
  "registry.aliyuncs.com/google_containers/kong"
  "docker.m.daocloud.io/library/kong"
  "docker.1panel.live/library/kong"
  "docker.io/library/kong"
)
kubernetes_dashboard_kong_image=${kubernetes_dashboard_kong_images[0]}
kubernetes_dashboard_ingress_enabled=true
kubernetes_dashboard_ingress_host=kubernetes.dashboard.local

# Prometheus 监控栈（使用国内镜像加速）
kube_prometheus_version=v0.14.0
kube_prometheus_mirrors=("https://k8s-sh.xuxiaowei.com.cn/mirrors/prometheus-operator/kube-prometheus" "https://github.com/prometheus-operator/kube-prometheus/archive/refs/tags" "https://ghproxy.com/https://github.com/prometheus-operator/kube-prometheus/archive/refs/tags")
kube_prometheus_mirror=${kube_prometheus_mirrors[0]}

# Grafana 镜像源
grafana_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/grafana"
  "registry.aliyuncs.com/google_containers/grafana"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/grafana"
  "docker.m.daocloud.io/grafana/grafana"
  "docker.1panel.live/grafana/grafana"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/grafana"
  "grafana/grafana"
)
grafana_image=${grafana_images[0]}

# Kube State Metrics 镜像源
kube_state_metrics_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/kube-state-metrics"
  "registry.aliyuncs.com/google_containers/kube-state-metrics"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/kube-state-metrics"
  "docker.m.daocloud.io/kube-state-metrics/kube-state-metrics"
  "docker.1panel.live/kube-state-metrics/kube-state-metrics"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/kube-state-metrics"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics"
)
kube_state_metrics_image=${kube_state_metrics_images[0]}

# Prometheus Adapter 镜像源
prometheus_adapter_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/prometheus-adapter"
  "registry.aliyuncs.com/google_containers/prometheus-adapter"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/prometheus-adapter"
  "docker.m.daocloud.io/prometheus-adapter/prometheus-adapter"
  "docker.1panel.live/prometheus-adapter/prometheus-adapter"
  "swr.cn-north-4.myhuaweicloud.com/ddn-k8s/prometheus-adapter"
  "registry.k8s.io/prometheus-adapter/prometheus-adapter"
)
prometheus_adapter_image=${prometheus_adapter_images[0]}

# ConfigMap Reload 镜像源
jimmidyson_configmap_reload_images=(
  "registry.cn-qingdao.aliyuncs.com/xuxiaoweicomcn/configmap-reload"
  "registry.aliyuncs.com/google_containers/configmap-reload"
  "registry.cn-hangzhou.aliyuncs.com/kubesphere/configmap-reload"
  "docker.m.daocloud.io/jimmidyson/configmap-reload"
  "docker.1panel.live/jimmidyson/configmap-reload"
  "jimmidyson/configmap-reload"
)
jimmidyson_configmap_reload_image=${jimmidyson_configmap_reload_images[0]}
prometheus_k8s_web_9090_node_port=30790
prometheus_k8s_reloader_web_8080_node_port=30780
alertmanager_main_web_9093_node_port=30893
alertmanager_main_reloader_web_8080_node_port=30880
grafana_http_3000_node_port=30900

# openssl 证书配置
dn_c=CN
dn_st=Beijing
dn_l=Beijing
dn_o=Kubernetes
dn_ou=Kubernetes
# dn_cn 将在系统检测后动态设置

etcd_version=v3.5.19
etcd_mirrors=("https://mirrors.huaweicloud.com/etcd" "https://storage.googleapis.com/etcd" "https://github.com/etcd-io/etcd/releases/download")
etcd_mirror=${etcd_mirrors[0]}
etcd_client_port_2379=2379
etcd_peer_port_2380=2380
etcd_join_port=22


# ================================================================
# 镜像源管理和智能选择功能
# ================================================================

# 测试镜像仓库可达性
# 参数: $1 = 镜像仓库地址（如 registry.aliyuncs.com）
_test_registry_connectivity() {
  local registry="$1"
  local timeout=5
  
  # 提取域名
  local domain=$(echo "$registry" | sed 's#https\?://##' | cut -d'/' -f1)
  
  # 测试连接性（快速超时）
  if command -v nc &>/dev/null; then
    # 使用 nc 测试 443 端口
    if timeout 3 nc -z -w 2 "$domain" 443 2>/dev/null; then
      return 0
    fi
  else
    # 使用 curl 测试
    if timeout 3 curl -s --connect-timeout 2 --max-time 2 "https://$domain" >/dev/null 2>&1; then
      return 0
    fi
  fi
  
  return 1
}

# 自动选择最快的镜像源（自动化模式：直接使用第一个可用源）
# 参数: $1 = 镜像名称数组变量名（如 "calico_node_images"）
# 返回: 最快的镜像地址
_select_fastest_image() {
  local -n image_array=$1
  
  # 自动化模式：跳过网络测试，直接使用第一个镜像源
  echo -e "${COLOR_BLUE}🚀 使用默认镜像源: ${image_array[0]%%/*}${COLOR_RESET}"
  echo "${image_array[0]}"
}

# 批量替换 YAML 文件中的镜像地址
# 参数: $1 = YAML 文件路径
#      $2 = 原始镜像模式（正则）
#      $3 = 新镜像地址
_replace_image_in_yaml() {
  local yaml_file="$1"
  local old_pattern="$2"
  local new_image="$3"
  
  if [[ ! -f $yaml_file ]]; then
    echo -e "${COLOR_RED}❌ YAML 文件不存在: $yaml_file${COLOR_RESET}"
    return 1
  fi
  
  # 执行替换
  sed -i "s#$old_pattern#$new_image#g" "$yaml_file"
  
  # 验证替换结果
  if grep -q "$new_image" "$yaml_file"; then
    return 0
  else
    return 1
  fi
}

# 智能替换所有 Calico 镜像
# 参数: $1 = calico.yaml 文件路径
_smart_replace_calico_images() {
  local calico_yaml="$1"
  
  echo -e "${COLOR_BLUE}🔄 智能替换 Calico 镜像地址...${COLOR_RESET}"
  
  # 如果启用了自动选择最优源
  if [[ $auto_select_fastest_mirror == true ]]; then
    echo -e "${COLOR_BLUE}🤖 自动选择最优镜像源模式${COLOR_RESET}"
    
    # 检测最快的 Node 镜像
    echo -e "\n${COLOR_BLUE}检测 Calico Node 镜像源:${COLOR_RESET}"
    calico_node_image=$(_select_fastest_image calico_node_images)
    
    # 检测最快的 CNI 镜像
    echo -e "\n${COLOR_BLUE}检测 Calico CNI 镜像源:${COLOR_RESET}"
    calico_cni_image=$(_select_fastest_image calico_cni_images)
    
    # 检测最快的 Kube-Controllers 镜像源
    echo -e "\n${COLOR_BLUE}检测 Calico Kube-Controllers 镜像源:${COLOR_RESET}"
    calico_kube_controllers_image=$(_select_fastest_image calico_kube_controllers_images)
    
    echo ""
  fi
  
  # 执行镜像替换
  echo -e "${COLOR_BLUE}📝 应用镜像配置...${COLOR_RESET}"
  
  # 替换 calico/node
  sed -i "s#docker\.io/calico/node#${calico_node_image}#g" "$calico_yaml"
  sed -i "s#quay\.io/calico/node#${calico_node_image}#g" "$calico_yaml"
  sed -i "s#calico/node:#${calico_node_image}:#g" "$calico_yaml"
  
  # 替换 calico/cni
  sed -i "s#docker\.io/calico/cni#${calico_cni_image}#g" "$calico_yaml"
  sed -i "s#quay\.io/calico/cni#${calico_cni_image}#g" "$calico_yaml"
  sed -i "s#calico/cni:#${calico_cni_image}:#g" "$calico_yaml"
  
  # 替换 calico/kube-controllers
  sed -i "s#docker\.io/calico/kube-controllers#${calico_kube_controllers_image}#g" "$calico_yaml"
  sed -i "s#quay\.io/calico/kube-controllers#${calico_kube_controllers_image}#g" "$calico_yaml"
  sed -i "s#calico/kube-controllers:#${calico_kube_controllers_image}:#g" "$calico_yaml"
  
  # 兼容老版本的镜像名称
  for old_image in "${calico_node_images[@]:1}"; do
    sed -i "s#$old_image#$calico_node_image#g" "$calico_yaml"
  done
  for old_image in "${calico_cni_images[@]:1}"; do
    sed -i "s#$old_image#$calico_cni_image#g" "$calico_yaml"
  done
  for old_image in "${calico_kube_controllers_images[@]:1}"; do
    sed -i "s#$old_image#$calico_kube_controllers_image#g" "$calico_yaml"
  done
  
  echo -e "${COLOR_GREEN}✅ Calico 镜像替换完成${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   Node: ${COLOR_GREEN}${calico_node_image}${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   CNI: ${COLOR_GREEN}${calico_cni_image}${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   Controllers: ${COLOR_GREEN}${calico_kube_controllers_image}${COLOR_RESET}"
}

# 显示所有可用的镜像源
_list_available_mirrors() {
  echo -e "${COLOR_BLUE}════════════════════════════════════════${COLOR_RESET}"
  echo -e "${COLOR_BLUE}  可用的容器镜像源列表  ${COLOR_RESET}"
  echo -e "${COLOR_BLUE}════════════════════════════════════════${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_GREEN}1. 阿里云容器镜像服务${COLOR_RESET}"
  echo -e "   - registry.aliyuncs.com"
  echo -e "   - registry.cn-hangzhou.aliyuncs.com"
  echo ""
  echo -e "${COLOR_GREEN}2. DaoCloud 镜像站${COLOR_RESET}"
  echo -e "   - docker.m.daocloud.io"
  echo ""
  echo -e "${COLOR_GREEN}3. 1Panel 镜像站${COLOR_RESET}"
  echo -e "   - docker.1panel.live"
  echo ""
  echo -e "${COLOR_GREEN}4. 华为云 SWR${COLOR_RESET}"
  echo -e "   - swr.cn-north-4.myhuaweicloud.com"
  echo ""
  echo -e "${COLOR_GREEN}5. 官方仓库（备用）${COLOR_RESET}"
  echo -e "   - registry.k8s.io"
  echo -e "   - docker.io"
  echo -e "   - quay.io"
  echo ""
  echo -e "${COLOR_BLUE}════════════════════════════════════════${COLOR_RESET}"
}

_k8s_support_kernel() {
  kubernetes_minor_version=$(echo $kubernetes_version | cut -d. -f2)
  
  if [[ $kernel_major_version -le 4 && $kernel_minor_version -lt 19 ]]; then
    # $(uname -r) < 4.19
    if [[ $kubernetes_minor_version -ge 32 ]]; then
      # $kubernetes_version >= v1.32.0
      echo -e "${COLOR_RED}无法安装 Kubernetes $kubernetes_version，停止执行${COLOR_RESET}"
      echo -e "${COLOR_RED}原因：v1.32.x+ 推荐最低内核为 4.19，当前内核为 $kernel_version${COLOR_RESET}"
      echo -e "${COLOR_YELLOW}建议：${COLOR_RESET}"
      echo -e "${COLOR_YELLOW}  1. 升级内核到 4.19+ (推荐)${COLOR_RESET}"
      echo -e "${COLOR_YELLOW}  2. 使用 --kubernetes-version=v1.31.13 指定旧版本${COLOR_RESET}"
      exit 1
    fi
  elif [[ $kernel_major_version -eq 4 && $kernel_minor_version -ge 19 ]] || [[ $kernel_major_version -eq 5 && $kernel_minor_version -lt 4 ]]; then
    # 4.19 <= $(uname -r) < 5.4
    if [[ $kubernetes_minor_version -ge 34 ]]; then
      # $kubernetes_version >= v1.34.0
      echo -e "${COLOR_YELLOW}警告：Kubernetes $kubernetes_version 推荐内核 5.4+，当前内核为 $kernel_version${COLOR_RESET}"
      echo -e "${COLOR_YELLOW}可继续安装，但建议升级内核以获得最佳性能和稳定性${COLOR_RESET}"
      sleep 3
    fi
  fi
}

_docker_repo() {
  if [[ $package_type == 'yum' ]]; then
    docker_gpgcheck=0
    case "$docker_repo_type" in
    "" | aliyun | tencent | docker)
      docker_gpgcheck=1
      ;;
    *) ;;
    esac

    sudo tee /etc/yum.repos.d/docker-ce.repo <<EOF
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=$docker_baseurl/$docker_repo_name/\$releasever/\$basearch/stable
enabled=1
gpgcheck=$docker_gpgcheck
gpgkey=$docker_baseurl/$docker_repo_name/gpg

EOF

    if [[ $os_type == 'anolis' ]]; then
      case "$os_version" in
      '23')
        anolis_docker_version=8
        echo -e "${COLOR_BLUE}$os_type $os_version 使用 $docker_repo_name $anolis_docker_version Docker 安装包${COLOR_RESET}"
        sudo sed -i "s#\$releasever#$anolis_docker_version#" /etc/yum.repos.d/docker-ce.repo
        ;;
      *) ;;
      esac
    fi

    if [[ $os_type == 'openEuler' ]]; then
      case "$os_version" in
      '20.03' | '22.03' | '24.03')
        openEuler_docker_version=8
        echo -e "${COLOR_BLUE}$os_type $os_version 使用 $docker_repo_name $openEuler_docker_version Docker 安装包${COLOR_RESET}"
        sudo sed -i "s#\$releasever#$openEuler_docker_version#" /etc/yum.repos.d/docker-ce.repo
        ;;
      *) ;;
      esac
    fi

    if [[ $os_type == 'uos' ]]; then
      case "$os_version" in
      '20')
        uos_docker_version=8
        echo -e "${COLOR_BLUE}$os_type $os_version 使用 $docker_repo_name $uos_docker_version Docker 安装包${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}$os_type 系统 自定义 Docker 仓库 不支持安装 containerd.io${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}$os_type 系统 官方仓库 containerd 版本过低，不建议使用${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}$os_type 系统 安装 containerd.io 时，使用特定版本：$containerd_io_rpm${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}$os_type 系统 可使用参数 ${COLOR_GREEN}containerd-io-rpm${COLOR_YELLOW} 指定安装 containerd.io 的 URL${COLOR_RESET}"
        sudo sed -i "s#\$releasever#$uos_docker_version#" /etc/yum.repos.d/docker-ce.repo
        ;;
      *) ;;
      esac
    fi

  elif [[ $package_type == 'zypper' ]]; then
    echo 'openSUSE 无需设置 Docker 仓库'

  elif [[ $package_type == 'apt' ]]; then
    sudo mkdir -p /etc/apt/sources.list.d

    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings
    timeout 30 sudo curl -fsSL --connect-timeout 10 --max-time 20 $docker_baseurl/$docker_repo_name/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $docker_baseurl/$docker_repo_name $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    if [[ $os_type == 'openkylin' ]]; then
      case "$code_name" in
      yangtze | nile)
        openkylin_docker_version=bookworm
        echo -e "${COLOR_BLUE}$os_type $os_version $code_name 使用 $docker_repo_name $openkylin_docker_version Docker 安装包${COLOR_RESET}"
        sed -i "s#$code_name#$openkylin_docker_version#" /etc/apt/sources.list.d/docker.list
        ;;
      *) ;;
      esac
    fi

    if [[ $os_type == 'kylin' ]]; then
      case "$os_version" in
      v10)
        kylin_docker_version=bullseye
        echo -e "${COLOR_BLUE}$os_type $os_version $code_name 使用 $docker_repo_name $kylin_docker_version Docker 安装包${COLOR_RESET}"
        sed -i "s#$code_name#$kylin_docker_version#" /etc/apt/sources.list.d/docker.list
        ;;
      *) ;;
      esac
    fi

    if [[ $os_type == 'Deepin' || $os_type == 'deepin' ]]; then
      case "$code_name" in
      apricot)
        deepin_docker_version=bullseye
        echo -e "${COLOR_BLUE}$os_type $code_name $os_version 使用 $docker_repo_name $deepin_docker_version Docker 安装包${COLOR_RESET}"
        sed -i "s#$code_name#$deepin_docker_version#" /etc/apt/sources.list.d/docker.list
        ;;
      beige)
        deepin_docker_version=bookworm
        echo -e "${COLOR_BLUE}$os_type $code_name $os_version 使用 $docker_repo_name $deepin_docker_version Docker 安装包${COLOR_RESET}"
        sed -i "s#$code_name#$deepin_docker_version#" /etc/apt/sources.list.d/docker.list
        ;;
      *) ;;
      esac
    fi

    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}配置 Docker 源${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi
}

_remove_apt_ord_docker() {
  case "$os_type" in
  ubuntu)
    if [[ $os_version == '18.04' ]]; then
      for pkg in docker.io docker-doc docker-compose containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    elif [[ $os_version == '20.04' ]]; then
      for pkg in docker.io docker-doc docker-compose docker-compose-v2 containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    else
      for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    fi
    ;;
  openkylin)
    if [[ $os_version == '1.0' || $os_version == '1.0.1' || $os_version == '1.0.2' ]]; then
      for pkg in docker.io docker-doc docker-compose containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    else
      for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    fi
    ;;
  debian)
    if [[ $os_version == '10' ]]; then
      for pkg in docker.io docker-doc docker-compose containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    elif [[ $os_version == '11' ]]; then
      for pkg in docker.io docker-doc docker-compose containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    else
      for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    fi
    ;;
  Deepin | deepin)
    if [[ $os_version == '20.9' ]]; then
      for pkg in docker.io docker-doc docker-compose containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    else
      for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    fi
    ;;
  kylin)
    if [[ $os_version == 'v10' ]]; then
      for pkg in docker.io docker-doc docker-compose containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    else
      for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout remove -y $pkg; done
    fi
    ;;
  *)
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}卸载旧版 Docker${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
    ;;
  esac
}

_containerd_install() {
  if [[ $os_type == 'uos' ]]; then
    sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    sudo yum -y install $containerd_io_rpm

  elif [[ $package_type == 'yum' ]]; then
    sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

    if [[ $os_type == 'openEuler' && $os_version == '20.03' ]]; then
      echo -e "${COLOR_BLUE}$os_type $os_version 安装 ${COLOR_GREEN}$container_selinux_rpm${COLOR_RESET}"
      sudo yum install -y $container_selinux_rpm
    fi

    sudo yum install -y containerd.io

  elif [[ $package_type == 'zypper' ]]; then
    sudo zypper -n install containerd

  elif [[ $package_type == 'apt' ]]; then
    _remove_apt_ord_docker
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y containerd.io

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}安装 Containerd${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi

  sudo systemctl start containerd
  sudo systemctl status containerd -l --no-pager
  sudo systemctl enable containerd
}

# 容器运行时
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/
_containerd_config() {
  sudo mkdir -p /etc/containerd/certs.d
  containerd_config_backup_path=/etc/containerd/config.toml.$(date +%Y%m%d%H%M%S)
  echo -e "${COLOR_BLUE}containerd 备份历史配置路径: ${COLOR_GREEN}$containerd_config_backup_path${COLOR_RESET}"
  sudo cp /etc/containerd/config.toml $containerd_config_backup_path || true
  sudo containerd config default | sudo tee /etc/containerd/config.toml

  echo -e "${COLOR_BLUE}containerd 根路径: ${COLOR_GREEN}$containerd_root${COLOR_RESET}"
  sed -i "s#^root = \".*\"#root = \"$containerd_root\"#" /etc/containerd/config.toml
  echo -e "${COLOR_BLUE}containerd 运行状态路径: ${COLOR_GREEN}$containerd_state${COLOR_RESET}"
  sed -i "s#^state = \".*\"#state = \"$containerd_state\"#" /etc/containerd/config.toml

  # 兼容 OpenKylin 2.0，防止在 /etc/containerd/config.toml 生成无关配置
  if [[ $os_type == 'openkylin' && $os_version == '2.0' ]]; then
    echo -e "${COLOR_BLUE}$os_type $os_version 注释 /etc/containerd/config.toml 无用配置${COLOR_RESET}"
    sudo sed -i 's/^User/#&/' /etc/containerd/config.toml
  fi

  echo -e "${COLOR_BLUE}containerd 配置中，registry.k8s.io/pause 使用: ${COLOR_GREEN}$pause_image ${COLOR_BLUE}镜像${COLOR_RESET}"
  sudo sed -i "s#registry.k8s.io/pause#$pause_image#g" /etc/containerd/config.toml

  echo -e "${COLOR_BLUE}containerd 配置中，SystemdCgroup 设置为: ${COLOR_GREEN}true ${COLOR_RESET}"
  sudo sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" /etc/containerd/config.toml

  echo -e "${COLOR_BLUE}containerd 配置中，certs 文件夹设置为: ${COLOR_GREEN}/etc/containerd/certs.d${COLOR_RESET}"
  sudo sed -i "s#config_path = \"\"#config_path = \"/etc/containerd/certs.d\"#" /etc/containerd/config.toml

  sudo systemctl restart containerd
  sudo systemctl status containerd -l --no-pager
  sudo systemctl enable containerd
}

_docker_install() {
  if [[ $package_type == 'yum' ]]; then
    sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

    if [[ $os_type == 'openEuler' && $os_version == '20.03' ]]; then
      echo -e "${COLOR_BLUE}$os_type $os_version 安装 ${COLOR_GREEN}$container_selinux_rpm${COLOR_RESET}"
      sudo yum install -y $container_selinux_rpm
    fi

    if [[ $os_type == 'uos' ]]; then
      sudo yum -y install $containerd_io_rpm
      sudo yum install -y docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin
    else
      sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

  elif [[ $package_type == 'zypper' ]]; then
    sudo zypper -n install docker

  elif [[ $package_type == 'apt' ]]; then
    _remove_apt_ord_docker
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}安装 Docker${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi

  sudo systemctl restart docker.socket
  sudo systemctl restart docker.service
  sudo systemctl status docker.socket -l --no-pager
  sudo systemctl status docker.service -l --no-pager
  sudo systemctl enable docker.socket
  sudo systemctl enable docker.service
  sudo docker info
  sudo docker ps
  sudo docker images
}

_socat() {
  if [[ $package_type == 'yum' ]]; then
    sudo yum -y install socat

  elif [[ $package_type == 'zypper' ]]; then
    sudo zypper -n install socat

  elif [[ $package_type == 'apt' ]]; then
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y socat

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}安装 socat${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi
}

_iproute() {
  if [[ $package_type == 'yum' ]]; then
    if [[ $os_type == 'anolis' ]]; then
      case "$os_version" in
      '7.7' | '7.9')
        sudo yum -y install iproute
        ;;
      *)
        sudo yum -y install iproute-tc
        ;;
      esac
    elif [[ $os_type == 'centos' ]]; then
      case "$centos_os_version" in
      '7.9.2009')
        sudo yum -y install iproute
        ;;
      *)
        sudo yum -y install iproute-tc
        ;;
      esac
    else
      sudo yum -y install iproute-tc
    fi

  elif [[ $package_type == 'zypper' ]]; then
    sudo zypper -n install iproute2

  elif [[ $package_type == 'apt' ]]; then
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y iproute2

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}安装 iproute-tc、iproute2${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi
}

_kubernetes_repo() {
  _k8s_support_kernel

  # Kubernetes 仓库版本号，包含: 主版本号、次版本号
  kubernetes_repo_version=$(echo $kubernetes_version | cut -d. -f1-2)

  if [[ $package_type == 'yum' ]]; then
    kubernetes_gpgcheck=0
    case "$kubernetes_repo_type" in
    "" | aliyun | tsinghua | kubernetes)
      echo -e "${COLOR_BLUE}开启了 gpg 检查${COLOR_RESET}"
      kubernetes_gpgcheck=1
      ;;
    *)
      echo -e "${COLOR_BLUE}未开启 gpg 检查${COLOR_RESET}"
      ;;
    esac

    sudo tee /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=$kubernetes_baseurl/$kubernetes_repo_version/rpm/
enabled=1
gpgcheck=$kubernetes_gpgcheck
gpgkey=$kubernetes_baseurl/$kubernetes_repo_version/rpm/repodata/repomd.xml.key

EOF

  elif [[ $package_type == 'zypper' ]]; then
    sudo tee /etc/zypp/repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=$kubernetes_baseurl/$kubernetes_repo_version/rpm/
enabled=1
gpgcheck=0
gpgkey=$kubernetes_baseurl/$kubernetes_repo_version/rpm/repodata/repomd.xml.key

EOF

  elif [[ $package_type == 'apt' ]]; then
    sudo mkdir -p /etc/apt/sources.list.d

    case "$kubernetes_repo_type" in
    "" | aliyun | tsinghua | kubernetes)
      sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
      sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y ca-certificates curl

      sudo install -m 0755 -d /etc/apt/keyrings
      timeout 30 sudo curl -fsSL --connect-timeout 10 --max-time 20 $kubernetes_baseurl/$kubernetes_repo_version/deb/Release.key -o /etc/apt/keyrings/kubernetes.asc
      sudo chmod a+r /etc/apt/keyrings/kubernetes.asc

      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/kubernetes.asc] $kubernetes_baseurl/$kubernetes_repo_version/deb/ /" |
        sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
      ;;
    *)
      echo \
        "deb [arch=$(dpkg --print-architecture) trusted=yes] $kubernetes_baseurl/$kubernetes_repo_version/deb/ /" |
        sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
      ;;
    esac

    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}配置 Kubernetes 源${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi
}

_swap_off() {
  free -h
  sudo swapoff -a
  free -h
  cat /etc/fstab
  sudo sed -i 's/.*swap.*/#&/' /etc/fstab
  cat /etc/fstab
}

_curl() {
  if [[ $package_type == 'yum' ]]; then
    sudo yum -y install curl

  elif [[ $package_type == 'zypper' ]]; then
    sudo zypper -n install curl

  elif [[ $package_type == 'apt' ]]; then
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y curl

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}安装 curl${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi
}

_ca_certificates() {
  if [[ $package_type == 'yum' ]]; then
    sudo yum -y install ca-certificates

  elif [[ $package_type == 'zypper' ]]; then
    sudo zypper -n install ca-certificates

  elif [[ $package_type == 'apt' ]]; then
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y ca-certificates

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}安装 ca-certificates${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi
}

_kubernetes_install() {
  _k8s_support_kernel

  version=${kubernetes_version:1}

  if [[ $package_type == 'yum' ]]; then
    sudo yum install -y kubelet-"$version" kubeadm-"$version" kubectl-"$version"

  elif [[ $package_type == 'zypper' ]]; then
    sudo zypper -n install kubelet-"$version" kubeadm-"$version" kubectl-"$version"

  elif [[ $package_type == 'apt' ]]; then
    if [[ $os_type == 'deepin' && $code_name == 'beige' ]]; then
      conntrack_name=$(basename "$conntrack_deb")
      timeout 60 curl -L --connect-timeout 10 --max-time 30 -o "$conntrack_name" "$conntrack_deb"
      dpkg -i "$conntrack_name"
    fi

    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y kubelet="$version"-$kubernetes_version_suffix kubeadm="$version"-$kubernetes_version_suffix kubectl="$version"-$kubernetes_version_suffix

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}安装 Kubernetes${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi
}

_kubernetes_images_pull() {
  kubeadm config images list --image-repository="$kubernetes_images" --kubernetes-version="$kubernetes_version"
  kubeadm config images pull --image-repository="$kubernetes_images" --kubernetes-version="$kubernetes_version"
}

# 启用 IPv4 数据包转发
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/
_enable_ipv4_packet_forwarding() {
  # Kubernetes 版本号，包含: 主版本号、次版本号
  kubernetes_version_tmp=$(echo $kubernetes_version | cut -d. -f1-2)

  ipv4_ip_forward=$(grep -w "net.ipv4.ip_forward" /etc/sysctl.conf | cut -d'=' -f2 | tr -d ' ')
  if [[ $ipv4_ip_forward == '0' ]]; then
    echo -e "${COLOR_YELLOW}/etc/sysctl.conf 文件中关闭了 net.ipv4.ip_forward，将注释此配置${COLOR_RESET}"
    # 如果 IPv4 数据包转发 已关闭: 注释已存在的配置，防止冲突
    sudo sed -i 's|net.ipv4.ip_forward|#net.ipv4.ip_forward|g' /etc/sysctl.conf
  fi

  ipv4_ip_forward=$(grep -w "net.ipv4.ip_forward" /etc/sysctl.d/99-sysctl.conf | cut -d'=' -f2 | tr -d ' ')
  if [[ $ipv4_ip_forward == '0' ]]; then
    echo -e "${COLOR_YELLOW}/etc/sysctl.d/99-sysctl.conf 文件中关闭了 net.ipv4.ip_forward，将注释此配置${COLOR_RESET}"
    # 如果 IPv4 数据包转发 已关闭: 注释已存在的配置，防止冲突
    sudo sed -i 's|net.ipv4.ip_forward|#net.ipv4.ip_forward|g' /etc/sysctl.d/99-sysctl.conf
  fi

  case "$kubernetes_version_tmp" in
  "v1.24" | "v1.25" | "v1.26" | "v1.27" | "v1.28" | "v1.29")
    # https://kubernetes.io/docs/setup/production-environment/container-runtimes/
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    # 设置所需的 sysctl 参数，参数在重新启动后保持不变
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    # 应用 sysctl 参数而不重新启动
    sudo sysctl --system
    lsmod | grep br_netfilter
    lsmod | grep overlay
    ;;
  *)
    # https://kubernetes.io/docs/setup/production-environment/container-runtimes/
    # 设置所需的 sysctl 参数，参数在重新启动后保持不变
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

    # 应用 sysctl 参数而不重新启动
    sudo sysctl --system
    ;;
  esac
}

_kubernetes_config() {
  _enable_ipv4_packet_forwarding
  _socat
  _iproute
  systemctl enable kubelet.service
}

_kubernetes_init_congrats() {
  echo
  echo
  echo
  echo -e "${COLOR_BLUE}${EMOJI_CONGRATS}${EMOJI_CONGRATS}${EMOJI_CONGRATS}${COLOR_RESET}"
  echo -e "${COLOR_BLUE}Kubernetes 已完成安装${COLOR_RESET}"
  echo
  echo -e "${COLOR_BLUE}请选择下列方式之一，重载环境变量后，即可直接控制 Kubernetes${COLOR_RESET}"
  echo
  echo -e "${COLOR_BLUE}1. 执行命令刷新环境变量:${COLOR_RESET}"
  echo -e "\t${COLOR_GREEN}source /etc/profile${COLOR_RESET}"
  echo -e "\t${COLOR_GREEN}source /etc/bash_completion.d/kubectl${COLOR_RESET}"
  echo
  echo -e "${COLOR_BLUE}2. 重新连接 SSH${COLOR_RESET}"
  echo
  echo
  echo
}

_k8s_init_pre_config_etcd() {
  etcd_external_num=0
  if [[ $etcd_ips ]]; then
    etcd_external_num=$(($etcd_external_num + 1))
  fi

  if [[ $etcd_cafile ]]; then
    etcd_external_num=$(($etcd_external_num + 1))
  fi

  if [[ $etcd_certfile ]]; then
    etcd_external_num=$(($etcd_external_num + 1))
  fi

  if [[ $etcd_keyfile ]]; then
    etcd_external_num=$(($etcd_external_num + 1))
  fi

  if [[ $etcd_external_num -gt 0 && $etcd_external_num -lt 4 ]]; then
    echo -e "${COLOR_RED}kubernetes 初始化 使用外部 ETCD 时，etcd 参数不完整${COLOR_RESET}"
    echo -e "${COLOR_RED}kubernetes 使用外部 ETCD 完整参数至少包含：${COLOR_GREEN}etcd-ips${COLOR_RESET}、${COLOR_GREEN}etcd-cafile${COLOR_RESET}、${COLOR_GREEN}etcd-certfile${COLOR_RESET}、${COLOR_GREEN}etcd-keyfile${COLOR_RESET}"
    echo -e "${COLOR_RED}kubernetes 不使用外部 ETCD 时，请不要包含下列参数：${COLOR_GREEN}etcd-ips${COLOR_RESET}、${COLOR_GREEN}etcd-cafile${COLOR_RESET}、${COLOR_GREEN}etcd-certfile${COLOR_RESET}、${COLOR_GREEN}etcd-keyfile${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看配置: ${COLOR_GREEN}${DOCS_CONFIG_LINK}${COLOR_RESET}"
    exit 1
  elif [ $etcd_external_num == 4 ]; then
    echo "etcd:" >>kubeadm-config.yaml
    echo "  external:" >>kubeadm-config.yaml
    echo "    caFile: $etcd_cafile" >>kubeadm-config.yaml
    echo "    certFile: $etcd_certfile" >>kubeadm-config.yaml
    echo "    keyFile: $etcd_keyfile" >>kubeadm-config.yaml
    echo "    endpoints:" >>kubeadm-config.yaml
    for etcd_ip in "${etcd_ips[@]}"; do
      echo "     - https://$etcd_ip:$etcd_client_port_2379" >>kubeadm-config.yaml
    done
  fi
}

_kubernetes_init() {
  if [[ $kubernetes_init_node_name ]]; then
    kubernetes_init_node_name="--node-name=$kubernetes_init_node_name"
  fi

  if [[ $control_plane_endpoint ]]; then
    control_plane_endpoint="controlPlaneEndpoint: $control_plane_endpoint"
  fi

  if [[ $service_cidr ]]; then
    service_cidr="serviceSubnet: $service_cidr"
  fi

  if [[ $pod_network_cidr ]]; then
    pod_network_cidr="podSubnet: $pod_network_cidr"
  fi

  kubeadm_apiVersion=$(kubeadm config print init-defaults | head -n 1)

  caCertificateValidityPeriod=''
  certificateValidityPeriod=''
  kubernetes_minor_version=$(echo $kubernetes_version | cut -d. -f2)
  if [[ $kubernetes_minor_version -ge 31 ]]; then
    # 证书有效期：100年（此配置仅支持 kubernetes v1.31.0+）
    caCertificateValidityPeriod='caCertificateValidityPeriod: 876000h0m0s'
    # 证书有效期：100年（此配置仅支持 kubernetes v1.31.0+）
    certificateValidityPeriod='certificateValidityPeriod: 876000h0m0s'
  fi

  cat <<EOF | sudo tee kubeadm-config.yaml
$kubeadm_apiVersion
kind: ClusterConfiguration
kubernetesVersion: $kubernetes_version
$control_plane_endpoint
$caCertificateValidityPeriod
$certificateValidityPeriod
imageRepository: $kubernetes_images
networking:
  dnsDomain: cluster.local
  $service_cidr
  $pod_network_cidr

EOF

  _k8s_init_pre_config_etcd

  kubeadm init $kubernetes_init_node_name --config=kubeadm-config.yaml

  KUBECONFIG=$(grep -w "KUBECONFIG" /etc/profile | cut -d'=' -f2)
  if [[ $KUBECONFIG != '/etc/kubernetes/admin.conf' ]]; then
    sudo sed -i 's/.*KUBECONFIG.*/#&/' /etc/profile
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >>/etc/profile
  fi

  # 此处兼容 AnolisOS 23.1，防止退出
  source /etc/profile || true

  echo -e "${COLOR_BLUE}查看集群配置: ${COLOR_GREEN}kubectl -n kube-system get cm kubeadm-config -o yaml${COLOR_RESET}"
  kubectl -n kube-system get cm kubeadm-config -o yaml

  echo -e "${COLOR_BLUE}查看证书有效期: ${COLOR_GREEN}kubeadm certs check-expiration${COLOR_RESET}"
  kubeadm certs check-expiration

  echo -e "${COLOR_BLUE}查看集群节点信息: ${COLOR_GREEN}kubectl get node -o wide${COLOR_RESET}"
  kubectl get node -o wide

  echo -e "${COLOR_BLUE}查看集群 Service: ${COLOR_GREEN}kubectl get svc -A -o wide${COLOR_RESET}"
  kubectl get svc -A -o wide

  echo -e "${COLOR_BLUE}查看集群 Pod: ${COLOR_GREEN}kubectl get pod -A -o wide${COLOR_RESET}"
  kubectl get pod -A -o wide

  if [[ $standalone == true ]]; then
    # 单机模式，在下方 $standalone == true 时执行 _kubernetes_init_congrats
    echo
  elif [[ $cluster == true ]]; then
    # 集群模式，在下方 $cluster == true 时执行 _kubernetes_init_congrats
    echo
  elif [[ $node == true ]]; then
    # 工作节点准备，不执行 _kubernetes_init_congrats
    echo
  else
    _kubernetes_init_congrats
  fi
}

_kubernetes_taint() {
  kubectl get nodes -o wide
  kubectl get pod -A -o wide
  kubectl get node -o yaml | grep taint -A 10
  kubernetes_version_tmp=$(echo $kubernetes_version | cut -d. -f1-2)
  if [[ $kubernetes_version_tmp == 'v1.24' ]]; then
    kubectl taint nodes --all node-role.kubernetes.io/master- || true
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
  else
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
  fi
  kubectl get node -o yaml | grep taint -A 10 | true
  kubectl get nodes -o wide
  kubectl get pod -A -o wide
}

_print_join_command() {
  kubeadm token create --print-join-command
}

_bash_completion() {
  if [[ $package_type == 'yum' ]]; then
    sudo yum -y install bash-completion
    # 此处兼容 AnolisOS 23.1，防止退出
    source /etc/profile || true
  elif [[ $package_type == 'zypper' ]]; then
    sudo zypper -n install bash-completion
    # 此处兼容 openSUSE Leap 15.6，防止退出
    source /etc/profile || true
  elif [[ $package_type == 'apt' ]]; then
    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y bash-completion
    # 此处兼容 Debian 11.7.0，防止退出
    source /etc/profile || true
  fi
}

# kubectl 的可选配置和插件
# 启用 shell 自动补全功能
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#optional-kubectl-configurations
_enable_shell_autocompletion() {
  _bash_completion

  if [[ $package_type == 'yum' || $package_type == 'zypper' || $package_type == 'apt' ]]; then
    sudo mkdir -p /etc/bash_completion.d
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl >/dev/null
    sudo chmod a+r /etc/bash_completion.d/kubectl
    source /etc/bash_completion.d/kubectl

  else
    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}启用 shell 自动补全功能${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_README_LINK${COLOR_RESET}"
    exit 1
  fi
}

_interface_name() {
  if ! [[ $interface_name ]]; then
    interface_name=$(ip route get 223.5.5.5 | grep -oP '(?<=dev\s)\w+' | head -n 1)
    if [[ "$interface_name" ]]; then
      echo -e "${COLOR_BLUE}上网网卡是 ${COLOR_RESET}${COLOR_GREEN}${interface_name}${COLOR_RESET}"
    else
      echo -e "${COLOR_RED}未找到上网网卡，停止安装${COLOR_RESET}"
      echo -e "${COLOR_RED}请阅读文档，查看网卡配置 interface-name: ${COLOR_GREEN}${DOCS_CONFIG_LINK}#interface-name${COLOR_RESET}"
      exit 1
    fi
  fi
}

_generate_calico_config() {
  echo -e "${COLOR_BLUE}🔧 生成 Calico 本地配置文件...${COLOR_RESET}"
  
  cat > calico.yaml << 'EOF'
# Calico v3.29.3 Configuration with China Mirror
apiVersion: v1
kind: ConfigMap
metadata:
  name: calico-config
  namespace: kube-system
data:
  typha_service_name: "none"
  calico_backend: "bird"
  veth_mtu: "0"
  cni_network_config: |-
    {
      "name": "k8s-pod-network",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "calico",
          "log_level": "info",
          "datastore_type": "kubernetes",
          "nodename": "__KUBERNETES_NODE_NAME__",
          "mtu": __CNI_MTU__,
          "ipam": {
              "type": "calico-ipam"
          },
          "policy": {
              "type": "k8s"
          },
          "kubernetes": {
              "kubeconfig": "__KUBECONFIG_FILEPATH__"
          }
        },
        {
          "type": "portmap",
          "snat": true,
          "capabilities": {"portMappings": true}
        },
        {
          "type": "bandwidth",
          "capabilities": {"bandwidth": true}
        }
      ]
    }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: calico-node
  namespace: kube-system
  labels:
    k8s-app: calico-node
spec:
  selector:
    matchLabels:
      k8s-app: calico-node
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        k8s-app: calico-node
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      hostNetwork: true
      tolerations:
        - effect: NoSchedule
          operator: Exists
        - key: CriticalAddonsOnly
          operator: Exists
        - effect: NoExecute
          operator: Exists
      serviceAccountName: calico-node
      terminationGracePeriodSeconds: 0
      priorityClassName: system-node-critical
      initContainers:
        - name: upgrade-ipam
          image: calico/cni:v3.29.3
          command: ["/opt/cni/bin/calico-ipam", "-upgrade"]
          env:
            - name: KUBERNETES_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: CALICO_NETWORKING_BACKEND
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: calico_backend
          volumeMounts:
            - mountPath: /var/lib/cni/networks
              name: host-local-net-dir
            - mountPath: /host/opt/cni/bin
              name: cni-bin-dir
          securityContext:
            privileged: true
        - name: install-cni
          image: calico/cni:v3.29.3
          command: ["/opt/cni/bin/install"]
          env:
            - name: CNI_CONF_NAME
              value: "10-calico.conflist"
            - name: CNI_NETWORK_CONFIG
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: cni_network_config
            - name: KUBERNETES_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: CNI_MTU
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: veth_mtu
            - name: SLEEP
              value: "false"
          volumeMounts:
            - mountPath: /host/opt/cni/bin
              name: cni-bin-dir
            - mountPath: /host/etc/cni/net.d
              name: cni-net-dir
          securityContext:
            privileged: true
      containers:
        - name: calico-node
          image: calico/node:v3.29.3
          env:
            - name: DATASTORE_TYPE
              value: "kubernetes"
            - name: WAIT_FOR_DATASTORE
              value: "true"
            - name: NODENAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: CALICO_NETWORKING_BACKEND
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: calico_backend
            - name: CLUSTER_TYPE
              value: "k8s,bgp"
            - name: IP
              value: "autodetect"
            - name: CALICO_IPV4POOL_IPIP
              value: "Always"
            - name: CALICO_IPV4POOL_VXLAN
              value: "Never"
            - name: CALICO_IPV4POOL_CIDR
              value: "10.244.0.0/16"
            - name: CALICO_DISABLE_FILE_LOGGING
              value: "true"
            - name: FELIX_DEFAULTENDPOINTTOHOSTACTION
              value: "ACCEPT"
            - name: FELIX_IPV6SUPPORT
              value: "false"
            - name: FELIX_LOGSEVERITYSCREEN
              value: "info"
            - name: FELIX_HEALTHENABLED
              value: "true"
          securityContext:
            privileged: true
          resources:
            requests:
              cpu: 250m
          livenessProbe:
            exec:
              command:
              - /bin/calico-node
              - -felix-live
              - -bird-live
            periodSeconds: 10
            initialDelaySeconds: 10
            failureThreshold: 6
            timeoutSeconds: 10
          readinessProbe:
            exec:
              command:
              - /bin/calico-node
              - -felix-ready
              - -bird-ready
            periodSeconds: 10
            timeoutSeconds: 10
          volumeMounts:
            - mountPath: /host/etc/cni/net.d
              name: cni-net-dir
              readOnly: false
            - mountPath: /lib/modules
              name: lib-modules
              readOnly: true
            - mountPath: /run/xtables.lock
              name: xtables-lock
              readOnly: false
            - mountPath: /var/run/calico
              name: var-run-calico
              readOnly: false
            - mountPath: /var/lib/calico
              name: var-lib-calico
              readOnly: false
      volumes:
        - name: lib-modules
          hostPath:
            path: /lib/modules
        - name: var-run-calico
          hostPath:
            path: /var/run/calico
        - name: var-lib-calico
          hostPath:
            path: /var/lib/calico
        - name: xtables-lock
          hostPath:
            path: /run/xtables.lock
            type: FileOrCreate
        - name: cni-bin-dir
          hostPath:
            path: /opt/cni/bin
        - name: cni-net-dir
          hostPath:
            path: /etc/cni/net.d
        - name: host-local-net-dir
          hostPath:
            path: /var/lib/cni/networks
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: calico-kube-controllers
  namespace: kube-system
  labels:
    k8s-app: calico-kube-controllers
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: calico-kube-controllers
  template:
    metadata:
      labels:
        k8s-app: calico-kube-controllers
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule
      serviceAccountName: calico-kube-controllers
      priorityClassName: system-cluster-critical
      containers:
        - name: calico-kube-controllers
          image: calico/kube-controllers:v3.29.3
          env:
            - name: ENABLED_CONTROLLERS
              value: node
            - name: DATASTORE_TYPE
              value: kubernetes
          livenessProbe:
            exec:
              command:
              - /usr/bin/check-status
              - -l
            periodSeconds: 10
            initialDelaySeconds: 10
            failureThreshold: 6
            timeoutSeconds: 10
          readinessProbe:
            exec:
              command:
              - /usr/bin/check-status
              - -r
            periodSeconds: 10
            timeoutSeconds: 10
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: calico-node
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: calico-kube-controllers
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: calico-node
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes", "namespaces"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["endpoints", "services"]
    verbs: ["watch", "list", "get"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["nodes/status"]
    verbs: ["patch", "update"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["watch", "list"]
  - apiGroups: [""]
    resources: ["pods", "namespaces", "serviceaccounts"]
    verbs: ["list", "watch"]
  - apiGroups: [""]
    resources: ["pods/status"]
    verbs: ["patch"]
  - apiGroups: ["crd.projectcalico.org"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: calico-kube-controllers
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["watch", "list", "get"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["crd.projectcalico.org"]
    resources: ["ippools"]
    verbs: ["list"]
  - apiGroups: ["crd.projectcalico.org"]
    resources: ["blockaffinities", "ipamblocks", "ipamhandles"]
    verbs: ["get", "list", "create", "update", "delete"]
  - apiGroups: ["crd.projectcalico.org"]
    resources: ["hostendpoints"]
    verbs: ["get", "list", "create", "update", "delete"]
  - apiGroups: ["crd.projectcalico.org"]
    resources: ["clusterinformations"]
    verbs: ["get", "create", "update"]
  - apiGroups: ["crd.projectcalico.org"]
    resources: ["kubecontrollersconfigurations"]
    verbs: ["get", "update", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: calico-node
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: calico-node
subjects:
- kind: ServiceAccount
  name: calico-node
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: calico-kube-controllers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: calico-kube-controllers
subjects:
- kind: ServiceAccount
  name: calico-kube-controllers
  namespace: kube-system
EOF
  
  echo -e "${COLOR_GREEN}✅ 本地 Calico 配置文件生成完成${COLOR_RESET}"
}

# 生成本地 Metrics Server 配置文件
# 参考: https://blog.csdn.net/zfw_666666/article/details/127007626
_generate_metrics_server_config() {
  echo -e "${COLOR_BLUE}🔧 生成 Metrics Server 本地配置文件...${COLOR_RESET}"
  
  cat > metrics_server.yaml << 'EOF'
# Metrics Server v0.7.2 本地配置
# 适配国内网络环境，使用国内镜像源
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-view: "true"
  name: system:aggregated-metrics-reader
rules:
- apiGroups:
  - metrics.k8s.io
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:metrics-server
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  ports:
  - name: https
    port: 443
    protocol: TCP
    targetPort: https
  selector:
    k8s-app: metrics-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls
        image: registry.aliyuncs.com/google_containers/metrics-server:v0.7.2
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /livez
            port: https
            scheme: HTTPS
          periodSeconds: 10
        name: metrics-server
        ports:
        - containerPort: 4443
          name: https
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /readyz
            port: https
            scheme: HTTPS
          initialDelaySeconds: 20
          periodSeconds: 10
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /tmp
          name: tmp-dir
      nodeSelector:
        kubernetes.io/os: linux
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      volumes:
      - emptyDir: {}
        name: tmp-dir
---
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  labels:
    k8s-app: metrics-server
  name: v1beta1.metrics.k8s.io
spec:
  group: metrics.k8s.io
  groupPriorityMinimum: 100
  insecureSkipTLSVerify: true
  service:
    name: metrics-server
    namespace: kube-system
  version: v1beta1
  versionPriority: 100
EOF
  
  echo -e "${COLOR_GREEN}✅ 本地 Metrics Server 配置文件生成完成${COLOR_RESET}"
}

_calico_install() {
  if ! [[ $calico_url ]]; then
    calico_url=$calico_mirror/$calico_version/manifests/calico.yaml
  fi
  
  calico_local_path=calico.yaml
  download_success=false
  
  # 尝试多个镜像源下载Calico配置
  if [[ $calico_url =~ ^https?:// ]]; then
    echo -e "${COLOR_BLUE}尝试从网络下载 Calico 配置文件${COLOR_RESET}"
    
    for mirror in "${calico_mirrors[@]}"; do
      url="$mirror/$calico_version/manifests/calico.yaml"
      echo -e "${COLOR_BLUE}尝试下载: ${COLOR_GREEN}$url${COLOR_RESET}"
      
      if timeout 60 curl -k --connect-timeout 10 --max-time 30 -o $calico_local_path "$url" 2>/dev/null; then
        if [[ -f $calico_local_path ]] && [[ -s $calico_local_path ]]; then
          # 验证下载的文件是否为有效的YAML
          echo -e "${COLOR_BLUE}验证 YAML 文件格式...${COLOR_RESET}"
          
          # 检查文件头部是否包含有效的Kubernetes资源定义
          if head -n 50 $calico_local_path | grep -qi "apiVersion" && \
             head -n 50 $calico_local_path | grep -qi "kind:" && \
             ! head -n 20 $calico_local_path | grep -qi "<html\|<!DOCTYPE\|<body"; then
            # 使用kubectl验证YAML格式（dry-run模式）
            if kubectl apply --dry-run=client -f $calico_local_path >/dev/null 2>&1; then
              echo -e "${COLOR_GREEN}✅ 下载成功，YAML 格式验证通过${COLOR_RESET}"
              download_success=true
              break
            else
              echo -e "${COLOR_YELLOW}⚠️ YAML 格式验证失败，文件可能损坏${COLOR_RESET}"
              echo -e "${COLOR_YELLOW}文件前10行内容：${COLOR_RESET}"
              head -n 10 $calico_local_path
              rm -f $calico_local_path
            fi
          else
            echo -e "${COLOR_YELLOW}⚠️ 下载的文件不是有效的 Kubernetes YAML 配置${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}文件前10行内容：${COLOR_RESET}"
            head -n 10 $calico_local_path
            rm -f $calico_local_path
          fi
        fi
      fi
      echo -e "${COLOR_YELLOW}⚠️ 下载失败，尝试下一个源...${COLOR_RESET}"
    done
  else
    calico_local_path=$calico_url
    if [[ -f $calico_local_path ]]; then
      download_success=true
    else
      echo -e "${COLOR_RED}❌ 指定的本地文件不存在: $calico_local_path${COLOR_RESET}"
      download_success=false
    fi
  fi
  
  # 如果网络下载失败，生成本地配置文件
  if [[ $download_success == false ]]; then
    echo -e "${COLOR_YELLOW}⚠️ 网络下载失败，生成本地 Calico 配置文件...${COLOR_RESET}"
    _generate_calico_config
  fi

  # 配置网卡信息
  if grep -q "interface=" "$calico_local_path"; then
    echo -e "${COLOR_BLUE}已配置 calico 使用的网卡，脚本跳过网卡配置${COLOR_RESET}"
  else
    _interface_name
    echo "上网网卡是 $interface_name"
    # 使用多行 sed 命令正确插入网卡配置
    sed -i '/k8s,bgp/a\            - name: IP_AUTODETECTION_METHOD' $calico_local_path
    sed -i '/IP_AUTODETECTION_METHOD/a\              value: "interface=INTERFACE_NAME"' $calico_local_path
    sed -i "s#INTERFACE_NAME#$interface_name#g" $calico_local_path
  fi

  # 使用智能镜像替换功能
  _smart_replace_calico_images "$calico_local_path"
  
  # 最终验证配置文件
  echo -e "${COLOR_BLUE}🔍 最终验证配置文件...${COLOR_RESET}"
  if ! kubectl apply --dry-run=client -f $calico_local_path >/dev/null 2>&1; then
    echo -e "${COLOR_RED}❌ Calico 配置文件验证失败${COLOR_RESET}"
    echo -e "${COLOR_RED}请检查配置文件：$calico_local_path${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}错误详情：${COLOR_RESET}"
    kubectl apply --dry-run=client -f $calico_local_path 2>&1 | head -n 20
    exit 1
  fi

  echo -e "${COLOR_BLUE}🚀 应用 Calico 配置...${COLOR_RESET}"
  if kubectl apply -f $calico_local_path; then
    echo -e "${COLOR_GREEN}✅ Calico 配置应用成功${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}❌ Calico 配置应用失败${COLOR_RESET}"
    echo -e "${COLOR_RED}请检查 kubectl 日志和集群状态${COLOR_RESET}"
    exit 1
  fi
  
  echo -e "${COLOR_BLUE}📋 查看所有 Pod 状态...${COLOR_RESET}"
  kubectl get pod -A -o wide
  
  if [[ $cluster != true ]]; then
    echo -e "${COLOR_BLUE}⏳ 等待所有 Pod 就绪（最多5分钟）...${COLOR_RESET}"
    kubectl wait --for=condition=Ready --all pods -A --timeout=300s || true
  fi
  
  echo -e "${COLOR_GREEN}✅ Calico 网络插件安装完成${COLOR_RESET}"
}

_flannel_install() {
  if ! [[ $flannel_url ]]; then
    flannel_url=$flannel_mirror/v${flannel_version#v}/Documentation/kube-flannel.yml
  fi

  flannel_local_path=flannel.yaml
  download_success=false

  # 尝试多个镜像源下载 Flannel 配置
  if [[ $flannel_url =~ ^https?:// ]]; then
    echo -e "${COLOR_BLUE}尝试从网络下载 Flannel 配置文件${COLOR_RESET}"
    for mirror in "${flannel_mirrors[@]}"; do
      url="$mirror/v${flannel_version#v}/Documentation/kube-flannel.yml"
      echo -e "${COLOR_BLUE}尝试下载: ${COLOR_GREEN}$url${COLOR_RESET}"
      if timeout 60 curl -k --connect-timeout 10 --max-time 30 -o $flannel_local_path "$url" 2>/dev/null; then
        if [[ -f $flannel_local_path ]] && [[ -s $flannel_local_path ]]; then
          # 验证下载的文件是否为有效的YAML
          echo -e "${COLOR_BLUE}验证 YAML 文件格式...${COLOR_RESET}"
          if head -n 50 $flannel_local_path | grep -qi "apiVersion" && \
             head -n 50 $flannel_local_path | grep -qi "kind:" && \
             ! head -n 20 $flannel_local_path | grep -qi "<html\\|<!DOCTYPE\\|<body"; then
            # 使用 kubectl 验证 YAML 格式（dry-run 模式）
            if kubectl apply --dry-run=client -f $flannel_local_path >/dev/null 2>&1; then
              echo -e "${COLOR_GREEN}✅ 下载成功，YAML 格式验证通过${COLOR_RESET}"
              download_success=true
              break
            else
              echo -e "${COLOR_YELLOW}⚠️ YAML 格式验证失败，文件可能损坏${COLOR_RESET}"
              echo -e "${COLOR_YELLOW}文件前10行内容：${COLOR_RESET}"
              head -n 10 $flannel_local_path
              rm -f $flannel_local_path
            fi
          else
            echo -e "${COLOR_YELLOW}⚠️ 下载的文件不是有效的 Kubernetes YAML 配置${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}文件前10行内容：${COLOR_RESET}"
            head -n 10 $flannel_local_path
            rm -f $flannel_local_path
          fi
        fi
      fi
      echo -e "${COLOR_YELLOW}⚠️ 下载失败，尝试下一个源...${COLOR_RESET}"
    done
  else
    flannel_local_path=$flannel_url
    if [[ -f $flannel_local_path ]]; then
      download_success=true
    else
      echo -e "${COLOR_RED}❌ 指定的本地文件不存在: $flannel_local_path${COLOR_RESET}"
      download_success=false
    fi
  fi

  # 如果所有下载都失败，退出
  if [[ $download_success == false ]]; then
    echo -e "${COLOR_RED}❌ 所有镜像源下载 Flannel 配置均失败${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}建议：${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}  1. 检查网络连接${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}  2. 使用本地配置文件：--flannel-url=/path/to/kube-flannel.yml${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}  3. 手动下载并指定：${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}     curl -o flannel.yaml https://raw.githubusercontent.com/flannel-io/flannel/${flannel_version#v}/Documentation/kube-flannel.yml${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}     ./k8s.sh --flannel-url=./flannel.yaml --flannel-install${COLOR_RESET}"
    exit 1
  fi

  echo -e "${COLOR_BLUE}🔄 替换镜像地址为国内源...${COLOR_RESET}"
  sudo sed -i 's/@sha256:[a-f0-9]\{64\}//g' $flannel_local_path
  sudo sed -i "s#docker\.io/flannel/flannel#${flannel_image}#g" $flannel_local_path
  sudo sed -i "s#quay\.io/coreos/flannel#${flannel_image}#g" $flannel_local_path
  sudo sed -i "s#flannel/flannel:#${flannel_image}:#g" $flannel_local_path

  if [[ $auto_select_fastest_mirror == true ]]; then
    echo -e "${COLOR_BLUE}🤖 自动选择最优镜像源模式${COLOR_RESET}"
    echo -e "\n${COLOR_BLUE}检测 Flannel 镜像源:${COLOR_RESET}"
    flannel_image=$(_select_fastest_image flannel_images)
    sudo sed -i "s#docker\.m\.daocloud\.io/flannel/flannel#${flannel_image}#g" $flannel_local_path
    sudo sed -i "s#docker\.1panel\.live/flannel/flannel#${flannel_image}#g" $flannel_local_path
    sudo sed -i "s#docker\.io/flannel/flannel#${flannel_image}#g" $flannel_local_path
  fi

  echo -e "${COLOR_BLUE}🚀 应用 Flannel 配置...${COLOR_RESET}"
  if kubectl apply -f $flannel_local_path; then
    echo -e "${COLOR_GREEN}✅ Flannel 配置应用成功${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}❌ Flannel 配置应用失败${COLOR_RESET}"
    echo -e "${COLOR_RED}请检查 kubectl 日志和集群状态${COLOR_RESET}"
    exit 1
  fi

  echo -e "${COLOR_BLUE}📋 查看所有 Pod 状态...${COLOR_RESET}"
  kubectl get pod -A -o wide

  if [[ $cluster != true ]]; then
    echo -e "${COLOR_BLUE}⏳ 等待所有 Pod 就绪（最多5分钟）...${COLOR_RESET}"
    kubectl wait --for=condition=Ready --all pods -A --timeout=300s || true
  fi

  echo -e "${COLOR_GREEN}✅ Flannel 网络插件安装完成${COLOR_RESET}"
}

_ingress_nginx_install() {
  if ! [[ $ingress_nginx_url ]]; then
    ingress_nginx_url=$ingress_nginx_mirror/controller-$ingress_nginx_version/deploy/static/provider/cloud/deploy.yaml
  fi

  ingress_nginx_local_path=ingress_nginx.yaml
  download_success=false
  
  # 尝试多个镜像源下载 Ingress Nginx 配置
  if [[ $ingress_nginx_url =~ ^https?:// ]]; then
    echo -e "${COLOR_BLUE}尝试从网络下载 Ingress Nginx 配置文件${COLOR_RESET}"
    
    for mirror in "${ingress_nginx_mirrors[@]}"; do
      url="$mirror/controller-$ingress_nginx_version/deploy/static/provider/cloud/deploy.yaml"
      echo -e "${COLOR_BLUE}尝试下载: ${COLOR_GREEN}$url${COLOR_RESET}"
      
      if timeout 60 curl -k --connect-timeout 10 --max-time 30 -o $ingress_nginx_local_path "$url" 2>/dev/null; then
        if [[ -f $ingress_nginx_local_path ]] && [[ -s $ingress_nginx_local_path ]]; then
          # 验证下载的文件是否为有效的YAML
          echo -e "${COLOR_BLUE}验证 YAML 文件格式...${COLOR_RESET}"
          
          # 检查文件头部是否包含有效的Kubernetes资源定义
          if head -n 50 $ingress_nginx_local_path | grep -qi "apiVersion" && \
             head -n 50 $ingress_nginx_local_path | grep -qi "kind:" && \
             ! head -n 20 $ingress_nginx_local_path | grep -qi "<html\|<!DOCTYPE\|<body"; then
            # 使用kubectl验证YAML格式（dry-run模式）
            if kubectl apply --dry-run=client -f $ingress_nginx_local_path >/dev/null 2>&1; then
              echo -e "${COLOR_GREEN}✅ 下载成功，YAML 格式验证通过${COLOR_RESET}"
              download_success=true
              break
            else
              echo -e "${COLOR_YELLOW}⚠️ YAML 格式验证失败，文件可能损坏${COLOR_RESET}"
              echo -e "${COLOR_YELLOW}文件前10行内容：${COLOR_RESET}"
              head -n 10 $ingress_nginx_local_path
              rm -f $ingress_nginx_local_path
            fi
          else
            echo -e "${COLOR_YELLOW}⚠️ 下载的文件不是有效的 Kubernetes YAML 配置${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}文件前10行内容：${COLOR_RESET}"
            head -n 10 $ingress_nginx_local_path
            rm -f $ingress_nginx_local_path
          fi
        fi
      fi
      echo -e "${COLOR_YELLOW}⚠️ 下载失败，尝试下一个源...${COLOR_RESET}"
    done
  else
    ingress_nginx_local_path=$ingress_nginx_url
    if [[ -f $ingress_nginx_local_path ]]; then
      download_success=true
    else
      echo -e "${COLOR_RED}❌ 指定的本地文件不存在: $ingress_nginx_local_path${COLOR_RESET}"
      download_success=false
    fi
  fi
  
  # 如果所有下载都失败，退出
  if [[ $download_success == false ]]; then
    echo -e "${COLOR_RED}❌ 所有镜像源下载 Ingress Nginx 配置均失败${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}建议：${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}  1. 检查网络连接${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}  2. 使用本地配置文件：--ingress-nginx-url=/path/to/deploy.yaml${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}  3. 手动下载并指定：${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}     curl -o ingress_nginx.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-$ingress_nginx_version/deploy/static/provider/cloud/deploy.yaml${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}     ./k8s.sh --ingress-nginx-url=./ingress_nginx.yaml --ingress-nginx-install${COLOR_RESET}"
    exit 1
  fi

  echo -e "${COLOR_BLUE}🔄 替换镜像地址为国内源...${COLOR_RESET}"
  
  # 删除镜像的 digest 引用（@sha256:...）
  sudo sed -i 's/@sha256:[a-f0-9]\{64\}//g' $ingress_nginx_local_path
  
  # 替换 Ingress Nginx Controller 镜像
  # 官方格式: registry.k8s.io/ingress-nginx/controller:vX.X.X
  sudo sed -i "s#registry\.k8s\.io/ingress-nginx/controller#${ingress_nginx_controller_image}#g" $ingress_nginx_local_path
  sudo sed -i "s#k8s\.gcr\.io/ingress-nginx/controller#${ingress_nginx_controller_image}#g" $ingress_nginx_local_path
  
  # 替换 Webhook CertGen 镜像
  # 官方格式: registry.k8s.io/ingress-nginx/kube-webhook-certgen:vX.X.X
  sudo sed -i "s#registry\.k8s\.io/ingress-nginx/kube-webhook-certgen#${ingress_nginx_kube_webhook_certgen_image}#g" $ingress_nginx_local_path
  sudo sed -i "s#k8s\.gcr\.io/ingress-nginx/kube-webhook-certgen#${ingress_nginx_kube_webhook_certgen_image}#g" $ingress_nginx_local_path
  
  # 兼容老版本的镜像名称
  for old_image in "${ingress_nginx_controller_images[@]:1}"; do
    sudo sed -i "s#$old_image#$ingress_nginx_controller_image#g" $ingress_nginx_local_path
  done
  for old_image in "${ingress_nginx_kube_webhook_certgen_images[@]:1}"; do
    sudo sed -i "s#$old_image#$ingress_nginx_kube_webhook_certgen_image#g" $ingress_nginx_local_path
  done
  
  echo -e "${COLOR_GREEN}✅ 镜像地址替换完成${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   Controller: ${COLOR_GREEN}${ingress_nginx_controller_image}${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   Webhook: ${COLOR_GREEN}${ingress_nginx_kube_webhook_certgen_image}${COLOR_RESET}"

  echo -e "${COLOR_BLUE}🚀 应用 Ingress Nginx 配置...${COLOR_RESET}"
  if kubectl apply -f $ingress_nginx_local_path; then
    echo -e "${COLOR_GREEN}✅ Ingress Nginx 配置应用成功${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}❌ Ingress Nginx 配置应用失败${COLOR_RESET}"
    exit 1
  fi
  
  kubectl get pod -A -o wide
}

_ingress_nginx_host_network() {
  kubectl -n ingress-nginx patch deployment ingress-nginx-controller --patch '{"spec": {"template": {"spec": {"hostNetwork": true}}}}'
}

# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#allow-snippet-annotations
# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#stream-snippet
# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#configuration-snippet
# CVE-2021-25742：https://github.com/kubernetes/kubernetes/issues/126811
_ingress_nginx_allow_snippet_annotations() {
  kubectl -n ingress-nginx patch configmap ingress-nginx-controller --type merge -p '{"data":{"allow-snippet-annotations":"true"}}'
}

_metrics_server_install() {
  if ! [[ $metrics_server_url ]]; then
    metrics_server_url=$metrics_server_mirror/$metrics_server_version/components.yaml
  fi

  metrics_server_local_path=metrics_server.yaml
  download_success=false
  
  # 尝试多个镜像源下载 Metrics Server 配置
  if [[ $metrics_server_url =~ ^https?:// ]]; then
    echo -e "${COLOR_BLUE}尝试从网络下载 Metrics Server 配置文件${COLOR_RESET}"
    
    for mirror in "${metrics_server_mirrors[@]}"; do
      url="$mirror/$metrics_server_version/components.yaml"
      echo -e "${COLOR_BLUE}尝试下载: ${COLOR_GREEN}$url${COLOR_RESET}"
      
      if timeout 60 curl -k --connect-timeout 10 --max-time 30 -o $metrics_server_local_path "$url" 2>/dev/null; then
        if [[ -f $metrics_server_local_path ]] && [[ -s $metrics_server_local_path ]]; then
          # 验证下载的文件是否为有效的YAML
          echo -e "${COLOR_BLUE}验证 YAML 文件格式...${COLOR_RESET}"
          
          # 检查文件头部是否包含有效的Kubernetes资源定义
          if head -n 50 $metrics_server_local_path | grep -qi "apiVersion" && \
             head -n 50 $metrics_server_local_path | grep -qi "kind:" && \
             ! head -n 20 $metrics_server_local_path | grep -qi "<html\\|<!DOCTYPE\\|<body"; then
            # 使用kubectl验证YAML格式（dry-run模式）
            if kubectl apply --dry-run=client -f $metrics_server_local_path >/dev/null 2>&1; then
              echo -e "${COLOR_GREEN}✅ 下载成功，YAML 格式验证通过${COLOR_RESET}"
              download_success=true
              break
            else
              echo -e "${COLOR_YELLOW}⚠️ YAML 格式验证失败，文件可能损坏${COLOR_RESET}"
              echo -e "${COLOR_YELLOW}文件前10行内容：${COLOR_RESET}"
              head -n 10 $metrics_server_local_path
              rm -f $metrics_server_local_path
            fi
          else
            echo -e "${COLOR_YELLOW}⚠️ 下载的文件不是有效的 Kubernetes YAML 配置${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}文件前10行内容：${COLOR_RESET}"
            head -n 10 $metrics_server_local_path
            rm -f $metrics_server_local_path
          fi
        fi
      fi
      echo -e "${COLOR_YELLOW}⚠️ 下载失败，尝试下一个源...${COLOR_RESET}"
    done
  else
    metrics_server_local_path=$metrics_server_url
    if [[ -f $metrics_server_local_path ]]; then
      download_success=true
    else
      echo -e "${COLOR_RED}❌ 指定的本地文件不存在: $metrics_server_local_path${COLOR_RESET}"
      download_success=false
    fi
  fi
  
  # 如果所有下载都失败，生成本地配置文件
  if [[ $download_success == false ]]; then
    echo -e "${COLOR_YELLOW}⚠️ 网络下载失败，生成本地 Metrics Server 配置文件...${COLOR_RESET}"
    _generate_metrics_server_config
  fi

  # 检查是否已经配置了 kubelet-insecure-tls（本地生成的配置已包含）
  if grep -q "kubelet-insecure-tls" "$metrics_server_local_path"; then
    echo -e "${COLOR_BLUE}✓ 已配置 kubelet-insecure-tls 参数${COLOR_RESET}"
  else
    # 如果是从网络下载的配置，需要手动添加参数
    echo -e "${COLOR_BLUE}🔄 替换镜像地址为国内源...${COLOR_RESET}"
    sudo sed -i "s#${metrics_server_images[-1]}#$metrics_server_image#g" $metrics_server_local_path
    
    if [[ $metrics_server_secure_tls != true ]]; then
      echo -e "${COLOR_BLUE}配置 kubelet-insecure-tls...${COLOR_RESET}"
      sed -i '/- args:/a \        - --kubelet-insecure-tls' $metrics_server_local_path
    fi
  fi
  
  # 确保镜像地址是国内源
  if ! grep -q "$metrics_server_image" "$metrics_server_local_path"; then
    echo -e "${COLOR_BLUE}🔄 替换镜像地址为国内源...${COLOR_RESET}"
    sudo sed -i "s#${metrics_server_images[-1]}#$metrics_server_image#g" $metrics_server_local_path
    # 兼容其他镜像源格式
    for old_image in "${metrics_server_images[@]:1}"; do
      sudo sed -i "s#$old_image#$metrics_server_image#g" $metrics_server_local_path
    done
  else
    echo -e "${COLOR_BLUE}✓ 已使用国内镜像源: ${COLOR_GREEN}${metrics_server_image}${COLOR_RESET}"
  fi

  echo -e "${COLOR_BLUE}🚀 应用 Metrics Server 配置...${COLOR_RESET}"
  if kubectl apply -f $metrics_server_local_path; then
    echo -e "${COLOR_GREEN}✅ Metrics Server 配置应用成功${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}❌ Metrics Server 配置应用失败${COLOR_RESET}"
    exit 1
  fi
  
  kubectl get pod -A -o wide
}

_tar_install() {
  if ! command -v 'tar' &>/dev/null; then
    if [[ $package_type == 'yum' ]]; then
      echo -e "${COLOR_BLUE}tar 未安装，正在安装...${COLOR_RESET}"
      sudo yum install -y tar
      echo -e "${COLOR_BLUE}tar 安装完成${COLOR_RESET}"
    elif [[ $package_type == 'apt' ]]; then
      echo -e "${COLOR_BLUE}tar 未安装，正在安装...${COLOR_RESET}"
      apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
      apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y tar
      echo -e "${COLOR_BLUE}tar 安装完成${COLOR_RESET}"
    fi
  fi
}

_helm_install() {
  if ! [[ $helm_url ]]; then
    case "$helm_repo_type" in
    "" | huawei)
      helm_url=${helm_mirrors[0]}/$helm_version/helm-$helm_version-linux-$cpu_platform.tar.gz
      ;;
    helm)
      helm_url=${helm_mirrors[-1]}/helm-$helm_version-linux-$cpu_platform.tar.gz
      ;;
    *) ;;
    esac
  fi
  echo -e "${COLOR_BLUE}Helm URL: ${COLOR_GREEN}$helm_url${COLOR_RESET}"

  helm_local_path=helm-$helm_version-linux-$cpu_platform.tar.gz
  helm_local_folder=helm-$helm_version-linux-$cpu_platform
  if [[ $helm_url =~ ^https?:// ]]; then
    echo -e "${COLOR_BLUE}下载 Helm...${COLOR_RESET}"
    if timeout 120 curl -k --connect-timeout 10 --max-time 60 -o $helm_local_path $helm_url 2>/dev/null; then
      if [[ -f $helm_local_path ]] && [[ -s $helm_local_path ]]; then
        # 验证是否为有效的 tar.gz 文件
        if file $helm_local_path | grep -qi "gzip compressed data"; then
          echo -e "${COLOR_GREEN}✅ Helm 下载成功${COLOR_RESET}"
        else
          echo -e "${COLOR_RED}❌ 下载的文件不是有效的 tar.gz 格式${COLOR_RESET}"
          file $helm_local_path
          exit 1
        fi
      else
        echo -e "${COLOR_RED}❌ 下载失败或文件为空${COLOR_RESET}"
        exit 1
      fi
    else
      echo -e "${COLOR_RED}❌ 下载 Helm 失败${COLOR_RESET}"
      exit 1
    fi
  else
    helm_local_path=$helm_url
    if [[ ! -f $helm_local_path ]]; then
      echo -e "${COLOR_RED}❌ 指定的本地文件不存在: $helm_local_path${COLOR_RESET}"
      exit 1
    fi
  fi

  _tar_install

  echo -e "${COLOR_BLUE}📦 解压 Helm...${COLOR_RESET}"
  mkdir -p $helm_local_folder
  if tar -zxvf $helm_local_path --strip-components=1 -C $helm_local_folder; then
    echo -e "${COLOR_GREEN}✅ Helm 解压成功${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}❌ Helm 解压失败${COLOR_RESET}"
    exit 1
  fi

  echo -e "${COLOR_BLUE}🔍 验证 Helm 版本...${COLOR_RESET}"
  $helm_local_folder/helm version
  
  echo -e "${COLOR_BLUE}📥 安装 Helm 到系统路径...${COLOR_RESET}"
  cp $helm_local_folder/helm /usr/local/bin/helm
  
  echo -e "${COLOR_GREEN}✅ Helm 安装完成${COLOR_RESET}"
  /usr/local/bin/helm version
  /usr/local/bin/helm ls -A
}

# https://github.com/kubernetes/dashboard?tab=readme-ov-file#installation
# https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard/values.yaml
# https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md
_helm_install_kubernetes_dashboard() {
  echo -e "${COLOR_BLUE}准备清理已存在的 kubernetes-dashboard charts 仓库 ...${COLOR_RESET}"
  helm repo remove kubernetes-dashboard || echo -e "${COLOR_BLUE}本地未安装 kubernetes-dashboard 仓库${COLOR_RESET}"
  echo -e "${COLOR_BLUE}准备安装 kubernetes-dashboard charts 仓库: ${COLOR_GREEN}$kubernetes_dashboard_chart${COLOR_RESET}"
  helm repo add kubernetes-dashboard $kubernetes_dashboard_chart

  echo -e "${COLOR_BLUE}准备生成 kubernetes-dashboard charts 仓库安装配置 ...${COLOR_RESET}"
  cat <<EOF | sudo tee kubernetes_dashboard.yml
app:
  ingress:
    enabled: $kubernetes_dashboard_ingress_enabled
    hosts:
      - localhost
      - $kubernetes_dashboard_ingress_host
    # Default: internal-nginx
    ingressClassName: nginx
auth:
  image:
    repository: $kubernetes_dashboard_auth_image
api:
  image:
    repository: $kubernetes_dashboard_api_image
web:
  image:
    repository: $kubernetes_dashboard_web_image
metricsScraper:
  image:
    repository: $kubernetes_dashboard_metrics_scraper_image
kong:
  image:
    repository: $kubernetes_dashboard_kong_image

EOF

  echo -e "${COLOR_BLUE}准备使用自定义配置安装 kubernetes-dashboard charts ...${COLOR_RESET}"
  helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard --version $kubernetes_dashboard_version -f kubernetes_dashboard.yml

  echo -e "${COLOR_BLUE}准备生成 kubernetes-dashboard service account yml ...${COLOR_RESET}"
  cat <<EOF | sudo tee kubernetes_dashboard_service_account.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard

EOF

  echo -e "${COLOR_BLUE}准备生成 kubernetes-dashboard cluster role binding yml ...${COLOR_RESET}"
  cat <<EOF | sudo tee kubernetes_dashboard_cluster_role_binding.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard

EOF

  echo -e "${COLOR_BLUE}准备生成 kubernetes-dashboard secret yml ...${COLOR_RESET}"
  cat <<EOF | sudo tee kubernetes_dashboard_secret.yml
apiVersion: v1
kind: Secret
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "admin-user"
type: kubernetes.io/service-account-token

EOF

  echo -e "${COLOR_BLUE}准备创建 kubernetes-dashboard service account yml ...${COLOR_RESET}"
  kubectl apply -f kubernetes_dashboard_service_account.yml
  echo -e "${COLOR_BLUE}准备创建 kubernetes-dashboard cluster role binding yml ...${COLOR_RESET}"
  kubectl apply -f kubernetes_dashboard_cluster_role_binding.yml
  echo -e "${COLOR_BLUE}准备创建 kubernetes-dashboard secret yml ...${COLOR_RESET}"
  kubectl apply -f kubernetes_dashboard_secret.yml

  echo -e "${COLOR_BLUE}准备创建 kubernetes-dashboard token（默认有效期 1h） ...${COLOR_RESET}"
  echo -e "${COLOR_BLUE}使用: ${COLOR_GREEN}kubectl -n kubernetes-dashboard create token admin-user --duration=86400s ${COLOR_BLUE}创建指定有效时间的 token${COLOR_RESET}"
  echo -e "${COLOR_BLUE}使用: ${COLOR_GREEN}kubectl -n kubernetes-dashboard get secret admin-user -o jsonpath={\".data.token\"} | base64 -d ${COLOR_BLUE}获取长期 token${COLOR_RESET}"
  echo ''
  kubectl -n kubernetes-dashboard create token admin-user
  echo ''
}

_firewalld_stop() {
  if [[ $package_type == 'yum' || $package_type == 'zypper' ]]; then
    sudo systemctl stop firewalld.service
    sudo systemctl disable firewalld.service
  fi
}

_selinux_disabled() {
  if [[ $package_type == 'yum' ]]; then
    getenforce
    sudo setenforce 0 || true
    sudo getenforce
    cat /etc/selinux/config
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
    cat /etc/selinux/config
  fi
}

# https://github.com/prometheus-operator/kube-prometheus#quickstart
# https://github.com/prometheus-operator/kube-prometheus/blob/main/docs/access-ui.md
_kube_prometheus_install() {
  if ! [[ $kube_prometheus_url ]]; then
    kube_prometheus_url=$kube_prometheus_mirror/$kube_prometheus_version/kube-prometheus-${kube_prometheus_version:1}.tar.gz
  fi
  echo -e "${COLOR_BLUE}kube_prometheus_url: ${COLOR_GREEN}$kube_prometheus_url${COLOR_RESET}"

  kube_prometheus_basename=$(basename "$kube_prometheus_url")
  timeout 300 curl -L --connect-timeout 10 --max-time 120 -o "$kube_prometheus_basename" "$kube_prometheus_url"
  tar -zxvf "$kube_prometheus_basename"
  kube_prometheus_folder=$(echo "$kube_prometheus_basename" | sed 's/.tar.gz//')
  cd $kube_prometheus_folder
  ls -la

  sed -i "s#grafana/grafana#$grafana_image#" manifests/grafana-deployment.yaml

  sed -i "s#k8s.gcr.io/kube-state-metrics/kube-state-metrics#$kube_state_metrics_image#" manifests/kubeStateMetrics-deployment.yaml
  sed -i "s#registry.k8s.io/kube-state-metrics/kube-state-metrics#$kube_state_metrics_image#" manifests/kubeStateMetrics-deployment.yaml

  sed -i "s#k8s.gcr.io/prometheus-adapter/prometheus-adapter#$prometheus_adapter_image#" manifests/prometheusAdapter-deployment.yaml
  sed -i "s#registry.k8s.io/prometheus-adapter/prometheus-adapter#$prometheus_adapter_image#" manifests/prometheusAdapter-deployment.yaml

  sed -i "s#jimmidyson/configmap-reload#$jimmidyson_configmap_reload_image#" manifests/blackboxExporter-deployment.yaml

  kubectl apply --server-side -f manifests/setup
  kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring
  kubectl apply -f manifests/
  kubectl get pod,svc --all-namespaces
  kubectl get prometheuses -n monitoring
}

_kube_prometheus_node_port() {
  kubectl -n monitoring patch svc prometheus-k8s -p '{"spec":{"type":"NodePort","ports":[{"name":"web","nodePort":'$prometheus_k8s_web_9090_node_port',"port":9090,"protocol":"TCP","targetPort":"web"},{"name":"reloader-web","nodePort":'$prometheus_k8s_reloader_web_8080_node_port',"port":8080,"protocol":"TCP","targetPort":"reloader-web"}]}}'
  kubectl -n monitoring patch svc alertmanager-main -p '{"spec":{"type":"NodePort","ports":[{"name":"web","nodePort":'$alertmanager_main_web_9093_node_port',"port":9093,"protocol":"TCP","targetPort":"web"},{"name":"reloader-web","nodePort":'$alertmanager_main_reloader_web_8080_node_port',"port":8080,"protocol":"TCP","targetPort":"reloader-web"}]}}'
  kubectl -n monitoring patch svc grafana -p '{"spec":{"type":"NodePort","ports":[{"name":"http","nodePort":'$grafana_http_3000_node_port',"port":3000,"protocol":"TCP","targetPort":"http"}]}}'
}

_kube_prometheus_remote_access() {
  kubectl -n monitoring patch networkpolicy prometheus-k8s -p '{"spec":{"egress":[{}],"ingress":[{"ports":[{"port":9090,"protocol":"TCP"},{"port":8080,"protocol":"TCP"}]},{"ports":[{"port":9090,"protocol":"TCP"}]},{"ports":[{"port":9090,"protocol":"TCP"}]}],"podSelector":{"matchLabels":{"app.kubernetes.io/component":"prometheus","app.kubernetes.io/instance":"k8s","app.kubernetes.io/name":"prometheus","app.kubernetes.io/part-of":"kube-prometheus"}},"policyTypes":["Egress","Ingress"]}}'
  kubectl -n monitoring patch networkpolicy alertmanager-main -p '{"spec":{"egress":[{}],"ingress":[{"ports":[{"port":9093,"protocol":"TCP"},{"port":8080,"protocol":"TCP"}]},{"ports":[{"port":9094,"protocol":"TCP"},{"port":9094,"protocol":"UDP"}]}],"podSelector":{"matchLabels":{"app.kubernetes.io/component":"alert-router","app.kubernetes.io/instance":"main","app.kubernetes.io/name":"alertmanager","app.kubernetes.io/part-of":"kube-prometheus"}},"policyTypes":["Egress","Ingress"]}}'
  kubectl -n monitoring patch networkpolicy grafana -p '{"spec":{"egress":[{}],"ingress":[{"ports":[{"port":3000,"protocol":"TCP"}]}],"podSelector":{"matchLabels":{"app.kubernetes.io/component":"grafana","app.kubernetes.io/name":"grafana","app.kubernetes.io/part-of":"kube-prometheus"}},"policyTypes":["Egress","Ingress"]}}'
}

_openssl_install() {
  if ! command -v 'openssl' &>/dev/null; then
    if [[ $package_type == 'yum' ]]; then
      echo -e "${COLOR_BLUE}openssl 未安装，正在安装...${COLOR_RESET}"
      sudo yum install -y openssl
      echo -e "${COLOR_BLUE}openssl 安装完成${COLOR_RESET}"
    elif [[ $package_type == 'apt' ]]; then
      echo -e "${COLOR_BLUE}openssl 未安装，正在安装...${COLOR_RESET}"
      apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
      apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y openssl
      echo -e "${COLOR_BLUE}openssl 安装完成${COLOR_RESET}"
    fi
  fi
}

_etcd_binary_install() {
  _firewalld_stop

  mkdir -p /root/.ssh
  mkdir -p /etc/etcd/pki

  if ! [[ $etcd_current_ip ]]; then
    etcd_current_ip=$(hostname -I | awk '{print $1}')
  fi

  # 当存在 etcd_ips 参数时，当前机器的 IP 必须在 etcd_ips 参数内
  if [[ $etcd_ips ]]; then
    if ! [[ "${etcd_ips[*]}" =~ ${etcd_current_ip} ]]; then
      echo "当前机器的 IP: $etcd_current_ip 不在 etcd 集群 IP 列表中，终止 etcd 安装"
      for etcd_ip in "${etcd_ips[@]}"; do
        echo "$etcd_ip"
      done
      exit 1
    fi
  fi

  # etcd_ips 参数的个数
  etcd_ips_length=${#etcd_ips[@]}
  # etcd_ips 参数中 @ 的数量
  etcd_ips_at_num=0
  # etcd_ips 参数中，自定义的 ETCD 节点 名称
  etcd_ips_names=()
  # etcd_ips 参数中，自定义的 ETCD 节点 IP
  etcd_ips_tmp=()
  for etcd_ip in "${etcd_ips[@]}"; do
    etcd_ip_tmp=$(echo $etcd_ip | awk -F'@' '{print $1}')
    etcd_ip_name_tmp=$(echo $etcd_ip | awk -F'@' '{print $2}')

    if [[ $etcd_ip_name_tmp ]]; then
      etcd_ips_names+=("$etcd_ip_name_tmp")
      etcd_ips_at_num=$(($etcd_ips_at_num + 1))
    fi

    etcd_ips_tmp+=("$etcd_ip_tmp")
  done

  if [[ $etcd_ips_at_num != 0 && "$etcd_ips_at_num" != "$etcd_ips_length" ]]; then
    echo "ETCD 名称配置错误：只能全部忽略名称或全部自定义名称"
    echo "etcd_ips: ${etcd_ips[*]}"
    exit 1
  fi

  etcd_ips=("${etcd_ips_tmp[@]}")
  etcd_ips_names_length=${#etcd_ips_names[@]}

  echo "当前 etcd 节点的 IP: $etcd_current_ip"
  echo "etcd 集群配置:"
  local etcd_num=0
  etcd_initial_cluster=''
  for etcd_ip in "${etcd_ips[@]}"; do
    etcd_num=$(($etcd_num + 1))
    if [[ $etcd_ips_names_length == 0 ]]; then
      etcd_name="etcd-$etcd_num"
    else
      etcd_name="${etcd_ips_names[$etcd_num - 1]}"
    fi

    echo "$etcd_name: $etcd_ip:$etcd_client_port_2379"
    etcd_initial_cluster+=$etcd_name=https://$etcd_ip:$etcd_peer_port_2380,
  done
  etcd_initial_cluster="${etcd_initial_cluster%,}"

  _tar_install

  if ! [[ $etcd_url ]]; then
    etcd_url=$etcd_mirror/$etcd_version/etcd-$etcd_version-linux-$cpu_platform.tar.gz
  fi

  echo "etcd_url=$etcd_url"

  timeout 300 curl -L --connect-timeout 10 --max-time 120 "${etcd_url}" -o etcd-${etcd_version}-linux-$cpu_platform.tar.gz
  tar xzvf etcd-${etcd_version}-linux-$cpu_platform.tar.gz

  etcd-${etcd_version}-linux-$cpu_platform/etcd --version
  etcd-${etcd_version}-linux-$cpu_platform/etcdctl version
  etcd-${etcd_version}-linux-$cpu_platform/etcdutl version

  cp -f etcd-${etcd_version}-linux-$cpu_platform/etcd /usr/local/bin/
  cp -f etcd-${etcd_version}-linux-$cpu_platform/etcdctl /usr/local/bin/
  cp -f etcd-${etcd_version}-linux-$cpu_platform/etcdutl /usr/local/bin/

  /usr/local/bin/etcd --version
  /usr/local/bin/etcdctl version
  /usr/local/bin/etcdutl version

  _openssl_install

  openssl genrsa -out etcd-ca.key 2048
  openssl req -x509 -new -nodes -key etcd-ca.key -subj "/CN=$etcd_current_ip" -days 36500 -out etcd-ca.crt

  cp etcd-ca.key /etc/etcd/pki/ca.key
  cp etcd-ca.crt /etc/etcd/pki/ca.crt
  ls -lh /etc/etcd/pki/ca.key
  ls -lh /etc/etcd/pki/ca.crt

  cat >etcd-ssl.cnf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = $dn_c
ST = $dn_st
L = $dn_l
O = $dn_o
OU = $dn_ou
CN = $dn_cn

[ req_ext ]
subjectAltName = @alt_names

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names

[ alt_names ]

EOF

  cat etcd-ssl.cnf

  local etcd_num=1
  echo "IP.$etcd_num = $etcd_current_ip" >>etcd-ssl.cnf
  for etcd_ip in "${etcd_ips[@]}"; do
    etcd_num=$(($etcd_num + 1))
    echo "IP.$etcd_num = $etcd_ip" >>etcd-ssl.cnf
  done

  cat etcd-ssl.cnf

  # 创建 etcd 服务端 CA 证书
  openssl genrsa -out etcd-server.key 2048
  openssl req -new -key etcd-server.key -config etcd-ssl.cnf -subj "/CN=etcd-server" -out etcd-server.csr
  openssl x509 -req -in etcd-server.csr -CA /etc/etcd/pki/ca.crt -CAkey /etc/etcd/pki/ca.key -CAcreateserial -days 36500 -extensions v3_ext -extfile etcd-ssl.cnf -out etcd-server.crt
  cp etcd-server.crt /etc/etcd/pki/server.crt
  cp etcd-server.key /etc/etcd/pki/server.key
  ls -lh /etc/etcd/pki/server.crt
  ls -lh /etc/etcd/pki/server.key

  # 创建 etcd 客户端 CA 证书
  openssl genrsa -out etcd-peer.key 2048
  openssl req -new -key etcd-peer.key -config etcd-ssl.cnf -subj "/CN=etcd-peer" -out etcd-peer.csr
  openssl x509 -req -in etcd-peer.csr -CA /etc/etcd/pki/ca.crt -CAkey /etc/etcd/pki/ca.key -CAcreateserial -days 36500 -extensions v3_ext -extfile etcd-ssl.cnf -out etcd-peer.crt
  cp etcd-peer.crt /etc/etcd/pki/peer.crt
  cp etcd-peer.key /etc/etcd/pki/peer.key
  ls -lh /etc/etcd/pki/peer.crt
  ls -lh /etc/etcd/pki/peer.key

  etcd_ips_names_length=${#etcd_ips_names[@]}
  etcd_init_name=etcd-1
  if [[ $etcd_ips_names_length != 0 ]]; then
    etcd_init_name=${etcd_ips_names[0]}
  fi

  cat >/etc/etcd/etcd.conf <<EOF
# 节点名称，每个节点不同
ETCD_NAME=$etcd_init_name
# 数据目录
ETCD_DATA_DIR=/etc/etcd/data

# etcd 服务端CA证书-crt
ETCD_CERT_FILE=/etc/etcd/pki/server.crt
# etcd 服务端CA证书-key
ETCD_KEY_FILE=/etc/etcd/pki/server.key
ETCD_TRUSTED_CA_FILE=/etc/etcd/pki/ca.crt
# 是否启用客户端证书认证
ETCD_CLIENT_CERT_AUTH=true
# 客户端提供的服务监听URL地址
ETCD_LISTEN_CLIENT_URLS=https://$etcd_current_ip:$etcd_client_port_2379
ETCD_ADVERTISE_CLIENT_URLS=https://$etcd_current_ip:$etcd_client_port_2379

# 集群各节点相互认证使用的CA证书-crt
ETCD_PEER_CERT_FILE=/etc/etcd/pki/server.crt
# 集群各节点相互认证使用的CA证书-key
ETCD_PEER_KEY_FILE=/etc/etcd/pki/server.key
# CA 根证书
ETCD_PEER_TRUSTED_CA_FILE=/etc/etcd/pki/ca.crt
# 为本集群其他节点提供的服务监听URL地址
ETCD_LISTEN_PEER_URLS=https://$etcd_current_ip:$etcd_peer_port_2380
# 本节点对外通告的 ETCD 客户端访问地址（集群内部）
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://$etcd_current_ip:$etcd_peer_port_2380

# 初始集群
ETCD_INITIAL_CLUSTER_TOKEN=etcd-cluster
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_INITIAL_CLUSTER=$etcd_initial_cluster
EOF

  if [[ $os_type == 'centos' || $os_type == 'anolis' || $os_type == 'almalinux' || $os_type == 'openEuler' || $os_type == 'rocky' || $os_type == 'uos' ]]; then
    cat >>/etc/etcd/etcd.conf <<'EOF'
# 兼容 CentOS7 / RHEL7 / UOS 等系统，使用 etcd 作为服务时可指定 etcd.conf 位置
ETCD_CONF_FILE=/etc/etcd/etcd.conf
EOF
  fi

  cat /etc/etcd/etcd.conf

  echo -e "${COLOR_BLUE}创建 etcd systemd 服务${COLOR_RESET}"
  cat >/etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name=${ETCD_NAME} \
  --data-dir=${ETCD_DATA_DIR} \
  --client-cert-auth=${ETCD_CLIENT_CERT_AUTH} \
  --trusted-ca-file=${ETCD_TRUSTED_CA_FILE} \
  --cert-file=${ETCD_CERT_FILE} \
  --key-file=${ETCD_KEY_FILE} \
  --listen-client-urls=${ETCD_LISTEN_CLIENT_URLS} \
  --advertise-client-urls=${ETCD_ADVERTISE_CLIENT_URLS} \
  --peer-client-cert-auth=true \
  --peer-trusted-ca-file=${ETCD_PEER_TRUSTED_CA_FILE} \
  --peer-cert-file=${ETCD_PEER_CERT_FILE} \
  --peer-key-file=${ETCD_PEER_KEY_FILE} \
  --listen-peer-urls=${ETCD_LISTEN_PEER_URLS} \
  --initial-advertise-peer-urls=${ETCD_INITIAL_ADVERTISE_PEER_URLS} \
  --initial-cluster=${ETCD_INITIAL_CLUSTER} \
  --initial-cluster-token=${ETCD_INITIAL_CLUSTER_TOKEN} \
  --initial-cluster-state=${ETCD_INITIAL_CLUSTER_STATE}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable etcd.service
  systemctl start etcd.service
  systemctl status etcd.service -l --no-pager
}

_etcd_binary_join() {
  echo -e "${COLOR_BLUE}将当前节点加入 etcd 集群...${COLOR_RESET}"
  if ! [[ $etcd_join_ip ]]; then
    echo -e "${COLOR_RED}未指定 etcd-join-ip 参数，退出${COLOR_RESET}"
    exit 1
  fi

  if ! [[ $etcd_join_port ]]; then
    etcd_join_port=22
  fi

  if [[ $etcd_join_ip == $etcd_current_ip ]]; then
    echo -e "${COLOR_RED}当前节点 IP ($etcd_current_ip) 不能与 etcd-join-ip 相同${COLOR_RESET}"
    exit 1
  fi

  if ! [[ $etcd_join_password ]]; then
    echo -e "${COLOR_RED}未指定 etcd-join 密码 (SSH 密码)，退出${COLOR_RESET}"
    exit 1
  fi

  if ! command -v 'sshpass' &>/dev/null; then
    echo -e "${COLOR_BLUE}安装 sshpass...${COLOR_RESET}"
    if [[ $package_type == 'yum' ]]; then
      sudo yum install -y epel-release || true
      sudo yum install -y sshpass
    elif [[ $package_type == 'apt' ]]; then
      sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
      sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y sshpass
    fi
  fi

  # 为目标 etcd 节点添加 known_hosts
  ssh-keyscan -H $etcd_join_ip -P $etcd_join_port >>/root/.ssh/known_hosts

  # 加入 etcd 集群
  echo -e "${COLOR_BLUE}通过 SSH 将当前节点加入 etcd 集群...${COLOR_RESET}"
  sshpass -p "$etcd_join_password" ssh -p $etcd_join_port root@$etcd_join_ip "etcdctl member add $etcd_current_ip --peer-urls=https://$etcd_current_ip:$etcd_peer_port_2380"

  # 在当前节点同步 etcd 数据目录
  echo -e "${COLOR_BLUE}同步 etcd 数据目录...${COLOR_RESET}"
  sshpass -p "$etcd_join_password" rsync -azq -e "ssh -p $etcd_join_port" root@$etcd_join_ip:/etc/etcd/data/ /etc/etcd/data/

  # 启动当前节点 etcd 服务
  echo -e "${COLOR_BLUE}启动当前节点 etcd 服务...${COLOR_RESET}"
  systemctl start etcd.service
  systemctl status etcd.service -l --no-pager
}

# ================================================================
# VIP 高可用功能 (HAProxy + Keepalived)
# ================================================================

# 安装Master VIP高可用
_availability_vip_install() {
  if ! [[ $availability_vip ]]; then
    echo -e "${COLOR_RED}错误：未指定 Master VIP 地址 (--availability-vip)${COLOR_RESET}"
    exit 1
  fi

  if ! [[ $availability_vip_no ]]; then
    echo -e "${COLOR_RED}错误：未指定 Master VIP 节点编号 (--availability-vip-no)${COLOR_RESET}"
    exit 1
  fi

  if ! [[ $availability_masters ]]; then
    echo -e "${COLOR_RED}错误：未指定 Master 节点列表 (--availability-masters)${COLOR_RESET}"
    exit 1
  fi

  echo -e "${COLOR_BLUE}🔧 配置 Master VIP 高可用...${COLOR_RESET}"
  
  # 确保Docker已安装
  if ! command -v docker &> /dev/null; then
    echo -e "${COLOR_BLUE}安装 Docker 以支持 HAProxy 和 Keepalived...${COLOR_RESET}"
    _docker_repo
    _docker_install
  fi

  # 创建HAProxy配置目录
  sudo mkdir -p /etc/haproxy-master/

  # 生成HAProxy配置文件
  echo -e "${COLOR_BLUE}生成 HAProxy 配置文件...${COLOR_RESET}"
  cat > /etc/haproxy-master/haproxy.cfg << EOF
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4096
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    tcp
    log                     global
    option                  tcplog
    option                  dontlognull
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

frontend k8s-master-frontend
    bind *:9443
    default_backend k8s-master-backend

listen stats
    mode                 http
    bind                 *:8888
    stats auth           $availability_haproxy_username:$availability_haproxy_password
    stats refresh        5s
    stats realm          HAProxy\ Statistics
    stats uri            /stats

backend k8s-master-backend
    mode        tcp
    balance     roundrobin
    option      tcp-check
EOF

  # 添加Master节点到HAProxy配置
  local master_count=0
  for master in "${availability_masters[@]}"; do
    master_count=$((master_count + 1))
    
    # 解析 name@ip:port 格式
    local master_name=$(echo "$master" | cut -d'@' -f1)
    local master_ip=$(echo "$master" | cut -d'@' -f2 | cut -d':' -f1)
    local master_port=$(echo "$master" | cut -d'@' -f2 | cut -d':' -f2)
    
    echo "    server      ${master_name} ${master_ip}:${master_port} check" >> /etc/haproxy-master/haproxy.cfg
  done

  # 启动HAProxy容器
  echo -e "${COLOR_BLUE}启动 HAProxy 容器...${COLOR_RESET}"
  docker stop k8s-haproxy 2>/dev/null || true
  docker rm k8s-haproxy 2>/dev/null || true
  
  # 启动HAProxy容器
  echo -e "${COLOR_BLUE}使用镜像: ${COLOR_GREEN}$haproxy_image:$haproxy_version${COLOR_RESET}"
  docker run \
    -d \
    --name k8s-haproxy \
    --net=host \
    --restart=always \
    -v /etc/haproxy-master/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
    $haproxy_image:$haproxy_version

  # 创建Keepalived配置目录
  sudo mkdir -p /etc/keepalived-master/

  # 获取网卡名称
  _interface_name

  # 生成Keepalived配置
  echo -e "${COLOR_BLUE}生成 Keepalived 配置文件...${COLOR_RESET}"
  
  local keepalived_state="BACKUP"
  local keepalived_priority=100
  
  if [[ $availability_vip_no -eq 1 ]]; then
    keepalived_state="MASTER"
    keepalived_priority=110
  fi

  cat > /etc/keepalived-master/keepalived.conf << EOF
! Configuration File for keepalived

global_defs {
   router_id MASTER_VIP_${availability_vip_no}
}

vrrp_script checkhaproxy
{
    script "/usr/bin/check-haproxy.sh"
    interval 2
    weight -30
}

vrrp_instance VI_MASTER {
    state $keepalived_state
    interface $interface_name
    virtual_router_id 51
    priority $keepalived_priority
    advert_int 1

    virtual_ipaddress {
        $availability_vip/24
    }

    authentication {
        auth_type PASS
        auth_pass master123
    }

    track_script {
        checkhaproxy
    }
}
EOF

  # 创建健康检查脚本
  cat > /etc/keepalived-master/check-haproxy.sh << 'EOF'
#!/bin/bash
count=`netstat -apn | grep :9443 | wc -l`
if [ $count -gt 0 ]; then
    exit 0
else
    exit 1
fi
EOF

  chmod +x /etc/keepalived-master/check-haproxy.sh

  # 启动Keepalived容器
  echo -e "${COLOR_BLUE}启动 Keepalived 容器...${COLOR_RESET}"
  docker stop k8s-keepalived 2>/dev/null || true
  docker rm k8s-keepalived 2>/dev/null || true
  
  # 启动Keepalived容器（统一使用osixia/keepalived配置方式）
  echo -e "${COLOR_BLUE}使用镜像: ${COLOR_GREEN}$keepalived_image:$keepalived_version${COLOR_RESET}"
  docker run \
    -d \
    --name k8s-keepalived \
    --restart=always \
    --net=host \
    --cap-add=NET_ADMIN \
    --cap-add=NET_BROADCAST \
    --cap-add=NET_RAW \
    -v /etc/keepalived-master/keepalived.conf:/etc/keepalived/keepalived.conf \
    -v /etc/keepalived-master/check-haproxy.sh:/usr/bin/check-haproxy.sh \
    $keepalived_image:$keepalived_version

  echo -e "${COLOR_GREEN}✅ Master VIP 高可用配置完成${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   VIP地址: ${COLOR_GREEN}$availability_vip:9443${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   HAProxy状态: ${COLOR_GREEN}http://$(hostname -I | awk '{print $1}'):8888/stats${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   用户名/密码: ${COLOR_GREEN}$availability_haproxy_username/$availability_haproxy_password${COLOR_RESET}"
}

# 安装Worker VIP高可用
_availability_worker_vip_install() {
  if ! [[ $availability_worker_vip ]]; then
    echo -e "${COLOR_RED}错误：未指定 Worker VIP 地址 (--availability-worker-vip)${COLOR_RESET}"
    exit 1
  fi

  if ! [[ $availability_worker_vip_no ]]; then
    echo -e "${COLOR_RED}错误：未指定 Worker VIP 节点编号 (--availability-worker-vip-no)${COLOR_RESET}"
    exit 1
  fi

  echo -e "${COLOR_BLUE}🔧 配置 Worker VIP 高可用...${COLOR_RESET}"
  
  # 确保Docker已安装
  if ! command -v docker &> /dev/null; then
    echo -e "${COLOR_BLUE}安装 Docker 以支持 HAProxy 和 Keepalived...${COLOR_RESET}"
    _docker_repo
    _docker_install
  fi

  # 创建HAProxy配置目录
  sudo mkdir -p /etc/haproxy-worker/

  # 生成HAProxy配置文件
  echo -e "${COLOR_BLUE}生成 Worker HAProxy 配置文件...${COLOR_RESET}"
  cat > /etc/haproxy-worker/haproxy.cfg << 'EOF'
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4096
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option                  http-server-close
    option                  forwardfor    except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

frontend ingress-frontend
    mode                 tcp
    bind                 *:80
    bind                 *:443
    option               tcplog
    default_backend      ingress-backend

listen stats
    mode                 http
    bind                 *:8889
    stats auth           admin:admin123456
    stats refresh        5s
    stats realm          HAProxy\ Statistics
    stats uri            /stats

backend ingress-backend
    mode        tcp
    balance     roundrobin
    server      worker-01 10.1.66.4:30080 check
    server      worker-02 10.1.66.5:30080 check
    server      worker-03 10.1.66.6:30080 check
    server      worker-04 10.1.66.7:30080 check
EOF

  # 启动HAProxy容器
  echo -e "${COLOR_BLUE}启动 Worker HAProxy 容器...${COLOR_RESET}"
  docker stop k8s-worker-haproxy 2>/dev/null || true
  docker rm k8s-worker-haproxy 2>/dev/null || true
  
  # 启动Worker HAProxy容器
  echo -e "${COLOR_BLUE}使用镜像: ${COLOR_GREEN}$haproxy_image:$haproxy_version${COLOR_RESET}"
  docker run \
    -d \
    --name k8s-worker-haproxy \
    --net=host \
    --restart=always \
    -v /etc/haproxy-worker/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
    $haproxy_image:$haproxy_version

  # 创建Keepalived配置目录
  sudo mkdir -p /etc/keepalived-worker/

  # 获取网卡名称
  _interface_name

  # 生成Keepalived配置
  echo -e "${COLOR_BLUE}生成 Worker Keepalived 配置文件...${COLOR_RESET}"
  
  local keepalived_state="BACKUP"
  local keepalived_priority=100
  
  if [[ $availability_worker_vip_no -eq 1 ]]; then
    keepalived_state="MASTER"
    keepalived_priority=110
  fi

  cat > /etc/keepalived-worker/keepalived.conf << EOF
! Configuration File for keepalived

global_defs {
   router_id WORKER_VIP_${availability_worker_vip_no}
}

vrrp_script checkhaproxy
{
    script "/usr/bin/check-worker-haproxy.sh"
    interval 2
    weight -30
}

vrrp_instance VI_WORKER {
    state $keepalived_state
    interface $interface_name
    virtual_router_id 52
    priority $keepalived_priority
    advert_int 1

    virtual_ipaddress {
        $availability_worker_vip/24
    }

    authentication {
        auth_type PASS
        auth_pass worker123
    }

    track_script {
        checkhaproxy
    }
}
EOF

  # 创建健康检查脚本
  cat > /etc/keepalived-worker/check-worker-haproxy.sh << 'EOF'
#!/bin/bash
count=`netstat -apn | grep :80 | wc -l`
if [ $count -gt 0 ]; then
    exit 0
else
    exit 1
fi
EOF

  chmod +x /etc/keepalived-worker/check-worker-haproxy.sh

  # 启动Keepalived容器
  echo -e "${COLOR_BLUE}启动 Worker Keepalived 容器...${COLOR_RESET}"
  docker stop k8s-worker-keepalived 2>/dev/null || true
  docker rm k8s-worker-keepalived 2>/dev/null || true
  
  # 启动Worker Keepalived容器（统一使用osixia/keepalived配置方式）
  echo -e "${COLOR_BLUE}使用镜像: ${COLOR_GREEN}$keepalived_image:$keepalived_version${COLOR_RESET}"
  docker run \
    -d \
    --name k8s-worker-keepalived \
    --restart=always \
    --net=host \
    --cap-add=NET_ADMIN \
    --cap-add=NET_BROADCAST \
    --cap-add=NET_RAW \
    -v /etc/keepalived-worker/keepalived.conf:/etc/keepalived/keepalived.conf \
    -v /etc/keepalived-worker/check-worker-haproxy.sh:/usr/bin/check-worker-haproxy.sh \
    $keepalived_image:$keepalived_version

  echo -e "${COLOR_GREEN}✅ Worker VIP 高可用配置完成${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   VIP地址: ${COLOR_GREEN}$availability_worker_vip:80/443${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   HAProxy状态: ${COLOR_GREEN}http://$(hostname -I | awk '{print $1}'):8889/stats${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   用户名/密码: ${COLOR_GREEN}admin/admin123456${COLOR_RESET}"
}

# ================================================================
# 帮助信息和使用说明
# ================================================================

_help() {
  cat << 'EOF'
Kubernetes 企业级自动化部署脚本 v1.0.0
开发组织：Novatra 工作组

使用方法:
  ./k8s-auto.sh [选项]

安装选项:
  --install                     完整安装 Kubernetes 集群（单节点模式）
  --cluster-install             集群模式安装（主节点）
  --node-install               工作节点安装并加入集群
  --containerd-install          仅安装 containerd 容器运行时
  --docker-install              仅安装 Docker 容器运行时

网络插件:
  --calico-install             安装 Calico 网络插件
  --flannel-install            安装 Flannel 网络插件

组件安装:
  --ingress-nginx-install      安装 Ingress Nginx 控制器
  --metrics-server-install     安装 Metrics Server
  --helm-install               安装 Helm 包管理器
  --dashboard-install          安装 Kubernetes Dashboard
  --prometheus-install         安装 Prometheus 监控栈

ETCD 相关:
  --etcd-install               安装外部 ETCD 集群
  --etcd-join                  加入现有 ETCD 集群

配置选项:
  --kubernetes-version=VERSION    指定 Kubernetes 版本 (默认: v1.34.1)
  --pod-network-cidr=CIDR         指定 Pod 网络 CIDR (默认: 10.244.0.0/16)
  --service-cidr=CIDR             指定 Service 网络 CIDR
  --control-plane-endpoint=IP     指定控制平面端点
  --node-name=NAME                指定节点名称
  --interface-name=NAME           指定网络接口名称

镜像源选项:
  --docker-repo-type=TYPE         Docker 仓库类型 (aliyun|tencent|docker)
  --kubernetes-repo-type=TYPE     Kubernetes 仓库类型 (aliyun|tsinghua|kubernetes)
  --helm-repo-type=TYPE           Helm 仓库类型 (huawei|helm)
  --auto-select-mirror            自动选择最快的镜像源

网络下载选项:
  --calico-url=URL                自定义 Calico 配置文件 URL
  --flannel-url=URL               自定义 Flannel 配置文件 URL
  --ingress-nginx-url=URL         自定义 Ingress Nginx 配置文件 URL
  --metrics-server-url=URL        自定义 Metrics Server 配置文件 URL

ETCD 配置:
  --etcd-ips=IP1,IP2,IP3          ETCD 集群 IP 列表
  --etcd-current-ip=IP            当前节点 IP
  --etcd-join-ip=IP               要加入的 ETCD 节点 IP
  --etcd-join-password=PASSWORD   SSH 密码

VIP 高可用选项:
  --availability-vip-install            安装 Master VIP 高可用（HAProxy + Keepalived）
  --availability-masters=MASTERS        Master 节点列表 (name@ip:port,...)
  --availability-vip=IP                 Master VIP 地址
  --availability-vip-no=NUMBER          Master VIP 节点编号（1=主，2+=备）
  --availability-worker-vip-install     安装 Worker VIP 高可用
  --availability-worker-vip=IP          Worker VIP 地址
  --availability-worker-vip-no=NUMBER   Worker VIP 节点编号（1=主，2+=备）

高级选项:
  --taint-master                  移除主节点污点（单节点模式）
  --standalone                    单机模式部署
  --cluster                       集群模式部署
  --node                          节点模式部署
  --print-join-command            显示节点加入命令
  --metrics-server-secure-tls     启用 Metrics Server 安全 TLS

其他选项:
  --help, -h                      显示此帮助信息
  --version, -v                   显示版本信息
  --list-mirrors                  显示可用镜像源列表

使用示例:
  # 单节点完整安装
  ./k8s-auto.sh --install --calico-install

  # 🚀 高可用集群一键自动部署（推荐）
  ./k8s-auto.sh --cluster-install --control-plane-endpoint=10.1.66.17:9443 \
    --kubernetes-version=v1.34.1 --node-name=k8s-master-01 \
    --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 \
    --availability-vip-install \
    --availability-masters=k8s-master-01@10.1.66.1:6443,k8s-master-02@10.1.66.2:6443,k8s-master-03@10.1.66.3:6443 \
    --availability-vip=10.1.66.17 --availability-vip-no=1

  # 其他Master节点安装VIP
  ./k8s-auto.sh --availability-vip-install \
    --availability-masters=k8s-master-01@10.1.66.1:6443,k8s-master-02@10.1.66.2:6443,k8s-master-03@10.1.66.3:6443 \
    --availability-vip=10.1.66.17 \
    --availability-vip-no=2

  # Worker节点VIP高可用
  ./k8s-auto.sh --availability-worker-vip-install \
    --availability-worker-vip=10.1.66.18 \
    --availability-worker-vip-no=1

  # 工作节点加入集群
  ./k8s-auto.sh --node-install

  # 仅安装容器运行时
  ./k8s-auto.sh --containerd-install

  # 安装网络插件
  ./k8s-auto.sh --calico-install --auto-select-mirror

  # 安装监控组件
  ./k8s-auto.sh --prometheus-install --helm-install

注意事项:
  1. 建议在 root 用户下运行脚本
  2. 确保系统时间同步
  3. 确保防火墙和 SELinux 已正确配置
  4. 集群安装时请先安装主节点，再安装工作节点

更多信息请参考: https://kubernetes.io/zh-cn/docs/

EOF
}

_version() {
  echo "Kubernetes 企业级自动化部署脚本 v1.0.0"
  echo "开发组织：Novatra 工作组"
  echo "支持：单节点、集群、高可用模式部署"
  echo "特性：国内网络优化、企业级安全、生产环境就绪"
}

# ================================================================
# 参数解析和验证
# ================================================================

# 初始化变量
install_mode=false
cluster_install=false
node_install=false
containerd_install=false
docker_install=false
calico_install=false
flannel_install=false
ingress_nginx_install=false
metrics_server_install=false
helm_install=false
dashboard_install=false
prometheus_install=false
etcd_install=false
etcd_join=false
taint_master=false
standalone=false
cluster=false
node=false
print_join_command=false
auto_select_fastest_mirror=false
list_mirrors=false
metrics_server_secure_tls=false
availability_vip_install=false
availability_worker_vip_install=false

# 解析命令行参数
_parse_args() {
  if [[ $# -eq 0 ]]; then
    echo -e "${COLOR_YELLOW}未指定任何参数，显示帮助信息${COLOR_RESET}"
    _help
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        _help
        exit 0
        ;;
      --version|-v)
        _version
        exit 0
        ;;
      --install)
        install_mode=true
        standalone=true
        ;;
      --cluster-install)
        cluster_install=true
        cluster=true
        ;;
      --node-install)
        node_install=true
        node=true
        ;;
      --containerd-install)
        containerd_install=true
        ;;
      --docker-install)
        docker_install=true
        ;;
      --calico-install)
        calico_install=true
        ;;
      --flannel-install)
        flannel_install=true
        ;;
      --ingress-nginx-install)
        ingress_nginx_install=true
        ;;
      --metrics-server-install)
        metrics_server_install=true
        ;;
      --helm-install)
        helm_install=true
        ;;
      --dashboard-install)
        dashboard_install=true
        ;;
      --prometheus-install)
        prometheus_install=true
        ;;
      --etcd-install)
        etcd_install=true
        ;;
      --etcd-join)
        etcd_join=true
        ;;
      --taint-master)
        taint_master=true
        ;;
      --standalone)
        standalone=true
        ;;
      --cluster)
        cluster=true
        ;;
      --node)
        node=true
        ;;
      --print-join-command)
        print_join_command=true
        ;;
      --auto-select-mirror)
        auto_select_fastest_mirror=true
        ;;
      --list-mirrors)
        list_mirrors=true
        ;;
      --metrics-server-secure-tls)
        metrics_server_secure_tls=true
        ;;
      --availability-vip-install)
        availability_vip_install=true
        ;;
      --availability-worker-vip-install)
        availability_worker_vip_install=true
        ;;
      --kubernetes-version=*)
        kubernetes_version="${1#*=}"
        ;;
      --pod-network-cidr=*)
        pod_network_cidr="${1#*=}"
        ;;
      --service-cidr=*)
        service_cidr="${1#*=}"
        ;;
      --control-plane-endpoint=*)
        control_plane_endpoint="${1#*=}"
        ;;
      --node-name=*)
        kubernetes_init_node_name="${1#*=}"
        ;;
      --interface-name=*)
        interface_name="${1#*=}"
        ;;
      --availability-masters=*)
        IFS=',' read -ra availability_masters <<< "${1#*=}"
        ;;
      --availability-vip=*)
        availability_vip="${1#*=}"
        ;;
      --availability-vip-no=*)
        availability_vip_no="${1#*=}"
        ;;
      --availability-worker-vip=*)
        availability_worker_vip="${1#*=}"
        ;;
      --availability-worker-vip-no=*)
        availability_worker_vip_no="${1#*=}"
        ;;
      --docker-repo-type=*)
        docker_repo_type="${1#*=}"
        ;;
      --kubernetes-repo-type=*)
        kubernetes_repo_type="${1#*=}"
        ;;
      --helm-repo-type=*)
        helm_repo_type="${1#*=}"
        ;;
      --calico-url=*)
        calico_url="${1#*=}"
        ;;
      --flannel-url=*)
        flannel_url="${1#*=}"
        ;;
      --ingress-nginx-url=*)
        ingress_nginx_url="${1#*=}"
        ;;
      --metrics-server-url=*)
        metrics_server_url="${1#*=}"
        ;;
      --etcd-ips=*)
        IFS=',' read -ra etcd_ips <<< "${1#*=}"
        ;;
      --etcd-current-ip=*)
        etcd_current_ip="${1#*=}"
        ;;
      --etcd-join-ip=*)
        etcd_join_ip="${1#*=}"
        ;;
      --etcd-join-password=*)
        etcd_join_password="${1#*=}"
        ;;
      --etcd-cafile=*)
        etcd_cafile="${1#*=}"
        ;;
      --etcd-certfile=*)
        etcd_certfile="${1#*=}"
        ;;
      --etcd-keyfile=*)
        etcd_keyfile="${1#*=}"
        ;;
      --containerd-io-rpm=*)
        containerd_io_rpm="${1#*=}"
        ;;
      --helm-url=*)
        helm_url="${1#*=}"
        ;;
      *)
        echo -e "${COLOR_RED}未知参数: $1${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}使用 --help 查看帮助信息${COLOR_RESET}"
        exit 1
        ;;
    esac
    shift
  done
}

# 验证参数
_validate_args() {
  # 检查互斥参数
  local mode_count=0
  [[ $install_mode == true ]] && ((mode_count++))
  [[ $cluster_install == true ]] && ((mode_count++))
  [[ $node_install == true ]] && ((mode_count++))
  
  if [[ $mode_count -gt 1 ]]; then
    echo -e "${COLOR_RED}错误：不能同时指定多个安装模式${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}请选择其中一个：--install, --cluster-install, --node-install${COLOR_RESET}"
    exit 1
  fi

  # 检查网络插件互斥
  if [[ $calico_install == true && $flannel_install == true ]]; then
    echo -e "${COLOR_RED}错误：不能同时安装 Calico 和 Flannel 网络插件${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}请选择其中一个：--calico-install 或 --flannel-install${COLOR_RESET}"
    exit 1
  fi

  # 检查容器运行时互斥
  if [[ $containerd_install == true && $docker_install == true ]]; then
    echo -e "${COLOR_RED}错误：不能同时安装 containerd 和 Docker${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}请选择其中一个：--containerd-install 或 --docker-install${COLOR_RESET}"
    exit 1
  fi

  # 验证 Kubernetes 版本格式
  if [[ $kubernetes_version && ! $kubernetes_version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${COLOR_RED}错误：Kubernetes 版本格式不正确：$kubernetes_version${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}正确格式：v1.34.1${COLOR_RESET}"
    exit 1
  fi

  # 验证 CIDR 格式
  if [[ $pod_network_cidr && ! $pod_network_cidr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    echo -e "${COLOR_RED}错误：Pod 网络 CIDR 格式不正确：$pod_network_cidr${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}正确格式：10.244.0.0/16${COLOR_RESET}"
    exit 1
  fi

  if [[ $service_cidr && ! $service_cidr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    echo -e "${COLOR_RED}错误：Service 网络 CIDR 格式不正确：$service_cidr${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}正确格式：10.96.0.0/12${COLOR_RESET}"
    exit 1
  fi
}

# ================================================================
# 主执行逻辑
# ================================================================

_main() {
  echo -e "${COLOR_BLUE}════════════════════════════════════════${COLOR_RESET}"
  echo -e "${COLOR_BLUE}  Kubernetes 企业级自动化部署脚本 v1.0.0  ${COLOR_RESET}"
  echo -e "${COLOR_BLUE}════════════════════════════════════════${COLOR_RESET}"
  echo -e "${COLOR_GREEN}🚀 全自动模式：优化超时设置，跳过交互，快速部署${COLOR_RESET}"
  echo ""

  # 系统检测
  echo -e "${COLOR_BLUE}🔍 系统环境检测...${COLOR_RESET}"
  _system_detect
  
  # 根据架构配置镜像
  _configure_images_by_arch
  echo ""

  # 显示镜像源列表
  if [[ $list_mirrors == true ]]; then
    _list_available_mirrors
    exit 0
  fi

  # 检查 root 权限
  if [[ $EUID -ne 0 ]]; then
    echo -e "${COLOR_RED}此脚本需要 root 权限运行${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}请使用 sudo 或切换到 root 用户${COLOR_RESET}"
    exit 1
  fi

  # 基础环境准备（所有安装模式都需要）
  if [[ $install_mode == true || $cluster_install == true || $node_install == true ]]; then
    echo -e "${COLOR_BLUE}🔧 [1/8] 准备基础环境...${COLOR_RESET}"
    echo -e "${COLOR_BLUE}  ├─ 安装 curl...${COLOR_RESET}"
    _curl
    echo -e "${COLOR_BLUE}  ├─ 安装 ca-certificates...${COLOR_RESET}"
    _ca_certificates
    echo -e "${COLOR_BLUE}  ├─ 关闭防火墙...${COLOR_RESET}"
    _firewalld_stop
    echo -e "${COLOR_BLUE}  ├─ 禁用 SELinux...${COLOR_RESET}"
    _selinux_disabled
    echo -e "${COLOR_BLUE}  └─ 关闭 Swap...${COLOR_RESET}"
    _swap_off
    echo -e "${COLOR_GREEN}✅ 基础环境准备完成${COLOR_RESET}"
  fi

  # 容器运行时安装
  if [[ $containerd_install == true ]]; then
    echo -e "${COLOR_BLUE}🐳 [2/8] 安装 containerd...${COLOR_RESET}"
    echo -e "${COLOR_BLUE}  ├─ 配置 Docker 仓库...${COLOR_RESET}"
    _docker_repo
    echo -e "${COLOR_BLUE}  ├─ 安装 containerd...${COLOR_RESET}"
    _containerd_install
    echo -e "${COLOR_BLUE}  └─ 配置 containerd...${COLOR_RESET}"
    _containerd_config
    echo -e "${COLOR_GREEN}✅ containerd 安装完成${COLOR_RESET}"
  elif [[ $docker_install == true ]]; then
    echo -e "${COLOR_BLUE}🐳 [2/8] 安装 Docker...${COLOR_RESET}"
    _docker_repo
    _docker_install
    echo -e "${COLOR_GREEN}✅ Docker 安装完成${COLOR_RESET}"
  elif [[ $install_mode == true || $cluster_install == true || $node_install == true ]]; then
    # 默认安装 containerd
    echo -e "${COLOR_BLUE}🐳 [2/8] 安装 containerd（默认容器运行时）...${COLOR_RESET}"
    echo -e "${COLOR_BLUE}  ├─ 配置 Docker 仓库...${COLOR_RESET}"
    _docker_repo
    echo -e "${COLOR_BLUE}  ├─ 安装 containerd...${COLOR_RESET}"
    _containerd_install
    echo -e "${COLOR_BLUE}  └─ 配置 containerd...${COLOR_RESET}"
    _containerd_config
    echo -e "${COLOR_GREEN}✅ containerd 安装完成${COLOR_RESET}"
  fi

  # Kubernetes 组件安装
  if [[ $install_mode == true || $cluster_install == true || $node_install == true ]]; then
    echo -e "${COLOR_BLUE}☸️ [3/8] 安装 Kubernetes 组件...${COLOR_RESET}"
    echo -e "${COLOR_BLUE}  ├─ 配置 Kubernetes 仓库...${COLOR_RESET}"
    _kubernetes_repo
    echo -e "${COLOR_BLUE}  ├─ 安装 kubelet、kubeadm、kubectl...${COLOR_RESET}"
    _kubernetes_install
    echo -e "${COLOR_BLUE}  ├─ 配置 Kubernetes...${COLOR_RESET}"
    _kubernetes_config
    echo -e "${COLOR_BLUE}  ├─ 启用 shell 自动补全...${COLOR_RESET}"
    _enable_shell_autocompletion
    echo -e "${COLOR_BLUE}  └─ 拉取 Kubernetes 镜像...${COLOR_RESET}"
    _kubernetes_images_pull
    echo -e "${COLOR_GREEN}✅ Kubernetes 组件安装完成${COLOR_RESET}"
  fi

  # 初始化 Kubernetes 集群
  if [[ $install_mode == true || $cluster_install == true ]]; then
    echo -e "${COLOR_BLUE}🚀 [4/8] 初始化 Kubernetes 集群...${COLOR_RESET}"
    _kubernetes_init
    
    # 单节点模式移除污点
    if [[ $taint_master == true || $standalone == true ]]; then
      echo -e "${COLOR_BLUE}🔓 移除主节点污点（允许调度 Pod）...${COLOR_RESET}"
      _kubernetes_taint
    fi
    echo -e "${COLOR_GREEN}✅ Kubernetes 集群初始化完成${COLOR_RESET}"
  fi

  # 网络插件安装
  if [[ $calico_install == true ]]; then
    echo -e "${COLOR_BLUE}🌐 [5/8] 安装 Calico 网络插件...${COLOR_RESET}"
    _calico_install
    echo -e "${COLOR_GREEN}✅ Calico 网络插件安装完成${COLOR_RESET}"
  elif [[ $flannel_install == true ]]; then
    echo -e "${COLOR_BLUE}🌐 [5/8] 安装 Flannel 网络插件...${COLOR_RESET}"
    _flannel_install
    echo -e "${COLOR_GREEN}✅ Flannel 网络插件安装完成${COLOR_RESET}"
  fi

  # Ingress 控制器安装
  if [[ $ingress_nginx_install == true ]]; then
    echo -e "${COLOR_BLUE}🌍 安装 Ingress Nginx 控制器...${COLOR_RESET}"
    _ingress_nginx_install
    
    # 自动启用主机网络模式（生产环境推荐）
    echo -e "${COLOR_BLUE}🔧 自动启用 Ingress Nginx 主机网络模式...${COLOR_RESET}"
    _ingress_nginx_host_network
    echo -e "${COLOR_GREEN}✅ 已启用主机网络模式${COLOR_RESET}"
  fi

  # Metrics Server 安装
  if [[ $metrics_server_install == true ]]; then
    echo -e "${COLOR_BLUE}📊 安装 Metrics Server...${COLOR_RESET}"
    _metrics_server_install
  fi

  # Helm 安装
  if [[ $helm_install == true ]]; then
    echo -e "${COLOR_BLUE}⛵ 安装 Helm...${COLOR_RESET}"
    _helm_install
  fi

  # Dashboard 安装
  if [[ $dashboard_install == true ]]; then
    if ! command -v helm &> /dev/null; then
      echo -e "${COLOR_YELLOW}Dashboard 需要 Helm，正在安装 Helm...${COLOR_RESET}"
      _helm_install
    fi
    echo -e "${COLOR_BLUE}🎛️ 安装 Kubernetes Dashboard...${COLOR_RESET}"
    _helm_install_kubernetes_dashboard
  fi

  # Prometheus 监控栈安装
  if [[ $prometheus_install == true ]]; then
    echo -e "${COLOR_BLUE}📈 安装 Prometheus 监控栈...${COLOR_RESET}"
    _kube_prometheus_install
    _kube_prometheus_node_port
    _kube_prometheus_remote_access
  fi

  # VIP 高可用配置
  if [[ $availability_vip_install == true ]]; then
    echo -e "${COLOR_BLUE}🔧 [6/8] 配置 Master VIP 高可用...${COLOR_RESET}"
    _availability_vip_install
    echo -e "${COLOR_GREEN}✅ Master VIP 高可用配置完成${COLOR_RESET}"
  fi

  if [[ $availability_worker_vip_install == true ]]; then
    echo -e "${COLOR_BLUE}🔧 [7/8] 配置 Worker VIP 高可用...${COLOR_RESET}"
    _availability_worker_vip_install
    echo -e "${COLOR_GREEN}✅ Worker VIP 高可用配置完成${COLOR_RESET}"
  fi

  # ETCD 相关操作
  if [[ $etcd_install == true ]]; then
    echo -e "${COLOR_BLUE}🗄️ 安装 ETCD 集群...${COLOR_RESET}"
    _etcd_binary_install
  elif [[ $etcd_join == true ]]; then
    echo -e "${COLOR_BLUE}🔗 加入 ETCD 集群...${COLOR_RESET}"
    _etcd_binary_join
  fi

  # 显示加入命令
  if [[ $print_join_command == true ]]; then
    echo -e "${COLOR_BLUE}📋 生成节点加入命令...${COLOR_RESET}"
    _print_join_command
  fi

  # 安装完成提示
  if [[ $install_mode == true || $cluster_install == true ]]; then
    echo -e "${COLOR_BLUE}🎉 [8/8] 部署完成，显示后续操作指引...${COLOR_RESET}"
    _kubernetes_init_congrats
  fi

  echo -e "${COLOR_GREEN}🎉 全自动部署脚本执行完成！${COLOR_RESET}"
  echo -e "${COLOR_BLUE}📋 部署总结：${COLOR_RESET}"
  [[ $install_mode == true || $cluster_install == true ]] && echo -e "${COLOR_GREEN}  ✅ Kubernetes 集群已初始化${COLOR_RESET}"
  [[ $availability_vip_install == true ]] && echo -e "${COLOR_GREEN}  ✅ Master VIP 高可用已配置${COLOR_RESET}"
  [[ $calico_install == true ]] && echo -e "${COLOR_GREEN}  ✅ Calico 网络插件已安装${COLOR_RESET}"
  [[ $flannel_install == true ]] && echo -e "${COLOR_GREEN}  ✅ Flannel 网络插件已安装${COLOR_RESET}"
}

# ================================================================
# 脚本入口点
# ================================================================

echo -e "${COLOR_BLUE}🚀 Kubernetes 自动化部署脚本启动中...${COLOR_RESET}"
echo -e "${COLOR_BLUE}📋 接收到 $# 个参数${COLOR_RESET}"

# 解析参数
echo -e "${COLOR_BLUE}🔧 解析命令行参数...${COLOR_RESET}"
_parse_args "$@"

# 验证参数
echo -e "${COLOR_BLUE}✅ 验证参数配置...${COLOR_RESET}"
_validate_args

# 执行主逻辑
echo -e "${COLOR_BLUE}🚀 开始执行主要部署逻辑...${COLOR_RESET}"
_main
