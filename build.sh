#!/bin/bash
set -e

IMAGE_NAME="tmatsuo/rocky8-ja-"
if [ "$TAG" = "" ]; then
    TAG="latest"
fi

CC_OPTION="-m"
if [ "$MODE" = "dev" ]; then
    CC_OPTION="-c"
    IS_DEV="-dev"
    sed 's|^RUN|RUN --mount=type=cache,id=rocky8,target=/var/cache/dnf --mount=type=cache,id=rocky8,target=/var/lib/dnf --mount=type=cache,id=rocky8,target=/root/.cache --mount=type=cache,id=rocky8,target=/root/.npm|g' Dockerfile.split > _Dockerfile.split.tmp
else
    sed 's|^#__BULDKIT_MARKER__||g' Dockerfile.split > _Dockerfile.split.tmp
fi

if [ "$FLAVOR" = "" ]; then
    FLAVOR="desktop-full"
fi

if [ "$FLAVOR" = "desktop-min" ]; then
    DESKTOP="" NGINX="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "desktop-with-filer" ]; then
    DESKTOP="" NGINX="" FILER="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "desktop-with-term-filer" ]; then
    DESKTOP="" NGINX="" FILER="" TTYD="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "vscode" ]; then
    NGINX="" CODE="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "term" ]; then
    NGINX="" TTYD="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "term-with-filer" ]; then
    NGINX="" FILER="" TTYD="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "xrdp" ]; then
    DESKTOP="" XRDP="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
else
    # desktop-full
    DESKTOP="" NGINX="" CODE="" XRDP="" FILER="" SSHD="" TTYD="" CHROME="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
fi

echo "docker build -t ${IMAGE_NAME}${FLAVOR}:${TAG}${IS_DEV} -f _Dockerfile.${FLAVOR}${IS_DEV} ."
DOCKER_BUILDKIT=1 docker build --progress=plain -t ${IMAGE_NAME}${FLAVOR}:${TAG}${IS_DEV} -f _Dockerfile.${FLAVOR}${IS_DEV} .
echo "builded from _Dockerfile.$FLAVOR${IS_DEV}"
