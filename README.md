# HAProxy Package Publisher

공식 HAProxy source tarball을 Docker 안에서 빌드하고, Ubuntu용 DEB 및 Rocky Linux용 RPM 패키지로 배포하는 프로젝트입니다. 빌드 의존성은 컨테이너에만 설치되며, 결과 패키지와 SHA-256 checksum만 호스트의 `output/` 디렉터리에 생성됩니다.

> 현재 기본 대상 버전은 **HAProxy 3.2.23 LTS**입니다. 다른 버전을 빌드할 때는 공식 tarball의 SHA-256 값도 반드시 함께 지정해야 합니다.

## 지원 플랫폼

| 플랫폼 | 빌드 이미지 | 산출물 |
|---|---|---|
| Ubuntu 22.04 (Jammy) | `ubuntu:22.04` | `.deb` |
| Ubuntu 24.04 (Noble) | `ubuntu:24.04` | `.deb` |
| Ubuntu 26.04 | `ubuntu:26.04` | `.deb` |
| Rocky Linux 8 | `rockylinux:8` | `.rpm` |
| Rocky Linux 9 | `rockylinux:9` | `.rpm` |

기본적으로 실행 환경과 같은 CPU 아키텍처의 패키지가 생성됩니다. GitHub-hosted `ubuntu-latest` runner에서는 일반적으로 `amd64` 패키지가 생성됩니다. `arm64` 산출물이 필요하면 ARM runner 또는 적절히 구성한 Buildx/QEMU 환경을 사용해야 합니다.

## 요구 사항

로컬 빌드에는 다음이 필요합니다.

- Docker Engine
- Docker daemon 접근 권한
- Docker Buildx
- Bash

확인 예시:

```bash
docker version
docker buildx version
docker info
```

## 빠른 시작

```bash
git clone https://github.com/Dotguin/haproxy-package-publisher.git
cd haproxy-package-publisher

chmod +x build-deb.sh build-rpm.sh

# Ubuntu 22.04, 24.04, 26.04용 DEB 패키지 빌드
./build-deb.sh

# Rocky Linux 8, 9용 RPM 패키지 빌드
./build-rpm.sh
```

특정 OS 버전만 빌드할 수도 있습니다.

```bash
# Ubuntu 24.04만
./build-deb.sh 24.04

# Rocky Linux 9만
./build-rpm.sh 9
```

## 다른 HAProxy 버전 빌드

빌드 스크립트는 `X.Y.Z` 형식의 upstream HAProxy 버전과 해당 공식 tarball의 SHA-256을 받습니다. source series (`X.Y`)는 자동 계산됩니다.

```bash
VERSION=3.4.2
RELEASE=1
SERIES=${VERSION%.*}
SHA256="$(
  curl -fsSL \
    "https://www.haproxy.org/download/${SERIES}/src/haproxy-${VERSION}.tar.gz.sha256" |
  awk 'NF { print $1; exit }'
)"

# SHA-256 형식 확인
[[ "$SHA256" =~ ^[[:xdigit:]]{64}$ ]]

./build-deb.sh --version "$VERSION" --release "$RELEASE" --sha256 "$SHA256"
./build-rpm.sh --version "$VERSION" --release "$RELEASE" --sha256 "$SHA256"
```

특정 대상만 지정할 수도 있습니다.

```bash
./build-deb.sh --version "$VERSION" --release "$RELEASE" --sha256 "$SHA256" 24.04
./build-rpm.sh --version "$VERSION" --release "$RELEASE" --sha256 "$SHA256" 9
```

기본값은 다음과 같습니다.

```text
HAPROXY_VERSION=3.2.23
PACKAGE_RELEASE=1
HAPROXY_SHA256=82d14ef33571e4edeb9197516c0d058a3775fb80541e46afe4377428e461fef0
```

환경 변수로도 지정할 수 있습니다.

```bash
HAPROXY_VERSION="$VERSION" PACKAGE_RELEASE="$RELEASE" HAPROXY_SHA256="$SHA256" ./build-deb.sh 24.04
HAPROXY_VERSION="$VERSION" PACKAGE_RELEASE="$RELEASE" HAPROXY_SHA256="$SHA256" ./build-rpm.sh 9
```

## 산출물과 checksum

