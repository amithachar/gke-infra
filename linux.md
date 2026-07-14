# Linux for SRE — Complete Guide (Beginner → 4+ Years Advanced) + Interview Prep

---

## How to use this guide
Each section moves from **concept → commands → real SRE scenario → interview Q&A**. Don't just memorize commands — understand *why* an SRE would reach for them at 3am during an incident. That's what interviewers are actually testing.

---

# PART 1: LINUX FUNDAMENTALS

## 1.1 What is Linux, really (for interviews)
- Linux = the **kernel** (process scheduling, memory management, device drivers, filesystem, networking stack). A "distro" (Ubuntu, RHEL, Debian, Amazon Linux) = kernel + GNU userland tools + package manager + init system.
- Everything is a file: devices (`/dev/sda`), processes (`/proc/1234`), even kernel tunables (`/proc/sys`, `/sys`).
- Boot sequence: **BIOS/UEFI → Bootloader (GRUB) → Kernel loads → initramfs → systemd (PID 1) → targets/services start**.

**Interview Q: Walk me through what happens when you power on a Linux server.**
> BIOS/UEFI does POST → hands off to bootloader (GRUB) → GRUB loads kernel + initramfs into memory → kernel initializes hardware, mounts root filesystem → kernel starts PID 1 (systemd) → systemd reads targets (like `multi-user.target` or `graphical.target`) and starts services in dependency order → login prompt / services come up.

## 1.2 The Filesystem Hierarchy (FHS)
| Path | Purpose |
|---|---|
| `/bin`, `/usr/bin` | User executables (merged on modern distros) |
| `/sbin`, `/usr/sbin` | System admin binaries |
| `/etc` | Config files |
| `/var` | Variable data: logs (`/var/log`), spool, cache |
| `/home` | User home dirs |
| `/tmp` | Temp files, cleared on reboot |
| `/opt` | Optional/third-party software |
| `/proc` | Virtual FS — live kernel/process info |
| `/sys` | Virtual FS — kernel device/driver info |
| `/dev` | Device files |
| `/mnt`, `/media` | Mount points |
| `/boot` | Kernel, GRUB config, initramfs |
| `/lib`, `/usr/lib` | Shared libraries |

**Commands:**
```bash
ls -lah                # list with hidden files, human sizes
tree -L 2               # visualize dir structure
find / -name "*.log" 2>/dev/null   # find files, suppress permission errors
find /var/log -mtime -1 -type f    # files modified in last 1 day
find / -size +100M                 # files larger than 100MB
locate nginx.conf       # fast search using prebuilt db (updatedb)
```

## 1.3 Users, Groups, Permissions
```bash
whoami; id; groups
useradd -m -s /bin/bash devuser
usermod -aG sudo devuser        # add to sudo group
passwd devuser
deluser devuser
cat /etc/passwd          # user:x:UID:GID:comment:home:shell
cat /etc/shadow          # hashed passwords (root only)
cat /etc/group
su - devuser              # switch user with env
sudo -l                   # list sudo privileges for current user
```

### Permissions
```
-rwxr-xr-- 1 root root 1024 Jul 14 10:00 file.sh
```
- Positions: type, owner(rwx), group(rwx), other(rwx)
- `r=4 w=2 x=1` → numeric mode e.g. `chmod 754 file.sh`
- `chmod`, `chown`, `chgrp`
```bash
chmod +x script.sh
chmod 644 file.txt
chown user:group file.txt
chown -R user:group /app/       # recursive
umask                            # default permission mask (022 typical)
```

### Special permissions
- **SUID (4)**: run as file owner (e.g. `/usr/bin/passwd`)
- **SGID (2)**: run as group owner; on dirs, new files inherit group
- **Sticky bit (1)**: on dirs like `/tmp`, only owner can delete their own files
```bash
chmod 4755 file      # SUID
chmod 2755 dir       # SGID
chmod 1777 /tmp      # sticky
find / -perm -4000 2>/dev/null   # find all SUID binaries (security audit!)
```

**Interview Q: A cron job run by user `app` can't write to `/data/output`, but `ls -l` shows `rwxrwxrwx`. What do you check next?**
> Beyond the standard bits, check: (1) SELinux/AppArmor context — `ls -Z`, `getenforce`, (2) filesystem mount options (`mount | grep /data` — is it `ro` or `noexec`?), (3) disk full / inode exhaustion (`df -h`, `df -i`), (4) ACLs (`getfacl /data/output`) which can override the classic bits, (5) parent directory execute permission (need `x` on every dir in the path to traverse it).

