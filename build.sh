#!/bin/bash
set -e

: ${BUILDER="docker"}

IMAGE_NAME="docker.io/tmatsuo/rocky8-ja-"
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
elif [ "$FLAVOR" = "desktop-custom" ]; then
    DESKTOP="" NGINX="" CODE="" TTYD="" CONTAINER="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "desktop-with-filer" ]; then
    DESKTOP="" NGINX="" FILER="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "desktop-with-term-filer" ]; then
    DESKTOP="" NGINX="" FILER="" TTYD="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "vscode" ]; then
    NGINX="" CODE="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "vscode-custom" ]; then
    NGINX="" CODE="" CONTAINER="" CHROME="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "term" ]; then
    NGINX="" TTYD="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "term-with-filer" ]; then
    NGINX="" FILER="" TTYD="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "xrdp" ]; then
    DESKTOP="" XRDP="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "desktop-full-custom" ]; then
    DESKTOP="" NGINX="" CODE="" XRDP="" FILER="" SSHD="" TTYD="" CHROME="" CONTAINER="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "desktop-full" ]; then
    DESKTOP="" NGINX="" CODE="" XRDP="" FILER="" SSHD="" TTYD="" CHROME="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
elif [ "$FLAVOR" = "all" ]; then
    for i in desktop-min desktop-with-filer desktop-with-term-filer vscode vscode-custom term term-with-filer xrdp desktop-full-custom desktop-full; do
        echo "------------------- building $i -------------------"
        FLAVOR=$i ./build.sh
        echo "------------------- building $i done --------------"
    done
    exit 0
else
    # desktop-full
    DESKTOP="" NGINX="" CODE="" XRDP="" FILER="" SSHD="" TTYD="" CHROME="" ./cocker $CC_OPTION _Dockerfile.split.tmp > _Dockerfile.${FLAVOR}${IS_DEV}
fi

set +e
which docker > /dev/null 2>&1
if [ $? -ne 0 ]; then
    BUILDER="podman"
fi
echo "building image using $BUILDER"

if [ ! -d /assets/revision ]; then
    mkdir -p ./assets/revision
fi
REVISION=$(TZ=UTC0 git show --quiet --date=local --format="%h %cd UTC t-matsuo/ctr-rocky8-desktop")
if [ $? -eq 0 ]; then
    echo $REVISION > ./assets/revision/revision
else
    echo "t-matsuo/ctr-rocky8-desktop" > ./assets/revision/revision
fi
set -e

echo "$BUILDER build -t ${IMAGE_NAME}${FLAVOR}:${TAG}${IS_DEV} -f _Dockerfile.${FLAVOR}${IS_DEV} ."
DOCKER_BUILDKIT=1 $BUILDER build --progress=plain -t ${IMAGE_NAME}${FLAVOR}:${TAG}${IS_DEV} -f _Dockerfile.${FLAVOR}${IS_DEV} .
echo "builded from _Dockerfile.$FLAVOR${IS_DEV}"
