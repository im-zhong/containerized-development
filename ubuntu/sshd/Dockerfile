FROM ubuntu

RUN apt update && apt install -y \
    openssh-server \
    sudo \ 
 && apt clean

EXPOSE 22

COPY entrypoint.sh /etc/entrypoint.sh
ENTRYPOINT [ "/etc/entrypoint.sh" ]
CMD [ "--help" ]
