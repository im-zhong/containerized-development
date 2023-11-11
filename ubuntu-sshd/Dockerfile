FROM ubuntu:focal

RUN apt update && apt install -y \
    openssh-server \
    sudo \
    && apt clean

EXPOSE 22

# apt install build-essential will fail, because it want you to add Geometry

# could not COPY sources.list before apt update, there are lost of certificate error
COPY etc/sources.list /etc/apt/sources.list

# 很多配置都可以放在这里 只要是一些公共的配置
# 但是开发相关的东西可以不弄 因为不同的语言毕竟开发环境不太一样 需要安装的包也不一样 到时候自己安装就行了
# 1. proxy
# 2. wgetrc
# 但是每个人的代理都不一样 所以最好是放在外面进行配置
# 而且我们这个容器的网络是host模式 所以不需要配置代理

COPY entrypoint.sh /etc/entrypoint.sh
ENTRYPOINT [ "/etc/entrypoint.sh" ]
CMD [ "--help" ]
