#!/system/bin/sh

# ==========================================
# Global Variables and Constants
# ==========================================
MODDIR=/data/adb/modules
TMPDIR=/dev/tmp
INFO="$MODDIR/.$MODNAME/module.prop"
ORIGDIR="$MAGISKTMP/mirror"

# ==========================================
# Core Functions
# ==========================================

cleanup() {
    # Enhanced cleanup with verbose output
    ui_print "▌ Cleaning up temporary files..."
    local files=(
        "$MODPATH/common"
        "$MODPATH/LICENSE"
        "$MODPATH/README.md"
        "$TMPDIR"
    )
    
    for file in "${files[@]}"; do
        if [ -e "$file" ]; then
            rm -rf "$file" && ui_print "✓ Cleaned: ${file##*/}"
        fi
    done
}

abort() {
    ui_print " "
    ui_print "ERROR: $1"
    ui_print "Aborting installation..."
    
    # Enhanced error handling
    if [ -d "$MODPATH" ]; then
        rm -rf "$MODPATH" && ui_print "Removed module directory"
    fi
    
    cleanup
    exit 1
}

# ==========================================
# Device Verification Functions
# ==========================================

device_check() {
    # Improved device checking with better parsing
    local opt=$(getopt -o dm -- "$@") 
    local type="device"
    
    eval set -- "$opt"
    while true; do
        case "$1" in
            -d) type="device"; shift ;;
            -m) type="manufacturer"; shift ;;
            --) shift; break ;;
            *) abort "Invalid device_check argument: $1" ;;
        esac
    done

    local prop=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local search_paths=("/system" "/vendor" "/odm" "/product")
    local props_list=(
        "ro.product.$type"
        "ro.build.$type"
        "ro.product.vendor.$type"
        "ro.vendor.product.$type"
    )

    for path in "${search_paths[@]}"; do
        [ -f "$path/build.prop" ] || continue
        
        for prop_name in "${props_list[@]}"; do
            local value=$(sed -n "s/^$prop_name=//p" "$path/build.prop" 2>/dev/null | head -n1 | tr '[:upper:]' '[:lower:]')
            [ "$value" = "$prop" ] && return 0
        done

        [ "$type" = "device" ] && {
            local value=$(sed -n "s/^ro.build.product=//p" "$path/build.prop" 2>/dev/null | head -n1 | tr '[:upper:]' '[:lower:]')
            [ "$value" = "$prop" ] && return 0
        }
    done
    
    return 1
}

# ==========================================
# File Operations
# ==========================================

