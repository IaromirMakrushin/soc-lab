#!/usr/bin/env bash
#
# 07-Wazuh-Setup.sh
# Run INSIDE WAZUH01 after Ubuntu Server 24.04 is installed:
#     sudo bash 07-Wazuh-Setup.sh
#
# 1. Sets hostname + static IP 10.10.10.20 on the lab NIC (matched by MAC).
# 2. Uses the temporary Default-Switch NIC (DHCP) for internet, if present.
# 3. Installs Wazuh all-in-one (indexer + server + dashboard).
#
# Check https://documentation.wazuh.com for the current version and adjust
# WAZUH_VER if the download fails.
#
set -euo pipefail

WAZUH_VER="4.14"
LAB_MAC="00:15:5d:0a:0a:14"     # must match 06-Create-WazuhVM.ps1
TEMP_MAC="00:15:5d:0a:0a:f0"
LAB_IP="10.10.10.20/24"
LAB_DNS="10.10.10.10"

[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }

hostnamectl set-hostname wazuh01

# Stop cloud-init from rewriting the network config
mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
rm -f /etc/netplan/50-cloud-init.yaml

cat > /etc/netplan/60-lab.yaml <<EOF
network:
  version: 2
  ethernets:
    lab:
      match: {macaddress: "${LAB_MAC}"}
      set-name: lab0
      dhcp4: false
      addresses: [${LAB_IP}]
      nameservers:
        addresses: [${LAB_DNS}]
        search: ["~lab.internal"]   # DC01 only answers lab names, not internet lookups
    temp:
      match: {macaddress: "${TEMP_MAC}"}
      set-name: inet0
      dhcp4: true
      optional: true
EOF
chmod 600 /etc/netplan/60-lab.yaml
netplan apply
sleep 5
ip -br addr

# Internet check (only reachable through the temporary NIC). Test the real
# installer URL - the bare packages.wazuh.com root returns 403 even when online.
INSTALL_URL="https://packages.wazuh.com/${WAZUH_VER}/wazuh-install.sh"
for i in 1 2 3 4 5 6; do
    curl -sfI "$INSTALL_URL" >/dev/null && break
    echo "Waiting for network ($i/6)..."; sleep 5
done
if ! curl -sfI "$INSTALL_URL" >/dev/null; then
    echo "No internet. Re-create/attach the TEMP-Internet NIC (06-Create-WazuhVM.ps1 -TempInternet)."
    exit 1
fi

apt-get update && apt-get -y upgrade

cd /root
curl -sO "$INSTALL_URL"
bash ./wazuh-install.sh -a

echo
echo "Wazuh installed. Admin password is in /root/wazuh-install-files.tar:"
echo "  sudo tar -O -xvf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt"
echo "Dashboard: https://10.10.10.20 (from a VM on LAB-Isolated)"
echo "Next: shut down, run 08-Remove-WazuhTempNIC.ps1 on the host."
