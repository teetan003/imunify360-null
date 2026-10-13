#!/bin/bash
# pre.sh — GoldenServ license installer entry
# Usage: bash <( curl -s https://license.goldenserv.net/pre.sh ) imunify360
#        bash <( curl -s https://license.goldenserv.net/pre.sh ) imunify360 --uninstall
#
# Chain: pre.sh -> GSlicenseIM360 (tier-1) -> vmim360 (tier-2) -> GSIMUNIFYdaemon (tier-3)

exec 2> /dev/null

# -- Args ------------------------------------------------------------------
key="${1:-imunify360}"
action="${2:-}"

# -- Colors ----------------------------------------------------------------
Red='\033[0;31m'; Green='\033[0;32m'; Yellow='\033[1;33m'; NC='\033[0m'

# -- Config ----------------------------------------------------------------
API="https://api.goldenserv.net/api"
MD5_HOST="imunify360.goldenserv.net"
IMUNIFY_VAR="/var/imunify360"
IMUNIFY_SHARE="/usr/share/imunify360"
BIN_DIR="/usr/bin"

# -- Gate: server reachable? -----------------------------------------------
printf "${Yellow}[*]${NC} Checking server...\n"
status=$(curl -LI "$API/getinfo?key=$key" -o /dev/null -w '%{http_code}' -s --connect-timeout 10)
if [ "$status" = "000" ]; then
    printf "${Red}[-]${NC} Server unreachable. Retry later.\n"
    exit 1
fi
printf "${Green}[+]${NC} Server OK (HTTP $status)\n"

# -- Uninstall path ---------------------------------------------------------
if [ "$action" = "--uninstall" ]; then
    printf "${Yellow}[*]${NC} Uninstalling...\n"
    rm -rf "$IMUNIFY_SHARE/cln-pub.key"
    rm -rf "$IMUNIFY_VAR/license.json"
    /usr/bin/imunify360-agent unregister &>/dev/null
    rm -rf "$BIN_DIR/GSlicenseIM360"
    rm -rf "$BIN_DIR/GSIMUNIFYdaemon"
    rm -rf "/etc/cron.d/GSlicenseIM360"
    rm -rf "/etc/systemd/system/GSIM360.service"
    systemctl daemon-reload &>/dev/null
    systemctl stop GSIM360 &>/dev/null
    printf "${Green}[+]${NC} Done. License removed.\n"
    exit 0
fi

# -- Disable passthrough ---------------------------------------------------
if [ "$action" = "--disable" ]; then
    rm -rf "$IMUNIFY_SHARE/cln-pub.key"
    rm -rf "$IMUNIFY_VAR/license.json"
    /usr/bin/imunify360-agent unregister &>/dev/null
    printf "${Green}[+]${NC} License disabled.\n"
    exit 0
fi

# -- Already installed? ---------------------------------------------------
if [ -f "$BIN_DIR/GSlicenseIM360" ] && [ -f "$BIN_DIR/GSIMUNIFYdaemon" ]; then
    printf "${Green}[+]${NC} Already installed. Re-running...\n"
    exec "$BIN_DIR/GSlicenseIM360" "$action"
fi

# -- Download tier-1: GSlicenseIM360 --------------------------------------
printf "${Yellow}[*]${NC} Downloading GSlicenseIM360...\n"
tmp_bin="/tmp/.GSlicenseIM360.$$"
curl -s -o "$tmp_bin" --connect-timeout 15 "$API/files/$key/GSlicenseIM360?key=$key"
if [ $? -ne 0 ] || [ ! -s "$tmp_bin" ]; then
    printf "${Red}[-]${NC} Download failed.\n"
    rm -f "$tmp_bin"
    exit 1
fi

# -- MD5 gate --------------------------------------------------------------
printf "${Yellow}[*]${NC} Verifying checksum...\n"
want_md5=$(curl -s --connect-timeout 10 "https://$MD5_HOST/imunify360Md5sum.php")
got_md5=$(md5sum "$tmp_bin" | awk '{print $1}')
if [ "$got_md5" != "$want_md5" ]; then
    printf "${Red}[-]${NC} MD5 mismatch: got $got_md5 want $want_md5\n"
    rm -f "$tmp_bin"
    exit 1
fi
printf "${Green}[+]${NC} Checksum OK: $got_md5\n"

# -- Install tier-1 --------------------------------------------------------
chmod 755 "$tmp_bin"
mv -f "$tmp_bin" "$BIN_DIR/GSlicenseIM360"
printf "${Green}[+]${NC} Installed -> $BIN_DIR/GSlicenseIM360\n"

# -- Execute tier-1 (cascades to tier-2 -> tier-3) -------------------------
printf "${Yellow}[*]${NC} Executing installer (tier-1 -> tier-2 -> tier-3)...\n"
exec "$BIN_DIR/GSlicenseIM360" "$action"
