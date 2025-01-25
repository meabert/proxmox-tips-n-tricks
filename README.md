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

### Bare minimum packages to setup my workflow

<p>These are the packages I install after every Proxmox install, the only changes
that take place before this are running the Post-Installation Script and the CPU
Microcode security patches both of which can be found VIA the following links.

#### Post-Install Script

<https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install>

#### Microcode Patches

<https://community-scripts.github.io/ProxmoxVE/scripts?id=microcode>

### Some optional items depending on your use-case

#### CPU Scaling Governor

<p> This allows you to set a power/performance profile to your CPU(s) assuming
they support a variety of profiles, some only support one or two.

<https://community-scripts.github.io/ProxmoxVE/scripts?id=scaling-governor>

#### Host Backup

<p> Enables extensive customization of backup outputs and location, not to
be confused with Proxmox Backup Server.

<https://community-scripts.github.io/ProxmoxVE/scripts?id=host-backup>

#### Proxmox Data Center Manager

<https://community-scripts.github.io/ProxmoxVE/scripts?id=proxmox-datacenter-manager>

### Manually added packages

<h3>apt install</h3>
sudo<br />
iperf3<br />
btop<br />
gcc<br />
make<br />
cmake<br />
automake<br />
build-essential<br />
git<br />
unzip<br />
lm-sensors<br />
powertop<br />
htop<br />
btop<br />
vim-nox<br />
shim-signed<br />
shim-helpers-amd64-signed<br />
grub-efi-amd64-signed<br />
proxmox-headers-6.8.12-7-pve<br />
sbsigntool<br />
efibootmgr<br />
efitools<br />
uuid-runtime<br />
dkmssbsigntool<br />
mokutil<br />
devscripts<br />
debhelper<br />
equivs<br />
git<br />

### Authentication - PAM Modules, add or remove as needed depending on your use case

<p>PAM or Pluggable Authentication Modules involve a variety of different
libraries used to facilitate different methods of authentication. I recommend
learning and adapting to various forms of authentication besides passwords.
Eventually passwords will become obsolete and from a security standpoint it's
excellent knowledge educating yourself on these methods. A common PAM would be
a YubiKey as an alternate form of ID, knowing this basic concept you can apply this
same concept to the libpam-zfs library as an example, this library is for
unlocking ZFS encrypted partitions.

<h3>apt install</h3>
libpam-yubico<br />
libpam-zfs<br />
libpam-u2f<br />
libpam-ufpidentity<br />
libpam-ssh-agent-auth<br />
libpam-radius-auth<br />
libpam-python<br />
libpam-pwquality<br />
libpam-poldi<br />
libpam-oath<br />
libpam-modules<br />
libpam-modules-bin<br />
libpam-mount<br />
libpam-mount-bin<br />
libpam-mysql<br />
libpam-gnome-keyring<br />
libpam-google-authenticator<br />
libpam-doc<br />
libpam-ccreds<br />
libpam-cads<br />
libpam-cgroup<br />
libpam-alreadyloggedin<br />
libpam-apparmor<br />
libpam-abl<br />
libnginx-mod-http-auth-pam<br />
libapache2-mod-authnz-pam<br />
libapache2-mod-intercept-form-submit<br />
libauthen-pam-perl<br />
libauthen-simple-pam-perl<br />
libbio-tools-phylo-paml-perl<br />
[EOF]
