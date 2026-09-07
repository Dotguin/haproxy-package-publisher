#!/usr/bin/env bash
# Build Ubuntu .debs into ./output/deb/ubuntu<release> using Docker BuildKit.
# Usage: ./build.sh [--version X.Y.Z --sha256 SHA256] [--no-cache] [22.04] [24.04] [26.04]
set -Eeuo pipefail

readonly DEFAULT_VERSION='3.2.23'
readonly DEFAULT_SHA256='82d14ef33571e4edeb9197516c0d058a3775fb80541e46afe4377428e461fef0'
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out_root="${root_dir}/output/deb"
version="${HAPROXY_VERSION:-$DEFAULT_VERSION}"
sha256="${HAPROXY_SHA256:-$DEFAULT_SHA256}"
no_cache=false
ubuntu_releases=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="${2:?--version requires X.Y.Z}"; shift 2 ;;
    --sha256) sha256="${2:?--sha256 requires a value}"; shift 2 ;;
    --no-cache) no_cache=true; shift ;;
    22.04|24.04|26.04) ubuntu_releases+=("$1"); shift ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) echo "Unknown option or Ubuntu release: $1" >&2; exit 2 ;;
  esac
done
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version must be X.Y.Z.' >&2; exit 2; }
[[ "$sha256" =~ ^[[:xdigit:]]{64}$ ]] || { echo 'SHA-256 must be 64 hexadecimal characters.' >&2; exit 2; }
[[ ${#ubuntu_releases[@]} -gt 0 ]] || ubuntu_releases=(22.04 24.04 26.04)
series="${version%.*}"

command -v docker >/dev/null 2>&1 || { echo 'ERROR: Docker CLI is required.' >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo 'ERROR: Docker daemon is unavailable or current user lacks access.' >&2; exit 1; }

for ubuntu_release in "${ubuntu_releases[@]}"; do
  destination="${out_root}/ubuntu${ubuntu_release}"
  rm -rf "$destination"
  mkdir -p "$destination"

  args=(buildx build --target artifact --output "type=local,dest=${destination}" -f "${root_dir}/Dockerfile-deb"
    --build-arg "UBUNTU_VERSION=${ubuntu_release}"
    --build-arg "PACKAGE_RELEASE=1~ubuntu${ubuntu_release}"
    --build-arg "HAPROXY_VERSION=${version}"
    --build-arg "HAPROXY_SERIES=${series}"
    --build-arg "HAPROXY_SHA256=${sha256}")
  $no_cache && args+=(--no-cache)
  args+=("$root_dir")
  DOCKER_BUILDKIT=1 docker "${args[@]}"

  shopt -s nullglob
  packages=("${destination}"/haproxy_*.deb)
  [[ ${#packages[@]} -eq 1 ]] || { echo "ERROR: Expected exactly one .deb for Ubuntu ${ubuntu_release}." >&2; exit 1; }
  (cd "$destination" && sha256sum "${packages[0]##*/}" > SHA256SUMS)
  printf '\nBuilt Ubuntu %s DEB: %s\nChecksum file: %s/SHA256SUMS\n' \
    "$ubuntu_release" "${packages[0]}" "$destination"
done
