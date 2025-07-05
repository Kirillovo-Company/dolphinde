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

# Функция для безопасной установки (пропускает ошибки для неважных пакетов)
safe_install() {
    local pkg=$1
    local importance=${2:-important} # important/optional
    
    if is_installed "$pkg"; then
        echo "✓ Пакет $pkg уже установлен, пропускаем..."
        return 0
    fi
    
    echo "Установка $pkg..."
    if pacman -S --noconfirm --needed "$pkg"; then
        echo "✓ $pkg успешно установлен"
        return 0
    else
        if [ "$importance" = "important" ]; then
            echo "ОШИБКА: Не удалось установить важный компонент $pkg!" >&2
            return 1
        else
            echo "⚠ Не удалось установить необязательный компонент $pkg, пропускаем..." >&2
            return 0
        fi
    fi
}

# Функция для выполнения команд с возможностью пропуска ошибок
safe_run() {
    local cmd=$1
    local importance=${2:-important} # important/optional
    
    if eval "$cmd"; then
        return 0
    else
        if [ "$importance" = "important" ]; then
            echo "ОШИБКА: Не удалось выполнить важную команду!" >&2
            echo "Команда: $cmd" >&2
            return 1
        else
            echo "⚠ Не удалось выполнить необязательную команду, пропускаем..." >&2
            echo "Команда: $cmd" >&2
            return 0
        fi
    fi
}

