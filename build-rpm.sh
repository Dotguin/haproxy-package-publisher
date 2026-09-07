#!/usr/bin/env bash
# Build Rocky Linux RPMs. Usage: ./build-rpm.sh [--version X.Y.Z --sha256 SHA256] [8] [9]
set -Eeuo pipefail

readonly DEFAULT_VERSION='3.2.23'
readonly DEFAULT_SHA256='82d14ef33571e4edeb9197516c0d058a3775fb80541e46afe4377428e461fef0'
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out_root="${root_dir}/output/rpm"
version="${HAPROXY_VERSION:-$DEFAULT_VERSION}"
sha256="${HAPROXY_SHA256:-$DEFAULT_SHA256}"
versions=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="${2:?--version requires X.Y.Z}"; shift 2 ;;
    --sha256) sha256="${2:?--sha256 requires a value}"; shift 2 ;;
    8|9) versions+=("$1"); shift ;;
    -h|--help) sed -n '2p' "$0"; exit 0 ;;
    *) echo "Unknown option or Rocky version: $1" >&2; exit 2 ;;
  esac
done
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version must be X.Y.Z.' >&2; exit 2; }
[[ "$sha256" =~ ^[[:xdigit:]]{64}$ ]] || { echo 'SHA-256 must be 64 hexadecimal characters.' >&2; exit 2; }
[[ ${#versions[@]} -gt 0 ]] || versions=(8 9)
series="${version%.*}"

command -v docker >/dev/null 2>&1 || { echo 'ERROR: Docker CLI is required.' >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo 'ERROR: Docker daemon is unavailable.' >&2; exit 1; }
for rocky in "${versions[@]}"; do
  destination="${out_root}/el${rocky}"
  rm -rf "$destination"; mkdir -p "$destination"
  DOCKER_BUILDKIT=1 docker buildx build --target artifact \
    --build-arg "ROCKY_VERSION=${rocky}" \
    --build-arg "HAPROXY_VERSION=${version}" \
    --build-arg "HAPROXY_SERIES=${series}" \
    --build-arg "HAPROXY_SHA256=${sha256}" \
    --output "type=local,dest=${destination}" -f "${root_dir}/Dockerfile-rpm" "$root_dir"
  mapfile -t packages < <(find "$destination" -type f -name 'haproxy-*.rpm' -print)
  [[ ${#packages[@]} -eq 1 ]] || { echo "ERROR: expected one RPM for EL${rocky}" >&2; exit 1; }
  (cd "$destination" && sha256sum "${packages[0]#${destination}/}" > SHA256SUMS)
  printf 'Built EL%s RPM: %s\n' "$rocky" "${packages[0]}"
done
