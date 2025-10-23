#!/bin/bash

# Novatra 工作团队
# GitHub 仓库: https://github.com/Novatra-ai/Novatra-Cloud-Native
# GitHub Issues: 问题反馈
# Email: novatra.ai@novatra.cn
# QQ群: 1061184149
#
# 如果发现脚本不能正常运行，可尝试执行：sed -i 's/\r$//' k8s.sh
#
# 代码格式使用：
# https://github.com/mvdan/sh
# 代码格式化命令：
# shfmt -l -w -i 2 k8s.sh

# 一旦有命令返回非零值，立即退出脚本
set -e

# 颜色定义
readonly COLOR_BLUE='\033[34m'
readonly COLOR_GREEN='\033[92m'
readonly COLOR_RED='\033[31m'
readonly COLOR_RESET='\033[0m'
readonly COLOR_YELLOW='\033[93m'

# 定义表情
readonly EMOJI_CONGRATS="\U0001F389"
readonly EMOJI_FAILURE="\U0001F61E"

# 文档链接
readonly DOCS_LINK=https://github.com/Novatra-ai/Novatra-Cloud-Native

# 查看系统类型、版本、内核
hostnamectl || true

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
readonly os_type=$(grep -w "ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
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
readonly os_version=$(grep -w "VERSION_ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
echo -e "${COLOR_BLUE}系统版本: ${COLOR_GREEN}$os_version${COLOR_RESET}"

readonly kylin_release_id=$(grep -w "KYLIN_RELEASE_ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
if [[ $kylin_release_id ]]; then
  echo -e "${COLOR_BLUE}银河麒麟代码版本: ${COLOR_GREEN}$kylin_release_id${COLOR_RESET}"
fi

# 代码版本
readonly code_name=$(grep -w "VERSION_CODENAME" /etc/os-release | cut -d'=' -f2 | tr -d '"')
if [[ $code_name ]]; then
  echo -e "${COLOR_BLUE}代码版本: ${COLOR_GREEN}$code_name${COLOR_RESET}"
fi

if [[ $os_type == 'centos' ]]; then
  readonly centos_os_version=$(cat /etc/redhat-release | awk '{print $4}')
  echo -e "${COLOR_BLUE}CentOS 系统具体版本: ${COLOR_GREEN}$centos_os_version${COLOR_RESET}"
fi

if [[ -e "/etc/debian_version" ]]; then
  readonly debian_os_version=$(cat /etc/debian_version)
  echo -e "${COLOR_BLUE}Debian 系统具体版本: ${COLOR_GREEN}$debian_os_version${COLOR_RESET}"
fi

if [[ $os_type == 'uos' ]]; then
  readonly uos_minor_version=$(grep -w "MinorVersion" /etc/os-version | cut -d'=' -f2 | tr -d '"')
  readonly uos_edition_name=$(grep -w "EditionName" /etc/os-version | cut -d'=' -f2 | tr -d '"' | head -n 1)
  echo -e "${COLOR_BLUE}UOS 系统具体版本: ${COLOR_GREEN}$uos_minor_version$uos_edition_name${COLOR_RESET}"
fi

# 输出 CPU 架构
readonly cpu_arch=$(uname -m)
if [[ $cpu_arch == 'aarch64' ]]; then
  readonly cpu_platform='arm64'
elif [[ $cpu_arch == 'x86_64' ]]; then
  readonly cpu_platform='amd64'
else
  readonly cpu_platform=$cpu_arch
fi
echo -e "${COLOR_BLUE}CPU 架构: ${COLOR_GREEN}$cpu_arch ($cpu_platform)${COLOR_RESET}"

# apt 锁超时时间
dpkg_lock_timeout=120

# Kubernetes 具体版本，包含: 主版本号、次版本号、修正版本号
kubernetes_version=v1.34.1
# Kubernetes 具体版本后缀
kubernetes_version_suffix=1.1
# Kubernetes 仓库
kubernetes_mirrors=("https://mirrors.aliyun.com/kubernetes-new/core/stable" "https://mirrors.tuna.tsinghua.edu.cn/kubernetes/core:/stable:" "https://pkgs.k8s.io/core:/stable:")
# Kubernetes 仓库: 默认仓库，取第一个
kubernetes_baseurl=${kubernetes_mirrors[0]}
# Kubernetes 镜像仓库
kubernetes_images_mirrors=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s" "registry.aliyuncs.com/google_containers" "registry.k8s.io")
# Kubernetes 镜像仓库: 默认仓库，取第一个
kubernetes_images=${kubernetes_images_mirrors[0]}
# pause 镜像
pause_image=${kubernetes_images_mirrors[0]}/pause
# 自定义 conntrack 安装包，仅在少数系统中使用，如：deepin 23
conntrack_deb=https://mirrors.aliyun.com/debian/pool/main/c/conntrack-tools/conntrack_1.4.6-2_$cpu_platform.deb

# Docker 仓库
docker_mirrors=("https://mirrors.aliyun.com/docker-ce/linux" "https://mirrors.cloud.tencent.com/docker-ce/linux" "https://download.docker.com/linux")
# Docker 仓库: 默认仓库，取第一个
docker_baseurl=${docker_mirrors[0]}
# 自定义 container-selinux 安装包，仅在少数系统中使用，如：OpenEuler 20.03
container_selinux_rpm=https://mirrors.aliyun.com/centos-altarch/7.9.2009/extras/i386/Packages/container-selinux-2.107-3.el7.noarch.rpm
# 自定义 containerd.io 安装包，仅在少数系统中使用，如：UOS
containerd_io_rpm=https://mirrors.aliyun.com/docker-ce/linux/centos/8/$cpu_arch/stable/Packages/containerd.io-1.6.32-3.1.el8.$cpu_arch.rpm
# Docker 仓库类型
docker_repo_name=$os_type

# containerd 根路径
containerd_root=/var/lib/containerd
# containerd 运行状态路径
containerd_state=/run/containerd

case "$os_type" in
anolis | almalinux | openEuler | rocky | uos)
  docker_repo_name='centos'
  ;;
kylin | openkylin | Deepin | deepin)
  docker_repo_name='debian'
  ;;
*) ;;
esac

availability_haproxy_username="admin"
availability_haproxy_password=novatra.com.cn
availability_haproxy_kube_apiserver=9443

haproxy_image=crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/haproxy-debian
haproxy_version=3.2-dev12-$cpu_platform

keepalived_image=crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/keepalived
keepalived_version=2025-10-17-$cpu_platform

calico_mirrors=("https://raw.githubusercontent.com/projectcalico/calico/refs/tags" "https://mirrors.aliyun.com/calico")
calico_mirror=${calico_mirrors[0]}
calico_version=v3.29.3
calico_node_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/calico-node" "docker.io/calico/node")
calico_node_image=${calico_node_images[0]}
calico_cni_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/calico-cni" "docker.io/calico/cni")
calico_cni_image=${calico_cni_images[0]}
calico_kube_controllers_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/calico-kube-controllers" "docker.io/calico/kube-controllers")
calico_kube_controllers_image=${calico_kube_controllers_images[0]}

ingress_nginx_mirrors=("https://raw.githubusercontent.com/kubernetes/ingress-nginx/refs/tags" "https://mirrors.aliyun.com/ingress-nginx")
ingress_nginx_mirror=${ingress_nginx_mirrors[0]}
ingress_nginx_version=v1.12.1
ingress_nginx_controller_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/ingress-nginx-controller" "registry.k8s.io/ingress-nginx/controller")
ingress_nginx_controller_image=${ingress_nginx_controller_images[0]}
ingress_nginx_kube_webhook_certgen_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/ingress-nginx-kube-webhook-certgen" "registry.k8s.io/ingress-nginx/kube-webhook-certgen")
ingress_nginx_kube_webhook_certgen_image=${ingress_nginx_kube_webhook_certgen_images[0]}

