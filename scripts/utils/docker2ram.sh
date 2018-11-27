#!/bin/bash

INIT_IMAGE=${1-"ubuntu:18.04"}
RAM_DISK=${2-"/tmp"}
DOCKER_REPO="/var/lib/docker"
RAM_REPO="${RAM_DISK}/docker"
IMAGE_TAR=`mktemp -u ${RAM_REPO}/XXXXXXXX.tar`

systemctl stop docker
umount "${DOCKER_REPO}" 2>/dev/null

systemctl start docker

ret=$?

if [ "$1" == "reset" ]; then
  exit $ret
fi

docker save "${INIT_IMAGE}" -o "${IMAGE_TAR}" \
    && systemctl stop docker \
    && mount -o bind "${RAM_REPO}" "${DOCKER_REPO}" \
    && systemctl start docker \
    && docker load -q -i "${IMAGE_TAR}" \
    && unlink "${IMAGE_TAR}" \
    && docker images "${INIT_IMAGE}" && df -h $RAM_DISK

