#!/bin/bash

docker pull ubuntu:focal
docker build -t ubuntu-sshd:focal .
mkdir -p ./home
cp /etc/skel/* ./home/