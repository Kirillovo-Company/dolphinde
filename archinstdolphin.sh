#!/bin/bash

# Проверка на выполнение от root
if [ "$(id -u)" -ne 0 ]; then
    echo "ОШИБКА: Этот скрипт должен быть запущен с правами root. Используйте sudo."
    exit 1
fi

# Функция для обработки ошибок
handle_error() {
    echo "ОШИБКА в строке $1. Команда: $2. Код выхода: $3" >&2
    exit 1
}

trap 'handle_error $LINENO "$BASH_COMMAND" $?' ERR

# Проверка интернет-соединения
echo "Проверка интернет-соединения..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    echo "ОШИБКА: Нет интернет-соединения!" >&2
    exit 1
fi

# Установка базовых компонентов
echo "Обновление системы и установка базовых компонентов..."
pacman -Syu --noconfirm || { echo "ОШИБКА: Не удалось обновить систему" >&2; exit 1; }
pacman -S --noconfirm --needed xorg-server xorg-xinit xorg-xrandr xorg-xsetroot || { echo "ОШИБКА: Не удалось установить Xorg" >&2; exit 1; }

# Установка основных компонентов
echo "Установка Openbox и зависимостей..."
pacman -S --noconfirm --needed openbox obconf tint2 lxterminal || { echo "ОШИБКА: Не удалось установить основные компоненты" >&2; exit 1; }

# Установка дополнительных утилит
echo "Установка дополнительных утилит..."
pacman -S --noconfirm --needed feh nitrogen lxappearance pcmanfm gvfs xarchiver file-roller \
    pulseaudio pavucontrol menu-cache obmenu-generator \
    network-manager-applet blueman volumeicon picom || { echo "ОШИБКА: Не удалось установить дополнительные утилиты" >&2; exit 1; }

# Проверка и копирование обоев
echo "Проверка файла обоев..."
WALLPAPER_SOURCE="$(dirname "$(realpath "$0")")/kirvalpaper.png"
if [ ! -f "$WALLPAPER_SOURCE" ]; then
    echo "ОШИБКА: Файл обоев kirvalpaper.png не найден в директории скрипта!" >&2
    exit 1
fi

WALLPAPER_DEST="/usr/share/wallpapers/kirvalpaper.png"
echo "Копирование обоев..."
mkdir -p /usr/share/wallpapers/ || { echo "ОШИБКА: Не удалось создать директорию для обоев" >&2; exit 1; }
if ! cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"; then
    echo "ОШИБКА: Не удалось скопировать обои" >&2
    exit 1
fi
chmod 644 "$WALLPAPER_DEST" || { echo "ОШИБКА: Не удалось изменить права доступа к обоям" >&2; exit 1; }

# Настройка для пользователей
echo "Настройка для пользователей..."
for USER_HOME in /home/*; do
    if [ -d "$USER_HOME" ]; then
        USER=$(basename "$USER_HOME")
        echo "Настройка для пользователя $USER..."
        
        # Проверка существования пользователя
        if ! id -u "$USER" &> /dev/null; then
            echo "ПРЕДУПРЕЖДЕНИЕ: Пользователь $USER не существует, пропускаем..."
            continue
        fi
        
        # Создание конфигурационных файлов Openbox
        echo "Создание конфигов Openbox..."
        mkdir -p "$USER_HOME/.config/openbox" || { echo "ОШИБКА: Не удалось создать директорию Openbox" >&2; exit 1; }
        cp /etc/xdg/openbox/{autostart,environment,menu.xml,rc.xml} "$USER_HOME/.config/openbox/" || { echo "ОШИБКА: Не удалось скопировать конфиги Openbox" >&2; exit 1; }
        chown -R "$USER:$USER" "$USER_HOME/.config" || { echo "ОШИБКА: Не удалось изменить владельца конфигов" >&2; exit 1; }
        
        # Настройка autostart
        echo "Настройка автозапуска..."
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
picom --config ~/.config/picom.conf &

# Системные треи
nm-applet &
blueman-applet &
volumeicon &
EOL

        chmod +x "$USER_HOME/.config/openbox/autostart" || { echo "ОШИБКА: Не удалось изменить права autostart" >&2; exit 1; }
        chown "$USER:$USER" "$USER_HOME/.config/openbox/autostart" || { echo "ОШИБКА: Не удалось изменить владельца autostart" >&2; exit 1; }

        # Настройка tint2
        echo "Настройка tint2..."
        mkdir -p "$USER_HOME/.config/tint2" || { echo "ОШИБКА: Не удалось создать директорию tint2" >&2; exit 1; }
        cat > "$USER_HOME/.config/tint2/tint2rc" << 'EOL'
[panel]
monitor = all
position = bottom center
size = 100% 30
margin = 0 0
padding = 2 0 2
dock = 0
wm_menu = 1

[background]
color = #333333 60
rounded = 0
border_width = 0

[taskbar]
mode = multi_desktop
padding = 6 2 6
show_all = true

[task]
max_width = 150
show_icon = true
show_text = true

[system]
systray_padding = 0 4 2
sort = ascending

[clock]
time1_format = %H:%M
time1_font = Sans 10
time2_format = %A %d %B
time2_font = Sans 8
color = #ffffff 100
padding = 2 0
EOL

        chown -R "$USER:$USER" "$USER_HOME/.config/tint2" || { echo "ОШИБКА: Не удалось изменить владельца tint2" >&2; exit 1; }

        # Генерация меню
        echo "Генерация меню..."
        sudo -u "$USER" obmenu-generator -p -i -c || { echo "ОШИБКА: Не удалось сгенерировать меню" >&2; exit 1; }
    fi
done

# Настройка SDDM
echo "Настройка SDDM..."
mkdir -p /usr/share/sddm/themes/sugar-candy/Backgrounds/ || { echo "ОШИБКА: Не удалось создать директорию для SDDM" >&2; exit 1; }
cp "$WALLPAPER_SOURCE" /usr/share/sddm/themes/sugar-candy/Backgrounds/ || { echo "ОШИБКА: Не удалось скопировать обои для SDDM" >&2; exit 1; }

cat > /etc/sddm.conf << 'EOL'
[Theme]
Current=sugar-candy
CursorTheme=Adwaita
Font=Sans Serif

[Autologin]
Session=openbox.desktop

[General]
EnableHiDPI=false
EOL

# Создание сессии Dolphin
echo "Создание сессии Dolphin..."
cat > /usr/share/xsessions/dolphin.desktop << 'EOL'
[Desktop Entry]
Name=Dolphin
Comment=Lightweight Openbox-based desktop
Exec=/usr/bin/openbox-session
TryExec=/usr/bin/openbox-session
Type=Application
EOL

# Настройка хука для pacman
echo "Настройка pacman hook..."
mkdir -p /etc/pacman.d/hooks || { echo "ОШИБКА: Не удалось создать директорию hooks" >&2; exit 1; }
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
systemctl enable sddm.service || { echo "ОШИБКА: Не удалось включить SDDM" >&2; exit 1; }

echo ""
echo "УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!"
echo "Рекомендуется перезагрузить систему:"
echo "sudo reboot"
