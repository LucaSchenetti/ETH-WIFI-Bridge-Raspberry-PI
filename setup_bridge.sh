#!/bin/bash

# =================================================================
# SETUP ETH-WIFI PROXY ARP BRIDGE (Version 5.0 - Final Stable)
# =================================================================

if [ "$EUID" -ne 0 ]; then 
  echo "Error: Please run as root (sudo)."
  exit 1
fi

echo "--- 1. Installing required packages ---"
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y parprouted dhcp-helper iptables iptables-persistent

echo "--- 2. Configuring IP Forwarding and Kernel Parameters ---"
cat <<EOF > /etc/sysctl.d/99-bridge.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.proxy_arp = 1
net.ipv4.conf.eth0.proxy_arp = 1
net.ipv4.conf.wlan0.proxy_arp = 1
EOF
sysctl -p /etc/sysctl.d/99-bridge.conf

echo "--- 3. Configuring DHCP-Helper ---"
# Relay DHCP: listens on eth0 and broadcasts on wlan0
echo 'DHCPHELPER_OPTS="-b wlan0"' > /etc/default/dhcp-helper

echo "--- 4. Creating Systemd Service (Corrected) ---"
cat << 'EOF' > /etc/systemd/system/parprouted.service
[Unit]
Description=Bridge ETH-WIFI Proxy ARP (V5 Stable)
After=network-online.target sys-subsystem-net-devices-wlan0.device docker.service
Wants=network-online.target sys-subsystem-net-devices-wlan0.device

[Service]
Type=forking
Restart=always
RestartSec=10

# A) Interface Preparation
ExecStartPre=/bin/bash -c 'until ip -4 addr show wlan0 | grep -q "inet "; do sleep 2; done'
ExecStartPre=/sbin/ip link set dev eth0 up
ExecStartPre=/sbin/ip addr flush dev eth0
ExecStartPre=/sbin/ip link set wlan0 promisc on
ExecStartPre=/sbin/ip link set eth0 promisc on

# B) IP Assignment and Firewall Rules (Docker-Safe)
ExecStartPre=/bin/bash -c 'WLAN_IP=$(ip -4 addr show wlan0 | grep -oP "(?<=inet\s)\d+(\.\d+){3}"); ip addr add $WLAN_IP/32 dev eth0 || true'
ExecStartPre=/bin/sleep 2
ExecStartPre=/sbin/iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
ExecStartPre=/sbin/iptables -P FORWARD ACCEPT
ExecStartPre=/sbin/iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ExecStartPre=/sbin/iptables -I FORWARD 2 -p udp --dport 67:68 --sport 67:68 -j ACCEPT
ExecStartPre=/sbin/iptables -I FORWARD 3 -i eth0 -o wlan0 -j ACCEPT

# C) Start Bridge (Clean syntax without problematic flags)
ExecStart=/usr/sbin/parprouted eth0 wlan0

# D) Cleanup on Stop
ExecStopPost=/sbin/iptables -t nat -D POSTROUTING -o wlan0 -j MASQUERADE || true
ExecStopPost=/sbin/ip link set wlan0 promisc off
ExecStopPost=/sbin/ip link set eth0 promisc off
ExecStopPost=/bin/bash -c 'WLAN_IP=$(ip -4 addr show wlan0 | grep -oP "(?<=inet\s)\d+(\.\d+){3}"); if [ -n "$WLAN_IP" ]; then ip addr del $WLAN_IP/32 dev eth0 || true; fi'

[Install]
WantedBy=multi-user.target
EOF

echo "--- 5. Final Activation ---"
systemctl daemon-reload
systemctl enable parprouted
systemctl enable dhcp-helper

# Manual cleanup before start to avoid conflicts
ip addr flush dev eth0
systemctl restart parprouted
systemctl restart dhcp-helper

echo "--- 6. Firewall Persistence ---"
# Automatically answer 'yes' to iptables-persistent prompts
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
iptables-save > /etc/iptables/rules.v4

echo "--- STATUS VERIFICATION ---"
sleep 2
systemctl status parprouted --no-pager
echo "----------------------------------------------------------------"
echo "Setup complete! If you see 'active (running)' above, you are good to go."
echo "Reboot the system to test persistence: sudo reboot"
