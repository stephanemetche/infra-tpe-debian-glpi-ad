<p align="center">
  <img src="assets/banner.svg" alt="Secure small-business IT infrastructure" width="100%">
</p>

<p align="center">
  <a href="README.md">🇫🇷 Français</a> · 🇬🇧 <b>English</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Debian-13-A81D33?logo=debian&logoColor=white" alt="Debian 13">
  <img src="https://img.shields.io/badge/Windows%20Server-2025-0078D6?logo=windows&logoColor=white" alt="Windows Server 2025">
  <img src="https://img.shields.io/badge/Active%20Directory-LDAP-1F4E79" alt="Active Directory">
  <img src="https://img.shields.io/badge/GLPI-12-0E4C92" alt="GLPI 12">
  <img src="https://img.shields.io/badge/Apache-2.4-D22128?logo=apache&logoColor=white" alt="Apache">
  <img src="https://img.shields.io/badge/MariaDB-11.8-003545?logo=mariadb&logoColor=white" alt="MariaDB">
  <img src="https://img.shields.io/badge/PHP-8.4-777BB4?logo=php&logoColor=white" alt="PHP 8.4">
  <img src="https://img.shields.io/badge/VMware-Workstation-607078?logo=vmware&logoColor=white" alt="VMware">
</p>

---

## 🎓 Context

> 📚 **Training project** — Hands-on lab completed at school, as part of the French professional certification **Secure Infrastructure Administrator (AIS)** at **GRETA**.
> Everything was deployed in a **virtual lab** (VMware Workstation): this is not a real customer engagement.

## 🏢 The scenario

> **Menuiserie Valloire** is a **fictional company** created to give the lab a realistic setting: a 20-person joinery business near Tours (France), with a workshop, a design office and an admin team.

Its IT grew without a plan: separate accounts everywhere, no hardware inventory, data on a single disk and no tested backup.

**My mission:** build a solid, secure and maintainable foundation:

| Business need | What I delivered |
|---|---|
| Don't lose data when a disk fails | Debian server on **software RAID 1**, disk failure tested for real |
| Recover from mistakes | **Backups** on a dedicated disk + **tested restore** |
| One account per employee | **Active Directory** connected to GLPI over **LDAP** |
| Know what's in the fleet | **Automatic inventory** of servers and workstations (GLPI agents) |
| Track requests and incidents | **GLPI**, open-source ITSM |
| Reduce the attack surface | **Key-only SSH**, **UFW** firewall, least privilege everywhere |

---

## 🗺️ Architecture

```mermaid
flowchart LR
    subgraph NAT["Network 192.168.60.0/24"]
        direction LR
        ADM["💻 Admin workstation<br/>PowerShell · browser"]
        GLPI["🐧 SRVGLPI01 — Debian 13<br/>192.168.60.20<br/>RAID 1 · Apache · MariaDB · PHP · GLPI<br/>backup disk · GLPI agent"]
        DC["🪟 SRV-AD — Windows Server 2025<br/>192.168.60.250<br/>AD DS · DNS · GLPI agent"]
    end
    ADM -- "SSH 2222 (key)" --> GLPI
    ADM -- "HTTP 80" --> GLPI
    GLPI -- "LDAP 389 (service account)" --> DC
    DC -- "inventory (authenticated agent)" --> GLPI
```

---

## 🧰 Skills demonstrated

| Area | What I implemented |
|---|---|
| **Storage** | Manual MBR partitioning, `mdadm` RAID 1 (3 mirrors), GRUB on both disks, **failure simulation and rebuild** |
| **Linux** | Static IP, DNS, security repositories and updates, `sudo` user, UUID-based mounts |
| **Security** | ed25519 key-only SSH, root login disabled, custom port, allow-list; UFW "deny all except"; default accounts neutralised |
| **Backup** | Timestamped `tar` archives, controlled exclusions, **restore test**, 3-2-1-1-0 analysis |
| **Web / DB** | LAMP stack, dedicated least-privilege database user, Apache VirtualHost exposing `public/` only |
| **Windows Server** | AD DS, DNS (reverse zone), users and service account via PowerShell, **GPO** |
| **Directory** | GLPI ↔ AD LDAP integration, `ldapsearch` testing, user import and authentication |
| **Asset management** | GLPI agents on Linux (Perl installer) and Windows (silent MSI), agent authentication |
| **Method** | Troubleshooting from simple to complex, test-before-apply, documented limitations |