# Основной процесс установки
main() {
    # Проверка интернет-соединения
    echo "Проверка интернет-соединения..."
    if ! ping -c 1 archlinux.org &> /dev/null; then
        echo "ОШИБКА: Нет интернет-соединения!" >&2
        return 1
    fi

    # Обновление системы
    echo "Обновление системы..."
    safe_run "pacman -Syu --noconfirm" "important" || return 1

    # Установка базовых компонентов (все важные)
    echo "Установка базовых компонентов Xorg..."
    for pkg in xorg-server xorg-xinit xorg-xrandr xorg-xsetroot; do
        safe_install "$pkg" "important" || return 1
    done

    # Основные компоненты (Openbox и SDDM - важные, остальные - необязательные)
    echo "Установка основных компонентов..."
    safe_install "openbox" "important" || return 1
    safe_install "obconf" "important" || return 1
    safe_install "tint2" "optional"
    safe_install "lxterminal" "optional"
    safe_install "sddm" "important" || return 1
    safe_install "sddm-theme-sugar-candy" "optional"

    # Дополнительные утилиты (все необязательные)
    echo "Установка дополнительных утилит..."
    for pkg in feh nitrogen lxappearance pcmanfm gvfs xarchiver file-roller \
               pulseaudio pavucontrol menu-cache obmenu-generator \
               network-manager-applet blueman volumeicon picom; do
        safe_install "$pkg" "optional"
    done

    # Копирование обоев
    echo "Работа с обоями..."
    WALLPAPER_SOURCE="$(dirname "$(realpath "$0")")/kirvalpaper.png"
    if [ ! -f "$WALLPAPER_SOURCE" ]; then
        echo "⚠ Файл обоев kirvalpaper.png не найден, будут использоваться стандартные" >&2
    else
        WALLPAPER_DEST="/usr/share/wallpapers/kirvalpaper.png"
        safe_run "mkdir -p /usr/share/wallpapers/" "optional"
        safe_run "cp '$WALLPAPER_SOURCE' '$WALLPAPER_DEST'" "optional"
        safe_run "chmod 644 '$WALLPAPER_DEST'" "optional"
    fi

    # Настройка для пользователей
    echo "Настройка пользовательских конфигов..."
    for USER_HOME in /home/*; do
        if [ -d "$USER_HOME" ]; then
            USER=$(basename "$USER_HOME")
            echo "Пользователь $USER..."
            
            if ! id -u "$USER" &> /dev/null; then
                echo "⚠ Пользователь $USER не существует, пропускаем..."
                continue
            fi
            
            # Конфигурация Openbox
            safe_run "mkdir -p '$USER_HOME/.config/openbox'" "optional"
            safe_run "cp /etc/xdg/openbox/{autostart,environment,menu.xml,rc.xml} '$USER_HOME/.config/openbox/'" "optional"
            safe_run "chown -R '$USER:$USER' '$USER_HOME/.config'" "optional"
            
            # Autostart
            safe_run "cat > '$USER_HOME/.config/openbox/autostart' << 'EOL'
#!/bin/sh
# Установка обоев
[ -f '/usr/share/wallpapers/kirvalpaper.png' ] && feh --bg-scale /usr/share/wallpapers/kirvalpaper.png &
# Панель
which tint2 >/dev/null && tint2 &
# Раскладка клавиатуры
which setxkbmap >/dev/null && setxkbmap us,ru -option grp:alt_shift_toggle &
# Дополнительные настройки
which xsetroot >/dev/null && xsetroot -cursor_name left_ptr &
which xset >/dev/null && xset s off &
which xset >/dev/null && xset -dpms &
# Композитор
which picom >/dev/null && picom --config ~/.config/picom.conf &
# Системные треи
which nm-applet >/dev/null && nm-applet &
which blueman-applet >/dev/null && blueman-applet &
which volumeicon >/dev/null && volumeicon &
EOL" "optional"
            
            safe_run "chmod +x '$USER_HOME/.config/openbox/autostart'" "optional"
            safe_run "chown '$USER:$USER' '$USER_HOME/.config/openbox/autostart'" "optional"
            
            # Настройка tint2
            safe_run "mkdir -p '$USER_HOME/.config/tint2'" "optional"
            safe_run "cat > '$USER_HOME/.config/tint2/tint2rc' << 'EOL'
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
EOL" "optional"
            
            safe_run "chown -R '$USER:$USER' '$USER_HOME/.config/tint2'" "optional"
            
            # Генерация меню
            safe_run "sudo -u '$USER' obmenu-generator -p -i -c" "optional"
        fi
    done

    # Настройка SDDM
    echo "Настройка SDDM..."
    safe_run "mkdir -p /usr/share/sddm/themes/sugar-candy/Backgrounds/" "optional"
    if [ -f "$WALLPAPER_SOURCE" ]; then
        safe_run "cp '$WALLPAPER_SOURCE' /usr/share/sddm/themes/sugar-candy/Backgrounds/" "optional"
    fi
    
    safe_run "cat > /etc/sddm.conf << 'EOL'
[Theme]
Current=sugar-candy
CursorTheme=Adwaita
Font=Sans Serif
[Autologin]
Session=openbox.desktop
[General]
EnableHiDPI=false
EOL" "optional"

    # Создание сессии Dolphin
    safe_run "cat > /usr/share/xsessions/dolphin.desktop << 'EOL'
[Desktop Entry]
Name=Dolphin
Comment=Lightweight Openbox-based desktop
Exec=/usr/bin/openbox-session
TryExec=/usr/bin/openbox-session
Type=Application
EOL" "important" || return 1

    # Настройка хука для pacman
    safe_run "mkdir -p /etc/pacman.d/hooks" "optional"
    safe_run "cat > /etc/pacman.d/hooks/obmenu-generator.hook << 'EOL'
[Trigger]
Operation = Install
Operation = Remove
Type = Package
Target = *
[Action]
Description = Updating Openbox menu...
When = PostTransaction
Exec = /usr/bin/obmenu-generator -p -i -c
EOL" "optional"

    # Включение SDDM
    safe_run "systemctl enable sddm.service" "important" || return 1

    echo ""
    echo "УСТАНОВКА ЗАВЕРШЕНА!"
    echo "Рекомендуется перезагрузить систему:"
    echo "sudo reboot"
    return 0
}

# Запуск главной функции
if main; then
    exit 0
else
    echo "УСТАНОВКА ЗАВЕРШИЛАСЬ С ОШИБКАМИ!" >&2
    exit 1
fi