metrics_server_version=v0.7.2
metrics_server_mirrors=("https://github.com/kubernetes-sigs/metrics-server/releases/download" "https://mirrors.aliyun.com/metrics-server")
metrics_server_mirror=${metrics_server_mirrors[0]}
metrics_server_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/metrics-server" "registry.k8s.io/metrics-server/metrics-server")
metrics_server_image=${metrics_server_images[0]}

helm_version=v3.16.3
# https://mirrors.huaweicloud.com/helm/v3.16.3/helm-v3.16.3-linux-amd64.tar.gz
# https://mirrors.huaweicloud.com/helm/v3.16.3/helm-v3.16.3-linux-arm64.tar.gz
# https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
# https://get.helm.sh/helm-v3.16.3-linux-arm64.tar.gz
helm_mirrors=("https://mirrors.huaweicloud.com/helm" "https://get.helm.sh")

kubernetes_dashboard_charts=("https://kubernetes.github.io/dashboard" "https://charts.kubernetes.io")
kubernetes_dashboard_chart=${kubernetes_dashboard_charts[0]}
kubernetes_dashboard_version=7.10.4
kubernetes_dashboard_auth_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/kubernetesui-dashboard-auth" "docker.io/kubernetesui/dashboard-auth")
kubernetes_dashboard_auth_image=${kubernetes_dashboard_auth_images[0]}
kubernetes_dashboard_api_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/kubernetesui-dashboard-api" "docker.io/kubernetesui/dashboard-api")
kubernetes_dashboard_api_image=${kubernetes_dashboard_api_images[0]}
kubernetes_dashboard_web_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/kubernetesui-dashboard-web" "docker.io/kubernetesui/dashboard-web")
kubernetes_dashboard_web_image=${kubernetes_dashboard_web_images[0]}
kubernetes_dashboard_metrics_scraper_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/kubernetesui-dashboard-metrics-scraper" "docker.io/kubernetesui/dashboard-metrics-scraper")
kubernetes_dashboard_metrics_scraper_image=${kubernetes_dashboard_metrics_scraper_images[0]}
kubernetes_dashboard_kong_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/kong" "docker.io/library/kong")
kubernetes_dashboard_kong_image=${kubernetes_dashboard_kong_images[0]}
kubernetes_dashboard_ingress_enabled=true
kubernetes_dashboard_ingress_host=kubernetes.dashboard.novatra.cn

kube_prometheus_version=v0.14.0
kube_prometheus_mirrors=("https://github.com/prometheus-operator/kube-prometheus/archive/refs/tags" "https://mirrors.aliyun.com/prometheus")
kube_prometheus_mirror=${kube_prometheus_mirrors[0]}
grafana_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/grafana" "grafana/grafana")
grafana_image=${grafana_images[0]}
kube_state_metrics_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/kube-state-metrics" "registry.k8s.io/kube-state-metrics/kube-state-metrics" "k8s.gcr.io/kube-state-metrics/kube-state-metrics")
kube_state_metrics_image=${kube_state_metrics_images[0]}
prometheus_adapter_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/prometheus-adapter" "registry.k8s.io/prometheus-adapter/prometheus-adapter" "k8s.gcr.io/prometheus-adapter/prometheus-adapter")
prometheus_adapter_image=${prometheus_adapter_images[0]}
jimmidyson_configmap_reload_images=("crpi-dlzxssbr77e6ioyd.cn-shanghai.personal.cr.aliyuncs.com/novatra-k8s/configmap-reload" "jimmidyson/configmap-reload")
jimmidyson_configmap_reload_image=${jimmidyson_configmap_reload_images[0]}
prometheus_k8s_web_9090_node_port=30790
prometheus_k8s_reloader_web_8080_node_port=30780
alertmanager_main_web_9093_node_port=30893
alertmanager_main_reloader_web_8080_node_port=30880
grafana_http_3000_node_port=30900

# openssl 证书配置
dn_c=CN
dn_st=Shandong
dn_l=Qingdao
dn_o=Novatra
dn_ou=Novatra
dn_cn=$(hostname -I | awk '{print $1}')

etcd_version=v3.5.19
etcd_mirrors=("https://mirrors.huaweicloud.com/etcd" "https://storage.googleapis.com/etcd" "https://github.com/etcd-io/etcd/releases/download")
etcd_mirror=${etcd_mirrors[0]}
etcd_client_port_2379=2379
etcd_peer_port_2380=2380
etcd_join_port=22

kernel_version=$(uname -r)
kernel_major_version=$(echo "$kernel_version" | cut -d. -f1)
kernel_minor_version=$(echo "$kernel_version" | cut -d. -f2)
echo -e "${COLOR_BLUE}系统内核版本: ${COLOR_GREEN}$kernel_version${COLOR_RESET}"

if [[ $kernel_major_version -le 4 && $kernel_minor_version -lt 19 ]]; then
  # $(uname -r) < 4.19
  echo -e "${COLOR_BLUE}可以安装 Kubernetes: ${COLOR_GREEN}v1.24.x ${COLOR_RESET}到${COLOR_GREEN} v1.31.x${COLOR_RESET}"
  echo -e "${COLOR_YELLOW}无法安装 Kubernetes v1.32.x +: ${COLOR_GREEN}v1.32.x + 推荐最低内核为 4.19${COLOR_RESET}"
else
  echo -e "${COLOR_BLUE}可以安装 Kubernetes: ${COLOR_GREEN}v1.24.x ${COLOR_RESET}到${COLOR_GREEN} v1.34.x +${COLOR_RESET}"
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
  echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
  exit 1
  ;;
esac

_k8s_support_kernel() {
  if [[ $kernel_major_version -le 4 && $kernel_minor_version -lt 19 ]]; then
    # $(uname -r) < 4.19

    kubernetes_minor_version=$(echo $kubernetes_version | cut -d. -f2)
    if [[ $kubernetes_minor_version -ge 32 ]]; then
      # $kubernetes_version >= v1.32.0

      echo -e "${COLOR_RED}无法安装 Kubernetes $kubernetes_version，停止执行: ${COLOR_GREEN}v1.32.x + 推荐最低内核为 4.19${COLOR_RESET}"
      exit 1
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
    sudo curl -fsSL $docker_baseurl/$docker_repo_name/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $docker_baseurl/$docker_repo_name \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
    exit 1

  fi

  sudo systemctl start containerd
  sudo systemctl status containerd -l --no-pager
  sudo systemctl enable containerd

}

# 容器运行时
# https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/
# https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
      sudo curl -fsSL $kubernetes_baseurl/$kubernetes_repo_version/deb/Release.key -o /etc/apt/keyrings/kubernetes.asc
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
      curl -o "$conntrack_name" "$conntrack_deb"
      dpkg -i "$conntrack_name"
    fi

    sudo apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y kubelet="$version"-$kubernetes_version_suffix kubeadm="$version"-$kubernetes_version_suffix kubectl="$version"-$kubernetes_version_suffix

  else

    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}安装 Kubernetes${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
    exit 1

  fi
}