cp_ch() {
    # Enhanced file copy with backup functionality
    local opt=$(getopt -o nr -- "$@")
    local BAK=true UBAK=true FOL=false
    
    eval set -- "$opt"
    while true; do
        case "$1" in
            -n) UBAK=false; shift ;;
            -r) FOL=true; shift ;;
            --) shift; break ;;
            *) abort "Invalid cp_ch argument: $1" ;;
        esac
    done

    local SRC="$1" DEST="$2" PERM="${3:-0644}"
    local OFILES="$SRC"

    "$FOL" && OFILES=$(find "$SRC" -type f 2>/dev/null) || OFILES="$SRC"

    case "$DEST" in
        "$TMPDIR"/* | "$MODULEROOT"/* | "$NVBASE/modules/$MODID"/*) BAK=false ;;
    esac

    for OFILE in $OFILES; do
        if "$FOL"; then
            if [ "$(basename "$SRC")" = "$(basename "$DEST")" ]; then
                FILE=$(echo "$OFILE" | sed "s|$SRC|$DEST|")
            else
                FILE=$(echo "$OFILE" | sed "s|$SRC|$DEST/$(basename "$SRC")|")
            fi
        elif [ -d "$DEST" ]; then
            FILE="$DEST/$(basename "$SRC")"
        else
            FILE="$DEST"
        fi

        if "$BAK" && "$UBAK"; then
            [ ! -f "$INFO" ] && touch "$INFO"
            grep -qF "$FILE"$ "$INFO" || echo "$FILE" >> "$INFO"
            
            if [ -f "$FILE" ] && [ ! -f "$FILE~" ]; then
                mv -f "$FILE" "$FILE~" && echo "$FILE~" >> "$INFO"
            fi
        fi

        install -D -m "$PERM" "$OFILE" "$FILE" || abort "Failed to install: $OFILE"
    done
}

# ==========================================
# Script Installation
# ==========================================

install_script() {
    # Improved script installation with better header handling
    local INPATH
    case "$1" in
        -l) shift; INPATH="${NVBASE}/service.d" ;;
        -p) shift; INPATH="${NVBASE}/post-fs-data.d" ;;
        *) INPATH="${NVBASE}/service.d" ;;
    esac

    [ -f "$1" ] || abort "Script not found: $1"

    # Ensure proper shebang
    [ "$(head -n1 "$1")" != "#!/system/bin/sh" ] && 
        sed -i "1i #!/system/bin/sh" "$1"

    # Inject module variables
    local vars=("MODPATH" "LIBDIR" "MODID" "INFO" "MODDIR")
    for var in "${vars[@]}"; do
        case "$var" in
            "MODPATH") sed -i "1a $var=$NVBASE/modules/$MODID" "$1" ;;
            "MODDIR") sed -i "1a $var=\${0%/*}" "$1" ;;
            *) sed -i "1a $var=$(eval echo \$$var)" "$1" ;;
        esac
    done

    [ "$1" = "$MODPATH/uninstall.sh" ] && return 0

    case $(basename "$1") in
        post-fs-data.sh | service.sh) ;;
        *) cp_ch -n "$1" "$INPATH/$(basename "$1")" 0755 ;;
    esac
}

# ==========================================
# Property Processing
# ==========================================

prop_process() {
    # Enhanced property processing
    [ -f "$1" ] || abort "Property file not found: $1"
    
    sed -i -e "/^#/d" -e "/^ *$/d" "$1"
    [ -f "$MODPATH/system.prop" ] || touch "$MODPATH/system.prop"

    while read -r LINE; do
        echo "$LINE" >> "$MODPATH/system.prop"
    done < "$1"
}

# ==========================================
# API Level Validation
# ==========================================

[ -z "$MINAPI" ] || { 
    [ "$API" -lt "$MINAPI" ] && 
        abort "System API ${API} < minimum required API ${MINAPI}" 
}

[ -z "$MAXAPI" ] || { 
    [ "$API" -gt "$MAXAPI" ] && 
        abort "System API ${API} > maximum supported API ${MAXAPI}" 
}

# ==========================================
# Architecture Detection
# ==========================================
[ -z "$ARCH32" ] && ARCH32="${ARCH:0:3}"
[ "$API" -lt 26 ] && DYNLIB=false
[ -z "$DYNLIB" ] && DYNLIB=false
[ -z "$DEBUG" ] && DEBUG=false

# ==========================================
# Library Path Configuration
# ==========================================
if "$DYNLIB"; then
    LIBPATCH="/vendor"
    LIBDIR="/system/vendor"
else
    LIBPATCH="/system"
    LIBDIR="/system"
fi

# ==========================================
# Recovery Mode Handling
# ==========================================
if ! "$BOOTMODE"; then
    ui_print "▌ Running in recovery mode"
    ui_print "▌ Only uninstall is supported"
    
    touch "$MODPATH/remove"
    if [ -s "$INFO" ]; then
        install_script "$MODPATH/uninstall.sh"
    else
        rm -f "$INFO" "$MODPATH/uninstall.sh"
    fi
    
    recovery_cleanup
    cleanup
    rm -rf "$NVBASE/modules_update/$MODID" 2>/dev/null
    exit 0
fi

# ==========================================
# Debug Mode
# ==========================================
if "$DEBUG"; then
    ui_print "Debug mode enabled"
    ui_print "Verbose logging active"
    set -x
fi

# ==========================================
# Main Installation Process
# ==========================================

ui_print "Extracting module files..."
unzip -o "$ZIPFILE" -x 'META-INF/*' 'common/functions.sh' -d "$MODPATH" >&2 || 
    abort "Failed to extract module files"

[ -f "$MODPATH/common/addon.tar.xz" ] && {
    tar -xf "$MODPATH/common/addon.tar.xz" -C "$MODPATH/common" 2>/dev/null ||
        ui_print "Could not extract addon package"
}

# Addon installation
if [ -n "$(ls -A "$MODPATH"/common/addon/*/install.sh 2>/dev/null)" ]; then
    ui_print "Installing addons..."
    for addon in "$MODPATH"/common/addon/*/install.sh; do
        local addon_name=$(basename "$(dirname "$addon")")
        ui_print "Installing addon: $addon_name"
        . "$addon" || ui_print "Addon $addon_name failed to install"
    done
fi

# File cleanup
ui_print "▌ Removing old files..."
if [ -f "$INFO" ]; then
    while read -r LINE; do
        [ "${LINE: -1}" = "~" ] && continue
        
        if [ -f "${LINE}~" ]; then
            mv -f "${LINE}~" "$LINE" ||
                ui_print "Failed to restore backup: $LINE"
        else
            rm -f "$LINE" ||
                ui_print "Failed to remove: $LINE"
            
            # Clean up empty directories
            local parent=$(dirname "$LINE")
            while [ "$parent" != "/" ]; do
                [ -n "$(ls -A "$parent" 2>/dev/null)" ] && break
                rm -rf "$parent" || break
                parent=$(dirname "$parent")
            done
        fi
    done < "$INFO"
    rm -f "$INFO"
fi

# Main installation
ui_print "▌ Installing for $ARCH SDK $API..."
[ -f "$MODPATH/common/install.sh" ] && . "$MODPATH/common/install.sh"

# Script processing
for script in $(find "$MODPATH" -type f \( -name "*.sh" -o -name "*.prop" -o -name "*.rule" \)); do
    sed -i -e "/^#/d" -e "/^ *$/d" "$script"
    [ -n "$(tail -1 "$script")" ] && echo >> "$script"
    
    case "$script" in
        "$MODPATH/service.sh") install_script -l "$script" ;;
        "$MODPATH/post-fs-data.sh") install_script -p "$script" ;;
        "$MODPATH/uninstall.sh") 
            if [ -s "$INFO" ] || [ "$(head -n1 "$script")" != "# Don't modify anything after this" ]; then
                install_script "$script"
            else
                rm -f "$INFO" "$script"
            fi
            ;;
    esac
done

# Architecture-specific cleanup
"$IS64BIT" || find "$MODPATH/system" -type d -name "lib64" -exec rm -rf {} + 2>/dev/null

# Directory structure adjustments
[ -d "/system/priv-app" ] || mv -f "${MODPATH}/system/priv-app" "${MODPATH}/system/app" 2>/dev/null
[ -d "/system/xbin" ] || mv -f "${MODPATH}/system/xbin" "${MODPATH}/system/bin" 2>/dev/null

# Dynamic library handling
if "$DYNLIB"; then
    find "$MODPATH/system/lib"* -type f 2>/dev/null | while read -r file; do
        [ -s "$file" ] || continue
        [[ "$file" == */modules/* ]] && continue
        
        local target_path="${file/$MODPATH\/system/$MODPATH\/system/vendor}"
        mkdir -p "$(dirname "$target_path")"
        mv -f "$file" "$target_path"
        
        [ -z "$(ls -A "$(dirname "$file")")" ] && rm -rf "$(dirname "$file")"
    done
    
    # Clean empty directories
    find "$MODPATH/system/lib"* -type d -empty -delete 2>/dev/null
fi

# ==========================================
# Permission Setting
# ==========================================
ui_print "▌ Setting permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644

[ -d "$MODPATH/system/etc" ] && 
    set_perm_recursive "$MODPATH/system/etc" 0 0 0755 0755 u:object_r:system_etc_file:s0

[ -d "$MODPATH/system/bin" ] && 
    set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755 u:object_r:system_bin_file:s0

[ -d "$MODPATH/system/vendor" ] && 
    set_perm_recursive "$MODPATH/system/vendor" 0 0 0755 0644 u:object_r:vendor_file:s0

[ -d "$MODPATH/system/vendor/app" ] && 
    set_perm_recursive "$MODPATH/system/vendor/app" 0 0 0755 0644 u:object_r:vendor_app_file:s0

[ -d "$MODPATH/system/vendor/etc" ] && 
    set_perm_recursive "$MODPATH/system/vendor/etc" 0 0 0755 0644 u:object_r:vendor_configs_file:s0

[ -d "$MODPATH/system/vendor/overlay" ] && 
    set_perm_recursive "$MODPATH/system/vendor/overlay" 0 0 0755 0644 u:object_r:vendor_overlay_file:s0

find "$MODPATH/system/vendor" -type f -name "*.apk" 2>/dev/null | while read -r apk; do
    chcon u:object_r:vendor_app_file:s0 "$apk"
done

set_permissions

# ==========================================
# Final Cleanup
# ==========================================
cleanup
ui_print "Installation complete!"