# Install Debian on the homelab host from macOS

This runbook installs Debian directly on the ThinkCentre M75q-1. The finished
host is named `homelab`, runs K3s later, and uses its 256 GB NVMe for the OS and
operational data. The DAS is deliberately excluded from the OS installation.

## Before starting

- Complete and verify the Penzance migration backup. In particular, retain
  `/var/lib/penzance/config` and the NAS media data.
- Connect the ThinkCentre to the router with Ethernet.
- Disconnect the five-bay DAS and any other non-NVMe storage before booting the
  installer. This avoids selecting a media disk by mistake.
- Have an empty USB drive of at least 2 GB. **The USB contents will be erased.**
- This procedure erases the ThinkCentre's 512 GB NVMe. It does not install
  Proxmox; Debian is installed directly on the hardware.

## Create the installer USB on macOS

Download the current Debian stable amd64 netinst image from the official
[Debian download page](https://www.debian.org/download). At the time this was
written, it is Debian 13.6 (`debian-13.6.0-amd64-netinst.iso`).

Run:

```sh
mkdir -p ~/Downloads/debian-homelab
cd ~/Downloads/debian-homelab

curl -fLO https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso
curl -fLO https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS

grep ' debian-13.6.0-amd64-netinst.iso$' SHA512SUMS | shasum -a 512 -c -
```

The final command must report `OK`. Insert the USB drive and identify its disk
number carefully:

```sh
diskutil list
```

For the remainder of this example, the USB is `/dev/disk4`. Replace that value
with the USB disk from `diskutil list`; do not use the Mac's internal disk.

```sh
diskutil unmountDisk /dev/disk4
sudo dd if=debian-13.6.0-amd64-netinst.iso of=/dev/rdisk4 bs=4194304
sync
diskutil eject /dev/disk4
```

`dd` does not show a progress bar on all macOS releases. Press `Ctrl+T` in the
terminal running `dd` to print progress without stopping it.

## Firmware and boot settings

1. Insert the USB in the ThinkCentre, power it on, and use `F1` for ThinkPad/
   ThinkCentre firmware setup or `F12` for the one-time boot menu.
2. Set boot mode to **UEFI only** and disable Legacy/CSM compatibility mode.
3. Enable CPU virtualization (AMD-V/SVM on this AMD ThinkCentre).
4. Leave Secure Boot enabled.
5. Enable the firmware option named similar to **After Power Loss: Power On**.
6. Boot the Debian USB in its UEFI entry and select **Install** for the
   keyboard-driven text installer.

## Debian installer choices

Choose these values unless the installer requires a hardware-specific choice:

| Installer screen | Choice |
| --- | --- |
| Language | English |
| Location | United Kingdom |
| Keyboard | British English |
| Network | Wired Ethernet with DHCP |
| Hostname | `homelab` |
| Domain name | Leave blank |
| Root password | Leave blank, so the normal user receives sudo access |
| Normal user | `ryan` (or the intended operator account) |
| Time zone | London |
| Package mirror | `deb.debian.org` |
| Popularity contest | No |
| Software selection | Select only **SSH server** and **standard system utilities**; deselect all desktop environments, web server, print server, and other roles |

### NVMe partitioning

Choose **Guided partitioning** → **Guided - use entire disk and set up LVM**.
Select only the 256 GB internal NVMe; the DAS must still be disconnected. Use
the default guided layout and confirm the write only after checking that the
target is the internal NVMe, not the USB installer.

The installed layout created the required EFI and `/boot` partitions plus a
`homelab-vg` LVM volume group containing a 224.5 GB root logical volume and
12 GB swap. Put operational data under `/srv/operational` on the root
filesystem initially; that leaves the DAS exclusively for the retained media.

Do not select encrypted LVM: this is an unattended homelab, and requiring a
local decryption passphrase after every power failure would prevent automatic
recovery.

Install GRUB to the NVMe's UEFI boot entry when prompted. Remove the USB and
reboot after installation completes.

## First boot

Log in locally, then apply the base update and install only host administration
tools. Kubernetes and applications are installed by the later GitOps bootstrap,
not manually here.

```sh
sudo apt-get update
sudo apt-get full-upgrade -y
sudo apt-get install -y \
  ca-certificates curl git jq less tmux vim dnsutils \
  smartmontools nfs-common mergerfs snapraid
sudo reboot
```

After reboot, find the DHCP-assigned address in the router, connect from the
Mac, and install your SSH public key. Substitute the observed address:

```sh
ssh ryan@192.168.1.x
cat ~/.ssh/id_ed25519.pub | ssh ryan@192.168.1.x \
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

If `~/.ssh/id_ed25519.pub` does not exist on the Mac, generate one first:

```sh
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519
```

Reserve `192.168.1.101` for `homelab` in the router's DHCP configuration. Do
not configure the router to use Pi-hole yet: Pi-hole is introduced only after
the host, Cilium, and its health checks are working.

## Next milestones

1. Run the host CLI bootstrap from the cloned repository:

   ```sh
   ./scripts/bootstrap-host-cli.sh
   ```

   It installs a lightweight XDG-based zsh, fzf, tmux, Vim, Git, ripgrep, and
   storage/network troubleshooting environment. Log out and reconnect afterward.
2. Install and authenticate host-level Tailscale, including Tailscale SSH.
3. Reattach the DAS; identify disks by stable `/dev/disk/by-id` paths.
4. Retain the existing ext4 DAS data disk labelled `stardust`, mount it under
   `/mnt/disks/stardust` by UUID, and create the one-disk MergerFS pool at
   `/mnt/crimson`. Do not format it: it contains the retained media and
   migration backup.
5. Bootstrap pinned K3s, Cilium, and Flux from the external private Git
   repository.
6. Deploy host-level Pi-hole at `192.168.1.101`; have it serve
   `pihole.home.rpca.uk` directly. Kubernetes applications use the Cilium
   Gateway at `192.168.1.102`.

See Debian's [official installation guide](https://www.debian.org/releases/stable/amd64/)
if installer screens differ after a Debian point release.
