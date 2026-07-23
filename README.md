*This project has been created as part of the 42 curriculum by dilferre.*

# Born2beRoot

## Description

Born2beRoot is a system administration project from the 42 curriculum. Its goal is to introduce the fundamentals of virtualization and server administration by building a secure, minimal Linux server inside a virtual machine (VirtualBox).

The project covers the full lifecycle of a small server setup:

- Installing a minimal Debian (or Rocky) system without any graphical interface.
- Configuring an encrypted LVM partitioning scheme.
- Enforcing a strong password policy and a strict `sudo` configuration.
- Hardening the system with a firewall (UFW) and a mandatory access control framework (AppArmor on Debian).
- Running an SSH service on a non-default port (4242) with root login disabled.
- Writing a `monitoring.sh` bash script that broadcasts system information to all terminals at boot and every 10 minutes.
- (Bonus) Setting up a functional WordPress site with lighttpd, MariaDB and PHP.
- (Bonus) Adding a self-chosen useful service (OpenVPN), justified during the defense.

The final deliverable is a Git repository containing only a `README.md` and a `signature.txt` (the SHA-1 of the virtual disk). The virtual machine itself is never committed.

---

## Instructions

### Prerequisites

- [VirtualBox](https://www.virtualbox.org/) (or [UTM](https://mac.getutm.app/) on Apple Silicon Macs where VirtualBox is unavailable).
- A Debian stable ISO (recommended) or a Rocky Linux stable ISO.
- Basic familiarity with the command line.

### Running the virtual machine

1. Clone the repository:
   ```bash
   git clone <repo-url> born2beroot
   cd born2beroot
   ```
2. Verify the signature of the virtual disk against `signature.txt`:
   ```bash
   # Linux / macOS
   sha1sum /path/to/<vm-name>.vdi
   # Windows (PowerShell / cmd)
   certUtil -hashfile "C:\Users\<user>\VirtualBox VMs\<vm-name>.vdi" sha1
   ```
   The output must match the content of `signature.txt` exactly. If it does not, the VM was modified after submission and the grade will be 0.

3. Import the `.vdi` into VirtualBox:
   - VirtualBox → Machine → New → Use an existing virtual hard disk file → select the `.vdi`.
   - Recommended settings: 1 CPU, 1024 MB RAM, NAT or Bridged adapter.

4. Start the VM. The login screen appears (no graphical interface — this is expected and required).

5. Connect via SSH from the host (port 4242):
   ```bash
   ssh dilferre@<VM_IP> -p 4242
   ```
   Root login over SSH is disabled by design.

### Default credentials

> Replace the placeholders below with the actual credentials set during installation. They are not stored in this repository for security reasons.

| Account | Username    | Notes |
|---------|-------------|-------|
| Root    | `root`      | SSH login disabled; console only. Password follows the strong policy. |
| User    | `dilferre`  | Member of `user42` and `sudo` groups. SSH login allowed on port 4242. |

### Services and ports

| Service    | Port       | Protocol | Purpose |
|------------|------------|----------|---------|
| SSH        | 4242       | TCP      | Remote shell (root login disabled) |
| lighttpd   | 80         | TCP      | WordPress web server (bonus) |
| OpenVPN    | 1194       | UDP      | Secure remote access tunnel (bonus) |

All other ports are blocked by UFW.

### Monitoring script

The `monitoring.sh` script is installed at `/root/monitoring.sh` inside the VM and is scheduled via root's crontab:

```cron
@reboot      sleep 30 && /root/monitoring.sh
*/10 * * * * /root/monitoring.sh
```

To interrupt it during the defense without modifying the script:

```bash
sudo systemctl stop cron
```

To resume:

```bash
sudo systemctl start cron
```

---

## Project description

### Operating system choice: Debian

Debian (latest stable) was chosen for this project. It is the recommended option for newcomers to system administration and fits the project constraints perfectly.

**Advantages:**
- Extremely stable and well-tested release cycle; the "stable" branch is production-grade.
- Massive package repository and one of the largest documentation bases among Linux distributions.
- `apt` ecosystem is straightforward and widely documented.
- AppArmor is the default mandatory access control framework, simpler to configure than SELinux.
- Low resource footprint, ideal for a minimal server VM.

**Disadvantages:**
- Packages in stable are older than in rolling distributions, which can mean missing features in newer software.
- The release cycle (roughly every 2 years) can lag behind upstream projects.
- Less suited for environments that require the latest kernel features out of the box.

### Main design choices

#### Partitioning (LVM over LUKS)

The disk is partitioned with a small unencrypted `/boot` partition and a single large encrypted (LUKS) partition that contains an LVM volume group named `LVMGroup`. Inside it, seven logical volumes are created to satisfy the bonus partitioning scheme:

```
sda
├── sda1        /boot        ~500M   (ext4, unencrypted)
└── sda5_crypt  (LUKS-encrypted)
    └── LVMGroup
        ├── root      /          ~10G    ext4
        ├── swap      [SWAP]     ~2G    swap
        ├── home      /home      ~5G    ext4
        ├── var       /var       ~3G    ext4
        ├── srv       /srv       ~3G    ext4
        ├── tmp       /tmp       ~3G    ext4
        └── var-log   /var/log   ~4G    ext4
```

Rationale:
- **Encryption (LUKS):** protects data at rest; the disk is unreadable without the passphrase, even if the `.vdi` is stolen.
- **LVM:** allows flexible resizing and management of logical volumes without repartitioning.
- **Separate volumes:** isolating `/`, `/home`, `/var`, `/srv`, `/tmp`, `/var/log` and swap prevents a single runaway process (e.g. logs filling `/var/log`) from taking down the whole system, enables per-volume mount options (e.g. `noexec` on `/tmp`), and aligns with the bonus requirement.

#### Security policies

**Password policy** (enforced via `/etc/pam.d/common-password` and `chage`):
- Passwords expire every 30 days.
- Minimum 2 days between password changes.
- Warning issued 7 days before expiration.
- Minimum length: 10 characters.
- Must contain at least one uppercase letter, one lowercase letter, and one digit.
- Must not contain more than 3 consecutive identical characters.
- Must not contain the username.
- Must differ from the previous password by at least 7 characters (does not apply to root).

**sudo configuration** (via a dedicated file in `/etc/sudoers.d/`):
- Maximum of 3 authentication attempts on incorrect password.
- Custom error message on authentication failure.
- Every `sudo` action (input and output) is logged to `/var/log/sudo/`.
- TTY mode is enabled.
- `secure_path` restricts the executable paths to:
  ```
  /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
  ```

**SSH:**
- Listens on port 4242.
- Root login is disabled (`PermitRootLogin no`).

**Firewall (UFW):**
- Active at boot.
- Only ports 4242/tcp (SSH), 80/tcp (lighttpd) and 1194/udp (OpenVPN) are open.

**Mandatory Access Control:**
- AppArmor is enabled and active at boot (`aa-status` confirms loaded profiles).

#### User management

- A non-root user `dilferre` exists and belongs to both the `user42` and `sudo` groups.
- During the defense, a new user is created and assigned to a group to demonstrate user management.

#### Services installed

| Service     | Role |
|-------------|------|
| SSH         | Remote administration on port 4242 |
| UFW         | Host firewall |
| AppArmor    | Mandatory access control |
| cron        | Schedules `monitoring.sh` |
| lighttpd    | Web server for WordPress (bonus) |
| MariaDB     | Database backend for WordPress (bonus) |
| PHP-FPM     | PHP processor for WordPress via FastCGI (bonus) |
| OpenVPN     | Secure remote access tunnel (bonus) |

### Comparisons

#### Debian vs Rocky Linux

| Aspect               | Debian | Rocky Linux |
|----------------------|--------|-------------|
| Origin               | Independent community project, one of the oldest distributions | Community successor to CentOS, RHEL-compatible |
| Package manager      | `apt` / dpkg, `.deb` packages | `dnf` / rpm, `.rpm` packages |
| Release model        | Stable / Testing / Unstable; stable every ~2 years | Rolling minor releases following RHEL upstream |
| Default MAC framework| AppArmor | SELinux |
| Default firewall     | UFW (wrapper over iptables/nftables) | firewalld (D-Bus based, zones) |
| SELinux              | Not default; can be installed but not typical | Enabled by default, must be configured for the project |
| KDump                | Not required | Not required for this project (explicitly waived) |
| Target audience      | General-purpose servers, beginners to sysadmin | Enterprise environments, RHEL ecosystem |
| Learning curve       | Gentler, vast community documentation | Steeper due to SELinux and RHEL conventions |

#### AppArmor vs SELinux

| Aspect          | AppArmor | SELinux |
|-----------------|----------|---------|
| Policy model    | Path-based: profiles reference file paths | Label-based: every object gets a security context label |
| Configuration   | Simpler, profiles in `/etc/apparmor.d/` | More complex, policies compiled and labels assigned system-wide |
| Default on      | Debian, Ubuntu, SUSE | RHEL, Rocky, Fedora, CentOS |
| Granularity     | Coarser but easier to reason about | Finer-grained, supports type enforcement and multi-category security |
| Learning curve  | Lower | Higher |
| Suitability here| Ideal for Debian beginners | Required on Rocky, more powerful but harder to configure |

#### UFW vs firewalld

| Aspect          | UFW | firewalld |
|-----------------|-----|-----------|
| Full name        | Uncomplicated Firewall | firewalld |
| Backend          | iptables / nftables (via wrapper) | iptables / nftables (via wrapper) |
| Interface        | Simple CLI (`ufw allow/ deny`) | D-Bus API + `firewall-cmd`, zone-based |
| Zones            | No zone concept | Zones (public, home, trusted, etc.) |
| Default on       | Debian, Ubuntu | RHEL, Rocky, Fedora |
| Complexity       | Low — designed for simplicity | Higher — designed for enterprise flexibility |
| Suitability here | Used on Debian (mandatory) | Used on Rocky (mandatory) |

#### VirtualBox vs UTM

| Aspect          | VirtualBox | UTM |
|-----------------|------------|-----|
| Platform        | Windows, Linux, Intel macOS | Apple Silicon macOS (also Intel macOS) |
| Backend         | Own hypervisor (VT-x/AMD-V) | QEMU under the hood |
| GUI             | Full-featured GUI, snapshots, shared folders | GUI tailored for macOS, QEMU-based |
| Performance      | Near-native on x86 hosts | Good on ARM via Apple's hypervisor |
| Snapshots        | Built-in, easy to manage | Supported via QEMU snapshots |
| Use case here   | Primary choice for the project | Fallback only when VirtualBox cannot run (e.g. Apple Silicon) |

---

## Resources

### Official documentation
- Debian Reference: https://www.debian.org/doc/
- Debian Administrator's Handbook: https://debian-handbook.info/
- LVM (Linux Documentation Project): https://tldp.org/HOWTO/LVM-HOWTO/
- LUKS / cryptsetup: https://gitlab.com/cryptsetup/cryptsetup
- AppArmor: https://apparmor.net/
- UFW / iptables: https://wiki.debian.org/Uncomplicated%20Firewall%20%28ufw%29
- sudo manual: https://www.sudo.ws/
- OpenSSH: https://www.openssh.com/manual.html
- lighttpd: https://redmine.lighttpd.net/projects/lighttpd/wiki
- MariaDB: https://mariadb.com/kb/en/documentation/
- PHP: https://www.php.net/manual/en/
- WordPress: https://wordpress.org/documentation/
- OpenVPN: https://openvpn.net/community-resources/
- Easy-RSA: https://github.com/OpenVPN/easy-rsa
- cron: https://man7.org/linux/man-pages/man8/cron.8.html

### Tutorials and articles
- DigitalOcean — Initial server setup with Debian: https://www.digitalocean.com/community/tutorials/initial-server-setup-with-debian-11
- ArchWiki — LVM on LUKS: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS
- HowtoForge — Install WordPress with lighttpd: https://www.howtoforge.com/

### How AI was used in this project

Artificial intelligence tools were used as a **support and review aid**, never as a substitute for understanding or executing the work. Specifically:

- **Concept clarification:** used to confirm the differences between AppArmor and SELinux, and between UFW and firewalld, before writing the comparison tables in this README.
- **Configuration review:** AI reviewed the `lighttpd` FastCGI configuration and the OpenVPN `server.conf` to catch syntax mistakes; all reviewed settings were then applied and tested manually inside the VM.
- **Script drafting:** `monitoring.sh` was drafted with AI assistance for the parsing logic of `/proc/meminfo` and `/proc/net/tcp`, then manually tested and adjusted so that every value matched the format required by the subject.
- **README structure:** AI helped outline the required sections of this README according to the subject; the content, design choices and justifications were written and validated by the author.

No AI tool was used to bypass the learning process: every command was executed, understood and explained by the author. The goal was to build real system administration skills, not to demonstrate that an AI can configure a server.

---

## Notes

- The virtual machine is **not** included in this repository (forbidden by the subject).
- The `signature.txt` file must be regenerated whenever the VM is modified, with the VM **powered off**, because the SHA-1 of the `.vdi` changes on every boot.
- A VirtualBox snapshot should be created after a fully working state and restored before each defense. No snapshot may be active at the start of an evaluation; the evaluator will create and delete a dedicated snapshot during the defense.
