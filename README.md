# Documentation

## Haphazardly collected scripts & tricks I've refined while building my homelab

### Objectives

Expand the scope beyond what is available VIA Proxmox Helper Scripts

<https://community-scripts.github.io/ProxmoxVE/scripts>
<https://github.com/community-scripts/ProxmoxVE>

Reliable access to one-shot install clips and key third party package
repositories. So many concepts and lopsided code philosophy's have led
me to just document it instead! Waste less time doing tedious configurations
so you can instead spend that time building something unique.

## Post Install Script Packages - Bare minimum packages to setup my workflow

<p>These are the packages I install after every Proxmox install, the only changes
that take place before this are running the Post-Installation Script and the CPU
Microcode security patches both of which can be found VIA the following links.

### Post-Install Script

<https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install>

### Microcode Patches

<https://community-scripts.github.io/ProxmoxVE/scripts?id=microcode>

#### Some optional items depending on your use-case

### CPU Scaling Governor

<p> This allows you to set a power/performance profile to your CPU(s) assuming
they support a variety of profiles, some only support one or two.

<https://community-scripts.github.io/ProxmoxVE/scripts?id=scaling-governor>

### Host Backup

<p> Enables extensive customization of backup outputs and location, not to
be confused with Proxmox Backup Server.

<https://community-scripts.github.io/ProxmoxVE/scripts?id=host-backup>

### Proxmox Datacenter Manager

<https://community-scripts.github.io/ProxmoxVE/scripts?id=proxmox-datacenter-manager>

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
