# containerized-development

Containerized development, such as C/C++ etc. also support connect to the container via ssh, 
so the vscode ssh extension could be used.

1. The ubuntu openssh server image
ubuntu-sshd: /ubuntu/sshd

2. TODO, maybe centos or whatever
  2.1 fix ubuntu-sshd's bug, if I do not use the 'passwd' option, the shell script would fail
  2.2 modify the default apt source, use ali 
  2.3 add some annotation, the ubuntu-sshd.yaml, service should be different in the same machine
