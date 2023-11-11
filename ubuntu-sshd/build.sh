#!/bin/bash

docker pull ubuntu:focal
docker build -t ubuntu-sshd:focal .

if [ ! -d ./home ]; then
    cp -r /etc/skel .
    mv skel home
    chmod 750 home
fi
