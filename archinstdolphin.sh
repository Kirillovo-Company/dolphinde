#!/bin/bash

# Проверка на выполнение от root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[1;31mОШИБКА: Этот скрипт должен быть запущен с правами root. Используйте sudo.\033[0m"
    exit 1
fi

# Цвета для вывода
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция проверки установки пакета
is_installed() {
    pacman -Qi "$1" &> /dev/null
    return $?
}

# Функция проверки доступности пакета
is_available() {
    pacman -Si "$1" &> /dev/null
    return $?
}

# Функция для безопасной установки
safe_install() {
    local pkg=$1
    local importance=${2:-important} # important/optional
    
    if is_installed "$pkg"; then
        echo -e "${GREEN}✓${NC} Пакет $pkg уже установлен, пропускаем..."
        return 0
    fi
    
    if ! is_available "$pkg"; then
        echo -e "${YELLOW}⚠${NC} Пакет $pkg недоступен в репозиториях, пропускаем..."
        return 0
    fi
    
    echo -e "Установка ${YELLOW}$pkg${NC}..."
    if pacman -S --noconfirm --needed "$pkg"; then
        echo -e "${GREEN}✓${NC} $pkg успешно установлен"
        return 0
    else
        if [ "$importance" = "important" ]; then
            echo -e "${RED}ОШИБКА: Не удалось установить важный компонент $pkg!${NC}" >&2
            return 1
        else
            echo -e "${YELLOW}⚠${NC} Не удалось установить необязательный компонент $pkg, пропускаем..." >&2
            return 0
        fi
    fi
}

# Функция для выполнения команд с возможностью пропуска ошибок
safe_run() {
    local cmd=$1
    local importance=${2:-important} # important/optional
    local description=${3:-$cmd}
    
    echo -e "Выполнение: ${YELLOW}$description${NC}"
    if eval "$cmd"; then
        return 0
    else
        if [ "$importance" = "important" ]; then
            echo -e "${RED}ОШИБКА: Не удалось выполнить важную команду!${NC}" >&2
            echo -e "Команда: $cmd" >&2
            return 1
        else
            echo -e "${YELLOW}⚠${NC} Не удалось выполнить необязательную команду, пропускаем..." >&2
            echo -e "Команда: $cmd" >&2
            return 0
        fi
    fi
}

# Функция для определения текущего Display Manager
get_active_dm() {
    if [ -f "/etc/systemd/system/display-manager.service" ]; then
        local active_dm=$(cat /etc/systemd/system/display-manager.service | awk -F'/' '{print $NF}')
        echo "$active_dm"
    else
        echo ""
    fi
}

