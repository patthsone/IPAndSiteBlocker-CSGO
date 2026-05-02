# IPAndSiteBlocker-CSGO

![Total Downloads](https://img.shields.io/github/downloads/patthsone/IPAndSiteBlocker-CSGO/total?style=flat&label=Total%20Downloads&labelColor=rgba(0%2C%2070%2C%20114%2C%201)&color=rgba(255%2C%20255%2C%20255%2C%201)) 
![Latest Release](https://img.shields.io/github/v/release/patthsone/IPAndSiteBlocker-CSGO?style=flat&label=Latest%20Release&labelColor=rgba(0%2C%2070%2C%20114%2C%201)&color=rgba(255%2C%20255%2C%20255%2C%201))

**IPAndSiteBlocker-CSGO** – плагин для SourceMod, который блокирует сообщения и имена игроков, содержащие IP-адреса, доменные имена (сайты) или запрещённые слова (бан-ворды). Поддерживает наказания через стандартные команды SourceMod (`sm_gag`, `ban`) и через **MaterialAdmin** (мут/бан). Гибко настраивается через белые списки и регулярные выражения (опционально).

## Возможности

- 🔒 Блокировка IP-адресов (с портом и без) в чате и именах.
- 🌐 Блокировка доменов (например, `example.com`, `sub.domain.ru`).
- 🚫 Фильтрация бан-вордов (мат, реклама, оскорбления).
- 📋 Белые списки IP и доменов (игнорирование).
- ⚖️ 5+ типов наказаний: предупреждение, кик, мут (`sm_gag`), бан, произвольная команда, а также мут/бан через MaterialAdmin.
- 📝 Логирование нарушений в файл.
- 💾 Автоматическое создание необходимых папок и файлов.
- 🔄 Поддержка MaterialAdmin (опционально, автоматически определяется).

## Требования

- **SourceMod 1.11+** (рекомендуется 1.12)
- **CS:GO** или другой Source-движок (CS2, L4D2 и т.д., но не проверялось)
- **MaterialAdmin** (только для наказаний типа 11 и 12) – опционально

## Установка

1. Скачайте последний релиз (файл `ip_site_blocker.smx`) или скомпилируйте исходник самостоятельно.
2. Поместите `ip_site_blocker.smx` в папку `addons/sourcemod/plugins/`.
3. Перезапустите сервер или выполните команду `sm plugins load ip_site_blocker`.
4. Плагин автоматически создаст папку `addons/sourcemod/configs/ip_site_blocker/` и файлы:
   - `whitelist_ip.txt`
   - `whitelist_domains.txt`
   - `banwords.txt`
5. Настройте белые списки и бан-слова в этих файлах (каждое значение с новой строки).
6. При необходимости отредактируйте CVAR в `cfg/sourcemod/ip_site_blocker.cfg` (файл создастся автоматически после загрузки плагина).

## Настройка

### Конфигурационные файлы

| Файл | Назначение |
|------|-------------|
| `addons/sourcemod/configs/ip_site_blocker/whitelist_ip.txt` | IP-адреса (можно с портом), которые не блокируются |
| `addons/sourcemod/configs/ip_site_blocker/whitelist_domains.txt` | Домены, которые не блокируются (например `my-server.ru`) |
| `addons/sourcemod/configs/ip_site_blocker/banwords.txt` | Запрещённые слова (регистр не важен) |
| `addons/sourcemod/translations/ip_site_blocker.phrases.txt` | Текстовые переводы (по умолчанию русский/английский) |

### CVAR (переменные в `cfg/sourcemod/ip_site_blocker.cfg`)

```cpp
// Включить/выключить проверку IP (1 - вкл, 0 - выкл)
sm_isb_enable_ip "1"

// Включить/выключить проверку доменов
sm_isb_enable_domain "1"

// Включить/выключить фильтр бан-вордов
sm_isb_enable_banwords "1"

// Включить логирование нарушений (лог в addons/sourcemod/logs/ip_site_blocker.log)
sm_isb_log "1"

// Тип наказания:
// 1  – только предупреждение в чате
// 2  – кик с сервера
// 3  – мут через sm_gag (SourceMod)
// 4  – бан через BanClient
// 5  – произвольная команда (см. sm_isb_punish_cmd)
// 11 – мут через MaterialAdmin (требуется MA)
// 12 – бан через MaterialAdmin (требуется MA)
sm_isb_punish_type "1"

// Произвольная команда для типа 5. Поддерживаются подстановки:
// {steamid64} , {ip} , {name} , #%i (userid)
sm_isb_punish_cmd "sm_gag #%i 60"

// Время мута (типы 3 и 11) в минутах
sm_isb_mute_time "60"

// Время бана (типы 4 и 12) в минутах (0 = навсегда)
sm_isb_ban_time "60"

// Тип бана MaterialAdmin: 1 – по SteamID, 2 – по IP
sm_isb_ma_ban_type "1"

// Тип мута MaterialAdmin: 1 – голосовой чат, 2 – текстовый, 3 – оба
sm_isb_ma_mute_type "3"