**Interview Q: Difference between hard link and soft link?**
> Hard link: another directory entry pointing to the same inode; same data, deleting original doesn't remove data until all links gone; can't cross filesystems, can't link directories. Soft (symbolic) link: a separate file containing a path reference; breaks if target moves; can cross filesystems and link directories. `ln file hardlink`, `ln -s file symlink`.

---

# PART 2: PROCESS & SYSTEM MANAGEMENT

## 2.1 Processes
```bash
ps aux                      # all processes, BSD style
ps -ef                      # all processes, standard style
ps -eLf                     # with threads
ps aux --sort=-%mem | head  # top memory consumers
top / htop                  # live view
pstree -p                   # process tree
pgrep -f nginx
pkill -f nginx
kill -15 <pid>               # SIGTERM (graceful)
kill -9 <pid>                # SIGKILL (force, no cleanup)
kill -1 <pid>                # SIGHUP (often reload config)
nice -n 10 command            # start with lower priority
renice -n 5 -p <pid>
nohup command &               # survive terminal close
disown                        # detach job from shell
jobs; fg; bg                  # job control
```

### Process states
- `R` running/runnable, `S` interruptible sleep, `D` uninterruptible sleep (usually I/O — **can't even be killed with -9**), `Z` zombie (finished but parent hasn't reaped), `T` stopped.