---

## 📸 Screenshots

<table>
  <tr>
    <td width="50%"><img src="assets/screenshots/raid-disk-failure.jpg" alt="Simulated disk failure"><br><sub><b>Simulated failure</b>: one disk removed, the server keeps running in degraded mode <code>[_U]</code>.</sub></td>
    <td width="50%"><img src="assets/screenshots/raid-rebuilt.jpg" alt="RAID rebuilt"><br><sub><b>Rebuild</b>: disk re-added, all three mirrors back to <code>[UU]</code>.</sub></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/glpi-ldap-test.jpg" alt="GLPI LDAP test"><br><sub><b>LDAP integration</b>: all five GLPI checks green.</sub></td>
    <td><img src="assets/screenshots/glpi-inventory.jpg" alt="GLPI inventory"><br><sub><b>Automatic inventory</b>: Debian and Windows Server reported by their agents.</sub></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/ssh-hardening-tests.jpg" alt="SSH tests"><br><sub><b>Hardened SSH</b>: key accepted; port 22, password and root rejected.</sub></td>
    <td><img src="assets/screenshots/backup-restore-test.jpg" alt="Restore test"><br><sub><b>Verified backup</b>: restored files identical to the originals.</sub></td>
  </tr>
</table>

*(Screenshots are from a French-language environment.)*

---

## 💽 Case study: the silent degraded RAID

Right after installation, the server ran perfectly… while one of its mirrors had **only one disk**, with no alert at all. Detection, fix, then a **real disk-failure simulation** and rebuild: the full RAID 1 lifecycle, with screenshots.

➡️ **[Read the full case study (in French)](docs/raid-degrade.md)**

---

## 🔧 Troubleshooting highlights

The most valuable part of this project was the problems I ran into. Each one is documented as **Symptom → Diagnosis → Root cause → Fix**.

| Incident | Root cause | Fix |
|---|---|---|
| RAID degraded `[U_]` **with no alert** right after install | One partition was never added to its mirror | Spotted in `/proc/mdstat`, `mdadm --add` |
| Disk reconnected but **not re-added** | Linux refuses a member that missed writes | Deliberate re-add, monitored rebuild |
| **No DNS resolution** after switching to static IP | The DHCP client emptied `resolv.conf` on shutdown | DNS servers set manually |
| `sdb` **became `sdc`** after adding a disk | Names follow detection order | **UUID** mounts, double-check before formatting |
| LDAP: `Strong(er) authentication required` | Windows Server 2025 requires LDAP signing by default | GPO adjusted for the lab, **LDAPS** planned |
| GLPI agent: `403` then `authentication required` | Inventory not saved, then agent auth required | Enabled + dedicated agent credentials |

➡️ Full write-ups (in French): [docs/incidents.md](docs/incidents.md)

---

## 🛡️ Security choices and known limitations

- **Plain LDAP (389)**: acceptable on an isolated lab network. **Production → LDAPS (636)** with AD CS, then re-enforce LDAP signing.
- **Backup on the same machine**: protects against mistakes, not disasters. **Next:** off-site copy, offline copy (ransomware), scheduling, encryption.
- **HTTP without TLS** for GLPI: switch to **HTTPS** before going live.

➡️ Details (in French): [docs/securite.md](docs/securite.md)

## 🚀 Roadmap

- [ ] LDAPS with AD CS and GPO certificate auto-enrolment
- [ ] HTTPS for GLPI
- [ ] Automated, off-site, encrypted backups
- [ ] Commented, idempotent GLPI install script
- [ ] Automated Debian install (preseed + PXE)
- [ ] Monitoring (Zabbix) and centralised logging

---

<p align="center">
  <b>Stéphane Metche</b> · Secure infrastructure administrator in training · aiming for DevSecOps<br>
  <a href="https://mr-metche.com">mr-metche.com</a> · <a href="https://github.com/stephanemetche">GitHub</a>
</p>
<p align="center"><sub>School lab (AIS training, GRETA) built in a virtual environment. “Menuiserie Valloire” is a fictional company.</sub></p>
