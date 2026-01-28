ETH–WiFi Bridge for Raspberry Pi (Proxy ARP)
✅ Tested on Raspberry Pi 4 running Raspberry Pi OS Lite

A robust Bash script that creates a transparent network bridge between the Ethernet (eth0) and Wi‑Fi (wlan0) interfaces on a Raspberry Pi.

This solution uses Proxy ARP and DHCP Helper to allow a device connected via Ethernet to receive an IP address directly from your main router and access the internet seamlessly—even when using a Wi‑Fi connection that does not natively support bridging.


🚀KEY FEATURES

- Transparent Bridging: The connected device appears as if it were directly connected to the main network.
- Docker-Safe: Includes specific iptables rules to prevent Docker from blocking bridge traffic.
- Persistent Configuration: Automatically starts at boot via systemd.
- Self-Healing: Automatically restarts the service if the Wi‑Fi connection drops.
- NAT Masquerading: Ensures compatibility with restrictive routers (e.g. Vodafone Station).


🛠PREREQUISITES

- A Raspberry Pi running Raspberry Pi OS (tested on Debian Bookworm/Trixie).
- A working Wi‑Fi connection on wlan0.
- A device connected to the eth0 port via an Ethernet cable.


📦QUICK INSTALLATION

1. Clone the repository:
   git clone https://github.com/LucaSchenetti/ETH-WIFI-Bridge-Raspberry-PI.git
   cd ETH-WIFI-Bridge-Raspberry-PI

2. Make the script executable:
   chmod +x bridge.sh

3. Run the installer:
   sudo ./bridge.sh

4. Reboot your Raspberry Pi:
   sudo reboot


🔍HOW TO VERIFY IT’S WORKING

1. Check the service status:
   systemctl status parprouted.service
   Look for: active (running)

2. Verify IP mirroring:
   ip addr show eth0
   Look for: the same IP address as wlan0, with a /32 netmask.


🛠MANUAL UNINSTALLATION

If you need to revert the changes and restore the default networking configuration:

sudo systemctl stop parprouted
sudo systemctl disable parprouted
sudo rm /etc/systemd/system/parprouted.service
sudo rm /etc/sysctl.d/99-bridge.conf
sudo systemctl daemon-reload