**Interview Q: What's a zombie process and how do you fix it?**
> A process that has terminated but its exit status hasn't been read by the parent via `wait()`, so its entry stays in the process table. You can't kill a zombie directly (it's already dead). Fix: signal or fix the parent to reap it (`kill -CHLD <parent_pid>`), or if parent is broken/exited, the zombie gets reparented to PID 1 (init/systemd) which reaps it. Too many zombies exhausts the PID table — check with `ps aux | grep Z`.

**Interview Q: What's a `D` state process and why is it dangerous?**
> Uninterruptible sleep — usually waiting on disk/NFS I/O. Cannot be killed even with SIGKILL because it's in a kernel syscall that must complete first. Multiple D-state processes usually indicate storage/NFS problems and can spike load average without CPU actually being busy.

**Interview Q: Load average is 8 on a 4-core box but CPU usage shows 20%. Explain.**
> Load average counts processes in `R` (runnable) **and** `D` (uninterruptible, usually I/O wait) states. High load with low CPU usage points to I/O bottleneck — check `iostat -x 1`, `vmstat 1`, disk latency, NFS mounts, or too many processes blocked on disk/network I/O rather than CPU contention.

## 2.2 systemd — service management
```bash
systemctl status nginx
systemctl start|stop|restart|reload nginx
systemctl enable|disable nginx        # start on boot or not
systemctl is-active nginx
systemctl list-units --type=service --state=running
systemctl list-units --failed
systemctl daemon-reload               # after editing unit files
journalctl -u nginx                   # logs for a unit
journalctl -u nginx -f                # follow (tail -f equivalent)
journalctl --since "1 hour ago"
journalctl -p err -b                  # errors since last boot
systemctl cat nginx                   # show unit file content
systemctl mask nginx                  # prevent starting even manually
systemctl get-default                 # current default target
systemctl set-default multi-user.target
```

### Unit file basics
```ini
[Unit]
Description=My App
After=network.target

[Service]
ExecStart=/usr/bin/myapp
Restart=on-failure
User=appuser

[Install]
WantedBy=multi-user.target
```

**Interview Q: A service keeps restarting/crash-looping. How do you debug?**
> `systemctl status <svc>` for restart count and last exit code → `journalctl -u <svc> -n 200 --no-pager` for logs leading to crash → check `Restart=` policy and `RestartSec` in the unit (avoid a tight restart storm) → check resource limits (`systemctl show <svc> | grep -i limit`, OOM kills via `dmesg | grep -i oom` or `journalctl -k | grep -i oom`) → check config file syntax → check dependency services (`systemctl list-dependencies <svc>`).

---

# PART 3: NETWORKING

## 3.1 Core commands
```bash
ip a                       # addresses (replaces ifconfig)
ip link show
ip route                   # routing table (replaces route -n)
ip -s link                 # interface stats (errors, drops)
ss -tulnp                  # listening ports, tcp/udp, numeric, processes (replaces netstat)
ss -tan state established
netstat -plnt              # legacy, still common in interviews
curl -I https://example.com
curl -v https://example.com          # verbose, see TLS/handshake
wget https://example.com
ping -c 4 host
traceroute host / tracepath host / mtr host   # mtr = live continuous traceroute
dig example.com
dig +short example.com
dig @8.8.8.8 example.com
nslookup example.com
host example.com
telnet host port           # test raw TCP connectivity
nc -zv host port           # port scan/check (netcat)
nc -l -p 8080              # listen on a port for testing
tcpdump -i eth0 port 443 -w capture.pcap
tcpdump -i any host 10.0.0.5 and port 80
arp -a                     # ARP cache
ip neigh                   # modern arp
```

## 3.2 DNS resolution order
`/etc/nsswitch.conf` (hosts line) → `/etc/hosts` → `/etc/resolv.conf` (nameservers) → actual DNS query. `systemd-resolved` may intercept on modern systems: `resolvectl status`.

**Interview Q: A pod/host can't resolve a hostname. How do you troubleshoot?**
> 1. `cat /etc/resolv.conf` — correct nameservers? 2. `dig example.com` vs `dig @8.8.8.8 example.com` — isolate whether it's the configured DNS server or general network. 3. `cat /etc/hosts` for overrides/typos. 4. Check `/etc/nsswitch.conf` order. 5. Check firewall/security group allows UDP/TCP 53 outbound. 6. Check MTU/fragmentation issues for large DNS responses (EDNS). 7. In containers, check the CNI/cluster DNS (CoreDNS) pod health and `/etc/resolv.conf` injected by the orchestrator.

**Interview Q: Explain the TCP 3-way handshake and TIME_WAIT.**
> Client sends SYN → server responds SYN-ACK → client sends ACK → connection established. On close, 4-way FIN exchange. TIME_WAIT: the side that initiated the close holds the socket for 2×MSL (max segment lifetime) to catch delayed packets, ensuring the connection is fully torn down before the port can be reused. High TIME_WAIT counts on busy servers (e.g., load balancers doing many short connections) can exhaust ephemeral ports — tune with `net.ipv4.tcp_tw_reuse`, `net.ipv4.ip_local_port_range`, or use connection pooling/keep-alive.

**Interview Q: How do you check what's using a specific port?**
```bash
ss -tulnp | grep :8080
lsof -i :8080
fuser 8080/tcp
```

## 3.3 Firewall
```bash
iptables -L -n -v                       # legacy
iptables -t nat -L -n -v
firewall-cmd --list-all                 # RHEL/firewalld
firewall-cmd --add-port=8080/tcp --permanent && firewall-cmd --reload
ufw status                              # Ubuntu
ufw allow 22/tcp
nft list ruleset                        # modern nftables
```

## 3.4 Network tuning knobs SREs actually touch
```bash
sysctl -a | grep tcp
sysctl net.core.somaxconn                 # max queued connections
sysctl -w net.ipv4.tcp_max_syn_backlog=4096
sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sysctl -w vm.swappiness=10
cat /proc/sys/net/ipv4/tcp_fin_timeout
# persist changes in /etc/sysctl.conf or /etc/sysctl.d/*.conf, then: sysctl -p
```

---

# PART 4: STORAGE & DISK

```bash
df -h                       # disk usage per filesystem
df -i                       # inode usage — "No space left" can mean inodes, not blocks!
du -sh /var/log/*           # size per subdir
du -sh --max-depth=1 / | sort -rh
lsblk                       # block devices tree
fdisk -l                    # partitions
mount | column -t
mount /dev/sdb1 /mnt/data
umount /mnt/data
cat /etc/fstab              # persistent mounts
blkid                       # UUIDs and filesystem types
mkfs.ext4 /dev/sdb1
fsck /dev/sdb1               # filesystem check (unmounted!)
tune2fs -l /dev/sda1          # ext filesystem info
iostat -x 1                   # disk I/O, %util, await
iotop                          # per-process disk I/O (like top)
lsof +D /mnt/data               # what's using files under a dir
lsof | grep deleted             # find "phantom" disk usage from deleted-but-open files
```

**Interview Q: `df -h` shows plenty of free space but the app says "No space left on device." Why?**
> Almost certainly inode exhaustion — `df -i` will show 100% inode usage even with free blocks. Common with apps creating huge numbers of tiny files (e.g., session files, logs, temp files). Fix: find and clean up the offending directory (`find /path -type f | wc -l` per subdir), and consider filesystem/inode-count re-provisioning.

**Interview Q: Disk shows full via `df` but `du` doesn't add up. Why?**
> Deleted-but-still-open files. A process holds a file descriptor to a file that's been unlinked (deleted) — space isn't reclaimed until the process closes it. Find with `lsof | grep deleted`, then either restart/signal the process or use `> /proc/<pid>/fd/<fd>` truncation trick, or restart the service to release the handle.

**Interview Q: How would you investigate a sudden disk I/O spike causing latency?**
> `iostat -x 1` for `%util`, `await`, `r/s`, `w/s` per device → `iotop -oa` to find the top I/O process → correlate with app logs/deploys → check for runaway logging, swapping (`vmstat 1`, `free -h` — is swap being used?), or a backup/cron job running concurrently → check RAID/disk health (`smartctl -a /dev/sda`, `cat /proc/mdstat`).

---

# PART 5: MEMORY & CPU

```bash
free -h                       # memory + swap
vmstat 1 5                     # cpu, memory, swap, io summary every 1s, 5 times
top / htop
mpstat -P ALL 1                 # per-core CPU
sar -u 1 5                       # historical/point CPU stats (sysstat package)
cat /proc/meminfo
cat /proc/cpuinfo
nproc                             # number of CPUs
uptime                             # load averages (1/5/15 min)
dmesg -T | grep -i "killed process"    # OOM killer log
cat /proc/<pid>/status                  # per-process memory detail (VmRSS etc.)
smem -tk                                 # better memory reporting (shared vs unique)
```

**Interview Q: Explain Linux load average and how to interpret 1/5/15.**
> Exponentially-damped moving averages of the number of processes in the run queue + uninterruptible I/O wait, over 1/5/15 minutes. Compare against core count: load of 4 on a 4-core box ≈ fully utilized; rising trend (1min > 5min > 15min) means load is currently increasing; falling trend means recovering. Always check *what kind* of load (CPU-bound `R` vs I/O-bound `D`) via `top`/`vmstat` before concluding.

**Interview Q: The OOM killer killed my process. How do you find out why and prevent it?**
> `dmesg -T | grep -i oom` or `journalctl -k | grep -i "out of memory"` shows which process was killed and memory state at the time. Check `oom_score_adj` per process (`/proc/<pid>/oom_score_adj`) to influence killer priority. Prevention: set proper memory limits/requests (cgroups, systemd `MemoryMax=`, container limits), fix memory leaks, add swap cautiously (masks problems, doesn't fix them), and add monitoring/alerting on memory trend before it hits OOM.

**Interview Q: What's the difference between buffer/cache memory and "used" memory — is a server with little free memory in trouble?**
> Linux aggressively uses spare RAM for page cache (file data) and buffers (block I/O metadata) since unused RAM is wasted RAM — this memory is reclaimed instantly under pressure. `free -h` "available" column (not "free") is the real metric for how much memory apps can actually get. Low "free" with high "available" is normal and healthy, not a problem.

---

# PART 6: LOGS & TROUBLESHOOTING WORKFLOW

```bash
tail -f /var/log/syslog          # or /var/log/messages on RHEL
journalctl -f
journalctl -u sshd --since "10 min ago"
journalctl --disk-usage
journalctl --vacuum-time=7d       # trim old logs
grep -i error /var/log/app.log | tail -50
grep -A5 -B5 "Exception" app.log   # context lines
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head    # top IPs
zgrep "error" app.log.gz            # search inside gzipped logs
logrotate -d /etc/logrotate.conf     # dry-run log rotation config
```

### A general SRE incident troubleshooting flow (very commonly asked)
1. **Confirm and scope the alert** — is it real, one host or fleet-wide, one region?
2. **Check recent changes** — deploys, config changes, feature flags (`git log`, deployment tool history) — most incidents are caused by a recent change.
3. **Golden signals** — latency, traffic, errors, saturation (from dashboards/metrics).
4. **Host-level triage** — `uptime`, `top`, `free -h`, `df -h`, `dmesg`, `journalctl -p err`.
5. **Application logs** — errors/exceptions around the incident window.
6. **Network** — connectivity to dependencies (`ss`, `curl`, `dig`, `tcpdump` if needed).
7. **Mitigate first, root-cause later** — rollback, restart, scale out, failover — restore service, then do full RCA/postmortem.
8. **Postmortem** — blameless, document timeline, contributing factors, and action items.

**Interview Q: Production is down. Walk me through your first 5 minutes.**
> Acknowledge the alert, check if it's a known/expected issue (maintenance window?), check the monitoring dashboard for scope (all hosts vs one, one region vs global), check very recent deploys/changes as the most likely cause, and decide fast: is a rollback/failover safe and faster than root-causing live? Communicate status to stakeholders early even before full RCA. Bias toward mitigation over investigation when user impact is ongoing.

---

# PART 7: PACKAGE MANAGEMENT

```bash
# Debian/Ubuntu
apt update && apt upgrade
apt install nginx
apt remove nginx / apt purge nginx
apt list --installed | grep nginx
dpkg -l | grep nginx
dpkg -L nginx           # files owned by package

# RHEL/CentOS/Fedora
yum install nginx / dnf install nginx
yum list installed | grep nginx
rpm -qa | grep nginx
rpm -ql nginx            # files owned by package
rpm -qf /etc/nginx/nginx.conf   # which package owns this file
yum history               # transaction history, can undo
```

---

# PART 8: SHELL SCRIPTING FOR SRE

```bash
#!/bin/bash
set -euo pipefail   # exit on error, undefined var, and fail on pipe errors — ALWAYS use in prod scripts

# variables & arithmetic
count=$((count + 1))
name="${1:-default}"           # default if $1 unset

# conditionals
if [[ -f "$file" ]]; then echo "exists"; fi
if [[ -z "$var" ]]; then echo "empty"; fi
if ping -c1 host &>/dev/null; then echo "up"; fi

# loops
for f in /var/log/*.log; do echo "$f"; done
while read -r line; do echo "$line"; done < file.txt

# functions
check_disk() {
  local usage
  usage=$(df / | awk 'NR==2{print $5}' | tr -d '%')
  if (( usage > 90 )); then echo "ALERT: disk at ${usage}%"; fi
}

# trap for cleanup on exit/signal
trap 'rm -f /tmp/lockfile; echo "cleaned up"' EXIT

# common text processing
awk -F: '{print $1}' /etc/passwd            # field splitting
sed -i 's/foo/bar/g' file.txt                # in-place replace
sed -n '10,20p' file.txt                      # print lines 10-20
grep -c "ERROR" app.log                        # count matches
sort -k2 -n file.txt | uniq -c
cut -d',' -f2 data.csv
xargs -I{} kill -9 {} < pids.txt
```

**Interview Q: Why `set -euo pipefail` in every script?**
> `-e` exits immediately on any non-zero exit code (prevents silently continuing after a failed command). `-u` treats unset variables as errors (catches typos in var names before they cause damage). `pipefail` makes a pipeline's exit code reflect the *last failing* command, not just the last command — otherwise `cmd_that_fails | grep something` could report success. Together they turn silent partial failures into loud, fast ones — critical for scripts that touch production.

**Interview Q: Write a one-liner to find and kill the top memory-consuming process (careful framing question).**
```bash
ps aux --sort=-%mem | awk 'NR==2{print $2}' | xargs -r kill -9
```
> But the better answer in an interview: explain you'd rarely do this blindly in prod — you'd first identify *why* memory is high, check if it's expected (e.g. a JVM with a large heap), and prefer a graceful `SIGTERM`/service restart over `-9` unless the process is unresponsive.

---

# PART 9: SECURITY & HARDENING

```bash
last -a                        # login history
lastb                           # failed login attempts
who / w                          # current logged in users
faillog -a                        # failed login counts
ssh-keygen -t ed25519
ssh -i key.pem user@host
cat ~/.ssh/authorized_keys
sshd -T | grep -i permitrootlogin     # effective sshd config
fail2ban-client status sshd            # brute-force protection
getenforce / setenforce 0               # SELinux mode (enforcing/permissive)
sestatus
aa-status                                # AppArmor status (Ubuntu)
auditctl -l                               # audit rules
ausearch -m avc                            # SELinux denials
openssl x509 -in cert.pem -noout -dates    # cert expiry check
openssl s_client -connect host:443 -servername host   # TLS handshake debug
find / -perm -4000 2>/dev/null              # SUID audit
find / -nouser -o -nogroup 2>/dev/null      # orphaned files (security smell)
```

**Interview Q: How do you harden SSH access on a fleet of servers?**
> Disable root login (`PermitRootLogin no`), disable password auth in favor of key-based (`PasswordAuthentication no`), change/limit listening interfaces, use `fail2ban` or similar for brute-force throttling, restrict via `AllowUsers`/`AllowGroups`, enforce key algorithms (disable weak ciphers), use bastion/jump hosts + short-lived certificates where possible, and centralize auth via SSO/IAM rather than static keys per host.

**Interview Q: How does SELinux differ from standard Unix permissions, and how would you debug an SELinux denial?**
> Standard permissions are discretionary (owner/group/other, DAC). SELinux is mandatory access control (MAC) — even root is constrained by policy; every process and file has a security context (`ls -Z`, `ps -Z`), and policy defines which contexts can interact regardless of file permission bits. Debug: `getenforce` to confirm it's enforcing, `ausearch -m avc -ts recent` or `journalctl` for AVC denials, `sealert -a /var/log/audit/audit.log` for human-readable explanation, then either fix context (`chcon`, `restorecon`) or generate a policy module (`audit2allow`) rather than just disabling SELinux.

---

# PART 10: CONTAINERS, CGROUPS & NAMESPACES (increasingly expected at 4+ yrs)

- **Namespaces** isolate *what a process can see*: PID, net, mount, UTS, IPC, user namespaces. This is how a container gets "its own" process tree, network stack, filesystem view.
- **cgroups** (control groups) limit/account *what a process can use*: CPU, memory, I/O, PIDs. This is how Docker/Kubernetes enforce resource limits/requests.
- Containers = namespaces (isolation) + cgroups (limits) + a layered filesystem (image), not a separate kernel.

```bash
docker ps -a
docker logs -f <container>
docker inspect <container> | jq '.[0].State'
docker exec -it <container> /bin/bash
docker stats                              # live cgroup-based resource usage
cat /sys/fs/cgroup/memory.max              # cgroup v2 memory limit for current cgroup
systemd-cgls                                # view cgroup tree
nsenter -t <pid> -n ip a                     # inspect another process's network namespace
lsns                                          # list namespaces
kubectl top pod / kubectl top node             # if on k8s
kubectl describe pod <pod>                       # events, resource limits, restarts
kubectl logs <pod> -c <container> --previous       # logs from before last crash
```

**Interview Q: A container keeps getting OOMKilled even though the host has free memory. Why?**
> The container is bound by its **cgroup memory limit**, not host-wide memory — if the process inside exceeds the cgroup's `memory.max`, the kernel OOM-kills it regardless of host headroom. Check `docker inspect` / `kubectl describe pod` for the configured limit vs actual usage trend, check for memory leaks, and consider whether the limit is simply too low for the workload's real footprint (e.g., JVM heap + off-heap + thread stacks all count).

**Interview Q: How is a container different from a VM, at the kernel level?**
> A VM virtualizes hardware and runs a full separate kernel via a hypervisor — strong isolation, heavier overhead. A container shares the host kernel and is isolated via namespaces (process/network/mount view) and constrained via cgroups (resource limits) — lightweight, fast startup, but weaker isolation boundary since a kernel exploit can potentially affect the host.

---

# PART 11: BOOT / RECOVERY TROUBLESHOOTING (senior-level favorite)

**Interview Q: A server won't boot after a kernel update. How do you recover?**
> Boot into GRUB menu (interrupt at splash screen), select the previous kernel version from the boot list to confirm it's kernel-specific, then either roll back the default boot entry (`grub2-set-default` / edit `/etc/default/grub` + `grub2-mkconfig`) or fix the new kernel's initramfs (`dracut -f` on RHEL, `update-initramfs -u` on Debian). If GRUB itself is broken, boot from rescue/live media, chroot into the installed system, and reinstall GRUB (`grub-install /dev/sda`).

**Interview Q: Root filesystem won't mount at boot — "fsck failed" — what now?**
> Boot into rescue mode / single-user mode via GRUB kernel parameter (`single` or `systemd.unit=rescue.target`), run `fsck` manually against the unmounted device (never fsck a mounted filesystem), review `/etc/fstab` for a bad entry (typo'd UUID, wrong mount options), and add `nofail` to non-critical mounts so one bad disk doesn't block the entire boot.

**Interview Q: How would you reset a forgotten root password?**
> Reboot, interrupt GRUB, edit the boot entry to append `init=/bin/bash` (or `rd.break` on RHEL8+) to boot directly to a shell bypassing normal init, remount root as read-write (`mount -o remount,rw /`), run `passwd root`, then reboot normally. On systems with SELinux, may need to touch `/.autorelabel` to fix contexts after rd.break edits.

---

# PART 12: RAPID-FIRE INTERVIEW Q&A BANK

### Beginner level
- **Q: Difference between `/etc` and `/var`?** → `/etc` is static config; `/var` is variable/runtime data (logs, spool, cache) that changes constantly.
- **Q: What does `chmod 755` mean?** → Owner: rwx (7), group: r-x (5), other: r-x (5).
- **Q: Difference between `>` and `>>`?** → `>` overwrites/truncates the file, `>>` appends.
- **Q: What's the difference between a process and a thread?** → A process has its own memory space and resources; threads within a process share the same memory space but have their own stack/registers — cheaper to create/switch between.
- **Q: How do you check disk space?** → `df -h` for filesystems, `du -sh` for directory sizes.
- **Q: What is `/etc/fstab`?** → Table defining filesystems to mount at boot (device, mount point, type, options, dump, fsck order).

### Intermediate level
- **Q: Difference between `SIGTERM` and `SIGKILL`?** → SIGTERM (15) asks the process to terminate gracefully (can be caught/handled for cleanup); SIGKILL (9) is immediate, unconditional termination by the kernel, no cleanup possible.
- **Q: How do cron jobs work, and how do you debug a cron job that "works manually but not in cron"?** → Cron runs with a minimal environment (no full `$PATH`, no interactive shell profile). Fix by using absolute paths in the script, explicitly sourcing environment/profile, and redirecting output to a log file (`* * * * * /path/script.sh >> /var/log/script.log 2>&1`) to capture errors.
- **Q: What's the difference between `su` and `sudo`?** → `su` switches to another user's full session (needs their password by default); `sudo` runs a single command as another user (typically root) using the *invoker's* own password, with fine-grained control via `/etc/sudoers` and full audit logging.
- **Q: Explain `/proc/loadavg` vs `/proc/stat`.** → `loadavg` gives the 1/5/15 min load averages plus running/total process counts; `stat` gives raw cumulative CPU time counters (user/nice/system/idle/iowait) since boot, used to calculate CPU% over an interval.
- **Q: How does DNS caching work on a Linux host?** → Depends on the resolver stack — `systemd-resolved` or `nscd`/`dnsmasq` may cache locally; otherwise each app or the glibc resolver queries upstream per TTL. Check `resolvectl statistics` or the relevant cache daemon.

### Advanced / 4+ years level
- **Q: How would you design monitoring/alerting for disk space to avoid pager fatigue?** → Alert on rate-of-change/time-to-full prediction, not just static thresholds (e.g., "will hit 100% in <4h" vs a flat "90% used" that might be normal for a log volume); use different severities for warn vs page; auto-remediate where safe (log rotation, temp cleanup) before paging a human.
- **Q: Explain the difference between cgroup v1 and v2.** → v1 has separate hierarchies per controller (cpu, memory, blkio mounted independently, can get inconsistent); v2 uses a single unified hierarchy with consistent controller interfaces, better delegation to containers, and is the default on modern distros/kernels (5.8+ widely, though adoption varies by orchestrator).
- **Q: How do you approach capacity planning for a fleet using only Linux-level metrics?** → Track trends (not snapshots) in CPU, memory, disk growth rate, network throughput, and load average over weeks/months; correlate with business metrics (traffic growth); use percentile-based (p95/p99) rather than average utilization since averages hide bursty saturation; project forward to trigger scaling before hitting limits, with headroom for failover capacity (N+1 or N+2).
- **Q: What's your approach to writing a Linux runbook/postmortem culture on a team?** → Blameless postmortems focused on systemic and process gaps, not individual blame; runbooks should include: symptom description, diagnostic commands with expected/abnormal output, mitigation steps in priority order, and escalation path; runbooks are living docs — tested/updated after every real incident that touches them, ideally via chaos/game-day exercises rather than left untouched until the next real fire.
- **Q: How do you detect and mitigate a "noisy neighbor" problem on a shared host/cluster?** → Use `cgroups` metrics (`docker stats`, `kubectl top`) to isolate which container/process is consuming disproportionate CPU/memory/IO; check `iostat`/`pidstat` per-process; enforce resource requests/limits and CPU/IO priority (`ionice`, `cpu.shares`/`cpu.weight`) so one workload can't starve others; consider dedicated node pools or taints/tolerations in k8s for noisy or critical workloads.
- **Q: Explain `strace` and when you'd use it in production.** → `strace -p <pid>` (or `-f` for child processes) traces system calls a process makes in real time — invaluable for "why is this hung/slow" when logs show nothing, e.g., seeing it's stuck in a `read()`/`connect()` syscall to a dead dependency. Use cautiously in production (adds overhead, can pause the traced process briefly); prefer `strace -c` for a summarized syscall count/time profile over long attach sessions. Related: `ltrace` for library calls, `perf top`/`perf record` for CPU profiling without the overhead of strace.
- **Q: What's the difference between vertical and horizontal scaling from an OS/kernel perspective, and where does Linux itself become the bottleneck?** → Vertical scaling (bigger box) can hit kernel-level ceilings: file descriptor limits (`ulimit -n`, `/proc/sys/fs/file-max`), NUMA effects on multi-socket memory access latency, single-threaded bottlenecks in the app itself, and network stack limits (`somaxconn`, ephemeral port exhaustion). Horizontal scaling avoids single-host ceilings but introduces coordination/consistency overhead — the OS-level lesson is that scaling isn't just "add more," it's understanding which specific kernel resource (fds, ports, memory, PIDs) actually constrains you first.

---

# PART 13: MUST-KNOW COMMAND CHEAT SHEET (quick reference)

| Task | Command |
|---|---|
| Disk usage | `df -h`, `du -sh` |
| Inode usage | `df -i` |
| Memory | `free -h`, `cat /proc/meminfo` |
| CPU load | `top`, `htop`, `uptime`, `mpstat` |
| Processes | `ps aux`, `pstree`, `pgrep`, `pkill` |
| Network sockets | `ss -tulnp`, `lsof -i` |
| Network path | `traceroute`, `mtr`, `ping` |
| DNS | `dig`, `nslookup`, `host` |
| Packet capture | `tcpdump` |
| Service mgmt | `systemctl`, `journalctl` |
| Logs | `tail -f`, `journalctl -f`, `grep` |
| Find files | `find`, `locate` |
| Permissions | `chmod`, `chown`, `getfacl`/`setfacl` |
| Archive | `tar -czvf`, `tar -xzvf` |
| Text processing | `awk`, `sed`, `grep`, `cut`, `sort`, `uniq` |
| Disk I/O | `iostat -x 1`, `iotop` |
| Kernel messages | `dmesg -T` |
| Users/auth | `last`, `who`, `w`, `id` |
| Cron | `crontab -l`, `crontab -e`, `/etc/cron.d/` |
| SSH debug | `ssh -vvv`, `sshd -T` |
| Syscall trace | `strace -p <pid>` |
| Compression | `gzip`, `zcat`, `zgrep` |
| Package (Debian) | `apt`, `dpkg` |
| Package (RHEL) | `yum`/`dnf`, `rpm` |

---

# PART 14: 30-60-90 DAY STUDY ROADMAP (since you're starting fresh but targeting 4+ yr roles)

**Weeks 1–2 (Foundations):** filesystem hierarchy, permissions/ownership, users/groups, basic bash, `ps`/`top`/`kill`, package managers. Practice: spin up a free-tier VM (or local VM/WSL) and do everything hands-on — don't just read.

**Weeks 3–4 (Services & Networking):** systemd deep-dive, journalctl, `ip`/`ss`/`dig`/`curl`, firewall basics, SSH hardening. Practice: break a service on purpose (bad config, wrong permission) and practice diagnosing it blind.

**Weeks 5–6 (Storage, Performance, Scripting):** disk/inode troubleshooting, `iostat`/`vmstat`/`free` interpretation, write 5+ real bash scripts (health check, log rotation, disk alert) with `set -euo pipefail`.

**Weeks 7–8 (Containers & Advanced Troubleshooting):** namespaces/cgroups, Docker basics, `strace`, OOM killer behavior, boot/GRUB recovery in a disposable VM (intentionally corrupt and recover one).

**Weeks 9–12 (Interview polish + systems thinking):** Practice explaining tradeoffs out loud (not just commands) — capacity planning, incident response flow, postmortem culture. Do mock troubleshooting scenarios: "load average high but CPU low," "disk full but du doesn't match," "service crash-looping," "DNS resolution failing" — all covered above — until you can talk through the diagnostic *sequence*, not just the final command.

> The single biggest differentiator interviewers look for at the 4+ year SRE level isn't command trivia — it's **diagnostic sequencing**: knowing *which command to run first* to narrow down a problem fastest, and being able to explain *why* each step ruled something in or out. Practice narrating your troubleshooting out loud, not just doing it.

---
*End of guide. Good luck — treat every command above as something to actually run on a test VM, not just read.*

