#! /bin/bash

# debug
set -xeuo pipefail
# set -euo pipefail
echo "-------- start fedora-sshd at $(date) --------"

sshd_config="/etc/ssh/sshd_config"
sudoers_file="/etc/sudoers"

function modify_file()
{
    local file="$1"
    local key="$2"
    local content="$3"
    local line=$(grep -n "${key}" ${file} | cut -d ':' -f 1)

    if [ -n "${content}" ]; then
        # we have content to add
        if [ -n "${line}" ]; then
            # if we find the line, we should overwrite it
            echo "info: change ${line}th of ${file} from"
            echo "  $(sed -n ${line}p ${file})"
            sed -i "${line}c ${content}" ${file}
            echo "to"
            echo "  $(sed -n ${line}p ${file})"
        else
            # if can not find , just append the content into the end
            echo "info: append ${content} to ${file}"
            echo "${content}" >> ${file}
        fi
    else
        # we do not have content
        if [ -n "${line}" ]; then
            # if we find the line, we should delete it
            echo "info: delete ${line}th of ${file} from"
            echo "  $(sed -n ${line}p ${file})"
            sed -i "${line}d" ${file}
            echo "to"
            echo "  $(sed -n ${line}p ${file})"
        fi
    fi
}

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
        echo "info: adduser uid: ${uid}, user: ${user}."
        adduser \
        ${uid_option} \
        ${user}
    else
        echo "info: ${user} already exists."
    fi
}

function change_passwd()
{
    local user="$1"
    local passwd="$2"

    if [ -n "${passwd}" ]; then
        echo "info: change ${user}'s password."
        echo "${user}:${passwd}" | chpasswd
    else
        echo "info: delete ${user}'s password and lock."
        passwd -d ${user}
        passwd -l ${user}
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
    modify_file "${sshd_config}" "^PasswordAuthentication" "${password_authentication_line}"
}

function make_sudoer()
{
    local user="$1"
    local passwd="$2"
    local sudo="$3"

    if [ -z "${passwd}" ] && [ "${sudo}" = 'passwd' ]; then
        echo "error: options <passwd> and <sudo> conflicts."
        exit 1
    fi

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
    modify_file "${sudoers_file}" "^${user}" "${sudoer_line}"
}

function delete_sudoer()
{
    modify_file "${sudoers_file}" "^${user}" ""
}

function enable_pubkey_authentication()
{
    local pubkey_authentication_line="PubkeyAuthentication yes"
    modify_file "${sshd_config}" "^PubkeyAuthentication" "${pubkey_authentication_line}"
}

function fix_ssh_permission()
{
    local user="$1"
    local group="${user}"
    local home="/home/${user}"

    if [ -d ${home} ]; then
        chown -R ${user}:${group} ${home}
        chmod 700 ${home}
    fi
    if [ -d ${home}/.ssh ]; then
        chmod 700 ${home}/.ssh
        chmod 600 ${home}/.ssh/*
        chmod 644 ${home}/.ssh/*.pub
    fi
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
    echo "  -p,--passwd <PASSWD>            the password of the user."
    echo "                                  if you do not give this option, then you can not login by passwd, which means you must give the authorized_keys."
    echo "                                  see sshd_config(5) PasswordAuthentication PubkeyAuthentication"
    echo "  -s,--sudo <passwd|nopasswd>     give the user sudo privilege." 
    echo "                                  passwd means you can get the sudo priviledge with input the passwd; nopasswd give you the nopasswd sudo privilege."
    echo "  -h,--help                       show help infomation."
}

# main
options=$(getopt -o u:p:s:h:: --longoptions uid:,user:,passwd:,sudo:,help:: -- "$@")
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

# user
if [ -n "${user}" ]; then
    if [ "${user}" = "root" ]; then
        echo "error: <user> can not be root"
        exit 1
    fi
    add_user "${uid}" "${user}"
else
    echo "error: option <user> must be set."
fi

# passwd
if [ -n "${passwd}" ]; then
    change_passwd "${user}" "${passwd}"
fi
change_password_authentication "${passwd}"

# sudoer
if [ -n "${sudo}" ]; then
    make_sudoer "${user}" "${passwd}" "${sudo}"
else
    delete_sudoer "${user}"
fi

# plugin
if [ -f "/etc/plugin.sh" ]; then
    echo "info: run /etc/plugin.sh"
    /etc/plugin.sh
fi

# make sure sshd could start successfully
mkdir -p /run/sshd
ssh-keygen -A
enable_pubkey_authentication
fix_ssh_permission "${user}"

echo "info: start openssh-server at PID 1."
exec /usr/sbin/sshd -D
