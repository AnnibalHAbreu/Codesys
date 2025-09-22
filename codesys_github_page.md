# Technical Note: CODESYS Runtime Reset Guide for Raspberry Pi

**Author:** [Your Name]  
**Date:** September 22, 2025  
**Version:** 1.0  
**Tested with:** CODESYS Development Tool 3.5 SP21 Patch 2  

---

## 📋 Overview

This technical note provides comprehensive procedures to reset the CODESYS Control runtime on Raspberry Pi devices. Two methods are covered:

- **🔧 User-only reset** — preserves applications and runtime configuration
- **⚙️ Complete factory reset** — restores runtime to default state

## 🎯 Scope and Applications

- **Target Platform:** Raspberry Pi with CODESYS Control runtime
- **Use Cases:** Recovery from locked admin access, corrupted user databases, factory reset scenarios
- **Requirements:** SSH access and administrative privileges

---

## 📚 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Method 1: User-Only Reset](#method-1-user-only-reset-lightweight)
3. [Method 2: Complete Factory Reset](#method-2-complete-factory-reset)
4. [Automated Shell Script](#automated-shell-script)
5. [Best Practices](#best-practices-and-recommendations)
6. [Downloads and Resources](#downloads-and-resources)

---

## 🔐 Prerequisites

Before proceeding with any reset procedure, ensure you have:

- ✅ Raspberry Pi running CODESYS Control runtime
- ✅ SSH client (PuTTY, Terminal, or similar)
- ✅ Administrative (`sudo`) privileges on the Pi
- ✅ Network connectivity to the Raspberry Pi
- ⚠️ **Important:** Backup of critical applications and configurations

**Tested Environment:**
- CODESYS Development Tool 3.5 SP21 Patch 2
- Raspberry Pi OS (Debian-based)
- CODESYS Control for Raspberry Pi

---

## Method 1: User-Only Reset (Lightweight)

This method removes only users, groups, and user-management rights while preserving all applications and runtime configurations.

### When to Use
- 🔑 Lost admin password or user access
- 👥 Need to clean up user accounts
- 🛡️ User database corruption
- ✅ Applications must remain intact

### Step-by-Step Procedure

```bash
# 1. Connect via SSH and stop the runtime
sudo systemctl stop CODESYSControl

# 2. Create backup directory
sudo mkdir -p /root/codesys-user-backup

# 3. Backup user-related files (recommended)
sudo cp -a /var/opt/codesys/.UserDatabase* /root/codesys-user-backup/
sudo cp -a /var/opt/codesys/.GroupDatabase* /root/codesys-user-backup/
sudo cp -a /var/opt/codesys/.UserMgmtRightsDb* /root/codesys-user-backup/

# 4. Remove user databases
sudo rm -f /var/opt/codesys/.UserDatabase*
sudo rm -f /var/opt/codesys/.GroupDatabase*
sudo rm -f /var/opt/codesys/.UserMgmtRightsDb*

# 5. Restart the runtime
sudo systemctl start CODESYSControl
```

### ✅ Expected Results
- Applications and runtime configuration remain intact
- All user accounts are removed
- New admin user required on next IDE connection
- **Next step:** Create admin user via **Tools → License Manager** in CODESYS IDE

---

## Method 2: Complete Factory Reset

This method removes **all runtime configuration**, including users, policies, applications, and boot applications.

### When to Use
- 🏭 Complete fresh start required
- 💥 Corrupted runtime configuration
- 🔄 Preparing device for new deployment
- ⚠️ **Warning:** All data will be lost

### Step-by-Step Procedure

```bash
# 1. Stop the runtime service
sudo systemctl stop CODESYSControl

# 2. Backup entire configuration (optional but recommended)
sudo mv /var/opt/codesys /var/opt/codesys.bak.$(date +%Y%m%d-%H%M%S)

# 3. Create new empty configuration directory
sudo mkdir -p /var/opt/codesys
sudo chown -R root:root /var/opt/codesys

# 4. Restart runtime service
sudo systemctl start CODESYSControl
```

### ⚠️ Expected Results
- **Complete factory reset** — all data removed
- Runtime restored to default state
- All users, policies, and applications deleted
- **Next step:** Create admin user via **Tools → License Manager** in CODESYS IDE

---

## 🤖 Automated Shell Script

For convenience, use this automated script that combines both reset methods with interactive selection:

```bash
#!/bin/bash
# reset-codesys-runtime.sh
# Author: [Your Name]
# Date: September 22, 2025
# Description: Interactive script to reset CODESYS Runtime on Raspberry Pi
# Tested with: CODESYS Development Tool 3.5 SP21 Patch 2

RUNTIME_DIR="/var/opt/codesys"
BACKUP_DIR="/root/codesys-backup-$(date +%Y%m%d-%H%M%S)"

echo "===== CODESYS Runtime Reset Script ====="
echo "Stopping CODESYS runtime service..."
sudo systemctl stop CODESYSControl
sleep 2

echo "Creating backup at $BACKUP_DIR ..."
sudo mkdir -p "$BACKUP_DIR"
sudo cp -a "$RUNTIME_DIR"/* "$BACKUP_DIR"/ 2>/dev/null || true

echo ""
echo "Select reset option:"
echo "1) Reset only users (keep applications and configs)"
echo "2) Reset entire runtime (factory reset)"
read -p "Enter choice [1 or 2]: " choice

case "$choice" in
    1)
        echo "Resetting only users..."
        sudo rm -f "$RUNTIME_DIR"/.UserDatabase* \
                  "$RUNTIME_DIR"/.GroupDatabase* \
                  "$RUNTIME_DIR"/.UserMgmtRightsDb*
        echo "✅ Users removed. Applications and configs remain intact."
        ;;
    2)
        echo "Resetting entire runtime configuration..."
        sudo mv "$RUNTIME_DIR" "${RUNTIME_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
        sudo mkdir -p "$RUNTIME_DIR"
        sudo chown -R root:root "$RUNTIME_DIR"
        echo "✅ Entire runtime reset to factory defaults."
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "Restarting CODESYS runtime service..."
sudo systemctl start CODESYSControl
sleep 3

echo "===== Reset Complete ====="
echo "📁 Backup stored at: $BACKUP_DIR"
echo "🔧 Next: Use CODESYS IDE -> Tools -> License Manager to create admin user"
echo "=============================================="
```

### 📥 Download Script
```bash
# Download and make executable
wget https://raw.githubusercontent.com/[username]/[repo]/main/reset-codesys-runtime.sh
chmod +x reset-codesys-runtime.sh

# Run the script
./reset-codesys-runtime.sh
```

---

## 🛡️ Best Practices and Recommendations

### Before Reset
- 💾 **Always backup critical applications and configurations**
- 📝 Document current user accounts and permissions
- 🔍 Verify SSH access and sudo privileges
- ⏰ Plan downtime window for production systems

### After Reset
- 🔐 Create strong admin credentials immediately
- 👥 Recreate necessary user accounts with minimal privileges
- 🧪 Test applications and configurations thoroughly
- 📋 Update documentation with new credentials

### Security Considerations
- 🔒 Change default passwords immediately
- 🚫 Disable unnecessary user accounts
- 📊 Implement proper access control policies
- 🔄 Regular backup schedule for user databases

---

## 🚨 Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Service won't stop | Process hung | `sudo killall CODESYSControl` then retry |
| Permission denied | Insufficient privileges | Verify sudo access |
| Backup fails | Disk space | Check available space with `df -h` |
| Runtime won't start | Configuration error | Check logs: `sudo journalctl -u CODESYSControl` |

### Log Analysis
```bash
# Check runtime service status
sudo systemctl status CODESYSControl

# View recent logs
sudo journalctl -u CODESYSControl -f

# Check runtime directory permissions
ls -la /var/opt/codesys/
```

---

## 📁 Downloads and Resources

### Files in this Repository
- 📄 `reset-codesys-runtime.sh` - Automated reset script
- 📋 `troubleshooting-guide.md` - Extended troubleshooting
- 🔧 `backup-restore-procedures.md` - Backup best practices

### External Resources
- [CODESYS Official Documentation](https://help.codesys.com/)
- [Raspberry Pi CODESYS Installation Guide](https://help.codesys.com/webapp/_rbp_install_runtime;product=codesys;version=3.5.17.0)
- [CODESYS User Management Documentation](https://help.codesys.com/webapp/_cds_user_management;product=codesys;version=3.5.17.0)

---

## 📞 Support and Contributing

### Found an Issue?
- 🐛 [Report bugs](../../issues)
- 💡 [Request features](../../issues)
- 📖 [Improve documentation](../../pulls)

### Tested Environments
- ✅ CODESYS Development Tool 3.5 SP21 Patch 2
- ✅ Raspberry Pi 4 Model B
- ✅ Raspberry Pi OS (32-bit and 64-bit)
- ✅ CODESYS Control for Raspberry Pi SL

---

## 📄 License and Citation

### License
This work is licensed under [MIT License](LICENSE) - feel free to use and modify.

### How to Cite
```bibtex
@misc{codesys_reset_guide2025,
  author = {[Your Name]},
  title = {Technical Note: CODESYS Runtime Reset Guide for Raspberry Pi},
  year = {2025},
  url = {https://[username].github.io/codesys-reset-guide},
  note = {Accessed: \today}
}
```

### Disclaimer
⚠️ **Use at your own risk.** Always backup critical data before performing reset operations. The author is not responsible for data loss or system damage.

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Sep 22, 2025 | Initial release with both reset methods |
| | | Added automated shell script |
| | | Comprehensive documentation |

---

*Last updated: September 22, 2025*  
*Hosted on [GitHub Pages](https://github.com/[username]/codesys-reset-guide)*