빌드 결과는 아래 구조로 저장됩니다.

```text
output/
├── deb/
│   ├── ubuntu22.04/
│   │   ├── haproxy_<version>-<revision>~ubuntu22.04_<arch>.deb
│   │   └── SHA256SUMS
│   ├── ubuntu24.04/
│   │   ├── haproxy_<version>-<revision>~ubuntu24.04_<arch>.deb
│   │   └── SHA256SUMS
│   └── ubuntu26.04/
│       ├── haproxy_<version>-<revision>~ubuntu26.04_<arch>.deb
│       └── SHA256SUMS
└── rpm/
    ├── el8/
    │   ├── <arch>/haproxy-<version>-<release>.el8.<arch>.rpm
    │   └── SHA256SUMS
    └── el9/
        ├── <arch>/haproxy-<version>-<release>.el9.<arch>.rpm
        └── SHA256SUMS
```

checksum 검증:

```bash
(cd output/deb/ubuntu24.04 && sha256sum --check SHA256SUMS)
(cd output/rpm/el9 && sha256sum --check SHA256SUMS)
```

## 패키지 버전 정책

패키지 버전은 upstream HAProxy 버전과 패키지 release/revision으로 구성됩니다.

```text
RPM: Name-Version-Release
     haproxy-3.2.23-6.el9.x86_64.rpm

DEB: upstream-version-debian-revision
     haproxy_3.2.23-6~ubuntu24.04_amd64.deb
```

권장 Git tag 형식은 아래와 같습니다.

```text
v<HAProxy upstream version>-<package release>

예시
v3.2.23-1  # 3.2.23 최초 패키징
v3.2.23-2  # 동일 upstream 버전의 패키징 수정
v3.2.23-6  # 동일 upstream 버전의 여섯 번째 패키징
v3.2.24-1  # upstream 버전 변경 후 release를 1부터 재시작
```

`<package release>`는 HAProxy 소스 자체의 버전이 아닙니다. systemd unit, 기본 설정, 의존성, 빌드 옵션 등 패키징 결과만 변경된 경우 release를 증가시킵니다.

`v3.2.23-6` 태그는 workflow에서 upstream version `3.2.23`과 package release `6`으로 분리됩니다. 이 release 값은 `build-deb.sh`/`build-rpm.sh`의 `--release` 옵션을 거쳐 RPM spec의 `Release`와 DEB의 Debian revision에 반영됩니다.

```text
haproxy-3.2.23-6.el8.<arch>.rpm
haproxy-3.2.23-6.el9.<arch>.rpm
haproxy_3.2.23-6~ubuntu22.04_<arch>.deb
haproxy_3.2.23-6~ubuntu24.04_<arch>.deb
haproxy_3.2.23-6~ubuntu26.04_<arch>.deb
```

## HAProxy 빌드 옵션

DEB와 RPM은 동일한 주요 HAProxy 옵션으로 컴파일됩니다.

```text
TARGET=linux-glibc
USE_OPENSSL=1
USE_PCRE2=1
USE_ZLIB=1
USE_LUA=1
USE_CRYPT_H=1
USE_LINUX_TPROXY=1
USE_GETADDRINFO=1
USE_SYSTEMD=1
USE_PROMEX=1
```

| 옵션 | 용도 |
|---|---|
| `USE_OPENSSL=1` | TLS/SSL 지원 |
| `USE_PCRE2=1` | PCRE2 정규식 지원 |
| `USE_ZLIB=1` | gzip/deflate 압축 지원 |
| `USE_LUA=1` | Lua 스크립팅 지원 |
| `USE_SYSTEMD=1` | systemd `Type=notify` 통합 |
| `USE_LINUX_TPROXY=1` | Linux transparent proxy 지원 |
| `USE_PROMEX=1` | Prometheus exporter 지원 |

`USE_LINUX_TPROXY=1`만으로 transparent proxy가 자동 구성되지는 않습니다. 실제 사용에는 Linux capability, `ip rule`, routing table, 방화벽 정책을 별도로 구성해야 합니다.

## 설치 파일과 서비스

패키지는 주요 파일을 다음 경로에 설치합니다.