_kubernetes_images_pull() {
  kubeadm config images list --image-repository="$kubernetes_images" --kubernetes-version="$kubernetes_version"
  kubeadm config images pull --image-repository="$kubernetes_images" --kubernetes-version="$kubernetes_version"
}

# 启用 IPv4 数据包转发
# https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/
# https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/
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

    # https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/#install-and-configure-prerequisites

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

    # https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/#install-and-configure-prerequisites

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
  echo -e "${COLOR_BLUE}1. 执行命令刷新环境变量:"
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
    echo -e "${COLOR_RED}请阅读文档，查看配置: ${COLOR_GREEN}${DOCS_LINK}${COLOR_RESET}"
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
# https://kubernetes.io/zh-cn/docs/tasks/tools/install-kubectl-linux/#optional-kubectl-configurations
# https://kubernetes.io/zh-cn/docs/tasks/tools/install-kubectl-linux/#optional-kubectl-configurations
_enable_shell_autocompletion() {

  _bash_completion

  if [[ $package_type == 'yum' || $package_type == 'zypper' || $package_type == 'apt' ]]; then

    sudo mkdir -p /etc/bash_completion.d
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl >/dev/null
    sudo chmod a+r /etc/bash_completion.d/kubectl
    source /etc/bash_completion.d/kubectl

  else

    echo -e "${COLOR_RED}不支持的发行版: ${COLOR_GREEN}$os_type ${COLOR_RED}启用 shell 自动补全功能${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看已支持的发行版: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
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
      echo -e "${COLOR_RED}请阅读文档，查看网卡配置 interface-name: ${COLOR_GREEN}${DOCS_LINK}${COLOR_RESET}"
      exit 1
    fi
  fi
}