# Основной процесс установки
main() {
    # Проверка интернет-соединения
    echo -e "\n${GREEN}=== Проверка интернет-соединения ===${NC}"
    if ! ping -c 1 archlinux.org &> /dev/null; then
        echo -e "${RED}ОШИБКА: Нет интернет-соединения!${NC}" >&2
        return 1
    fi

    # Обновление системы
    echo -e "\n${GREEN}=== Обновление системы ===${NC}"
    safe_run "pacman -Syu --noconfirm" "important" "Обновление пакетов" || return 1

    # Установка базовых компонентов
    echo -e "\n${GREEN}=== Установка базовых компонентов Xorg ===${NC}"
    for pkg in xorg-server xorg-xinit xorg-xrandr xorg-xsetroot; do
        safe_install "$pkg" "important" || return 1
    done

    # Установка основных компонентов
    echo -e "\n${GREEN}=== Установка основных компонентов ===${NC}"
    safe_install "openbox" "important" || return 1
    
    # Установка obconf или альтернатив
    if is_available "obconf"; then
        safe_install "obconf" "optional"
    else
        echo -e "${YELLOW}⚠ obconf недоступен в репозиториях, устанавливаем альтернативы...${NC}"
        safe_install "lxappearance" "optional"
        safe_install "obmenu-generator" "optional"
    fi
    
    safe_install "tint2" "optional"
    safe_install "lxterminal" "optional"

    # Проверка и настройка Display Manager
    echo -e "\n${GREEN}=== Проверка Display Manager ===${NC}"
    CURRENT_DM=$(get_active_dm)
    
    if [ -n "$CURRENT_DM" ] && [ "$CURRENT_DM" != "sddm.service" ]; then
        echo -e "${YELLOW}⚠ Обнаружен уже установленный Display Manager ($CURRENT_DM), пропускаем установку SDDM${NC}"
    else
        # Установка SDDM
        safe_install "sddm" "important" || return 1
        safe_install "sddm-theme-sugar-candy" "optional"
        
        # Настройка SDDM
        safe_run "mkdir -p /usr/share/sddm/themes/sugar-candy/Backgrounds/" "optional" "Создание директории тем SDDM"
        
        # Копирование обоев
        WALLPAPER_SOURCE="$(dirname "$(realpath "$0")")/kirvalpaper.png"
        if [ -f "$WALLPAPER_SOURCE" ]; then
            safe_run "cp '$WALLPAPER_SOURCE' /usr/share/sddm/themes/sugar-candy/Backgrounds/" "optional" "Копирование обоев для SDDM"
            safe_run "cp '$WALLPAPER_SOURCE' /usr/share/wallpapers/kirvalpaper.png" "optional" "Копирование обоев для рабочего стола"
        else
            echo -e "${YELLOW}⚠ Файл обоев kirvalpaper.png не найден, будут использоваться стандартные${NC}"
        fi
        
        # Настройка конфига SDDM
        safe_run "cat > /etc/sddm.conf << 'EOL'
[Theme]
Current=sugar-candy
CursorTheme=Adwaita
Font=Sans Serif
[Autologin]
Session=openbox.desktop
[General]
EnableHiDPI=false
EOL" "important" "Настройка конфига SDDM" || return 1
        
        # Включение SDDM только если он не был активен ранее
        if [ -z "$CURRENT_DM" ]; then
            safe_run "systemctl enable sddm.service" "important" "Включение SDDM" || return 1
        else
            echo -e "${YELLOW}⚠ SDDM уже настроен как Display Manager, пропускаем включение${NC}"
        fi
    fi

    # Установка дополнительных утилит
    echo -e "\n${GREEN}=== Установка дополнительных утилит ===${NC}"
    for pkg in feh nitrogen lxappearance pcmanfm gvfs xarchiver file-roller \
               pulseaudio pavucontrol menu-cache obmenu-generator \
               network-manager-applet blueman volumeicon picom; do
        safe_install "$pkg" "optional"
    done

    # Настройка для пользователей
    echo -e "\n${GREEN}=== Настройка пользовательских конфигов ===${NC}"
    for USER_HOME in /home/*; do
        if [ -d "$USER_HOME" ]; then
            USER=$(basename "$USER_HOME")
            echo -e "Настройка для пользователя ${YELLOW}$USER${NC}..."
            
            if ! id -u "$USER" &> /dev/null; then
                echo -e "${YELLOW}⚠ Пользователь $USER не существует, пропускаем...${NC}"
                continue
            fi
            
            # Конфигурация Openbox
            safe_run "mkdir -p '$USER_HOME/.config/openbox'" "optional" "Создание директории Openbox"
            safe_run "cp /etc/xdg/openbox/{autostart,environment,menu.xml,rc.xml} '$USER_HOME/.config/openbox/'" "optional" "Копирование конфигов Openbox"
            
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
EOL" "optional" "Создание autostart"
            
            safe_run "chmod +x '$USER_HOME/.config/openbox/autostart'" "optional" "Установка прав autostart"
            
            # Настройка tint2
            safe_run "mkdir -p '$USER_HOME/.config/tint2'" "optional" "Создание директории tint2"
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
EOL" "optional" "Создание tint2rc"
            
            # Установка прав
            safe_run "chown -R '$USER:$USER' '$USER_HOME/.config'" "important" "Настройка прав доступа"
            
            # Генерация меню
            safe_run "sudo -u '$USER' obmenu-generator -p -i -c" "optional" "Генерация меню приложений"
        fi
    done

    # Создание сессии Dolphin
    echo -e "\n${GREEN}=== Создание сессии Dolphin ===${NC}"
    safe_run "cat > /usr/share/xsessions/dolphin.desktop << 'EOL'
[Desktop Entry]
Name=Dolphin
Comment=Lightweight Openbox-based desktop
Exec=/usr/bin/openbox-session
TryExec=/usr/bin/openbox-session
Type=Application
EOL" "important" "Создание сессии Dolphin" || return 1

    # Настройка хука для pacman
    echo -e "\n${GREEN}=== Настройка pacman hook ===${NC}"
    safe_run "mkdir -p /etc/pacman.d/hooks" "optional" "Создание директории hooks"
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
EOL" "optional" "Создание pacman hook"

    echo -e "\n${GREEN}=== УСТАНОВКА ЗАВЕРШЕНА ===${NC}"
    echo -e "Рекомендуется перезагрузить систему:"
    echo -e "${YELLOW}sudo reboot${NC}"
    return 0
}

# Запуск главной функции
echo -e "\n${GREEN}=== ЗАПУСК УСТАНОВКИ DOLPHIN DESKTOP ===${NC}"
if main; then
    echo -e "${GREEN}Установка успешно завершена!${NC}"
    exit 0
else
    echo -e "${RED}УСТАНОВКА ЗАВЕРШИЛАСЬ С ОШИБКАМИ!${NC}" >&2
    exit 1
fi
