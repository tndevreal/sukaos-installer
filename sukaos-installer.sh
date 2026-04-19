#!/usr/bin/env bash
set -e





ask() {
    read -r -p "$1" ans
    echo "$ans"
}

backup_file() {
    local f="$1"
    if [ -e "$f" ]; then
        cp -a "$f" "${f}.bak.$(date +%s)"
    fi
}





TARGET_USER="$(ask 'Target username: ')"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "User does not exist."
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo "Using home directory: $TARGET_HOME"





echo "Are you on a desktop or laptop"
echo "1. desktop"
echo "2. laptop"
CHOICE="$(ask 'Choice [1/2]: ')"

POLYBAR_SRC=""

case "$CHOICE" in
    1)
        POLYBAR_SRC="polybarconfig1"
        ;;
    2)
        POLYBAR_SRC="polybarconfig2"
        ;;
    *)
        echo "Invalid choice, defaulting to desktop."
        POLYBAR_SRC="polybarconfig1"
        ;;
esac





KEYBOARD_LAYOUT="$(ask 'Keyboard layout (fi/us/ru/etc): ')"
KEYBOARD_LAYOUT="${KEYBOARD_LAYOUT:-us}"

echo "Setting keyboard layout to $KEYBOARD_LAYOUT"

backup_file /etc/vconsole.conf
cat >/etc/vconsole.conf <<EOF
KEYMAP=$KEYBOARD_LAYOUT
EOF

mkdir -p /etc/X11/xorg.conf.d
backup_file /etc/X11/xorg.conf.d/00-keyboard.conf
cat >/etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$KEYBOARD_LAYOUT"
EndSection
EOF





if [ -d "$POLYBAR_SRC" ]; then
    echo "Copying $POLYBAR_SRC → ~/.config/polybar"
    mkdir -p "$TARGET_HOME/.config/polybar"
    cp -a "$POLYBAR_SRC/"* "$TARGET_HOME/.config/polybar/"
    chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.config/polybar"
else
    echo "WARNING: $POLYBAR_SRC not found!"
fi





if [ -d executables ]; then
    echo "Copying executables → /bin"
    cp -a executables/* /bin/
else
    echo "WARNING: executables/ missing"
fi





backup_file /etc/os-release
cat >/etc/os-release <<'EOF'
NAME="SukaOS Linux"
PRETTY_NAME="SukaOS Linux V0.4"
ID=sukaos
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
LOGO=sukaos-logo
EOF






for cfg in picom kitty suka dunst; do
    if [ -d "configs/$cfg" ]; then
        mkdir -p "$TARGET_HOME/.config/$cfg"
        cp -a "configs/$cfg/"* "$TARGET_HOME/.config/$cfg/"
    fi
done

chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.config"





backup_file "$TARGET_HOME/.xinitrc"
cat >"$TARGET_HOME/.xinitrc" <<'EOF'
#/bin/bash
exec sukawm-non-tiling
EOF
chown "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.xinitrc"


#install packages


pacman -Sy --noconfirm opendoas rofi dunst picom polybar xdg-desktop-portal-gtk feh  

backup_file /etc/doas.conf
cat >/etc/doas.conf <<EOF
permit :wheel
permit nopass $TARGET_USER
permit nopass root
EOF
chmod 600 /etc/doas.conf

# Ensure wheel membership
if ! id "$TARGET_USER" | grep -q wheel; then
    usermod -aG wheel "$TARGET_USER"
fi



#aliases

BASHRC="$TARGET_HOME/.bashrc"
touch "$BASHRC"
backup_file "$BASHRC"

sed -i '/alias sudo=/d' "$BASHRC"
sed -i '/alias suka-update=/d' "$BASHRC"

cat >>"$BASHRC" <<'EOF'

# SukaOS aliases
alias sudo='doas'
alias suka-update='doas pacman -Syu && doas flatpak update'
EOF

chown "$TARGET_USER":"$TARGET_USER" "$BASHRC"





backup_file /etc/issue
cat >/etc/issue <<'EOF'
SukaOS Linux V0.4 \n \l
EOF

echo
echo "======================================="
echo "   SukaOS installation complete"
echo "======================================="
echo "Reboot or re-login to apply everything."

