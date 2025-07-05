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

# Функция для безопасного удаления
safe_remove() {
    local pkg=$1
    local importance=${2:-optional} # important/optional
    
    if pacman -Qi "$pkg" &> /dev/null; then
        echo -e "Удаление ${YELLOW}$pkg${NC}..."
        if pacman -Rsn --noconfirm "$pkg"; then
            echo -e "${GREEN}✓${NC} $pkg успешно удален"
            return 0
        else
            if [ "$importance" = "important" ]; then
                echo -e "${RED}ОШИБКА: Не удалось удалить важный компонент $pkg!${NC}" >&2
                return 1
            else
                echo -e "${YELLOW}⚠${NC} Не удалось удалить необязательный компонент $pkg, пропускаем..." >&2
                return 0
            fi
        fi
    else
        echo -e "${GREEN}✓${NC} Пакет $pkg не установлен, пропускаем..."
        return 0
    fi
}

# Основной процесс удаления
main() {
    echo -e "\n${RED}=== НАЧАЛО УДАЛЕНИЯ DOLPHIN DESKTOP ===${NC}"
    
    # Отключение SDDM
    echo -e "\n${YELLOW}=== Отключение SDDM ===${NC}"
    if systemctl is-enabled sddm.service &> /dev/null; then
        echo -e "Отключаем SDDM..."
        systemctl disable sddm.service
    else
        echo -e "SDDM уже отключен, пропускаем..."
    fi
    
    # Удаление сессии Dolphin
    echo -e "\n${YELLOW}=== Удаление сессии Dolphin ===${NC}"
    if [ -f "/usr/share/xsessions/dolphin.desktop" ]; then
        rm -f /usr/share/xsessions/dolphin.desktop
        echo -e "Сессия Dolphin удалена"
    else
        echo -e "Сессия Dolphin не найдена, пропускаем..."
    fi
    
    # Удаление хука pacman
    echo -e "\n${YELLOW}=== Удаление pacman hook ===${NC}"
    if [ -f "/etc/pacman.d/hooks/obmenu-generator.hook" ]; then
        rm -f /etc/pacman.d/hooks/obmenu-generator.hook
        echo -e "Pacman hook удален"
    else
        echo -e "Pacman hook не найден, пропускаем..."
    fi
    
    # Удаление обоев
    echo -e "\n${YELLOW}=== Удаление обоев ===${NC}"
    WALLPAPER_DEST="/usr/share/wallpapers/kirvalpaper.png"
    if [ -f "$WALLPAPER_DEST" ]; then
        rm -f "$WALLPAPER_DEST"
        echo -e "Обои удалены"
    else
        echo -e "Обои не найдены, пропускаем..."
    fi
    
    # Удаление SDDM темы
    echo -e "\n${YELLOW}=== Удаление SDDM темы ===${NC}"
    safe_remove "sddm-theme-sugar-candy"
    
    # Удаление основных пакетов
    echo -e "\n${YELLOW}=== Удаление основных пакетов ===${NC}"
    safe_remove "sddm" "important"
    safe_remove "openbox" "important"
    safe_remove "obconf"
    safe_remove "lxpanel"  # Удаление lxpanel вместо tint2
    safe_remove "lxterminal"
    
    # Удаление дополнительных утилит
    echo -e "\n${YELLOW}=== Удаление дополнительных утилит ===${NC}"
    for pkg in feh nitrogen lxappearance pcmanfm gvfs xarchiver file-roller \
               pulseaudio pavucontrol menu-cache obmenu-generator \
               network-manager-applet blueman volumeicon picom; do
        safe_remove "$pkg"
    done
    
    # Удаление конфигов пользователей
    echo -e "\n${YELLOW}=== Очистка пользовательских конфигов ===${NC}"
    for USER_HOME in /home/*; do
        if [ -d "$USER_HOME" ]; then
            USER=$(basename "$USER_HOME")
            echo -e "Очистка для пользователя ${YELLOW}$USER${NC}..."
            
            if [ -d "$USER_HOME/.config/openbox" ]; then
                echo -e "Удаление конфигов Openbox..."
                rm -rf "$USER_HOME/.config/openbox"
            fi
            
            if [ -d "$USER_HOME/.config/lxpanel" ]; then  # Удаление конфигов lxpanel вместо tint2
                echo -e "Удаление конфигов lxpanel..."
                rm -rf "$USER_HOME/.config/lxpanel"
            fi
            
            chown -R "$USER:$USER" "$USER_HOME/.config"
        fi
    done
    
    echo -e "\n${GREEN}=== УДАЛЕНИЕ ЗАВЕРШЕНО ===${NC}"
    echo -e "Рекомендуется перезагрузить систему:"
    echo -e "${YELLOW}sudo reboot${NC}"
    return 0
}

# Запуск главной функции
if main; then
    exit 0
else
    echo -e "${RED}УДАЛЕНИЕ ЗАВЕРШИЛОСЬ С ОШИБКАМИ!${NC}" >&2
    exit 1
fi
