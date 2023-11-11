#! /bin/bash

# debug
# set -xeuo pipefail

function change_passwd()
{
    local user="$1"
    local passwd="$2"

    if [ -n "${passwd}" ]; then
        echo "info: set ${user}'s password to ${passwd}."
        echo "${user}:${passwd}" | chpasswd
    fi
}

function add_to_sudo_group()
{
    local user="$1"

    local result=$(cat /etc/group | grep "^sudo" | grep "${user}")
    if [ -z "${result}" ]; then
        usermod -aG sudo ${user}
    fi
}

function add_user()
{
    local uid="$1"
    local user="$2"
    local passwd="$3"

    local result=$(cat /etc/passwd | grep "^${user}")
    if [ -z "${result}" ]; then
        local uid_option=""
        if [ -n "${uid}" ]; then
            uid_option="--uid ${uid}"
        fi

        echo "info: adduser uid: ${uid}, user: ${user}"
        adduser \
        --disabled-password \
        --gecos '' \
        ${uid_option} \
        ${user}
        change_passwd ${user} ${passwd}
        add_to_sudo_group ${user}
    else
        echo "info: ${user} is exist."
    fi
}

function help()
{
    echo "docker run [docker-options] ubuntu-sshd:focal [options]"
    echo "introduction:"
    echo "  This image will help creating an openssh-server based on ubuntu."
    echo "  create the same user as youself in the host machine in the container, the uid and gid could get by command 'id \$USER'."
    echo "options:"
    echo "  --uid <UID>                     force the new userid to be the given UID. see adduser(8)."
    echo "  -u,--user <USER>                the new user name. see adduser(8)."
    echo "  -p,--passwd <PASSWD>            the password of the user."
    echo "                                  passwd means you can get the sudo priviledge with input the passwd; nopasswd give you the nopasswd sudo privilege."
    echo "  -h,--help                       show help infomation."
}

# main
options=$(getopt -o u:p:h:: --longoptions uid:,user:,passwd:,help:: -- "$@")
eval set -- "${options}"

uid=""
user=""
passwd=""

while true; do
    case "$1" in
        --uid)
            uid="$2"
            shift 2
            ;;
        -u|--user)
            user="$2"
            shift 2
            ;;
        -p|--passwd)
            passwd="$2"
            shift 2
            ;;
        -h|--help)
            help
            exit 0
            ;;
        '')
            break
            ;;
        --)
            shift
            break
            ;;
        *)
            help
            exit 1
            ;;
    esac
done

# echo all options
echo "uid: ${uid}"
echo "user: ${user}"
echo "passwd: ${passwd}"

# add user
if [ -n "${user}" ]; then
    add_user "${uid}" "${user}" "${passwd}"
else
    echo "error: option <user> must be given."
fi

# start openssh-server at PID 1
echo "info: start openssh-server."
mkdir -p /run/sshd
exec /usr/sbin/sshd -D
