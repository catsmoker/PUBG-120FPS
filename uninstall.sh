#!/system/bin/sh

# ==========================================
# Clean Uninstall Script for Magisk Module
# ==========================================

MODDIR=/data/adb/modules
[ -z "$MODNAME" ] && MODNAME="STRPxUNLOCKER"
INFO=$MODDIR/.$MODNAME/module.prop

cleanup_files() {
    if [ -f "$INFO" ]; then
        while read -r LINE || [ -n "$LINE" ]; do
            # Skip empty lines and comments
            [ -z "$LINE" ] && continue
            [ "${LINE:0:1}" = "#" ] && continue
            
            # Skip lines ending with ~ (backups)
            if [ "${LINE: -1}" = "~" ]; then
                continue
              
            # Restore original files from backups
            elif [ -f "${LINE}~" ]; then
                if mv -f "${LINE}~" "$LINE"; then
                    echo "✓ Restored original: $LINE"
                else
                    echo "! Failed to restore: $LINE"
                    continue
                fi
              
            # Remove installed files
            else
                if [ -e "$LINE" ]; then
                    if rm -f "$LINE"; then
                        echo "✓ Removed: $LINE"
                    else
                        echo "! Failed to remove: $LINE"
                    fi
                    
                    # Clean up empty parent directories
                    local PARENT=$(dirname "$LINE")
                    while [ "$PARENT" != "/" ]; do
                        if [ -d "$PARENT" ] && [ -z "$(ls -A "$PARENT" 2>/dev/null)" ]; then
                            rmdir "$PARENT" 2>/dev/null && echo "✓ Removed empty directory: $PARENT"
                            PARENT=$(dirname "$PARENT")
                        else
                            break
                        fi
                    done
                fi
            fi
        done < "$INFO"
    fi
}

# Main execution
echo " "
echo "┌───────────────────────────────────────┐"
echo "│    UNINSTALLING FPS UNLOCKER MODULE   │"
echo "└───────────────────────────────────────┘"
echo " "

cleanup_files

# Final cleanup
rm -rf "$MODDIR/.$MODNAME" 2>/dev/null
echo " "
echo "Uninstallation complete!"
echo " "

exit 0