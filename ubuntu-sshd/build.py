#!/usr/bin/env python

from jinja2 import Environment, FileSystemLoader
import argparse
import getpass
import pwd
import subprocess

# build ubuntu-sshd:focal image
subprocess.run(args=['docker', 'build', '-t', 'ubuntu-sshd:focal', '.'],
               check=True)

parser = argparse.ArgumentParser()
parser.add_argument('-n', '--name', type=str, required=True)
parser.add_argument('-p', '--port', type=int, required=True)
args = parser.parse_args()

env = Environment(loader=FileSystemLoader(searchpath='.'))
template = env.get_template(name='ubuntu-sshd.j2')

user: str = getpass.getuser()
uid: int = pwd.getpwnam(user).pw_uid
output: str = template.render(uid=uid, user=user,
                              passwd=user, name=args.name, port=args.port)
with open(file='ubuntu-sshd.yaml', mode='w') as f:
    f.write(output)

# create ubuntu-sshd container by docker-compose
subprocess.run(args=['docker-compose', '-f',
               'ubuntu-sshd.yaml', 'up', '-d'], check=True)
