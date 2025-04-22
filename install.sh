#!/system/bin/sh

# ==========================================
# Module Configuration
# ==========================================
SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=false
LATESTARTSERVICE=true
CLEANSERVICE=true
DEBUG=false

# ==========================================
# Module Information Display
# ==========================================
print_modname() {
    ui_print " "
    ui_print "┌───────────────────────────────────────┐"
    ui_print "│    UNIVERSAL FPS UNLOCKER v2.0        │"
    ui_print "│    Powered by CATSMOKER               │"
    ui_print "└───────────────────────────────────────┘"
    ui_print " "

    # Device information section
    ui_print "DEVICE INFORMATION"
    ui_print "├ Model: $(getprop ro.product.model)"
    ui_print "├ Brand: $(getprop ro.product.manufacturer)"
    ui_print "├ SOC: $(getprop ro.product.board)"
    ui_print "├ CPU: $(getprop ro.hardware)"
    ui_print "├ Android: $(getprop ro.build.version.release)"
    ui_print "├ Kernel: $(uname -r)"
    ui_print "└ RAM: $(awk 'BEGIN {printf "%.1f GB", $(getprop ro.hw.device.ram)/1024/1024}')"
    ui_print " "

    # Architecture detection
    ui_print "DETECTING ARCHITECTURE..."
    case $(getprop ro.product.cpu.abi) in
        arm64-v8a) 
            ARCH="arm64"
            ui_print "├ Architecture: ARM64 (64-bit)"
            ;;
        armeabi-v7a) 
            ARCH="arm"
            ui_print "├ Architecture: ARM32 (32-bit)"
            ;;
        *)
            ui_print "├ Architecture: Unknown ($(getprop ro.product.cpu.abi))"
            abort "Unsupported architecture"
            ;;
    esac
    ui_print "└ Extracting $ARCH binaries..."
    ui_print " "

    # Installation instructions
    ui_print "USAGE INSTRUCTIONS"
    ui_print "├ After installation, run:"
    ui_print "│   su -c UNLOCKER"
    ui_print "└ in Termux to access the FPS menu"
    ui_print " "

    # Warning message
    ui_print "WARNING"
    ui_print "├ This module modifies system parameters"
    ui_print "├ Use at your own risk!"
    ui_print "└ Not responsible for any issues"
    ui_print " "
}

# ==========================================
# Installation Process
# ==========================================
on_install() {
    ui_print "INSTALLING..."
    ui_print "├ [1/1] Installing system files..."
    unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2 || abort "Failed to install system files"
    ui_print "└ Installation complete!"
    ui_print " "
}

# ==========================================
# Set Permissions
# ==========================================
set_permissions() {
    ui_print "SETTING PERMISSIONS..."
    
    # Set standard permissions
    set_perm_recursive "$MODPATH" 0 0 0755 0644
    
    # Set executable permissions
    set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755
    
    ui_print "└ Permissions set successfully!"
    ui_print " "
}

# ==========================================
# Main Execution
# ==========================================
SKIPUNZIP=1
[ -z "$TMPDIR" ] && TMPDIR=/dev/tmp

unzip -qjo "$ZIPFILE" 'common/functions.sh' -d "$TMPDIR" >&2 || abort "Failed to extract functions.sh"
. "$TMPDIR/functions.sh" || abort "Failed to load functions.sh"

# Cleanup temporary files
cleanup() {
    rm -rf "$TMPDIR" 2>/dev/null
}
trap cleanup EXIT