_calico_install() {
  if ! [[ $calico_url ]]; then
    calico_url=$calico_mirror/$calico_version/manifests/calico.yaml
  fi
  echo -e "${COLOR_BLUE}calico manifests url: ${COLOR_GREEN}$calico_url${COLOR_RESET}"

  calico_local_path=calico.yaml
  if [[ $calico_url =~ ^https?:// ]]; then
    curl -k -o $calico_local_path $calico_url
  else
    calico_local_path=$calico_url
  fi

  if grep -q "interface=" "$calico_local_path"; then
    echo -e "${COLOR_BLUE}已配置 calico 使用的网卡，脚本跳过网卡配置${COLOR_RESET}"
  else
    _interface_name

    sed -i '/k8s,bgp/a \            - name: IP_AUTODETECTION_METHOD\n              value: "interface=INTERFACE_NAME"' $calico_local_path
    sed -i "s#INTERFACE_NAME#$interface_name#g" $calico_local_path
  fi

  sed -i "s#${calico_node_images[-1]}#$calico_node_image#g" $calico_local_path
  sed -i "s#${calico_cni_images[-1]}#$calico_cni_image#g" $calico_local_path
  sed -i "s#${calico_kube_controllers_images[-1]}#$calico_kube_controllers_image#g" $calico_local_path

  kubectl apply -f $calico_local_path
  kubectl get pod -A -o wide
  if [[ $cluster != true ]]; then
    kubectl wait --for=condition=Ready --all pods -A --timeout=300s || true
  fi
}

_ingress_nginx_install() {
  if ! [[ $ingress_nginx_url ]]; then
    ingress_nginx_url=$ingress_nginx_mirror/controller-$ingress_nginx_version/deploy/static/provider/cloud/deploy.yaml
  fi
  echo -e "${COLOR_BLUE}ingress nginx manifests url: ${COLOR_GREEN}$ingress_nginx_url${COLOR_RESET}"

  ingress_nginx_local_path=ingress_nginx.yaml
  if [[ $ingress_nginx_url =~ ^https?:// ]]; then
    curl -k -o $ingress_nginx_local_path $ingress_nginx_url
  else
    ingress_nginx_local_path=$ingress_nginx_url
  fi

  sudo sed -i 's/@.*$//' $ingress_nginx_local_path
  sudo sed -i "s#${ingress_nginx_controller_images[-1]}#$ingress_nginx_controller_image#g" $ingress_nginx_local_path
  sudo sed -i "s#${ingress_nginx_kube_webhook_certgen_images[-1]}#$ingress_nginx_kube_webhook_certgen_image#g" $ingress_nginx_local_path

  kubectl apply -f $ingress_nginx_local_path
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
  echo -e "${COLOR_BLUE}metrics server manifests url: ${COLOR_GREEN}$metrics_server_url${COLOR_RESET}"

  metrics_server_local_path=metrics_server.yaml
  if [[ $metrics_server_url =~ ^https?:// ]]; then
    curl -k -o $metrics_server_local_path $metrics_server_url
  else
    metrics_server_local_path=$metrics_server_url
  fi

  sudo sed -i "s#${metrics_server_images[-1]}#$metrics_server_image#g" $metrics_server_local_path

  if [[ $metrics_server_secure_tls != true ]]; then
    sed -i '/- args:/a \ \ \ \ \ \ \ \ - --kubelet-insecure-tls' $metrics_server_local_path
  fi

  kubectl apply -f $metrics_server_local_path
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
  echo -e "${COLOR_BLUE}helm url: ${COLOR_GREEN}$helm_url${COLOR_RESET}"

  helm_local_path=helm-$helm_version-linux-$cpu_platform.tar.gz
  helm_local_folder=helm-$helm_version-linux-$cpu_platform
  if [[ $helm_url =~ ^https?:// ]]; then
    curl -k -o $helm_local_path $helm_url
  else
    helm_local_path=$helm_url
  fi

  _tar_install

  mkdir -p $helm_local_folder
  tar -zxvf $helm_local_path --strip-components=1 -C $helm_local_folder

  $helm_local_folder/helm version
  cp $helm_local_folder/helm /usr/local/bin/helm
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
  echo -e "${COLOR_BLUE}使用: ${COLOR_GREEN}kubectl -n kubernetes-dashboard get secret admin-user -o jsonpath={".data.token"} | base64 -d ${COLOR_BLUE}获取长期 token${COLOR_RESET}"
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
  curl -o "$kube_prometheus_basename" "$kube_prometheus_url"
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

  curl -L "${etcd_url}" -o etcd-${etcd_version}-linux-$cpu_platform.tar.gz
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
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://$etcd_current_ip:$etcd_peer_port_2380

# 集群名称
ETCD_INITIAL_CLUSTER_TOKEN=etcd-cluster
# 集群各节点endpoint列表
ETCD_INITIAL_CLUSTER="$etcd_initial_cluster"
# 初始集群状态
ETCD_INITIAL_CLUSTER_STATE=new

EOF

  cat /etc/etcd/etcd.conf

  cat >/usr/lib/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target

EOF

  cat /usr/lib/systemd/system/etcd.service

  systemctl daemon-reload
  systemctl enable etcd.service
  systemctl restart etcd.service
  systemctl status etcd.service -l --no-pager

  local test_etcd
  if ! [[ $etcd_ips ]]; then
    test_etcd=true
  fi
  if [[ $etcd_ips_length == 1 ]]; then
    test_etcd=true
  fi
  if [[ $test_etcd == true ]]; then
    /usr/local/bin/etcdctl --cacert=/etc/etcd/pki/ca.crt --cert=/etc/etcd/pki/peer.crt --key=/etc/etcd/pki/peer.key --endpoints=https://"$etcd_current_ip":$etcd_client_port_2379 endpoint health
  fi
}

_etcd_binary_join() {

  _firewalld_stop

  if ! [[ $etcd_current_ip ]]; then
    etcd_current_ip=$(hostname -I | awk '{print $1}')
  fi

  if [[ -f /root/.ssh/id_rsa ]]; then
    mv /root/.ssh/id_rsa /root/.ssh/id_rsa.$(date +%Y%m%d%H%M%S)
  fi
  if [[ -f /root/.ssh/id_rsa.pub ]]; then
    mv /root/.ssh/id_rsa.pub /root/.ssh/id_rsa.pub.$(date +%Y%m%d%H%M%S)
  fi

  ssh-keygen -t rsa -f /root/.ssh/id_rsa -N '' -q
  ssh-keyscan -H $etcd_join_ip -P $etcd_join_port >>/root/.ssh/known_hosts

  if [[ $etcd_join_password ]]; then
    if ! command -v 'sshpass' &>/dev/null; then
      if [[ $package_type == 'yum' ]]; then
        sudo yum install -y sshpass
      else
        apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y sshpass
      fi
    fi

    sshpass -p $etcd_join_password scp -P $etcd_join_port /root/.ssh/id_rsa.pub root@$etcd_join_ip:/root/.ssh/authorized_keys
  else

    scp -P $etcd_join_port /root/.ssh/id_rsa.pub root@$etcd_join_ip:/root/.ssh/authorized_keys
  fi

  mkdir -p /etc/etcd/pki

  scp -P $etcd_join_port root@$etcd_join_ip:/usr/local/bin/etcd /usr/local/bin/
  scp -P $etcd_join_port root@$etcd_join_ip:/usr/local/bin/etcdctl /usr/local/bin/
  scp -P $etcd_join_port root@$etcd_join_ip:/usr/local/bin/etcdutl /usr/local/bin/

  scp -P $etcd_join_port root@$etcd_join_ip:/etc/etcd/pki/ca.key /etc/etcd/pki/
  scp -P $etcd_join_port root@$etcd_join_ip:/etc/etcd/pki/ca.crt /etc/etcd/pki/

  scp -P $etcd_join_port root@$etcd_join_ip:/usr/lib/systemd/system/etcd.service /usr/lib/systemd/system/

  scp -P $etcd_join_port root@$etcd_join_ip:/etc/etcd/pki/server.crt /etc/etcd/pki/
  scp -P $etcd_join_port root@$etcd_join_ip:/etc/etcd/pki/server.key /etc/etcd/pki/
  scp -P $etcd_join_port root@$etcd_join_ip:/etc/etcd/pki/peer.crt /etc/etcd/pki/
  scp -P $etcd_join_port root@$etcd_join_ip:/etc/etcd/pki/peer.key /etc/etcd/pki/

  scp -P $etcd_join_port root@$etcd_join_ip:/etc/etcd/etcd.conf /etc/etcd/

  source /etc/etcd/etcd.conf

  echo $ETCD_INITIAL_CLUSTER

  etcd_from_name=$ETCD_NAME
  echo $etcd_from_name

  etcd_current_ip=$(hostname -I | awk '{print $1}')
  echo $etcd_current_ip

  IFS=',' read -ra etcd_nodes <<<"$ETCD_INITIAL_CLUSTER"
  for etcd_node in "${etcd_nodes[@]}"; do
    echo $etcd_node
    if [[ $etcd_node =~ $etcd_current_ip ]]; then
      node_name=$(echo $etcd_node | awk -F'=' '{print $1}')
      break
    fi
  done

  echo $node_name

  sudo sed -i "s#ETCD_NAME=$etcd_from_name#ETCD_NAME=$node_name#g" /etc/etcd/etcd.conf

  sudo sed -i "s#ETCD_LISTEN_CLIENT_URLS=https://$etcd_join_ip:$etcd_client_port_2379#ETCD_LISTEN_CLIENT_URLS=https://$etcd_current_ip:$etcd_client_port_2379#g" /etc/etcd/etcd.conf
  sudo sed -i "s#ETCD_ADVERTISE_CLIENT_URLS=https://$etcd_join_ip:$etcd_client_port_2379#ETCD_ADVERTISE_CLIENT_URLS=https://$etcd_current_ip:$etcd_client_port_2379#g" /etc/etcd/etcd.conf

  sudo sed -i "s#ETCD_LISTEN_PEER_URLS=https://$etcd_join_ip:$etcd_peer_port_2380#ETCD_LISTEN_PEER_URLS=https://$etcd_current_ip:$etcd_peer_port_2380#g" /etc/etcd/etcd.conf
  sudo sed -i "s#ETCD_INITIAL_ADVERTISE_PEER_URLS=https://$etcd_join_ip:$etcd_peer_port_2380#ETCD_INITIAL_ADVERTISE_PEER_URLS=https://$etcd_current_ip:$etcd_peer_port_2380#g" /etc/etcd/etcd.conf

  /usr/local/bin/etcd --version
  /usr/local/bin/etcdctl version
  /usr/local/bin/etcdutl version

  systemctl daemon-reload
  systemctl enable etcd.service
  systemctl restart etcd.service
  systemctl status etcd.service -l --no-pager
}

_check_availability_master() {
  local master=$1

  echo -e "${COLOR_BLUE}检查/处理 主节点地址 ${master} 开始${COLOR_RESET}"

  # 使用 @ 符号分割主机名和地址
  IFS='@' read -ra parts <<<"$master"
  local name="${parts[0]}"
  local address="${parts[1]}"

  # 使用冒号分割 IP 地址和端口
  IFS=':' read -ra ADDR <<<"$address"
  local ip="${ADDR[0]}"
  local port="${ADDR[1]}"

  # 检查IP地址是否合法
  if ! echo "$ip" | grep -P -q "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"; then
    echo -e "${COLOR_RED}检查 ${master} 时发现，IP地址 ${ip} 不合法，退出程序${COLOR_RESET}"
    exit 1
  fi

  if ! [[ $port =~ ^[0-9]+$ ]]; then
    echo -e "${COLOR_RED}检查 ${master} 时发现，端口 ${port} 必须是整数，退出程序${COLOR_RESET}"
    exit 1
  fi

  # 检查端口是否在合法范围内（1到65535）
  if ((port < 1 || port > 65535)); then
    echo -e "${COLOR_RED}检查 ${master} 时发现，端口 ${port} 不合法，退出程序${COLOR_RESET}"
    exit 1
  fi

  # 将解析结果存入数组
  availability_master_array+=("$name $address")

  echo -e "${COLOR_BLUE}检查/处理 主节点地址 ${master} 结束${COLOR_RESET}"
}

_availability_haproxy_install() {

  local container_name=k8s-haproxy

  if docker ps -a --format "{{.Names}}" | grep -Eq "^$container_name$"; then
    echo -e "${COLOR_YELLOW}$container_name 容器已存在，不会重复创建${COLOR_RESET}"
  else

    mkdir -p /etc/haproxy/

    cat >/etc/haproxy/haproxy.cfg <<EOF
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4096
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats

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

frontend  kube-apiserver
    mode                 tcp
    bind                 *:$availability_haproxy_kube_apiserver
    option               tcplog
    default_backend      kube-apiserver

listen stats
    mode                 http
    bind                 *:8888
    stats auth           $availability_haproxy_username:$availability_haproxy_password
    stats refresh        5s
    stats realm          HAProxy\ Statistics
    stats uri            /stats
    log                  127.0.0.1 local3 err

backend kube-apiserver
    mode        tcp
    balance     roundrobin
EOF

    cat /etc/haproxy/haproxy.cfg

    # 遍历数组
    for master in "${availability_master_array[@]}"; do
      echo "    server  $master check" >>/etc/haproxy/haproxy.cfg
    done

    echo "" >>/etc/haproxy/haproxy.cfg

    cat /etc/haproxy/haproxy.cfg

    docker run \
      -d \
      --name k8s-haproxy \
      --net=host \
      --restart=always \
      -v /etc/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
      "${haproxy_image}:${haproxy_version}"
  fi
}

_check_availability_vip_no() {
  local no=$1

  # 验证 AVAILABILITY_VIP_NO 是否为整数
  if ! [[ $no =~ ^[0-9]+$ ]]; then
    echo -e "${COLOR_RED}VIP 编号 必须是整数，退出程序${COLOR_RESET}"
    exit 1
  fi

  if [[ $no == 1 ]]; then
    availability_vip_state=MASTER
  else
    availability_vip_state=BACKUP
  fi

}

_check_availability_vip() {
  local ip=$1

  if ! echo "$ip" | grep -P -q "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"; then
    echo -e "${COLOR_RED}kubernetes 高可用 VIP: ${ip} 不是一个有效 IP，退出程序${COLOR_RESET}"
    exit 1
  fi
}

_availability_keepalived_install() {

  local container_name=k8s-keepalived

  if docker ps -a --format "{{.Names}}" | grep -Eq "^$container_name$"; then
    echo -e "${COLOR_YELLOW}$container_name 容器已存在，不会重复创建${COLOR_RESET}"
  else

    # 网卡
    _interface_name

    mkdir -p /etc/keepalived/

    cat >/etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
   router_id LVS_$availability_vip_no
}

vrrp_script checkhaproxy
{
    script "/usr/bin/check-haproxy.sh"
    interval 2
    weight -30
}

vrrp_instance VI_1 {
    state $availability_vip_state
    interface $interface_name
    virtual_router_id 51
    priority 100
    advert_int 1

    virtual_ipaddress {
        $availability_vip/24 dev $interface_name
    }

    authentication {
        auth_type PASS
        auth_pass password
    }

    track_script {
        checkhaproxy
    }
}

EOF

    cat >/etc/keepalived/check-haproxy.sh <<EOF
#!/bin/bash

count=\`netstat -apn | grep $availability_haproxy_kube_apiserver | wc -l\`

if [ $count -gt 0 ]; then
    exit 0
else
    exit 1
fi

EOF

    cat /etc/keepalived/keepalived.conf
    cat /etc/keepalived/check-haproxy.sh

    docker run \
      -d \
      --name k8s-keepalived \
      --restart=always \
      --net=host \
      --cap-add=NET_ADMIN \
      --cap-add=NET_BROADCAST \
      --cap-add=NET_RAW \
      -v /etc/keepalived/keepalived.conf:/container/service/keepalived/assets/keepalived.conf \
      -v /etc/keepalived/check-haproxy.sh:/usr/bin/check-haproxy.sh \
      "${keepalived_image}:${keepalived_version}" \
      --copy-service
  fi

}

_availability_vip_install() {
  _availability_haproxy_install
  _availability_keepalived_install
}

while [[ $# -gt 0 ]]; do
  case "$1" in

  config=* | -config=* | --config=*)
    config="${1#*=}"
    echo -e "${COLOR_BLUE}启用了配置文件 ${COLOR_GREEN}$config${COLOR_RESET}"
    source $config
    ;;

  standalone | -standalone | --standalone)
    standalone=true
    ;;

  cluster | -cluster | --cluster)
    cluster=true
    ;;

  node | -node | --node)
    node=true
    ;;

  dpkg-lock-timeout=* | -dpkg-lock-timeout=* | --dpkg-lock-timeout=*)
    dpkg_lock_timeout="${1#*=}"
    ;;

  firewalld-stop | -firewalld-stop | --firewalld-stop)
    firewalld_stop=true
    ;;

  selinux-disabled | -selinux-disabled | --selinux-disabled)
    selinux_disabled=true
    ;;

  bash-completion | -bash-completion | --bash-completion)
    bash_completion=true
    ;;

  kubernetes-repo | -kubernetes-repo | --kubernetes-repo)
    kubernetes_repo=true
    ;;

  kubernetes-repo-type=* | -kubernetes-repo-type=* | --kubernetes-repo-type=*)
    kubernetes_repo_type="${1#*=}"
    case "$kubernetes_repo_type" in
    aliyun)
      kubernetes_baseurl=${kubernetes_mirrors[0]}
      ;;
    tsinghua)
      kubernetes_baseurl=${kubernetes_mirrors[1]}
      ;;
    kubernetes)
      kubernetes_baseurl=${kubernetes_mirrors[-1]}
      ;;
    *)
      echo -e "${COLOR_BLUE}使用自定义 Kubernetes 仓库地址 ${COLOR_GREEN}$kubernetes_repo_type${COLOR_RESET}"
      kubernetes_baseurl=$kubernetes_repo_type
      ;;
    esac
    ;;

  kubernetes-images=* | -kubernetes-images=* | --kubernetes-images=*)
    kubernetes_images="${1#*=}"
    case "$kubernetes_images" in
    aliyun)
      kubernetes_images=${kubernetes_images_mirrors[0]}
      ;;
    Novatra-Container-Registry)
      kubernetes_images=${kubernetes_images_mirrors[1]}
      ;;
    kubernetes)
      kubernetes_images=${kubernetes_images_mirrors[-1]}
      ;;
    *)
      echo -e "${COLOR_RED}不支持自定义 Kubernetes 镜像仓库: ${COLOR_GREEN}$kubernetes_images${COLOR_RESET}"
      echo -e "${COLOR_RED}请阅读文档，查看 Kubernetes 镜像仓库配置 kubernetes-images: ${COLOR_GREEN}${DOCS_LINK}${COLOR_RESET}"
      exit 1
      ;;
    esac
    ;;

  swap-off | -swap-off | --swap-off)
    swap_off=true
    ;;

  curl | -curl | --curl)
    curl=true
    ;;

  ca-certificates | -ca-certificates | --ca-certificates)
    ca_certificates=true
    ;;

  conntrack-deb=* | -conntrack-deb=* | --conntrack-deb=*)
    conntrack_deb="${1#*=}"
    ;;

  kubernetes-install | -kubernetes-install | --kubernetes-install)
    kubernetes_install=true
    ;;

  kubernetes-images-pull | -kubernetes-images-pull | --kubernetes-images-pull)
    kubernetes_images_pull=true
    ;;

  kubernetes-config | -kubernetes-config | --kubernetes-config)
    kubernetes_config=true
    ;;

  kubernetes-init | -kubernetes-init | --kubernetes-init)
    kubernetes_init=true
    ;;

  kubernetes-init-congrats | -kubernetes-init-congrats | --kubernetes-init-congrats)
    kubernetes_init_congrats=true
    ;;

  kubernetes-init-node-name=* | -kubernetes-init-node-name=* | --kubernetes-init-node-name=*)
    kubernetes_init_node_name="${1#*=}"
    ;;

  control-plane-endpoint=* | -control-plane-endpoint=* | --control-plane-endpoint=*)
    # 关于 apiserver-advertise-address 和 ControlPlaneEndpoint 的注意事项
    # https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#considerations-about-apiserver-advertise-address-and-controlplaneendpoint
    # https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#considerations-about-apiserver-advertise-address-and-controlplaneendpoint
    control_plane_endpoint="${1#*=}"
    ;;

  service-cidr=* | -service-cidr=* | --service-cidr=*)
    # kubeadm init
    # --service-cidr string     默认值："10.96.0.0/12"
    # https://kubernetes.io/zh-cn/docs/reference/setup-tools/kubeadm/kubeadm-init/
    # https://kubernetes.io/zh-cn/docs/reference/setup-tools/kubeadm/kubeadm-init/
    service_cidr="${1#*=}"
    ;;

  pod-network-cidr=* | -pod-network-cidr=* | --pod-network-cidr=*)
    pod_network_cidr="${1#*=}"
    ;;

  print-join-command | -print-join-command | --print-join-command)
    print_join_command=true
    ;;

  kubernetes-taint | -kubernetes-taint | --kubernetes-taint)
    kubernetes_taint=true
    ;;

  kubernetes-version=* | -kubernetes-version=* | --kubernetes-version=*)
    kubernetes_version="${1#*=}"
    _k8s_support_kernel
    ;;

  kubernetes-version-suffix=* | -kubernetes-version-suffix=* | --kubernetes-version-suffix=*)
    kubernetes_version_suffix="${1#*=}"
    ;;

  enable-shell-autocompletion | -enable-shell-autocompletion | --enable-shell-autocompletion)
    enable_shell_autocompletion=true
    ;;

  docker-repo | -docker-repo | --docker-repo)
    docker_repo=true
    ;;

  docker-repo-type=* | -docker-repo-type=* | --docker-repo-type=*)
    docker_repo_type="${1#*=}"
    case "$docker_repo_type" in
    aliyun)
      docker_baseurl=${docker_mirrors[0]}
      ;;
    tencent)
      docker_baseurl=${docker_mirrors[1]}
      ;;
    docker)
      docker_baseurl=${docker_mirrors[-1]}
      ;;
    *)
      echo -e "${COLOR_BLUE}使用自定义 Docker 仓库地址: ${COLOR_GREEN}$docker_repo_type${COLOR_RESET}"
      docker_baseurl=$docker_repo_type
      ;;
    esac
    ;;

  container-selinux-rpm=* | -container-selinux-rpm=* | --container-selinux-rpm=*)
    container_selinux_rpm="${1#*=}"
    ;;

  containerd-io-rpm=* | -containerd-io-rpm=* | --containerd-io-rpm=*)
    containerd_io_rpm="${1#*=}"
    ;;

  containerd-install | -containerd-install | --containerd-install)
    containerd_install=true
    ;;

  pause-image=* | -pause-image=* | --pause-image=*)
    pause_image="${1#*=}"
    ;;

  containerd-config | -containerd-config | --containerd-config)
    containerd_config=true
    ;;

  containerd-root=* | -containerd-root=* | --containerd-root=*)
    containerd_root="${1#*=}"
    ;;

  containerd-state=* | -containerd-state=* | --containerd-state=*)
    containerd_state="${1#*=}"
    ;;

  docker-install | -docker-install | --docker-install)
    docker_install=true
    ;;

  availability-vip-install | -availability-vip-install | --availability-vip-install)
    availability_vip_install=true
    ;;

  availability-master=* | -availability-master=* | --availability-master=*)
    availability_master="${1#*=}"
    echo -e "${COLOR_BLUE}kubernetes 高可用主节点地址$((${#availability_master_array[@]} + 1))：${COLOR_RESET}${COLOR_GREEN}${availability_master}${COLOR_RESET}"

    _check_availability_master "$availability_master"
    ;;

  availability-vip=* | -availability-vip=* | --availability-vip=*)
    availability_vip="${1#*=}"
    echo -e "${COLOR_BLUE}kubernetes 高可用 VIP：${COLOR_RESET}${COLOR_GREEN}${availability_vip}${COLOR_RESET}"

    _check_availability_vip "$availability_vip"
    ;;

  availability-vip-no=* | -availability-vip-no=* | --availability-vip-no=*)
    availability_vip_no="${1#*=}"
    echo -e "${COLOR_BLUE}kubernetes 高可用 VIP 编号：${COLOR_RESET}${COLOR_GREEN}${availability_vip_no}${COLOR_RESET}"

    _check_availability_vip_no "$availability_vip_no"
    ;;

  interface-name=* | -interface-name=* | --interface-name=*)
    interface_name="${1#*=}"
    ;;

  calico-install | -calico-install | --calico-install)
    calico_install=true
    ;;

  calico-url=* | -calico-url=* | --calico-url=*)
    calico_url="${1#*=}"
    ;;

  calico-mirror=* | -calico-mirror=* | --calico-mirror=*)
    calico_mirror="${1#*=}"
    ;;

  calico-version=* | -calico-version=* | --calico-version=*)
    calico_version="${1#*=}"
    ;;

  calico-node-image=* | -calico-node-image=* | --calico-node-image=*)
    calico_node_image="${1#*=}"
    ;;

  calico-cni-image=* | -calico-cni-image=* | --calico-cni-image=*)
    calico_cni_image="${1#*=}"
    ;;

  calico-kube-controllers-image=* | -calico-kube-controllers-image=* | --calico-kube-controllers-image=*)
    calico_kube_controllers_image="${1#*=}"
    ;;

  ingress-nginx-install | -ingress-nginx-install | --ingress-nginx-install)
    ingress_nginx_install=true
    ;;

  ingress-nginx-host-network | -ingress-nginx-host-network | --ingress-nginx-host-network)
    ingress_nginx_host_network=true
    ;;

  ingress-nginx-url=* | -ingress-nginx-url=* | --ingress-nginx-url=*)
    ingress_nginx_url="${1#*=}"
    ;;

  ingress-nginx-mirror=* | -ingress-nginx-mirror=* | --ingress-nginx-mirror=*)
    ingress_nginx_mirror="${1#*=}"
    ;;

  ingress-nginx-version=* | -ingress-nginx-version=* | --ingress-nginx-version=*)
    ingress_nginx_version="${1#*=}"
    ;;

  ingress-nginx-controller-image=* | -ingress-nginx-controller-image=* | --ingress-nginx-controller-image=*)
    ingress_nginx_controller_image="${1#*=}"
    ;;

  ingress-nginx-kube-webhook-certgen-image=* | -ingress-nginx-kube-webhook-certgen-image=* | --ingress-nginx-kube-webhook-certgen-image=*)
    ingress_nginx_kube_webhook_certgen_image="${1#*=}"
    ;;

  ingress-nginx-allow-snippet-annotations | -ingress-nginx-allow-snippet-annotations | --ingress-nginx-allow-snippet-annotations)
    ingress_nginx_allow_snippet_annotations=true
    ;;

  metrics-server-install | -metrics-server-install | --metrics-server-install)
    metrics_server_install=true
    ;;

  metrics-server-url=* | -metrics-server-url=* | --metrics-server-url=*)
    metrics_server_url="${1#*=}"
    ;;

  metrics-server-version=* | -metrics-server-version=* | --metrics-server-version=*)
    metrics_server_version="${1#*=}"
    ;;

  metrics-server-mirror=* | -metrics-server-mirror=* | --metrics-server-mirror=*)
    metrics_server_mirror="${1#*=}"
    ;;

  metrics-server-image=* | -metrics-server-image=* | --metrics-server-image=*)
    metrics_server_image="${1#*=}"
    ;;

  metrics-server-secure-tls | -metrics-server-secure-tls | --metrics-server-secure-tls)
    metrics_server_secure_tls=true
    ;;

  helm-install | -helm-install | --helm-install)
    helm_install=true
    ;;

  helm-version=* | -helm-version=* | --helm-version=*)
    helm_version="${1#*=}"
    ;;

  helm-url=* | -helm-url=* | --helm-url=*)
    helm_url="${1#*=}"
    ;;

  helm-repo-type=* | -helm-repo-type=* | --helm-repo-type=*)
    helm_repo_type="${1#*=}"
    case "$helm_repo_type" in
    "" | huawei | helm) ;;
    *)
      echo -e "${COLOR_RED}helm-repo-type 参数值: ${COLOR_GREEN}$helm_repo_type${COLOR_RED} 无效，合法值: 空、huawei、helm，或者使用 helm-url 自定义 helm 下载地址，退出程序${COLOR_RESET}"
      echo -e "${COLOR_RED}请阅读文档，查看 helm 仓库配置 helm-repo-type: ${COLOR_GREEN}${DOCS_LINK}${COLOR_RESET}"
      exit 1
      ;;
    esac
    ;;

  helm-install-kubernetes-dashboard | -helm-install-kubernetes-dashboard | --helm-install-kubernetes-dashboard)
    helm_install_kubernetes_dashboard=true
    ;;

  kubernetes-dashboard-chart=* | -kubernetes-dashboard-chart=* | --kubernetes-dashboard-chart=*)
    kubernetes_dashboard_chart="${1#*=}"
    ;;

  kubernetes-dashboard-version=* | -kubernetes-dashboard-version=* | --kubernetes-dashboard-version=*)
    kubernetes_dashboard_version="${1#*=}"
    ;;

  kubernetes-dashboard-auth-image=* | -kubernetes-dashboard-auth-image=* | --kubernetes-dashboard-auth-image=*)
    kubernetes_dashboard_auth_image="${1#*=}"
    ;;

  kubernetes-dashboard-api-image=* | -kubernetes-dashboard-api-image=* | --kubernetes-dashboard-api-image=*)
    kubernetes_dashboard_api_image="${1#*=}"
    ;;

  kubernetes-dashboard-web-image=* | -kubernetes-dashboard-web-image=* | --kubernetes-dashboard-web-image=*)
    kubernetes_dashboard_web_image="${1#*=}"
    ;;

  kubernetes-dashboard-metrics-scraper-image=* | -kubernetes-dashboard-metrics-scraper-image=* | --kubernetes-dashboard-metrics-scraper-image=*)
    kubernetes_dashboard_metrics_scraper_image="${1#*=}"
    ;;

  kubernetes-dashboard-kong-image=* | -kubernetes-dashboard-kong-image=* | --kubernetes-dashboard-kong-image=*)
    kubernetes_dashboard_kong_image="${1#*=}"
    ;;

  kubernetes-dashboard-ingress-enabled=* | -kubernetes-dashboard-ingress-enabled=* | --kubernetes-dashboard-ingress-enabled=*)
    kubernetes_dashboard_ingress_enabled="${1#*=}"
    if [[ $kubernetes_dashboard_ingress_enabled != 'true' && $kubernetes_dashboard_ingress_enabled != 'false' ]]; then
      echo -e "${COLOR_RED}无效参数: kubernetes-dashboard-ingress-enabled=$kubernetes_dashboard_ingress_enabled，合法值：true/false，退出程序${COLOR_RESET}"
    fi
    ;;

  kubernetes-dashboard-ingress-host=* | -kubernetes-dashboard-ingress-host=* | --kubernetes-dashboard-ingress-host=*)
    kubernetes_dashboard_ingress_host="${1#*=}"
    ;;

  dn-c=* | -dn-c=* | --dn-c=*)
    dn_c="${1#*=}"
    ;;

  dn-st=* | -dn-st=* | --dn-st=*)
    dn_st="${1#*=}"
    ;;

  dn-l=* | -dn-l=* | --dn-l=*)
    dn_l="${1#*=}"
    ;;

  dn-o=* | -dn-o=* | --dn-o=*)
    dn_o="${1#*=}"
    ;;

  dn-ou=* | -dn-ou=* | --dn-ou=*)
    dn_ou="${1#*=}"
    ;;

  dn-cn=* | -dn-cn=* | --dn-cn=*)
    dn_cn="${1#*=}"
    ;;

  etcd-binary-install | -etcd-binary-install | --etcd-binary-install)
    etcd_binary_install=true
    ;;

  etcd-ips=* | -etcd-ips=* | --etcd-ips=*)
    etcd_ips+=("${1#*=}")
    ;;

  etcd-client-port-2379=* | -etcd-client-port-2379=* | --etcd-client-port-2379=*)
    etcd_client_port_2379="${1#*=}"
    ;;

  etcd-peer-port-2380=* | -etcd-peer-port-2380=* | --etcd-peer-port-2380=*)
    etcd_peer_port_2380="${1#*=}"
    ;;

  etcd-url=* | -etcd-url=* | --etcd-url=*)
    etcd_url="${1#*=}"
    ;;

  etcd-version=* | -etcd-version=* | --etcd-version=*)
    etcd_version="${1#*=}"
    ;;

  etcd-current-ip=* | -etcd-current-ip=* | --etcd-current-ip=*)
    etcd_current_ip="${1#*=}"
    ;;

  etcd-binary-join | -etcd-binary-join | --etcd-binary-join)
    etcd_binary_join=true
    ;;

  etcd-join-ip=* | -etcd-join-ip=* | --etcd-join-ip=*)
    etcd_join_ip="${1#*=}"
    ;;

  etcd-join-port=* | -etcd-join-port=* | --etcd-join-port=*)
    etcd_join_port="${1#*=}"
    ;;

  etcd-cafile=* | -etcd-cafile=* | --etcd-cafile=*)
    etcd_cafile="${1#*=}"
    ;;

  etcd-certfile=* | -etcd-certfile=* | --etcd-certfile=*)
    etcd_certfile="${1#*=}"
    ;;

  etcd-keyfile=* | -etcd-keyfile=* | --etcd-keyfile=*)
    etcd_keyfile="${1#*=}"
    ;;

  kube-prometheus-install | -kube-prometheus-install | --kube-prometheus-install)
    kube_prometheus_install=true
    ;;

  kube-prometheus-version=* | -kube-prometheus-version=* | --kube-prometheus-version=*)
    kube_prometheus_version="${1#*=}"
    ;;

  kube-prometheus-url=* | -kube-prometheus-url=* | --kube-prometheus-url=*)
    kube_prometheus_url="${1#*=}"
    ;;

  grafana-image=* | -grafana-image=* | --grafana-image=*)
    grafana_image="${1#*=}"
    ;;

  kube-state-metrics-image=* | -kube-state-metrics-image=* | --kube-state-metrics-image=*)
    kube_state_metrics_image="${1#*=}"
    ;;

  prometheus-adapter-image=* | -prometheus-adapter-image=* | --prometheus-adapter-image=*)
    prometheus_adapter_image="${1#*=}"
    ;;

  jimmidyson-configmap-reload-image=* | -jimmidyson-configmap-reload-image=* | --jimmidyson-configmap-reload-image=*)
    jimmidyson_configmap_reload_image="${1#*=}"
    ;;

  kube-prometheus-node-port | -kube-prometheus-node-port | --kube-prometheus-node-port)
    kube_prometheus_node_port=true
    ;;

  prometheus-k8s-web-9090-node-port=* | -prometheus-k8s-web-9090-node-port=* | --prometheus-k8s-web-9090-node-port=*)
    prometheus_k8s_web_9090_node_port="${1#*=}"
    ;;

  prometheus-k8s-reloader-web-8080-node-port=* | -prometheus-k8s-reloader-web-8080-node-port=* | --prometheus-k8s-reloader-web-8080-node-port=*)
    prometheus_k8s_reloader_web_8080_node_port="${1#*=}"
    ;;

  alertmanager-main-web-9093-node-port=* | -alertmanager-main-web-9093-node-port=* | --alertmanager-main-web-9093-node-port=*)
    alertmanager_main_web_9093_node_port="${1#*=}"
    ;;

  alertmanager-main-reloader-web-8080-node-port=* | -alertmanager-main-reloader-web-8080-node-port=* | --alertmanager-main-reloader-web-8080-node-port=*)
    alertmanager_main_reloader_web_8080_node_port="${1#*=}"
    ;;

  grafana-http-3000-node-port=* | -grafana-http-3000-node-port=* | --grafana-http-3000-node-port=*)
    grafana_http_3000_node_port="${1#*=}"
    ;;

  kube-prometheus-remote-access | -kube-prometheus-remote-access | --kube-prometheus-remote-access)
    kube_prometheus_remote_access=true
    ;;

  *)
    echo -e "${COLOR_RED}无效参数: $1，退出程序${COLOR_RESET}"
    echo -e "${COLOR_RED}请阅读文档，查看参数配置: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
    exit 1
    ;;
  esac
  shift
done

if ! command -v 'sudo' &>/dev/null; then
  if [[ $package_type == 'apt' ]]; then
    echo -e "${COLOR_BLUE}sudo 未安装，正在安装...${COLOR_RESET}"
    apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout update
    apt-get -o Dpkg::Lock::Timeout=$dpkg_lock_timeout install -y sudo
    echo -e "${COLOR_BLUE}sudo 安装完成${COLOR_RESET}"
  fi
fi

_node() {
  _swap_off
  _curl
  _ca_certificates
  _firewalld_stop
  _selinux_disabled
  _bash_completion
  _docker_repo
  _containerd_install
  _containerd_config
  _kubernetes_repo
  _kubernetes_install
  _kubernetes_images_pull
  _kubernetes_config
}

# 三者互斥

count=0

if [[ $standalone == true ]]; then
  count=$(expr $count + 1)
fi

if [[ $cluster == true ]]; then
  count=$(expr $count + 1)
fi

if [[ $node == true ]]; then
  count=$(expr $count + 1)
fi

if [[ $count -gt 1 ]]; then
  echo ''
  echo ''
  echo ''
  echo -e "${COLOR_RED}${EMOJI_FAILURE}${EMOJI_FAILURE}${EMOJI_FAILURE}${COLOR_RESET}"
  echo -e "${COLOR_RED}参数 standalone、cluster、node 三者互斥${COLOR_RESET}"
  echo -e "${COLOR_RED}请阅读文档，查看配置: ${COLOR_GREEN}$DOCS_LINK${COLOR_RESET}"
  echo ''
  echo ''
  echo ''
  exit 1
fi

if [[ $standalone == true ]]; then
  # 单机模式

  if ! [[ $kubernetes_init_node_name ]]; then
    kubernetes_init_node_name=k8s-1
  fi
  _node
  _kubernetes_init
  _helm_install
  _calico_install
  _kubernetes_taint
  _ingress_nginx_install
  _ingress_nginx_host_network
  _metrics_server_install
  _enable_shell_autocompletion
  _print_join_command
  _kubernetes_init_congrats
elif [[ $cluster == true ]]; then
  # 集群模式

  if ! [[ $kubernetes_init_node_name ]]; then
    kubernetes_init_node_name=k8s-1
  fi
  _node
  _kubernetes_init
  _helm_install
  _calico_install
  _ingress_nginx_install
  _ingress_nginx_host_network
  _metrics_server_install
  _enable_shell_autocompletion
  _print_join_command
  _kubernetes_init_congrats
elif [[ $node == true ]]; then
  # 工作节点准备

  _node

  echo
  echo
  echo
  echo -e "${COLOR_BLUE}${EMOJI_CONGRATS}${EMOJI_CONGRATS}${EMOJI_CONGRATS}${COLOR_RESET}"
  echo -e "${COLOR_BLUE}Kubernetes 节点已配置完成${COLOR_RESET}"
  echo
  echo -e "${COLOR_BLUE}请选择下列方式之一：${COLOR_RESET}"
  echo
  echo -e "${COLOR_BLUE}1. 初始化为控制节点（控制平面）${COLOR_RESET}"
  echo -e "${COLOR_BLUE}2. 作为工作节点加入集群${COLOR_RESET}"
  echo
  echo
  echo

else

  if [[ $swap_off == true ]]; then
    _swap_off
  fi

  if [[ $curl == true ]]; then
    _curl
  fi

  if [[ $ca_certificates == true ]]; then
    _ca_certificates
  fi

  if [[ $firewalld_stop == true ]]; then
    _firewalld_stop
  fi

  if [[ $selinux_disabled == true ]]; then
    _selinux_disabled
  fi

  if [[ $bash_completion == true ]]; then
    _bash_completion
  fi

  if [[ $docker_repo == true ]]; then
    _docker_repo
  fi

  if [[ $docker_install == true ]]; then
    _docker_install
  fi

  if [[ $containerd_install == true ]]; then
    _containerd_install
  fi

  if [[ $containerd_config == true ]]; then
    _containerd_config
  fi

  if [[ $availability_vip_install == true ]]; then
    _availability_vip_install
  fi

  if [[ $kubernetes_repo == true ]]; then
    _kubernetes_repo
  fi

  if [[ $kubernetes_install == true ]]; then
    _kubernetes_install
  fi

  if [[ $kubernetes_images_pull == true ]]; then
    _kubernetes_images_pull
  fi

  if [[ $kubernetes_config == true ]]; then
    _kubernetes_config
  fi

  if [[ $kubernetes_init == true ]]; then
    _kubernetes_init
  fi

  if [[ $helm_install == true ]]; then
    _helm_install
  fi

  if [[ $calico_install == true ]]; then
    _calico_install
  fi

  if [[ $kubernetes_taint == true ]]; then
    _kubernetes_taint
  fi

  if [[ $enable_shell_autocompletion == true ]]; then
    _enable_shell_autocompletion
  fi

  if [[ $ingress_nginx_install == true ]]; then
    _ingress_nginx_install
  fi

  if [[ $ingress_nginx_host_network == true ]]; then
    _ingress_nginx_host_network
  fi

  if [[ $ingress_nginx_allow_snippet_annotations == true ]]; then
    _ingress_nginx_allow_snippet_annotations
  fi

  if [[ $metrics_server_install == true ]]; then
    _metrics_server_install
  fi

  if [[ $print_join_command == true ]]; then
    _print_join_command
  fi

  if [[ $kubernetes_init_congrats == true ]]; then
    _kubernetes_init_congrats
  fi

  if [[ $helm_install_kubernetes_dashboard == true ]]; then
    _helm_install_kubernetes_dashboard
  fi

  if [[ $etcd_binary_install == true ]]; then
    _etcd_binary_install
  fi

  if [[ $etcd_binary_join == true ]]; then
    _etcd_binary_join
  fi

  if [[ $kube_prometheus_install == true ]]; then
    _kube_prometheus_install
  fi

  if [[ $kube_prometheus_node_port == true ]]; then
    _kube_prometheus_node_port
  fi

  if [[ $kube_prometheus_remote_access == true ]]; then
    _kube_prometheus_remote_access
  fi

fi
