# Documentation

## Haphazardly collected scripts & tricks I've refined while building my homelab

### Objectives

Expand the scope beyond what is available VIA Proxmox Helper Scripts

<https://community-scripts.github.io/ProxmoxVE/scripts>
<https://github.com/community-scripts/ProxmoxVE>

Reliable access to one-shot install clips and key third party package
repositories. I almost titled this you WILL lose your mind trying to remember
all of the commands, concepts and lopsided code philosophy's so document it
instead! The idea is to waste less time doing tedious configurations so
instead you can spend that time on building up something unique.

## Post Install Script Packages - Bare minimum packages to setup my workflow

<h3>apt install</h3>
sudo
iperf3
btop
gcc
make
cmake
automake
build-essential
git
unzip
lm-sensors
powertop
htop
btop
vim-nox
shim-signed
shim-helpers-amd64-signed
grub-efi-amd64-signed
proxmox-headers-6.8.12-7-pve
sbsigntool
efibootmgr
efitools
uuid-runtime
dkmssbsigntool
mokutil
devscripts
debhelper
equivs
git

## Authentication - Some PAM Modules, add or remove as needed depending on your requirements

<p>PAM or Pluggable Authentication Modules involve a variety of different
libraries used to facilitate different methods of authentication. I recommend
learning and adapting to authenticating many ways besides passwords. Eventually
I fell passwords will become obsolete and from a security standpoint it's
excellent knowledge educating yourself on these methods. A common PAM would be
a YubiKey as an alternate form of ID.

<h3>apt install</h3>
libpam-yubico
libpam-zfs
libpam-u2f
libpam-ufpidentity
libpam-ssh-agent-auth
libpam-radius-auth
libpam-python
libpam-pwquality
libpam-poldi
libpam-passwdqc
libpam-oath
libpam-modules
libpam-modules-bin
libpam-mount
libpam-mount-bin
libpam-mysql
libpam-net
libpam-ldapd
libpam-gnome-keyring
libpam-google-authenticator
libpam-doc
libpam-ccreds
libpam-cads
libpam-cgroup
libpam-alreadyloggedin
libpam-apparmor
libpam-abl
libnginx-mod-http-auth-pam
libapache2-mod-authnz-pam
libapache2-mod-intercept-form-submit
libauthen-pam-perl
libauthen-simple-pam-perl
libbio-tools-phylo-paml-perl
[EOF]
