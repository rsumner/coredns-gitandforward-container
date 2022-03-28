# CoreDNS container with git plugin for authoritative zones and forwarding

To find dependencies for SSH and Git during build, you can run these
commands, put them into a file and sort-unique them. 

* ldd /usr/bin/ssh | cut -d '>' -f 2 | awk '{print $1}')
* ldd /usr/bin/git | cut -d '>' -f 2 | awk '{print $1}')

