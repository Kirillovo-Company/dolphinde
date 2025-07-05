#!/bin/bash

# Проверка на выполнение от root
if [ "$(id -u)" -ne 0 ]; then
    echo "ОШИБКА: Этот скрипт должен быть запущен с правами root. Используйте sudo."
    exit 1
fi

# Функция проверки установки пакета
is_installed() {
    pacman -Qi "$1" &> /dev/null
    return $?
}

# Функция для безопасной установки
safe_install() {
    local pkg=$1
    if is_installed "$pkg"; then
        echo "Пакет $pkg уже установлен, пропускаем..."
    else
        echo "Установка $pkg..."
        pacman -S --noconfirm --needed "$pkg" || { echo "ОШИБКА: Не удалось установить $pkg" >&2; return 1; }
    fi
}

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

# Обновление системы (пропускаем если не нужно)
echo "Проверка обновлений системы..."
pacman -Syu --noconfirm || { echo "ОШИБКА: Не удалось обновить систему" >&2; exit 1; }

# Установка базовых компонентов
echo "Установка базовых компонентов Xorg..."
for pkg in xorg-server xorg-xinit xorg-xrandr xorg-xsetroot; do
    safe_install "$pkg"
done

# Установка основных компонентов
echo "Установка основных компонентов..."
for pkg in openbox obconf tint2 lxterminal sddm sddm-theme-sugar-candy; do
    safe_install "$pkg"
done

# Установка дополнительных утилит
echo "Установка дополнительных утилит..."
for pkg in feh nitrogen lxappearance pcmanfm gvfs xarchiver file-roller \
           pulseaudio pavucontrol menu-cache obmenu-generator \
           network-manager-applet blueman volumeicon picom; do
    safe_install "$pkg"
done

# Проверка и копирование обоев
echo "Проверка файла обоев..."
WALLPAPER_SOURCE="$(dirname "$(realpath "$0")")/kirvalpaper.png"
if [ ! -f "$WALLPAPER_SOURCE" ]; then
    echo "ОШИБКА: Файл обоев kirvalpaper.png не найден в директории скрипта!" >&2
    exit 1
fi

WALLPAPER_DEST="/usr/share/wallpapers/kirvalpaper.png"
echo "Копирование обоев..."
mkdir -p /usr/share/wallpapers/
if [ ! -f "$WALLPAPER_DEST" ] || ! cmp -s "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"; then
    cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST" || { echo "ОШИБКА: Не удалось скопировать обои" >&2; exit 1; }
    chmod 644 "$WALLPAPER_DEST" || { echo "ОШИБКА: Не удалось изменить права доступа к обоям" >&2; exit 1; }
else
    echo "Обои уже существуют и идентичны, пропускаем копирование..."
fi

# Настройка для пользователей
echo "Настройка для пользователей..."
for USER_HOME in /home/*; do
    if [ -d "$USER_HOME" ]; then
        USER=$(basename "$USER_HOME")
        echo "Настройка для пользователя $USER..."
        
        if ! id -u "$USER" &> /dev/null; then
            echo "ПРЕДУПРЕЖДЕНИЕ: Пользователь $USER не существует, пропускаем..."
            continue
        fi
        
        # Конфигурация Openbox
        echo "Настройка Openbox..."
        mkdir -p "$USER_HOME/.config/openbox"
        if [ ! -f "$USER_HOME/.config/openbox/autostart" ]; then
            cp /etc/xdg/openbox/{autostart,environment,menu.xml,rc.xml} "$USER_HOME/.config/openbox/"
        else
            echo "Конфиги Openbox уже существуют, пропускаем..."
        fi
        chown -R "$USER:$USER" "$USER_HOME/.config"
        
        # Autostart
        if [ ! -f "$USER_HOME/.config/openbox/autostart" ] || ! grep -q "feh --bg-scale" "$USER_HOME/.config/openbox/autostart"; then
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
            chmod +x "$USER_HOME/.config/openbox/autostart"
        else
            echo "Autostart уже настроен, пропускаем..."
        fi
        chown "$USER:$USER" "$USER_HOME/.config/openbox/autostart"
        
        # Настройка tint2
        echo "Настройка tint2..."
        mkdir -p "$USER_HOME/.config/tint2"
        if [ ! -f "$USER_HOME/.config/tint2/tint2rc" ]; then
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
        else
            echo "Конфиг tint2 уже существует, пропускаем..."
        fi
        chown -R "$USER:$USER" "$USER_HOME/.config/tint2"
        
        # Генерация меню
        echo "Генерация меню..."
        sudo -u "$USER" obmenu-generator -p -i -c || echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось сгенерировать меню" >&2
    fi
done

# Настройка SDDM
echo "Настройка SDDM..."
mkdir -p /usr/share/sddm/themes/sugar-candy/Backgrounds/
if [ ! -f "/usr/share/sddm/themes/sugar-candy/Backgrounds/kirvalpaper.png" ] || \
   ! cmp -s "$WALLPAPER_SOURCE" "/usr/share/sddm/themes/sugar-candy/Backgrounds/kirvalpaper.png"; then
    cp "$WALLPAPER_SOURCE" "/usr/share/sddm/themes/sugar-candy/Backgrounds/" || { echo "ОШИБКА: Не удалось скопировать обои для SDDM" >&2; exit 1; }
else
    echo "Обои для SDDM уже существуют, пропускаем..."
fi

if [ ! -f "/etc/sddm.conf" ]; then
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
else
    echo "Конфиг SDDM уже существует, пропускаем..."
fi

# Создание сессии Dolphin
echo "Проверка сессии Dolphin..."
if [ ! -f "/usr/share/xsessions/dolphin.desktop" ]; then
    cat > /usr/share/xsessions/dolphin.desktop << 'EOL'
[Desktop Entry]
Name=Dolphin
Comment=Lightweight Openbox-based desktop
Exec=/usr/bin/openbox-session
TryExec=/usr/bin/openbox-session
Type=Application
EOL
else
    echo "Сессия Dolphin уже существует, пропускаем..."
fi

# Настройка хука для pacman
echo "Проверка pacman hook..."
if [ ! -f "/etc/pacman.d/hooks/obmenu-generator.hook" ]; then
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
else
    echo "Pacman hook уже существует, пропускаем..."
fi

# Включение SDDM
echo "Проверка службы SDDM..."
if ! systemctl is-enabled sddm.service &> /dev/null; then
    systemctl enable sddm.service || { echo "ОШИБКА: Не удалось включить SDDM" >&2; exit 1; }
else
    echo "SDDM уже включен, пропускаем..."
fi

echo ""
echo "УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!"
echo "Рекомендуется перезагрузить систему:"
echo "sudo reboot"
