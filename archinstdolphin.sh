#!/bin/bash

# Проверка на выполнение от root
if [ "$(id -u)" -ne 0 ]; then
  echo "Этот скрипт должен быть запущен с правами root. Используйте sudo."
  exit 1
fi

# Установка базовых компонентов
echo "Установка базовых компонентов..."
pacman -Syu --noconfirm
pacman -S --noconfirm xorg-server xorg-xinit xorg-xrandr xorg-xsetroot

# Установка основных компонентов
echo "Установка Openbox и зависимостей..."
pacman -S --noconfirm openbox obconf tint2 lxterminal lightdm lightdm-gtk-greeter

# Установка дополнительных утилит
echo "Установка дополнительных утилит..."
pacman -S --noconfirm feh nitrogen lxappearance pcmanfm gvfs xarchiver file-roller \
                     pulseaudio pavucontrol menu-cache obmenu-generator \
                     network-manager-applet blueman volumeicon picom

# Копирование обоев
echo "Копирование обоев..."
WALLPAPER_SOURCE="$(dirname "$(realpath "$0")")/kirvalpaper.png"
WALLPAPER_DEST="/usr/share/wallpapers/kirvalpaper.png"

mkdir -p /usr/share/wallpapers/
cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"
chmod 644 "$WALLPAPER_DEST"

# Настройка для каждого пользователя
for USER_HOME in /home/*; do
  USER=$(basename "$USER_HOME")
  
  if [ -d "$USER_HOME" ]; then
    echo "Настройка для пользователя $USER..."
    
    # Создание конфигурационных файлов Openbox
    mkdir -p "$USER_HOME/.config/openbox"
    cp /etc/xdg/openbox/{autostart,environment,menu.xml,rc.xml} "$USER_HOME/.config/openbox/"
    chown -R "$USER:$USER" "$USER_HOME/.config"
    
    # Настройка autostart
    cat > "$USER_HOME/.config/openbox/autostart" << 'EOL'
#!/bin/sh

# Установка обоев
feh --bg-scale /usr/share/wallpapers/kirvalpaper.png &

# Запуск панели tint2
tint2 &

# Настройка раскладки клавиатуры
setxkbmap us,ru -option grp:alt_shift_toggle &

# Дополнительные настройки
xsetroot -cursor_name left_ptr &
xset s off &
xset -dpms &

# Запуск композитора
picom &

# Системные треи
nm-applet &
blueman-applet &
volumeicon &
EOL

    chmod +x "$USER_HOME/.config/openbox/autostart"
    chown "$USER:$USER" "$USER_HOME/.config/openbox/autostart"

    # Настройка tint2
    mkdir -p "$USER_HOME/.config/tint2"
    cat > "$USER_HOME/.config/tint2/tint2rc" << 'EOL'
# Панель
panel_monitor = all
panel_position = bottom center
panel_items = TSC
panel_size = 100% 30
panel_margin = 0 0
panel_padding = 2 0 2
panel_dock = 0
wm_menu = 1

# Фон
panel_background_id = 1
rounded = 0
border_width = 0
background_color = #333333 60

# Таксбар
taskbar_mode = multi_desktop
taskbar_padding = 6 2 6
taskbar_background_id = 0
taskbar_active_background_id = 0
taskbar_name = 1
taskbar_name_background_id = 0
taskbar_name_active_background_id = 0
taskbar_name_font = Sans 10
taskbar_name_font_color = #ffffff 100
taskbar_name_active_font_color = #ffffff 100

# Системная зона
system_tray_padding = 0 4 2
system_tray_sort = ascending

# Часы
time1_format = %H:%M
time1_font = Sans 10
time2_format = %A %d %B
time2_font = Sans 8
clock_font_color = #ffffff 100
clock_padding = 2 0
clock_background_id = 0
EOL

    chown -R "$USER:$USER" "$USER_HOME/.config/tint2"

    # Генерация меню
    sudo -u "$USER" obmenu-generator -p -i -c
  fi
done

# Настройка LightDM
echo "Настройка LightDM..."
cat > /etc/lightdm/lightdm.conf << 'EOL'
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=dolphin
EOL

cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'EOL'
[greeter]
background = /usr/share/wallpapers/kirvalpaper.png
theme-name = Adwaita-dark
icon-theme-name = Adwaita
font-name = Sans 10
EOL

# Создание .desktop файла для сессии Dolphin
echo "Создание сессии Dolphin..."
cat > /usr/share/xsessions/dolphin.desktop << 'EOL'
[Desktop Entry]
Name=Dolphin
Comment=Lightweight Openbox-based desktop
Exec=/usr/bin/openbox-session
TryExec=/usr/bin/openbox-session
Type=Application
EOL

# Создание хука для обновления меню
echo "Создание pacman hook для обновления меню..."
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/obmenu-generator.hook << 'EOL'
[Trigger]
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Updating Openbox menu...
When = PostTransaction
Exec = /usr/bin/obmenu-generator -p -i -c
EOL

# Включение LightDM
echo "Включение LightDM..."
systemctl enable lightdm.service

echo "Установка завершена! Система будет перезагружена через 10 секунд..."
sleep 10
reboot
