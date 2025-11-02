#!/bin/bash

Help()
{
   echo "Proxmox SNMP UPS Installer Configuration."
   echo
   echo "Syntax: $0 [-a|-c|-p]"
   echo "options:"
   echo "  -a a.b.c.d     The IP Address of the UPS to configure"
   echo "  -c public      SNMP Community Name to connect to UPS"
   echo "                 Default: public"
   echo "  -p ********    Password for Localhost nut access"
   echo "                 If not specified, a password will be generated."
   echo
}

# Set defaults if not specified on commandline
IPADDR="127.0.0.1"
UPSCOMM="public"
NUTPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32; echo)

# Pass Commandline Arguments
while getopts ":a:c:p:" opt; do
   case $opt in
      a) # UPS IP Address
        IPADDR="${OPTARG}";;
      c) # UPS Community
        UPSCOMM="${OPTARG}";;
      p) # nut password
        NUTPASS="${OPTARG}";;
      :) # no argument
         echo "Option -${OPTARG} requires an argument."
         exit;;
      *) # invalid option
         Help
         exit;;
   esac
done

# Check for the IP Address, this is the minimum required option
if [[ "${IPADDR}" == "127.0.0.1" ]]; then
  echo -e "ERROR: IP Address of UPS notspecified see help...\n"
  Help
  exit 404
fi

# Install Nut
apt install -y nut nut-snmp

# Download and extract configuration files
if [ ! -f "nutconfig.tar.gz" ]; then
    echo "Downloading Configuration..."
    wget https://raw.githubusercontent.com/steven-geo/proxmox-nut/refs/heads/master/nutconfig.tar.gz -O nutconfig.tar.gz
else
    echo "Using Existing Configuration tarball"
fi
tar -xvzf nutconfig.tar.gz -C /etc

echo "Configuring NUT"
echo "  UPS IP Address = ${IPADDR}"
echo "  UPS SNMP Community = ${UPSCOMM}"
echo "  NUT Password = ***********"
# Edit ups.conf replace port=<ipaddress>
sed -i "s/^port.*/port=$IPADDR/g" /etc/nut/ups.conf
# Edit ups.conf replace community=public (if required)
sed -i "s/^community.*/community=$UPSCOMM/g" /etc/nut/ups.conf
# Edit upsd.users - edit password=
sed -i "s/^password.*/password = $NUTPASS/g" /etc/nut/upsd.users
# Edit upsmon.conf - update password to match upsd.users
sed -i "s/^MONITOR.*/MONITOR ups@localhost 1 upsadmin $NUTPASS master/g" /etc/nut/upsmon.conf

#Ensure our actions are executable
chmod +x /etc/nut/upssched-cmd

# Restart/Start services with our new configuration
service nut-server restart
service nut-client restart
systemctl restart nut-monitor

echo "Nut successfully configured"
