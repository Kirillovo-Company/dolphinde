#!/bin/bash

# Проверка на выполнение от root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root. Используйте sudo."
    exit 1
fi

# Функция для обработки ошибок
handle_error() {
    echo "Ошибка в строке $1. Код выхода: $2"
    echo "Дополнительная информация:"
    echo "$3"
    exit 1
}

trap 'handle_error $LINENO $? "$BASH_COMMAND"' ERR

# Установка базовых компонентов
echo "Установка базовых компонентов..."
pacman -Syu --noconfirm || { echo "Ошибка при обновлении системы"; exit 1; }
pacman -S --noconfirm --needed xorg-server xorg-xinit xorg-xrandr xorg-xsetroot || { echo "Ошибка при установке Xorg"; exit 1; }

# Установка основных компонентов
echo "Установка Openbox и зависимостей..."
pacman -S --noconfirm --needed openbox obconf tint2 lxterminal sddm || { echo "Ошибка при установке основных компонентов"; exit 1; }

# Установка дополнительных утилит
echo "Установка дополнительных утилит..."
pacman -S --noconfirm --needed feh nitrogen lxappearance pcmanfm gvfs xarchiver file-roller \
    pulseaudio pavucontrol menu-cache obmenu-generator \
    network-manager-applet blueman volumeicon picom || { echo "Ошибка при установке дополнительных утилит"; exit 1; }

# Проверка существования файла обоев
WALLPAPER_SOURCE="$(dirname "$(realpath "$0")")/kirvalpaper.png"
if [ ! -f "$WALLPAPER_SOURCE" ]; then
    echo "Файл обоев kirvalpaper.png не найден в директории скрипта!"
    exit 1
fi

# Копирование обоев
echo "Копирование обоев..."
WALLPAPER_DEST="/usr/share/wallpapers/kirvalpaper.png"
mkdir -p /usr/share/wallpapers/ || { echo "Ошибка при создании директории для обоев"; exit 1; }
cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST" || { echo "Ошибка при копировании обоев"; exit 1; }
chmod 644 "$WALLPAPER_DEST" || { echo "Ошибка при изменении прав доступа к обоям"; exit 1; }

# Настройка для каждого пользователя
for USER_HOME in /home/*; do
    USER=$(basename "$USER_HOME")
    
    if [ -d "$USER_HOME" ]; then
        echo "Настройка для пользователя $USER..."
        
        # Создание конфигурационных файлов Openbox
        mkdir -p "$USER_HOME/.config/openbox" || { echo "Ошибка при создании директории Openbox"; exit 1; }
        cp /etc/xdg/openbox/{autostart,environment,menu.xml,rc.xml} "$USER_HOME/.config/openbox/" || { echo "Ошибка при копировании конфигов Openbox"; exit 1; }
        chown -R "$USER:$USER" "$USER_HOME/.config" || { echo "Ошибка при изменении владельца конфигов"; exit 1; }
        
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

        chmod +x "$USER_HOME/.config/openbox/autostart" || { echo "Ошибка при изменении прав autostart"; exit 1; }
        chown "$USER:$USER" "$USER_HOME/.config/openbox/autostart" || { echo "Ошибка при изменении владельца autostart"; exit 1; }

        # Настройка tint2
        mkdir -p "$USER_HOME/.config/tint2" || { echo "Ошибка при создании директории tint2"; exit 1; }
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

        chown -R "$USER:$USER" "$USER_HOME/.config/tint2" || { echo "Ошибка при изменении владельца tint2"; exit 1; }

        # Генерация меню
        sudo -u "$USER" obmenu-generator -p -i -c || { echo "Ошибка при генерации меню"; exit 1; }
    fi
done

# Настройка SDDM
echo "Настройка SDDM..."

# Установка темы SDDM (опционально)
pacman -S --noconfirm --needed sddm-theme-sugar-candy || { echo "Ошибка при установке темы SDDM"; exit 1; }

# Настройка конфигурации SDDM
cat > /etc/sddm.conf << 'EOL'
[Theme]
Current=sugar-candy

[Autologin]
Session=openbox.desktop

[General]
EnableHiDPI=false
EOL

# Настройка обоев для SDDM
mkdir -p /usr/share/sddm/themes/sugar-candy/Backgrounds/ || { echo "Ошибка при создании директории SDDM"; exit 1; }
cp "$WALLPAPER_SOURCE" /usr/share/sddm/themes/sugar-candy/Backgrounds/ || { echo "Ошибка при копировании обоев SDDM"; exit 1; }

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
mkdir -p /etc/pacman.d/hooks || { echo "Ошибка при создании директории hooks"; exit 1; }
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

# Включение SDDM
echo "Включение SDDM..."
systemctl enable sddm.service || { echo "Ошибка при включении SDDM"; exit 1; }

echo "Установка успешно завершена!"
echo "Рекомендуется перезагрузить систему:"
echo "sudo reboot"
