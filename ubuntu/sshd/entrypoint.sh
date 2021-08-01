#! /bin/bash

# debug
set -xeuo pipefail
# set -euo pipefail

# set -e: exit immediately if a command exits with a non-zero status
# function is_user_exist()
# {
#     local user="$1"
#     local result=$(cat /etc/passwd | grep "^${user}")

#     if [ -z "${result}" ]; then
#         return 0
#     else
#         return 1
#     fi
# }

function add_user()
{
    local uid="$1"
    local user="$2"
    local gid="$3"
    local group="$4"

    local uid_option=""
    if [ -n "${uid}" ]; then
        uid_option="--uid ${udi}"
    fi
    local gid_option=""
    if [ -n "${gid}" ]; then
        gid_option=="--gid ${gid}"
    fi
    local group_option=""
    if [ -n "${group}" ]; then
        group_option="--group ${group}"
    fi

    # fix: if we restart, the is_user_exist will return 1 and cause exit because set -e
    # is_user_exist ${user}
    local result=$(cat /etc/passwd | grep "^${user}")
    if [ -z "${result}" ]; then
        echo "info: adduser uid: ${uid}, user: ${user}, gid: ${gid} group: ${group}."
        adduser \
        --disabled-password \
        --gecos '' \
        ${uid_option} \
        ${gid_option} \
        ${group_option} \
        ${user}
        # --home HOME \
        # --shell SHELL \
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

# 注意home路径的权限问题
function authenticate_pubkeys()
{
    local user="$1"
    local group="$2"
    local home="$3"
    local authorized_keys="$4"

    echo "info: cp ${authorized_keys} to ${home}/.ssh/authorized_keys."
    mkdir -p ${home}/.ssh
    cp ${authorized_keys} ${home}/.ssh/authorized_keys
    chown -R ${user}:${group} ${home}/.ssh
    chmod 700 ${home}/.ssh
    chmod 600 ${home}/.ssh/authorized_keys
}

function help()
{
    echo "docker run [docker-options] ubuntu-sshd [options]"
    echo "introduction:"
    echo "  This image will help creating an openssh-server based on ubuntu."
    echo "  create the same user as youself in the host machine in the container, the uid and gid could get by command 'id \$USER'."
    echo "  and also, the option <passwd> or <authorized_keys> should be given."
    echo "options:"
    echo "  --uid <UID>                     force the new userid to be the given UID. see adduser(8)."
    echo "  -u,--user <USER>                the new user name. see adduser(8)."
    echo "  --gid <GID>                     add the new user to the GID group."
    echo "                                  if the group is not exists, force the new groupid to be the given GID. see adduser(8)."
    echo "  -g,--group <GROUP>              add the new user to the GROUP, if the group is not exists, create it. see adduser(8)."
    echo "  -p,--passwd <PASSWD>            the password of the user."
    echo "                                  if you do not give this option, then you can not login by passwd, which means you must give the authorized_keys."
    echo "                                  see sshd_config(5) PasswordAuthentication PubkeyAuthentication"
    echo "  -s,--sudo <passwd|nopasswd>     give the user sudo privilege." 
    echo "                                  passwd means you can get the sudo priviledge with input the passwd; nopasswd give you the nopasswd sudo privilege."
    echo "  -a,--authorized_keys <PATH>     give the IN-THE-CONTAINER absolute path of the public keys file."
    echo "  -h,--help                       show help infomation."
}

# main
options=$(getopt -o u:g:p:s:a:h:: --longoptions uid:,user:,gid:,group:,passwd:,sudo:,authorized_keys:,help:: -- "$@")
eval set -- "${options}"

uid=""
user=""
gid=""
group=""
passwd=""
sudo=""
authorized_keys=""

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
        --gid)
            gid="$2"
            shift 2
            ;;
        -g|--group)
            group="$2"
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
        -a|--authorized_keys)
            authorized_keys="$2"
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
echo "gid: ${gid}"
echo "group: ${group}"
echo "passwd: ${passwd}"
echo "sudo: ${sudo}"
echo "authorized_keys: ${authorized_keys}"

# add user
if [ -n "${user}" ]; then
    add_user "${uid}" "${user}" "${gid}" "${group}"
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

# authenticate ssh public key
if [ -n "${authorized_keys}" ]; then
    local home="/home/${user}"
    authenticate_pubkeys ${user} ${group} ${home} ${authorized_keys}
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
