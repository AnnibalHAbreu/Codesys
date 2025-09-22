# Technical Note and Reset Script for CODESYS Runtime on Raspberry Pi

**Author:** [Your Name]  
**Date:** 22-Sep-2025  
**Scope:** Procedures to reset users or the entire configuration of CODESYS Control runtime on Raspberry Pi devices.  
**Tested with:** CODESYS Development Tool 3.5 SP21 Patch 2

---

## 1. Introduction

This technical note describes two methods to reset the CODESYS Control runtime on a Raspberry Pi:

1. **Reset only runtime users** – preserves applications and runtime configuration.  
2. **Reset entire runtime configuration** – restores the runtime to a “factory default” state, erasing all users, policies, and local configurations.

These procedures require SSH access to the Raspberry Pi and administrative privileges.

---

## 2. Prerequisites

- Raspberry Pi running CODESYS Control runtime  
- SSH access from Windows/Linux/macOS  
- Administrative (sudo) privileges  
- Optional: Backup storage location for user/configuration files  
- Tested with **CODESYS Development Tool 3.5 SP21 Patch 2**

---

## 3. Option 1: Reset Only Runtime Users (Lightweight)

This method removes only the users, groups, and user-management rights, preserving all applications and other runtime configurations.

**Steps:**

```bash
# Connect via SSH and stop the runtime
sudo systemctl stop CODESYSControl

# Backup user database (recommended)
sudo mkdir -p /root/codesys-user-backup
sudo cp -a /var/opt/codesys/.UserDatabase* /root/codesys-user-backup/
sudo cp -a /var/opt/codesys/.GroupDatabase* /root/codesys-user-backup/
sudo cp -a /var/opt/codesys/.UserMgmtRightsDb* /root/codesys-user-backup/

# Remove users and groups
sudo rm -f /var/opt/codesys/.UserDatabase*
sudo rm -f /var/opt/codesys/.GroupDatabase*
sudo rm -f /var/opt/codesys/.UserMgmtRightsDb*

# Restart the runtime
sudo systemctl start CODESYSControl
```

**Outcome:**
- Applications and runtime configuration remain intact  
- A new admin user will be required on next connection via CODESYS IDE  
- To create a new user: **Tools → License Manager** in the IDE

---

## 4. Option 2: Reset Entire Runtime Configuration (Factory Reset)

This method removes **all runtime configuration**, including users, policies, applications, and boot apps.

**Steps:**

```bash
# Stop the runtime
sudo systemctl stop CODESYSControl

# Backup full runtime configuration (optional)
sudo mv /var/opt/codesys /var/opt/codesys.bak.$(date +%Y%m%d-%H%M%S)

# Create new empty configuration folder
sudo mkdir -p /var/opt/codesys
sudo chown -R root:root /var/opt/codesys

# Restart runtime
sudo systemctl start CODESYSControl
```

**Outcome:**
- Runtime restored to factory defaults  
- All users, policies, and applications removed  
- Create a new admin user via **Tools → License Manager** in the IDE

---

## 5. Recommendations

- Backup critical data before resets  
- Use user-only reset to recover admin without touching applications  
- Use full reset only for corrupted runtime or full reinstallation  
- Keep track of backup timestamps

---

## 6. Combined Shell Script

```bash
#!/bin/bash
# reset-codesys-runtime.sh
# Author: [Your Name]
# Date: 22-Sep-2025
# Description: Script to reset CODESYS Runtime users or full configuration on Raspberry Pi
# Tested with: CODESYS Development Tool 3.5 SP21 Patch 2

RUNTIME_DIR="/var/opt/codesys"
BACKUP_DIR="/root/codesys-backup-$(date +%Y%m%d-%H%M%S)"

echo "===== CODESYS Runtime Reset Script ====="
echo "Stopping CODESYS runtime service..."
sudo systemctl stop CODESYSControl
sleep 2

echo "Creating backup at $BACKUP_DIR ..."
sudo mkdir -p "$BACKUP_DIR"
sudo cp -a "$RUNTIME_DIR"/* "$BACKUP_DIR"/

echo "\nSelect reset option:"
echo "1) Reset only users (keep applications and configs)"
echo "2) Reset entire runtime (factory reset)"
read -p "Enter choice [1 or 2]: " choice

case "$choice" in
    1)
        echo "Resetting only users..."
        sudo rm -f "$RUNTIME_DIR"/.UserDatabase* \
                  "$RUNTIME_DIR"/.GroupDatabase* \
                  "$RUNTIME_DIR"/.UserMgmtRightsDb*
        echo "Users removed. Applications and other configs remain intact."
        ;;
    2)
        echo "Resetting entire runtime configuration..."
        sudo mv "$RUNTIME_DIR" "${RUNTIME_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
        sudo mkdir -p "$RUNTIME_DIR"
        sudo chown -R root:root "$RUNTIME_DIR"
        echo "Entire runtime configuration reset to factory defaults."
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "Restarting CODESYS runtime service..."
sudo systemctl start CODESYSControl
sleep 2

echo "===== Reset complete ====="
echo "Backup of previous configuration stored at: $BACKUP_DIR"
echo "If you reset users, use CODESYS IDE -> Tools -> License Manager to create a new runtime admin user."
echo "=============================================="
```

