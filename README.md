# Build Your Own System 

Build a custom system offline from scratch

## Getting Started

Configuring your own system requires knowing what you want.

## Usage

Build a Debian with Kernel 4.3.5 (based on configuration file config-4.3.5)
```
./byos.sh --file=config/debian.conf build [DEVICE] config/config-4.3.5 4.3.5
```
Update an existed whole system with Kernel 4.3.5 with Grsecurity (based on Grsecurity configuration file config-4.3.5-grsec)
```
./byos.sh --file=config/debian.conf --grsec=grsecurity/grsecurity-3.1-4.3.5-201602092235.patch update [DEVICE] config/config-4.3.5-grsec 4.3.5
```
Update an existed whole system with Kernel 4.3.5 with Grsecurity (Grsecurity configuration defined wit menuconfig)
```
./byos.sh --alt=menuconfig --file=config/debian.conf --grsec=grsecurity/grsecurity-3.1-4.3.5-201602092235.patch update [DEVICE] config/config-4.3.5-grsec 4.3.5
```

## Task lists

- [ ] Check if packages are available
- [ ] Redirect all messages (errors, outputs, etc.) into one or more files
- [ ] Check if gcc plugin is available (for GRSEC)

> Your gcc installation does not support plugins.  
> If the necessary headers for plugin support are missing, they should be installed.  
> On Debian, apt-get install gcc-<ver>-plugin-dev.  
> If you choose to ignore this error and lessen the improvements provided by this patch, re-run make with the DISABLE_PAX_PLUGINS=y argument..

## Managing multiple compiler version

Erasing current update-alternatives setup for gcc

```
sudo update-alternatives --remove-all gcc 
```

** Install Packages **

Installing compiler version packages

```
sudo apt-get install gcc-x.x gcc-x.x
```

** Install Alternatives **

Installing symbol links for gcc, then linking cc to gcc respectively.

```
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-x.x 10
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-x.x 20

sudo update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30
sudo update-alternatives --set cc /usr/bin/gcc
```

** Configure Alternatives **

Configuring commands for gcc to switch between x.x and x.x interactively:

```
sudo update-alternatives --config gcc
```

## Issue lists

- [ ] Issue with dpkg -i command

> update-initramfs: Generating /boot/initrd.img-4.3.5
> W: Possible missing firmware /lib/firmware/rtl_nic/rtl8107e-2.fw for module r8169
