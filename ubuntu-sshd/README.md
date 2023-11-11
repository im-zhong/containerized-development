## ubuntu-sshd

This image is for those who want to connect to a container via ssh.
Tou could use this image to start an openssh-server and expose its port, 
then you could just use `ssh -p PORT user@hostname` to connect into it.

There are two main ways you could use this image:
The first and the simplest, just get if from docker hub and use it.
    `docker pull zhong/ubuntu-sshd`
then, run it to check help infomation
    `docker run zhong/ubuntu-sshd` or `docker run zhong/ubuntu-sshd -h`
will show help infomation.

The second way is clone this project,
    `git clone git@github.com:im-zhong/containerized-development.git`
and cd to this directory
    `cd ubuntu/sshd`
then, you could build the docker image yourself and use it.

You must add a new user to the container, and also prepare a home directory
to be the volume.
the home directory in this project provide the default bash file for you, which
you could use it directly as your home volume, or you can prepare one yourself.

The last one important thing is you could provide the public key and use public key
authentication otherwise through password. you could use the option --authorized_keys.
But, the simplest way is just create a directory in the home called .ssh, and put the
file 'authorized_keys' in it. the openssh-server will use it as default.
And every start and restart of this image, the public key file will be COPY to that default
location and OVERWRITE the old file, be aware.
