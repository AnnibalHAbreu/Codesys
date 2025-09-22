#!/bin/bash
# reset-codesys-runtime.sh
# Author: Annibal H Abreu
# Date: 22-Sep-2025
# Description: Script to reset CODESYS Runtime users or full configuration on Raspberry Pi
# Tested with: CODESYS Development Tool 3.5 SP21 Patch 2
# Repository: https://github.com/AnnibalHAbreu/codesys

RUNTIME_DIR="/var/opt/codesys"
BACKUP_DIR="/root/codesys-backup-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if CODESYS runtime directory exists
if [[ ! -d "$RUNTIME_DIR" ]]; then
    print_error "CODESYS runtime directory not found: $RUNTIME_DIR"
    print_error "Please ensure CODESYS Control for Raspberry Pi is installed"
    exit 1
fi

echo "=============================================="
echo "  CODESYS Runtime Reset Script"
echo "  Author: Annibal H Abreu"
echo "  Date: 22-Sep-2025"
echo "=============================================="
echo ""

print_info "Checking CODESYS runtime service status..."
if systemctl is-active --quiet CODESYSControl; then
    print_info "CODESYS runtime is currently running"
else
    print_warning "CODESYS runtime is not running"
fi

print_info "Stopping CODESYS runtime service..."
systemctl stop CODESYSControl
sleep 3

# Verify service is stopped
if systemctl is-active --quiet CODESYSControl; then
    print_error "Failed to stop CODESYS runtime service"
    print_error "Trying to force stop..."
    killall CODESYSControl 2>/dev/null
    sleep 2
    if systemctl is-active --quiet CODESYSControl; then
        print_error "Cannot stop CODESYS runtime. Exiting."
        exit 1
    fi
fi

print_success "CODESYS runtime service stopped"

print_info "Creating backup at $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"

# Create backup with error handling
if cp -a "$RUNTIME_DIR"/* "$BACKUP_DIR"/ 2>/dev/null; then
    print_success "Backup created successfully"
else
    print_warning "Backup creation had some issues (directory might be empty)"
fi

echo ""
echo "Available reset options:"
echo "1) Reset only users (keep applications and configurations)"
echo "2) Reset entire runtime configuration (factory reset)"
echo "3) Cancel and restore service"
echo ""

while true; do
    read -p "Enter your choice [1, 2, or 3]: " choice
    case "$choice" in
        1)
            print_info "Selected: Reset only users"
            echo ""
            print_warning "This will remove all user accounts, groups, and user management rights"
            print_warning "Applications and runtime configurations will be preserved"
            echo ""
            read -p "Are you sure you want to continue? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                print_info "Resetting only users..."
                rm -f "$RUNTIME_DIR"/.UserDatabase* \
                      "$RUNTIME_DIR"/.GroupDatabase* \
                      "$RUNTIME_DIR"/.UserMgmtRightsDb* 2>/dev/null
                print_success "User databases removed successfully"
                print_info "Applications and other configurations remain intact"
            else
                print_info "Operation cancelled"
                break
            fi
            break
            ;;
        2)
            print_info "Selected: Complete factory reset"
            echo ""
            print_warning "This will remove ALL runtime configuration including:"
            print_warning "- All user accounts and groups"
            print_warning "- All applications and boot applications"
            print_warning "- All runtime policies and settings"
            print_warning "- All local configurations"
            echo ""
            read -p "Are you absolutely sure you want to continue? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                print_info "Performing factory reset..."
                # Move current directory with timestamp
                mv "$RUNTIME_DIR" "${RUNTIME_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
                # Create new empty directory
                mkdir -p "$RUNTIME_DIR"
                chown -R root:root "$RUNTIME_DIR"
                print_success "Runtime configuration reset to factory defaults"
            else
                print_info "Operation cancelled"
                break
            fi
            break
            ;;
        3)
            print_info "Operation cancelled by user"
            break
            ;;
        *)
            print_error "Invalid choice. Please enter 1, 2, or 3"
            ;;
    esac
done

print_info "Restarting CODESYS runtime service..."
systemctl start CODESYSControl
sleep 3

# Verify service started
if systemctl is-active --quiet CODESYSControl; then
    print_success "CODESYS runtime service started successfully"
else
    print_error "Failed to start CODESYS runtime service"
    print_info "Check service status with: sudo systemctl status CODESYSControl"
    print_info "Check logs with: sudo journalctl -u CODESYSControl -f"
fi

echo ""
echo "=============================================="
print_success "Reset operation completed"
echo "=============================================="
print_info "Backup of previous configuration: $BACKUP_DIR"

if [[ $choice == "1" || $choice == "2" ]]; then
    echo ""
    print_info "Next steps:"
    echo "1. Open CODESYS Development Environment"
    echo "2. Connect to your Raspberry Pi"
    echo "3. Go to Tools → License Manager"
    echo "4. Create a new runtime administrator user"
    echo ""
    print_warning "Important: Save your new admin credentials securely!"
fi

echo ""
print_info "For troubleshooting:"
echo "- Service status: sudo systemctl status CODESYSControl"
echo "- View logs: sudo journalctl -u CODESYSControl -f"
echo "- Repository: https://github.com/AnnibalHAbreu/codesys"
echo "=============================================="