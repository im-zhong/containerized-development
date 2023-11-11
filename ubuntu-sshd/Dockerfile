FROM ubuntu:focal

RUN apt update && apt install -y \
    openssh-server \
    sudo \
    && apt clean

EXPOSE 22

COPY etc/sources.list /etc/apt/sources.list

COPY entrypoint.sh /etc/entrypoint.sh
ENTRYPOINT [ "/etc/entrypoint.sh" ]
CMD [ "--help" ]
