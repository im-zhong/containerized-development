FROM fedora

RUN dnf update -y && dnf install -y \
    openssh-server \
    passwd \
 && dnf autoremove -y \
 && dnf clean all

EXPOSE 22

COPY entrypoint.sh /etc/entrypoint.sh
ENTRYPOINT [ "/etc/entrypoint.sh" ]
CMD [ "--help" ]