```text
/usr/sbin/haproxy
/etc/haproxy/haproxy.cfg
/etc/haproxy/conf.d/
/etc/haproxy/conf.d/.keep
/etc/sysconfig/haproxy
/etc/logrotate.d/haproxy
/lib/systemd/system/haproxy.service
```

서비스는 기본 설정과 `conf.d` 디렉터리를 함께 읽습니다.

```ini
ExecStartPre=/usr/sbin/haproxy -f $CONFIG -f $CFGDIR -c -q $OPTIONS
ExecStart=/usr/sbin/haproxy -Ws -f $CONFIG -f $CFGDIR -p $PIDFILE $OPTIONS
```

간단한 조각 설정 예시:

```bash
sudo tee /etc/haproxy/conf.d/frontend.cfg >/dev/null <<'EOF'
frontend http_in
    bind :80
    default_backend app

backend app
    server app1 127.0.0.1:8080 check
EOF

sudo haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/conf.d -c
sudo systemctl enable --now haproxy
```

설치 과정은 서비스를 자동으로 enable/start하지 않습니다. 설정 검증 후 명시적으로 서비스를 활성화하세요. RPM에서는 `/etc/haproxy/haproxy.cfg`와 `/etc/sysconfig/haproxy`가 `config(noreplace)`로 처리됩니다.

## GitHub Actions Release

workflow 파일은 [`.github/workflows/release.yml`](.github/workflows/release.yml)입니다.

### Tag 기반 릴리스

현재 workflow는 `v*` 패턴의 tag push에서 동작합니다.

```bash
git tag v3.2.23-1
git push origin v3.2.23-1
```

workflow는 다음 작업을 수행합니다.

1. tag 이름을 `upstream version`과 `package release`로 해석합니다. 예를 들어 `v3.2.23-6`은 HAProxy `3.2.23`, package release `6`입니다.
2. HAProxy 공식 checksum 파일을 다운로드해 source SHA-256을 확인합니다.
3. Ubuntu 22.04/24.04/26.04 DEB와 Rocky Linux 8/9 RPM을 matrix로 병렬 빌드합니다.
4. 패키지와 각 대상의 `SHA256SUMS`를 artifact로 업로드합니다.
5. 모든 빌드가 성공하면 tag 기반 GitHub Release에 산출물을 첨부합니다.

GitHub Release 작성에는 다음 권한이 필요하며 workflow에 이미 선언되어 있습니다.

```yaml
permissions:
  contents: write
```

### 수동 빌드

Actions 탭에서 **Build and release HAProxy packages** workflow를 선택한 후 `Run workflow`를 실행할 수 있습니다.

수동 실행은 현재 Git tag가 아니므로 패키지 artifact는 생성하지만 `release` job은 실행하지 않습니다. GitHub Release를 생성하려면 tag push로 실행하세요.

## 문제 해결

### RPM의 `%changelog`에서 `bad date` 오류

RPM spec의 `%changelog` 날짜는 유효한 영문 날짜여야 합니다. Dockerfile은 다음 형식으로 빌드 날짜를 생성합니다.

```bash
LC_ALL=C date -u '+%a %b %d %Y'
```

생성된 spec을 `rpmbuild` 전에 출력하여 `@BUILD_DATE@` 토큰이 남아 있거나 `Thu Jan 01 1970` 같은 고정된 값이 남지 않았는지 확인하세요.

```bash
sed -n '/^%changelog/,$p' /root/rpmbuild/SPECS/haproxy.spec
```

### Docker daemon에 연결할 수 없음

```text
ERROR: Docker daemon is unavailable
```

Docker 서비스를 시작하고 현재 사용자가 Docker daemon에 접근할 수 있는지 확인합니다.

```bash
docker info
```

Linux에서 필요하다면 사용자를 `docker` 그룹에 추가한 뒤 로그인 세션을 다시 시작합니다.

```bash
sudo usermod -aG docker "$USER"
```

## 보안 및 운영 참고

- 공식 HAProxy tarball은 다운로드 직후 SHA-256으로 검증됩니다.
- checksum 값은 신뢰 가능한 HAProxy 공식 `.sha256` endpoint에서 확인해야 합니다.
- GitHub Release에 게시하기 전 `SHA256SUMS` 검증을 권장합니다.
- 운영 배포 전에는 각 OS와 아키텍처에서 서비스 기동 및 설정 문법 검증을 수행하세요.
