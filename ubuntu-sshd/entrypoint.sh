#! /bin/bash

# debug
set -xeuo pipefail

function add_user()
{
    local uid="$1"
    local user="$2"

    local uid_option=""
    if [ -n "${uid}" ]; then
        uid_option="--uid ${uid}"
    fi

    local result=$(cat /etc/passwd | grep "^${user}")
    if [ -z "${result}" ]; then
        echo "info: adduser uid: ${uid}, user: ${user}, gid: ${gid} group: ${group}."
        adduser \
        --disabled-password \
        --gecos '' \
        ${uid_option} \
        ${user}
    else
        echo "info: ${user} is exist."
    fi
}

function change_passwd()
{
    local user="$1"
    local passwd="$2"

    if [ -n "${passwd}" ]; then
        echo "info: change ${user}'s password."
        echo "${user}:${passwd}" | chpasswd
    fi
}

function change_password_authentication()
{
    local passwd="$1"
    local password_authentication_line=""
    if [ -z "${passwd}" ]; then
        password_authentication_line="PasswordAuthentication no"
    else
        password_authentication_line="PasswordAuthentication yes"
    fi

    local sshd_config="/etc/ssh/sshd_config"
    local line=$(grep -n '^PasswordAuthentication' ${sshd_config} | cut -d ':' -f 1)
    if [ -z "${line}" ]; then
        # if can not find , just append the content into the end
        echo "info: append ${password_authentication_line} to ${sshd_config}"
        echo "${password_authentication_line}" >> ${sshd_config}
    else
        # if we find the line, we should overwrite it
        echo "info: change ${line}th of ${sshd_config} from"
        echo "  $(sed -n ${line}p ${sshd_config})"
        sed -i "${line}c ${password_authentication_line}" ${sshd_config}
        echo "to"
        echo "  $(sed -n ${line}p ${sshd_config})"
    fi
}

# 有一个更简单的方法 就是将我们加入sudo组里面 这样不用修改文件
function make_sudoer()
{
    local user="$1"
    local sudo="$2"

    local nopasswd="false"
    if [ "${sudo}" = "nopasswd" ]; then
        nopasswd="NOPASSWD:"
    elif [ "${sudo}" = "passwd" ]; then
        nopasswd=""
    else
        echo "error: invalid operand of option <sudo>, use -h for more infomation."
        exit 1
    fi
    local sudoer_line="${user} ALL=(ALL) ${nopasswd}ALL"

    local sudoers_file="/etc/sudoers"
    local line=$(grep -n "^${user}" ${sudoers_file} | cut -d ':' -f 1)

    if [ -z "${line}" ]; then
        echo "info: append ${sudoer_line} to ${sudoers_file}."
        echo "${sudoer_line}" >> ${sudoers_file}
    else
        echo "info: change ${line} of ${sudoers_file} from"
        echo "  $(sed -n ${line}p ${sudoers_file})"
        sed -i "${line}c ${sudoer_line}" ${sudoers_file}
        echo "to"
        echo "  $(sed -n ${line}p ${sudoers_file})"
    fi
}

function add_to_sudo_group()
{
    local user="$1"
    local sudo="$2"

    if [ "${sudo}" = "nopasswd" ]; then
        usermod -aG sudo ${user}
    elif [ "${sudo}" = "passwd" ]; then
        usermod -aG sudo ${user}
    else
        echo "error: invalid operand of option <sudo>, use -h for more infomation."
        exit 1
    fi
}

function help()
{
    echo "docker run [docker-options] ubuntu-sshd:focal [options]"
    echo "introduction:"
    echo "  This image will help creating an openssh-server based on ubuntu."
    echo "  create the same user as youself in the host machine in the container, the uid and gid could get by command 'id \$USER'."
    echo "  and also, the option <passwd> or <authorized_keys> should be given."
    echo "options:"
    echo "  --uid <UID>                     force the new userid to be the given UID. see adduser(8)."
    echo "  -u,--user <USER>                the new user name. see adduser(8)."
    echo "  -p,--passwd <PASSWD>            the password of the user."
    echo "                                  if you do not give this option, then you can not login by passwd, which means you must give the authorized_keys."
    echo "                                  see sshd_config(5) PasswordAuthentication PubkeyAuthentication"
    echo "  -s,--sudo <passwd|nopasswd>     give the user sudo privilege." 
    echo "                                  passwd means you can get the sudo priviledge with input the passwd; nopasswd give you the nopasswd sudo privilege."
    echo "  -h,--help                       show help infomation."
}

# main
options=$(getopt -o u:p:s:a:h:: --longoptions uid:,user:,passwd:,sudo:,help:: -- "$@")
eval set -- "${options}"

uid=""
user=""
passwd=""
sudo=""

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
        -s|--sudo)
            sudo="$2"
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
echo "sudo: ${sudo}"

# add user
if [ -n "${user}" ]; then
    add_user "${uid}" "${user}"
else
    echo "error: option <user> must be given."
fi

# change password
if [ -n "${passwd}" ]; then
    change_passwd ${user} ${passwd}
fi

# change ssh password authentication
change_password_authentication ${passwd}

# make sudoer
if [ -n "${sudo}" ]; then
    make_sudoer ${user} ${sudo}
fi

# plugins
if [ -f "/etc/plugin.sh" ]; then
    echo "info: run /etc/plugin.sh"
    /etc/plugin.sh
fi

# start openssh-server at PID 1
echo "info: start openssh-server."
mkdir -p /run/sshd
exec /usr/sbin/sshd -D
