# HAProxy 3.2.23 LTS 패키지 빌더

HAProxy **3.2.23 LTS**를 공식 소스 tarball에서 빌드해 다음 패키지를 생성합니다. 빌드 도구와 라이브러리는 Docker 컨테이너에만 설치되므로 호스트 OS 환경에 의존하지 않습니다.

| 대상 | 산출물 |
|---|---|
| Ubuntu 22.04 (Jammy), 24.04 (Noble), 26.04 | `.deb` |
| Rocky Linux 8 | `.rpm` |
| Rocky Linux 9 | `.rpm` |

소스 tarball은 빌드 중 SHA-256으로 검증됩니다.

```text
https://www.haproxy.org/download/3.2/src/haproxy-3.2.23.tar.gz
SHA-256: 82d14ef33571e4edeb9197516c0d058a3775fb80541e46afe4377428e461fef0
```

## 요구 사항

- Docker Engine 및 현재 사용자의 Docker daemon 접근 권한
- Docker Buildx (최근 Docker Desktop/Engine에 기본 포함)

## 다른 HAProxy 버전 빌드

버전은 `X.Y.Z` 형식으로 지정하면 source series (`X.Y`)는 자동으로 계산됩니다. 예를 들어 `3.4.2`는 `download/3.4/src/`에서 다운로드합니다. **버전과 그 공식 tarball SHA-256은 반드시 함께 지정**해야 합니다.

```bash
VERSION=3.4.2
SERIES=${VERSION%.*}
SHA256=$(curl -fsSL "https://www.haproxy.org/download/${SERIES}/src/haproxy-${VERSION}.tar.gz.sha256" | awk 'NF {print $1; exit}')

./build.sh --version "$VERSION" --sha256 "$SHA256"
./build-rpm.sh --version "$VERSION" --sha256 "$SHA256" 8 9
```

기본값은 HAProxy 3.2.23이며, 환경 변수도 지원합니다.

```bash
HAPROXY_VERSION=3.4.2 HAPROXY_SHA256="$SHA256" ./build.sh
```

## 로컬 빌드

```bash
chmod +x build.sh build-rpm.sh

# Ubuntu 22.04, 24.04, 26.04 native-architecture DEB 모두 생성
./build.sh

# 특정 Ubuntu 릴리스만 생성
./build.sh 22.04
./build.sh 24.04
./build.sh 26.04

# Rocky 8 및 Rocky 9 RPM 모두 생성
./build-rpm.sh

# 특정 Rocky 버전만 생성
./build-rpm.sh 8
./build-rpm.sh 9
```

산출물 위치:

```text
output/
├── deb/
│   ├── ubuntu22.04/
│   │   ├── haproxy_3.2.23-1~ubuntu22.04_<architecture>.deb
│   │   └── SHA256SUMS
│   ├── ubuntu24.04/
│   │   ├── haproxy_3.2.23-1~ubuntu24.04_<architecture>.deb
│   │   └── SHA256SUMS
│   └── ubuntu26.04/
│       ├── haproxy_3.2.23-1~ubuntu26.04_<architecture>.deb
│       └── SHA256SUMS
└── rpm/
    ├── el8/
    │   ├── SHA256SUMS
    │   └── <architecture>/haproxy-3.2.23-1.el8.<architecture>.rpm
    └── el9/
        ├── SHA256SUMS
        └── <architecture>/haproxy-3.2.23-1.el9.<architecture>.rpm
```

각 출력 디렉터리의 `SHA256SUMS`는 다음처럼 확인합니다.

```bash
(cd output/deb/ubuntu24.04 && sha256sum -c SHA256SUMS)
(cd output/rpm/el8 && sha256sum -c SHA256SUMS)
```

> 기본값은 빌드 호스트와 같은 CPU 아키텍처입니다. GitHub Actions의 `ubuntu-latest`에서는 `amd64` 패키지가 생성됩니다. `arm64` 패키지는 ARM runner 또는 별도로 설정한 Buildx/QEMU builder에서 생성하세요.

## 활성화된 HAProxy 빌드 옵션

요청한 옵션과 기존 런타임 기능에 필요한 옵션을 모두 반영했습니다.

```text
TARGET=linux-glibc
USE_OPENSSL=1
USE_PCRE2=1
USE_ZLIB=1
USE_LUA=1
USE_CRYPT_H=1
USE_LINUX_TPROXY=1
USE_GETADDRINFO=1
USE_PROMEX=1
```

추가한 항목은 다음입니다.

- `USE_ZLIB=1`: gzip/deflate 압축 지원
- `USE_SYSTEMD=1`: systemd `Type=notify` 서비스 통합

HAProxy 3.2에서는 `USE_SLZ=1`과 `USE_ZLIB=1`을 동시에 활성화할 수 있으므로, 표준 gzip/deflate 지원을 위해 `USE_ZLIB=1`만 사용합니다. TPROXY 사용에는 커널/네트워크 정책 설정(CAP_NET_ADMIN, ip rule/route 등)이 별도로 필요합니다.

## 구성 구조 및 systemd

패키지가 설치하는 구조:

```text
/etc/haproxy/haproxy.cfg       # global/defaults 중심의 주 설정
/etc/haproxy/conf.d/           # frontend/backend/listen 조각 설정 위치
/etc/haproxy/conf.d/.keep      # 빈 디렉터리 보존용 파일
/etc/sysconfig/haproxy         # OPTIONS=... 추가 인수
```

서비스는 `/etc/haproxy/haproxy.cfg`와 `/etc/haproxy/conf.d/`를 함께 읽습니다. 따라서 frontend/backend 설정을 `conf.d/` 밑의 `*.cfg` 파일로 분리할 수 있습니다.

```ini
ExecStartPre=/usr/sbin/haproxy -f $CONFIG -f $CFGDIR -c -q $OPTIONS
ExecStart=/usr/sbin/haproxy -Ws -f $CONFIG -f $CFGDIR -p $PIDFILE $OPTIONS
```

예시:

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

설치 시 서비스는 자동으로 enable/start 하지 않습니다. 설정 검토 후 명시적으로 활성화합니다. `/etc/haproxy/haproxy.cfg` 및 `/etc/sysconfig/haproxy`는 업그레이드 시 보존되는 패키지 구성 파일입니다.

## GitHub Actions Release

`.github/workflows/release.yml`이 제공됩니다.

1. `v*` 형식의 tag push에서 실행됩니다. 예: `v3.2.23-1`
2. Ubuntu 22.04/24.04/26.04 DEB, Rocky 8 RPM, Rocky 9 RPM을 병렬 Docker Buildx 빌드합니다.
3. 생성물과 checksum을 workflow artifact로 보존합니다.
4. 모든 빌드 성공 후 GitHub Release에 `.deb`, `.rpm`, `SHA256SUMS`를 업로드합니다.

ECR 로그인이나 이미지 push는 필요하지 않습니다. workflow가 release를 만들 수 있도록 `permissions: contents: write`가 설정되어 있습니다.

---

> 이 프로젝트의 README와 소스 코드는 AI로 작성되었습니다.
