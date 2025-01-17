#!/usr/bin/env bash

YW=`echo "\033[33m"`
RD=`echo "\033[01;31m"`
BL=`echo "\033[36m"`
GN=`echo "\033[1;92m"`
CL=`echo "\033[m"`
RETRY_NUM=10
RETRY_EVERY=3
NUM=$RETRY_NUM
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

function error_exit() {
  trap - ERR
  local reason="Unknown failure occurred."
  local msg="${1:-$reason}"
  local flag="${RD}‼ ERROR ${CL}$EXIT@$LINE"
  echo -e "$flag $msg" 1>&2
  exit $EXIT
}

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

msg_info "Setting up Container OS "
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null
while [ "$(hostname -I)" = "" ]; do
  1>&2 echo -en "${CROSS}${RD} No Network! "
  sleep $RETRY_EVERY
  ((NUM--))
  if [ $NUM -eq 0 ]
  then
    1>&2 echo -e "${CROSS}${RD} No Network After $RETRY_NUM Tries${CL}"    
    exit 1
  fi
done
msg_ok "Set up Container OS"
msg_ok "Network Connected: ${BL}$(hostname -I)"

if nc -zw1 8.8.8.8 443; then  msg_ok "Internet Connected"; else  msg_error "Internet NOT Connected"; exit 1; fi;
RESOLVEDIP=$(nslookup "github.com" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
if [[ -z "$RESOLVEDIP" ]]; then msg_error "DNS Lookup Failure";  else msg_ok "DNS Resolved github.com to $RESOLVEDIP";  fi;

msg_info "Updating Container OS"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated Container OS"

msg_info "Installing Dependencies"
apt-get install -y sudo &>/dev/null
apt-get install -y curl &>/dev/null
apt-get install -y sudo &>/dev/null
apt-get install -y gnupg &>/dev/null
apt-get install -y sudo &>/dev/null
apt-get install -y xinit &>/dev/null
msg_ok "Installed Dependencies"


cat > ~/.xinitrc << __EOF__
#!/bin/sh
exec emulationstation
__EOF__




msg_info "Setting Up Hardware Acceleration"  
apt-get -y install \
    va-driver-all \
    ocl-icd-libopencl1 &>/dev/null 

msg_ok "Set Up Hardware Acceleration"  

msg_info "Setting Up kodi user"
useradd -d /home/roberto -m roberto &>/dev/null
gpasswd -a roberto audio &>/dev/null
gpasswd -a roberto video &>/dev/null
gpasswd -a roberto render &>/dev/null
groupadd -r autologin &>/dev/null
gpasswd -a roberto autologin &>/dev/null
gpasswd -a roberto input &>/dev/null #to enable direct access to devices
sudo sed -i -e '$a\roberto ALL=(ALL) NOPASSWD:ALL' /etc/sudoers

msg_ok "Set Up roberto user"

msg_info "Installing lightdm"
DEBIAN_FRONTEND=noninteractive apt-get install -y lightdm &>/dev/null
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
msg_ok "Installed lightdm"

msg_info "Setting up device detection for xorg"
apt-get install -y xserver-xorg-input-evdev &>/dev/null

cat >/usr/local/bin/preX-populate-input.sh  << __EOF__
#!/usr/bin/env bash
### Creates config file for X with all currently present input devices
#   after connecting new device restart X (systemctl restart lightdm)
######################################################################
cat >/etc/X11/xorg.conf.d/10-lxc-input.conf << _EOF_
Section "ServerFlags"
     Option "AutoAddDevices" "False"
EndSection
_EOF_
cd /dev/input
for input in event*
do
cat >> /etc/X11/xorg.conf.d/10-lxc-input.conf <<_EOF_
Section "InputDevice"
    Identifier "\$input"
    Option "Device" "/dev/input/\$input"
    Option "AutoServerLayout" "true"
    Driver "evdev"
EndSection
_EOF_
done
__EOF__

/bin/chmod +x /usr/local/bin/preX-populate-input.sh
/bin/mkdir -p /etc/systemd/system/lightdm.service.d

cat > /etc/systemd/system/lightdm.service.d/override.conf << __EOF__
[Service]
ExecStartPre=/bin/sh -c '/usr/local/bin/preX-populate-input.sh'
SupplementaryGroups=video render input audio tty
__EOF__

systemctl daemon-reload
msg_ok "Set up device detection for xorg"


msg_info "Customizing Container"

chmod -x /etc/update-motd.d/*
touch ~/.hushlogin
GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
mkdir -p $(dirname $GETTY_OVERRIDE)

cat << EOF > $GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF

systemctl daemon-reload
systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')
msg_ok "Customized Container"


msg_info "Cleaning up"
apt-get autoremove >/dev/null
apt-get autoclean >/dev/null
msg_ok "Cleaned"



msg_info "Installing emulation"
apt-get update &>/dev/null
apt-get install -y x11-utils &>/dev/null
apt-get install -y xorg &>/dev/null
apt-get install -y gnome-terminal &>/dev/null
apt-get install -y openbox &>/dev/null
apt-get install -y pulseaudio &>/dev/null
apt-get install -y alsa-utils &>/dev/null
apt-get install -y menu &>/dev/null
apt-get install -y libglib2.0-bin &>/dev/null
apt-get install -y at-spi2-core &>/dev/null
apt-get install -y libglib2.0-bin &>/dev/null
apt-get install -y dbus-x11 &>/dev/null
apt-get install -y git &>/dev/null
apt-get install -y dialog &>/dev/null
apt-get install -y unzip &>/dev/null
apt-get install -y xmlstarlet &>/dev/null
set +e
alias die=''
apt-get install --ignore-missing -y &>/dev/null
git clone --depth=1 https://github.com/RetroPie/RetroPie-Setup.git &>/dev/null
msg_ok "il processo potrebbe essere lungo attendere"
./RetroPie-Setup/retropie_packages.sh setup basic_install &>/dev/null
alias die='EXIT=$? LINE=$LINENO error_exit'
set -e
msg_ok "Installed emulation"


msg_info "Updating xsession"
cat <<EOF >/usr/share/xsessions/kodi-alsa.desktop
[Desktop Entry]
Name=Kodi-alsa
Comment=This session will start Kodi media center with alsa support
Exec=env AE_SINK=ALSA kodi-standalone
TryExec=env AE_SINK=ALSA kodi-standalone
Type=Application
EOF


cat <<EOF >/home/kodi/.xsession
[Desktop Entry]
Name=Kodi-alsa
Comment=This session will start Kodi media center with alsa support
Exec=env AE_SINK=ALSA kodi-standalone
TryExec=env AE_SINK=ALSA kodi-standalone
Type=Application
EOF





msg_ok "Updated xsession"

msg_info "Setting up autologin"

cat <<EOF >/etc/lightdm/lightdm.conf
[Seat:*]
#autologin-user=kodi
#autologin-session=kodi-alsa
EOF

msg_ok "Set up autologin"

mkdir /etc/lightdm/lightdm.conf.d/

cat <<EOF >/etc/lightdm/lightdm.conf.d/autologin-kodi.conf
[Seat:*]
autologin-user=kodi
autologin-session=kodi-alsa
EOF
msg_ok "Set up autologin"






msg_info "Starting X up"
systemctl start lightdm
ln -fs /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
msg_info "Started X"
