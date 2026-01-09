# CODESYS USB Auto-Mapping Solution

**Date:** 2026-01-09  
**System:** macOS mini with CODESYS IDE + Docker containers  
**Problem:** USB serial devices need to be automatically mapped to specific Docker containers  
**Solution:** udev rules + Docker wrapper script for automatic device injection

---

## Table of Contents

1. [Problem Description](#problem-description)
2. [Solution Overview](#solution-overview)
3. [Part 1: USB Device Mapping with udev](#part-1-usb-device-mapping-with-udev)
4. [Part 2: Docker Wrapper for Auto-Injection](#part-2-docker-wrapper-for-auto-injection)
5. [Testing and Verification](#testing-and-verification)
6. [Maintenance and Troubleshooting](#maintenance-and-troubleshooting)

---

## Problem Description

### Environment
- **5 CODESYS containers** require USB serial devices:   
  - `Medidor` → `/dev/ttyMedidor`
  - `Inversor-1` → `/dev/ttyInversor01`
  - `Inversor-2` → `/dev/ttyInversor02`
  - `Inversor-3` → `/dev/ttyInversor03`
  - `Inversor-4` → `/dev/ttyInversor04`

- **1 CODESYS Gateway container** (`Gateway-1`) does NOT require USB

### Hardware Setup
- **USB Hub** with **5 USB-to-RS485 converters**
- **Important:** Only ONE converter has a serial number
- **Solution:** Use `ID_PATH` instead of serial numbers for reliable mapping

### Challenges
1. USB devices appear as `/dev/ttyUSB0`, `/dev/ttyUSB1`, etc., which can change on reboot
2. Most USB-to-RS485 converters lack unique serial numbers
3. CODESYS IDE does not support custom Docker options
4. Need automatic device injection without manual intervention

---

## Solution Overview

### Two-Part Solution

**Part 1: udev Rules**  
- Map USB devices by `ID_PATH` (physical USB port location) to consistent device names
- Alternative: Use serial numbers when available
- Ensures `/dev/ttyMedidor`, `/dev/ttyInversor01`, etc., always point to the correct devices

**Part 2: Docker Wrapper Script**  
- Intercepts Docker commands from CODESYS IDE
- Automatically injects `--device` flags for specific containers
- Transparent to CODESYS IDE

---

## Part 1: USB Device Mapping with udev

### Understanding ID_PATH vs Serial Numbers

**Two methods for identifying USB devices:**

| Method | When to Use | Pros | Cons |
|--------|-------------|------|------|
| **Serial Number** (`ATTRS{serial}`) | Devices with unique serial numbers | Device can be moved to any USB port | Requires unique serial numbers |
| **ID_PATH** | Devices without serial numbers OR using USB hub | Works with cheap converters | Device must stay in same USB port |

**In this project:** We use **ID_PATH** because only one of our 5 USB-to-RS485 converters has a serial number.

---

### Step 1: Identify USB Devices

List all connected USB serial devices:

```bash
ls -l /dev/ttyUSB*
```

For each device, get detailed information:

```bash
udevadm info -a -n /dev/ttyUSB0 | grep -E 'SUBSYSTEM|ATTRS{serial}|ID_PATH'
```

Or get ID_PATH directly: 

```bash
udevadm info --query=property --name=/dev/ttyUSB0 | grep ID_PATH
```

### Step 2: Collect ID_PATH for Each Device

Create a mapping table by checking each USB port:

```bash
for dev in /dev/ttyUSB*; do
    echo "=== $dev ==="
    udevadm info --query=property --name=$dev | grep ID_PATH
done
```

Example output:
```
=== /dev/ttyUSB0 ===
ID_PATH=pci-0000:00:14.0-usb-0:1:1.0
=== /dev/ttyUSB1 ===
ID_PATH=pci-0000:00:14.0-usb-0:2:1.0
=== /dev/ttyUSB2 ===
ID_PATH=pci-0000:00:14.0-usb-0:3:1.0
```

**Important:** `ID_PATH` represents the physical USB port.  If you move a device to a different port, the mapping will change.

### Step 3: Create Mapping Table

Document your physical setup:

| Physical Device | ID_PATH | Target Name | Purpose |
|----------------|---------|-------------|---------|
| USB Hub Port 1 | `pci-0000:00:14.0-usb-0:3. 1: 1.0` | `/dev/ttyMedidor` | Medidor |
| USB Hub Port 2 | `pci-0000:00:14.0-usb-0:3.2:1.0` | `/dev/ttyInversor01` | Inversor-1 |
| USB Hub Port 3 | `pci-0000:00:14.0-usb-0:3.3:1.0` | `/dev/ttyInversor02` | Inversor-2 |
| USB Hub Port 4 | `pci-0000:00:14.0-usb-0:3.4:1.0` | `/dev/ttyInversor03` | Inversor-3 |
| USB Hub Port 5 | `pci-0000:00:14.0-usb-0:3.4. 1:1.0` | `/dev/ttyInversor04` | Inversor-4 |

### Step 4: Create udev Rules File

Create `/etc/udev/rules.d/99-usb-serial. rules`:

```bash
sudo nano /etc/udev/rules.d/99-usb-serial.rules
```

#### Option A: Using ID_PATH (Our Implementation)

**Recommended when using USB hub with identical converters:**

```udev
# USB-to-RS485 Converters on USB Hub
# Using ID_PATH for devices without unique serial numbers

# Medidor - Hub Port 1
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.1:1.0", SYMLINK+="ttyMedidor", MODE="0666"

# Inversor-1 - Hub Port 2
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.2:1.0", SYMLINK+="ttyInversor01", MODE="0666"

# Inversor-2 - Hub Port 3
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.3:1.0", SYMLINK+="ttyInversor02", MODE="0666"

# Inversor-3 - Hub Port 4
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.4:1.0", SYMLINK+="ttyInversor03", MODE="0666"

# Inversor-4 - Hub Port 5
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.4.1:1.0", SYMLINK+="ttyInversor04", MODE="0666"
```

#### Option B: Using Serial Numbers (Alternative)

**Use this if your USB converters have unique serial numbers:**

```udev
# USB-to-RS485 Converters with Unique Serial Numbers

# Medidor
SUBSYSTEM=="tty", ATTRS{serial}=="FT9F0VCM", SYMLINK+="ttyMedidor", MODE="0666"

# Inversor-1
SUBSYSTEM=="tty", ATTRS{serial}=="A10MRIKT", SYMLINK+="ttyInversor01", MODE="0666"

# Inversor-2
SUBSYSTEM=="tty", ATTRS{serial}=="FT9F3BSG", SYMLINK+="ttyInversor02", MODE="0666"

# Inversor-3
SUBSYSTEM=="tty", ATTRS{serial}=="FT9F3EIO", SYMLINK+="ttyInversor03", MODE="0666"

# Inversor-4
SUBSYSTEM=="tty", ATTRS{serial}=="A10MRIMC", SYMLINK+="ttyInversor04", MODE="0666"
```

#### Option C:  Hybrid Approach

**Mix both methods if some devices have serial numbers and others don't:**

```udev
# Medidor - Has serial number
SUBSYSTEM=="tty", ATTRS{serial}=="FT9F0VCM", SYMLINK+="ttyMedidor", MODE="0666"

# Inversors - No serial numbers, use ID_PATH
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.2:1.0", SYMLINK+="ttyInversor01", MODE="0666"
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.3:1.0", SYMLINK+="ttyInversor02", MODE="0666"
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.4:1.0", SYMLINK+="ttyInversor03", MODE="0666"
SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.4.1:1.0", SYMLINK+="ttyInversor04", MODE="0666"
```

### Step 5: Reload udev Rules

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Step 6: Verify Symbolic Links

```bash
ls -l /dev/tty{Medidor,Inversor*}
```

Expected output:
```
lrwxrwxrwx 1 root root 7 Jan  9 07:15 /dev/ttyInversor01 -> ttyUSB1
lrwxrwxrwx 1 root root 7 Jan  9 07:15 /dev/ttyInversor02 -> ttyUSB2
lrwxrwxrwx 1 root root 7 Jan  9 07:15 /dev/ttyInversor03 -> ttyUSB3
lrwxrwxrwx 1 root root 7 Jan  9 07:15 /dev/ttyInversor04 -> ttyUSB4
lrwxrwxrwx 1 root root 7 Jan  9 07:15 /dev/ttyMedidor -> ttyUSB0
```

### Step 7: Test Device Access

```bash
ls -l /dev/ttyMedidor
cat /dev/ttyMedidor  # Press Ctrl+C after a few seconds
```

✅ **Part 1 Complete:** USB devices now have consistent names!  

---

## Part 2: Docker Wrapper for Auto-Injection

### Step 1: Backup Original Docker Binary

```bash
sudo mv /usr/bin/docker /usr/bin/docker.real
```

### Step 2: Create Docker Wrapper Script

Create `/usr/bin/docker`:

```bash
sudo nano /usr/bin/docker
```

Add this content:

```bash
#!/bin/bash

# Docker wrapper to auto-inject USB devices for specific CODESYS containers

ARGS=("$@")

# Check if this is a 'docker run' command
if [[ "${ARGS[0]}" == "run" ]]; then
    # Check for specific container names and inject --device flag
    for i in "${! ARGS[@]}"; do
        if [[ "${ARGS[$i]}" == "--name" ]]; then
            CONTAINER_NAME="${ARGS[$i+1]}"
            
            case "$CONTAINER_NAME" in
                "Medidor")
                    ARGS=("${ARGS[@]:0:$i}" "--device=/dev/ttyMedidor:/dev/ttyMedidor" "${ARGS[@]: $i}")
                    break
                    ;;
                "Inversor-1")
                    ARGS=("${ARGS[@]:0:$i}" "--device=/dev/ttyInversor01:/dev/ttyInversor01" "${ARGS[@]:$i}")
                    break
                    ;;
                "Inversor-2")
                    ARGS=("${ARGS[@]:0:$i}" "--device=/dev/ttyInversor02:/dev/ttyInversor02" "${ARGS[@]:$i}")
                    break
                    ;;
                "Inversor-3")
                    ARGS=("${ARGS[@]:0:$i}" "--device=/dev/ttyInversor03:/dev/ttyInversor03" "${ARGS[@]:$i}")
                    break
                    ;;
                "Inversor-4")
                    ARGS=("${ARGS[@]:0:$i}" "--device=/dev/ttyInversor04:/dev/ttyInversor04" "${ARGS[@]:$i}")
                    break
                    ;;
            esac
        fi
    done
fi

# Execute the real Docker binary
exec /usr/bin/docker. real "${ARGS[@]}"
```

### Step 3: Make Wrapper Executable

```bash
sudo chmod +x /usr/bin/docker
```

### Step 4: Verify File Permissions

```bash
ls -l /usr/bin/docker /usr/bin/docker.real
```

Expected output:
```
-rwxr-xr-x 1 root root     1338 Jan  9 07:20 /usr/bin/docker
-rwxr-xr-x 1 root root 43984046 Jan  8 22:39 /usr/bin/docker. real
```

✅ **Part 2 Complete:** Docker wrapper is ready!  

---

## Testing and Verification

### Test 1: Verify udev Symbolic Links

Check all symbolic links exist:

```bash
ls -l /dev/tty{Medidor,Inversor*}
```

Check ID_PATH for each device:

```bash
for dev in /dev/tty{Medidor,Inversor*}; do
    echo "=== $dev ==="
    udevadm info --query=property --name=$dev | grep ID_PATH
done
```

### Test 2: Manual Docker Command

Remove any existing test container:  
```bash
docker rm -f Medidor
```

Create Medidor manually:
```bash
docker run -d --name Medidor \
  -v /var/opt/codesysvcontrol/instances/Medidor/conf/codesyscontrol:/conf/codesyscontrol \
  -v /var/opt/codesysvcontrol/instances/Medidor/data/codesyscontrol:/data/codesyscontrol \
  -v /var/opt/codesysvcontrol/instances/Medidor/api:/var/opt/codesyscontrolapi \
  codesyscontrol_virtuallinux: 4.18.0.0
```

Verify USB device was injected:
```bash
docker inspect Medidor | grep -A 5 '"Devices"'
```

Expected output:
```json
"Devices": [
    {
        "PathOnHost": "/dev/ttyMedidor",
        "PathInContainer": "/dev/ttyMedidor",
        "CgroupPermissions": "rwm"
    }
]
```

Check device is accessible inside container:
```bash
docker exec Medidor ls -l /dev/ttyMedidor
```

Expected output:
```
crw-rw-rw- 1 root dialout 188, 2 Jan  9 10:22 /dev/ttyMedidor
```

### Test 3: CODESYS IDE Integration

1. **Remove test container:**
   ```bash
   docker rm -f Medidor
   ```

2. **In CODESYS IDE, click RUN on Medidor**

3. **Verify USB mapping:**
   ```bash
   docker inspect Medidor | grep -A 5 '"Devices"'
   docker ps | grep Medidor
   ```

4. **Test Inversor container:**
   - In CODESYS IDE, click RUN on Inversor-1
   ```bash
   docker inspect Inversor-1 | grep -A 5 '"Devices"'
   ```

### Test 4: All Containers

Start all containers from CODESYS IDE, then verify:  

```bash
docker ps | grep -E "Medidor|Inversor"
```

Check all USB mappings: 
```bash
echo "=== Medidor ===" && docker inspect Medidor | grep -A 3 '"Devices"' && \
echo "" && echo "=== Inversor-1 ===" && docker inspect Inversor-1 | grep -A 3 '"Devices"' && \
echo "" && echo "=== Inversor-2 ===" && docker inspect Inversor-2 | grep -A 3 '"Devices"' && \
echo "" && echo "=== Inversor-3 ===" && docker inspect Inversor-3 | grep -A 3 '"Devices"' && \
echo "" && echo "=== Inversor-4 ===" && docker inspect Inversor-4 | grep -A 3 '"Devices"'
```

Expected output: 
```
=== Medidor ===
"Devices": [
    {
        "PathOnHost": "/dev/ttyMedidor",
        "PathInContainer": "/dev/ttyMedidor",

=== Inversor-1 ===
"Devices": [
    {
        "PathOnHost": "/dev/ttyInversor01",
        "PathInContainer": "/dev/ttyInversor01",

=== Inversor-2 ===
"Devices": [
    {
        "PathOnHost": "/dev/ttyInversor02",
        "PathInContainer": "/dev/ttyInversor02",

=== Inversor-3 ===
"Devices": [
    {
        "PathOnHost":  "/dev/ttyInversor03",
        "PathInContainer": "/dev/ttyInversor03",

=== Inversor-4 ===
"Devices": [
    {
        "PathOnHost": "/dev/ttyInversor04",
        "PathInContainer": "/dev/ttyInversor04",
```

### Test 5: Gateway (Should Have No USB)

Start Gateway-1 from CODESYS IDE:  

```bash
docker ps | grep Gateway-1
docker inspect Gateway-1 | grep -A 3 '"Devices"'
```

Expected output:
```
"Devices": [],
```

✅ **Gateway-1 correctly has NO USB devices!**

### Test 6: Reboot Persistence

1. **Reboot the system:**
   ```bash
   sudo reboot
   ```

2. **After reboot, verify wrapper is intact:**
   ```bash
   ls -l /usr/bin/docker /usr/bin/docker.real
   ```

3. **Verify udev symbolic links still exist:**
   ```bash
   ls -l /dev/tty{Medidor,Inversor*}
   ```

4. **Start containers from CODESYS IDE and verify USB mapping still works**

---

## Maintenance and Troubleshooting

### Understanding ID_PATH Format

`ID_PATH` represents the physical USB port path. Example breakdown: 

```
pci-0000:00:14.0-usb-0:3.2: 1.0
│   │           │       │ │ │
│   │           │       │ │ └─ Interface
│   │           │       │ └─── Port on hub
│   │           │       └───── Hub port
│   │           └───────────── USB bus
│   └───────────────────────── PCI device
└───────────────────────────── PCI bus
```

**Important Notes:**
- Moving a device to a different USB port changes the ID_PATH
- Changing hub ports changes the ID_PATH  
- Keep devices in the same physical ports for ID_PATH mapping

### Adding New USB Devices

#### Method 1: Using ID_PATH (No Serial Number)

1. **Connect the new USB device to a specific port**

2. **Find its ID_PATH:**
   ```bash
   udevadm info --query=property --name=/dev/ttyUSBX | grep ID_PATH
   ```

3. **Add rule to `/etc/udev/rules. d/99-usb-serial. rules`:**
   ```udev
   SUBSYSTEM=="tty", ENV{ID_PATH}=="pci-0000:00:14.0-usb-0:3.5:1.0", SYMLINK+="ttyNewDevice", MODE="0666"
   ```

4. **Reload udev:**
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

5. **Add case to Docker wrapper** (`/usr/bin/docker`):
   ```bash
   "NewContainer")
       ARGS=("${ARGS[@]:0:$i}" "--device=/dev/ttyNewDevice:/dev/ttyNewDevice" "${ARGS[@]: $i}")
       break
       ;;
   ```

#### Method 2: Using Serial Number (If Available)

1. **Connect the new USB device**

2. **Find its serial number:**
   ```bash
   udevadm info -a -n /dev/ttyUSBX | grep -i 'ATTRS{serial}'
   ```

3. **Add rule to `/etc/udev/rules.d/99-usb-serial.rules`:**
   ```udev
   SUBSYSTEM=="tty", ATTRS{serial}=="SERIAL_HERE", SYMLINK+="ttyNewDevice", MODE="0666"
   ```

4. **Follow steps 4-5 from Method 1**

### Relocating USB Hub to Different Port

If you move your USB hub to a different computer port:

1. **Check new ID_PATH for all devices:**
   ```bash
   for dev in /dev/ttyUSB*; do
       echo "=== $dev ==="
       udevadm info --query=property --name=$dev | grep ID_PATH
   done
   ```

2. **Update all ID_PATH values in `/etc/udev/rules. d/99-usb-serial. rules`**

3. **Reload udev:**
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

4. **Verify symbolic links:**
   ```bash
   ls -l /dev/tty{Medidor,Inversor*}
   ```

### Checking Docker Wrapper Logs

To debug wrapper behavior, add logging:

```bash
sudo nano /usr/bin/docker
```

Add after `#!/bin/bash`:
```bash
echo "$(date): $@" >> /tmp/docker-wrapper.log
```

Monitor logs:
```bash
tail -f /tmp/docker-wrapper.log
```

### Reverting to Original Docker

If needed, restore original Docker binary:  

```bash
sudo rm /usr/bin/docker
sudo mv /usr/bin/docker.real /usr/bin/docker
```

### Verifying udev Rules

Check if udev rules are active:
```bash
udevadm test $(udevadm info -q path -n /dev/ttyUSB0) 2>&1 | grep -i symlink
```

Test specific rule:
```bash
udevadm info --query=property --name=/dev/ttyMedidor
```

### Common Issues

**Issue 1: Device not mapped after reboot**
- Check udev rules:  `cat /etc/udev/rules. d/99-usb-serial.rules`
- Reload udev: `sudo udevadm control --reload-rules && sudo udevadm trigger`
- Verify symbolic links: `ls -l /dev/tty{Medidor,Inversor*}`

**Issue 2: Wrapper not working**
- Check permissions: `ls -l /usr/bin/docker`
- Verify shebang: `head -1 /usr/bin/docker` (should be `#!/bin/bash`)
- Check for typos: `cat /usr/bin/docker | grep docker. real`

**Issue 3: Container starts but no USB inside**
- Verify device exists on host: `ls -l /dev/ttyMedidor`
- Check container name matches case statement
- Inspect container: `docker inspect ContainerName | grep -A 5 Devices`

**Issue 4: ID_PATH changed after reboot**
- This can happen if USB enumeration order changes
- Use `dmesg | grep tty` to see USB detection order
- Consider using `ID_PATH_TAG` or serial numbers if available
- Update udev rules with new ID_PATH values

**Issue 5: Multiple devices with same ID_PATH**
- This shouldn't happen with ID_PATH
- Verify with:  `udevadm info --query=property --name=/dev/ttyUSBX`
- Check for hub port numbering issues
- Consider adding additional attributes to udev rules

**Issue 6: Symbolic link points to wrong device**
- USB hub port might be mislabeled
- Verify physical connections
- Use `dmesg` to see which ttyUSB corresponds to which port
- Update ID_PATH in udev rules

---

## Best Practices

### When to Use ID_PATH vs Serial Numbers

| Scenario | Recommended Method |
|----------|-------------------|
| USB devices without serial numbers | Use ID_PATH |
| Cheap USB-to-RS485 converters | Use ID_PATH |
| Devices connected via USB hub | Use ID_PATH |
| Need to move device between ports | Use Serial Number |
| Multiple identical devices | Use ID_PATH (fixed ports) |
| Devices with unique serial numbers | Use Serial Number |

### Documenting Your Setup

Always maintain a physical diagram showing:
- USB hub port numbers
- Which converter is in which port
- ID_PATH for each port
- Target device name

Example:
```
USB Hub (7-port)
├─ Port 1 → ID_PATH: pci-0000:00:14.0-usb-0:3.1:1.0 → /dev/ttyMedidor
├─ Port 2 → ID_PATH: pci-0000:00:14.0-usb-0:3.2:1.0 → /dev/ttyInversor01
├─ Port 3 → ID_PATH: pci-0000:00:14.0-usb-0:3.3:1.0 → /dev/ttyInversor02
├─ Port 4 → ID_PATH: pci-0000:00:14.0-usb-0:3.4:1.0 → /dev/ttyInversor03
└─ Port 5 → ID_PATH: pci-0000:00:14.0-usb-0:3.4.1:1.0 → /dev/ttyInversor04
```

### Labeling Physical Hardware

Use physical labels on: 
- USB hub ports (Port 1, Port 2, etc.)
- USB-to-RS485 converters (Medidor, Inv-1, etc.)
- RS485 cables

This prevents confusion during maintenance or troubleshooting.

---

## Summary

### What Was Implemented

✅ **udev Rules Using ID_PATH:**
- 5 USB-to-RS485 converters mapped via physical USB port location
- Works with devices that lack unique serial numbers
- Survives reboots (as long as devices stay in same ports)
- Permissions set to 0666 for container access

✅ **Docker Wrapper:**
- Intercepts `docker run` commands
- Auto-injects `--device` flags for 5 specific containers
- Transparent to CODESYS IDE
- Leaves other containers (Gateway-1) unaffected

✅ **Testing:**
- All 5 containers successfully receive USB devices
- Gateway-1 correctly has no USB devices
- Solution survives system reboot
- Works seamlessly with CODESYS IDE

### Hardware Configuration

- **USB Hub:** 1x multi-port USB hub
- **Converters:** 5x USB-to-RS485 converters (only 1 has serial number)
- **Mapping Method:** ID_PATH (physical USB port location)

### Files Modified

| File | Purpose |
|------|---------|
| `/etc/udev/rules.d/99-usb-serial.rules` | USB device name mapping via ID_PATH |
| `/usr/bin/docker` | Docker wrapper script |
| `/usr/bin/docker.real` | Original Docker binary (renamed) |

### Container Mapping Table

| Container | USB Device | ID_PATH Example |
|-----------|------------|-----------------|
| Medidor | `/dev/ttyMedidor` | `pci-0000:00:14.0-usb-0:3.1:1.0` |
| Inversor-1 | `/dev/ttyInversor01` | `pci-0000:00:14.0-usb-0:3.2:1.0` |
| Inversor-2 | `/dev/ttyInversor02` | `pci-0000:00:14.0-usb-0:3.3:1.0` |
| Inversor-3 | `/dev/ttyInversor03` | `pci-0000:00:14.0-usb-0:3.4:1.0` |
| Inversor-4 | `/dev/ttyInversor04` | `pci-0000:00:14.0-usb-0:3.4.1:1.0` |
| Gateway-1 | *None* | N/A |

---

## Conclusion

This solution provides **fully automatic USB device mapping** for CODESYS containers without requiring any changes to the CODESYS IDE or manual intervention. 

### Key Advantages of Using ID_PATH

✅ **Works with cheap USB converters** - No need for expensive converters with serial numbers  
✅ **Stable mapping** - As long as devices stay in same USB ports  
✅ **Simple troubleshooting** - Physical port location is easy to verify  
✅ **Cost-effective** - Use any USB-to-RS485 converter  

### Important Reminders

⚠️ **Do not move devices between USB ports** - ID_PATH will change  
⚠️ **Label your hardware** - Makes maintenance easier  
⚠️ **Document your setup** - Keep a diagram of port assignments  

The system is: 

- ✅ **Persistent** - survives reboots (with same port connections)
- ✅ **Transparent** - no CODESYS configuration needed
- ✅ **Selective** - only affects specific containers
- ✅ **Maintainable** - easy to add new devices
- ✅ **Production-ready** - tested and verified
- ✅ **Cost-effective** - works with cheap USB converters

**No more manual USB mapping required!** 🎉

---

**Document Version:** 2.0  
**Last Updated:** 2026-01-09  
**Author:** AnnibalHAbreu with GitHub Copilot  
**Hardware:** USB Hub + 5x USB-to-RS485 Converters (using ID_PATH mapping)