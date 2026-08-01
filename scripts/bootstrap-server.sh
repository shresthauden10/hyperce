#!/usr/bin/env bash
set -euo pipefail

KIND_VERSION="${KIND_VERSION:-v0.23.0}"

case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

echo "== Docker =="
if command -v docker >/dev/null 2>&1; then
  echo "docker already installed: $(docker --version)"
else
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
fi

if ! getent group docker >/dev/null 2>&1; then
  sudo groupadd docker
fi
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo "Added $USER to the docker group — this takes effect on the next login/SSH session."
fi

sudo systemctl enable --now docker >/dev/null 2>&1 || true

echo "== Docker Compose plugin =="
if docker compose version >/dev/null 2>&1; then
  echo "docker compose already installed: $(docker compose version)"
else
  sudo apt-get update -qq
  sudo apt-get install -y docker-compose-plugin
fi

echo "== kubectl =="
if command -v kubectl >/dev/null 2>&1; then
  echo "kubectl already installed: $(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion || true)"
else
  KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
fi

echo "== kind =="
if command -v kind >/dev/null 2>&1; then
  echo "kind already installed: $(kind --version)"
else
  curl -fsSLo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  sudo install -o root -g root -m 0755 /tmp/kind /usr/local/bin/kind
  rm -f /tmp/kind
fi

echo "== helm =="
if command -v helm >/dev/null 2>&1; then
  echo "helm already installed: $(helm version --short)"
else
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3.sh
  chmod +x /tmp/get-helm-3.sh
  sudo /tmp/get-helm-3.sh
  rm -f /tmp/get-helm-3.sh
fi

echo "Bootstrap complete."
