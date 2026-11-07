#!/data/data/com.termux/files/usr/bin/bash
# Claude Code + Ubuntu + XFCE for Termux / Termux:X11
# Safe to rerun: preserves an existing container and resumes configuration.
set -Eeuo pipefail

readonly CONTAINER="claude-code"
readonly DISPLAY_NUMBER=":1"
readonly PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
readonly BIN_DIR="$PREFIX_DIR/bin"
readonly LAUNCHER="$BIN_DIR/claude-code-desktop"
readonly MIN_FREE_KB=4000000

log()  { printf '\n\033[1;32m[SETUP]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[AVISO]\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31m[ERRO]\033[0m %s\n' "$*" >&2; exit 1; }
on_error() {
  local rc=$?
  printf '\n\033[1;31m[ERRO]\033[0m Falha na linha %s (código %s).\n' "${BASH_LINENO[0]:-desconhecida}" "$rc" >&2
  printf 'O ambiente não será apagado. Corrija a causa e execute novamente o mesmo comando para continuar.\n' >&2
  exit "$rc"
}
trap on_error ERR

# ---------- Preflight ----------
[ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux ] || die "Execute este comando dentro do aplicativo Termux."
[ "$(uname -m)" = "aarch64" ] || die "Aparelho incompatível: é necessário Android ARM64 (aarch64)."
command -v pkg >/dev/null 2>&1 || die "O gerenciador de pacotes pkg não foi encontrado."
[ -n "${PREFIX:-}" ] || die "A variável PREFIX não está definida. Abra o Termux oficial e tente novamente."

# Android's package service (pm path) may fail with a Binder transaction error
# on some devices even when Termux:X11 is installed. Do not block setup here.
if command -v pm >/dev/null 2>&1 && ! pm path com.termux.x11 >/dev/null 2>&1; then
  warn "Não foi possível confirmar o Termux:X11 via pm path. Isso pode ser uma falha do serviço Android; a abertura real será verificada ao iniciar o desktop."
fi

FREE_KB="$(df -Pk "$PREFIX_DIR" | awk 'NR==2 {print $4}')"
if [[ "$FREE_KB" =~ ^[0-9]+$ ]]; then
  if [ "$FREE_KB" -lt "$MIN_FREE_KB" ]; then
    die "Há menos de aproximadamente 4 GB livres no armazenamento do Termux. Libere espaço antes de instalar Ubuntu, XFCE e Claude Code."
  fi
  if [ "$FREE_KB" -lt 8388608 ]; then
    warn "Há menos de 8 GB livres. A instalação pode precisar de espaço adicional para atualizações e cache."
  fi
fi

# ---------- Termux packages ----------
log "Atualizando os repositórios do Termux..."
pkg update -y
pkg install -y x11-repo
pkg update -y

log "Instalando o suporte Linux e gráfico no Termux..."
pkg install -y proot-distro termux-x11-nightly git curl wget ca-certificates termux-tools

command -v termux-x11 >/dev/null 2>&1 || die "O comando termux-x11 não foi instalado. Confira os repositórios do Termux."
command -v proot-distro >/dev/null 2>&1 || die "proot-distro não foi instalado."

# ---------- Ubuntu container (create once, then resume) ----------
if proot-distro list 2>/dev/null | grep -Eq "(^|[[:space:]])${CONTAINER}([*]?[[:space:]]|$)"; then
  log "O Ubuntu '$CONTAINER' já existe. Vou preservar e continuar a configuração."
else
  log "Baixando e criando Ubuntu 24.04 ARM64 isolado..."
  proot-distro install --name "$CONTAINER" ubuntu:24.04
fi

# Confirm that the container can actually be entered before modifying it.
proot-distro login "$CONTAINER" -- /bin/true >/dev/null 2>&1 || die "O Ubuntu '$CONTAINER' existe, mas não abriu corretamente. Não foi apagado; verifique o erro do proot-distro."

# ---------- Desktop and runtime ----------
log "Instalando/atualizando XFCE, terminal, Thunar, DBus e ferramentas..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  xfce4 xfce4-terminal thunar dbus-x11 dbus-user-session \
  xterm fonts-dejavu-core adwaita-icon-theme \
  nodejs npm git curl wget ca-certificates file procps psmisc \
  sudo xdg-utils
'

# Claude Code officially supports Linux ARM64 and requires Node.js 18+.
log "Validando Node.js e npm dentro do Ubuntu..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
node -e "const v=process.versions.node.split(\".\").map(Number); if(v[0] < 18) { console.error(\"Node.js 18+ é obrigatório; encontrado: \" + process.version); process.exit(1); }"
npm --version
'

# Install official CLI tools inside Ubuntu (not in the Android host).
log "Instalando Claude Code pelo pacote oficial da Anthropic..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
npm install -g @anthropic-ai/claude-code
command -v claude
claude --version
'

log "Instalando Codex CLI pelo pacote oficial da OpenAI..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
npm install -g @openai/codex
command -v codex
codex --version
'

# Optional developer tools and browsers. These are best-effort because
# GUI/GPU support inside Android PRoot varies by device.
log "Instalando Antigravity CLI oficial..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
if curl -fsSL https://antigravity.google/cli/install.sh | bash; then
  command -v agy || true
else
  echo "AVISO: Antigravity CLI não pôde ser instalado neste aparelho."
fi
' || warn "Antigravity CLI não foi instalado; o restante da instalação continuará."

log "Instalando ZCode oficial da Z.ai para Linux ARM64..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
ZCODE_VERSION="3.17.2"
ZCODE_DEB="/tmp/ZCode-${ZCODE_VERSION}-linux-arm64.deb"
ZCODE_URL="https://cdn-zcode.z.ai/zcode/electron/releases/${ZCODE_VERSION}/linux-arm64/ZCode-${ZCODE_VERSION}-linux-arm64.deb"
if curl -fL --retry 3 "$ZCODE_URL" -o "$ZCODE_DEB"; then
  if dpkg -i "$ZCODE_DEB"; then
    rm -f "$ZCODE_DEB"
  else
    apt-get update
    apt-get install -f -y
    dpkg -i "$ZCODE_DEB"
    rm -f "$ZCODE_DEB"
  fi
  if ! command -v zcode >/dev/null 2>&1 && ! command -v ZCode >/dev/null 2>&1; then
    echo "AVISO: pacote ZCode instalado, mas o comando executável não foi localizado."
  fi
else
  echo "AVISO: download oficial do ZCode ARM64 falhou; os demais componentes continuarão."
fi
' || warn "ZCode não pôde ser instalado; o restante da instalação continuará."

log "Instalando Brave para ARM64 pelo repositório oficial..."
proot-distro login "$CONTAINER" -- bash -lc '
set -u
export DEBIAN_FRONTEND=noninteractive
if curl -fsS https://dl.brave.com/install.sh | sh; then
  command -v brave-browser || true
else
  echo "AVISO: Brave não pôde ser instalado."
fi
' || warn "Brave não foi instalado; o restante da instalação continuará."

log "Tentando instalar Google Chrome ARM64 pelo repositório oficial..."
proot-distro login "$CONTAINER" -- bash -lc '
set -u
export DEBIAN_FRONTEND=noninteractive
install -d -m 0755 /etc/apt/keyrings
if curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg; then
  echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
  apt-get update
  apt-get install -y google-chrome-stable
else
  echo "AVISO: não foi possível obter a chave oficial do Chrome."
fi
' || warn "Google Chrome não foi instalado. O repositório oficial pode não oferecer pacote para esta arquitetura."

# ---------- XFCE menu shortcut ----------
log "Criando o atalho do Claude Code no menu do XFCE..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
mkdir -p /usr/local/bin /usr/share/applications
cat > /usr/local/bin/claude-code-terminal <<'"'"'EOF'"'"'
#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"
exec xfce4-terminal --title="Claude Code" --hold --command="claude"
EOF
chmod 755 /usr/local/bin/claude-code-terminal
cat > /usr/share/applications/claude-code.desktop <<'"'"'EOF'"'"'
[Desktop Entry]
Version=1.0
Type=Application
Name=Claude Code
Comment=Open Claude Code in a terminal
Exec=/usr/local/bin/claude-code-terminal
Icon=utilities-terminal
Terminal=false
Categories=Development;
EOF
cat > /usr/local/bin/codex-terminal <<'"'"'EOF'"'"'
#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"
exec xfce4-terminal --title="OpenAI Codex" --hold --command="codex"
EOF
chmod 755 /usr/local/bin/codex-terminal
cat > /usr/share/applications/codex.desktop <<'"'"'EOF'"'"'
[Desktop Entry]
Version=1.0
Type=Application
Name=OpenAI Codex
Comment=Open Codex CLI in a terminal
Exec=/usr/local/bin/codex-terminal
Icon=utilities-terminal
Terminal=false
Categories=Development;
EOF

# Antigravity CLI terminal launcher.
cat > /usr/local/bin/antigravity-terminal <<'"'"'EOF'"'"'
#!/bin/bash
exec xfce4-terminal --title="Google Antigravity" --hold --command="agy"
EOF
chmod 755 /usr/local/bin/antigravity-terminal
cat > /usr/share/applications/antigravity-cli.desktop <<'"'"'EOF'"'"'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Antigravity CLI
Comment=Open Antigravity CLI
Exec=/usr/local/bin/antigravity-terminal
Icon=utilities-terminal
Terminal=false
Categories=Development;
EOF

# ZCode desktop launcher. The package may expose either command spelling.
if command -v zcode >/dev/null 2>&1 || command -v ZCode >/dev/null 2>&1 || [ -x /opt/ZCode/zcode ]; then
  cat > /usr/local/bin/zcode-desktop <<'EOF'
#!/bin/bash
if command -v zcode >/dev/null 2>&1; then
  exec zcode --no-sandbox --disable-gpu "$@"
elif command -v ZCode >/dev/null 2>&1; then
  exec ZCode --no-sandbox --disable-gpu "$@"
elif [ -x /opt/ZCode/zcode ]; then
  exec /opt/ZCode/zcode --no-sandbox --disable-gpu "$@"
fi
echo "ZCode não encontrado. Verifique a instalação do pacote oficial." >&2
exit 127
EOF
  chmod 755 /usr/local/bin/zcode-desktop
  cat > /usr/share/applications/zcode.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=ZCode (Z.ai)
Comment=AI coding workspace by Z.ai
Exec=/usr/local/bin/zcode-desktop %U
Icon=utilities-terminal
Terminal=false
Categories=Development;IDE;
EOF
fi

# Graphical editor and browser launchers. Chromium browsers need no-sandbox
# in many PRoot setups; this is a compatibility trade-off, not full isolation.
for app in brave-browser google-chrome-stable; do
  case "$app" in
    zed) label="Zed"; exec_cmd="zed" ;;
    brave-browser) label="Brave"; exec_cmd="brave-browser --no-sandbox --disable-dev-shm-usage" ;;
    google-chrome-stable) label="Google Chrome"; exec_cmd="google-chrome-stable --no-sandbox --disable-dev-shm-usage" ;;
  esac
  if command -v "$app" >/dev/null 2>&1; then
    cat > "/usr/share/applications/${app}.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${label}
Comment=Launch ${label}
Exec=${exec_cmd} %U
Icon=${app}
Terminal=false
Categories=Network;WebBrowser;
EOF
  fi
done

# Copy application shortcuts to the XFCE desktop as visible one-click icons.
mkdir -p /root/Desktop
for desktop_file in claude-code.desktop codex.desktop antigravity-cli.desktop zcode.desktop brave-browser.desktop google-chrome-stable.desktop; do
  if [ -f "/usr/share/applications/$desktop_file" ]; then
    cp "/usr/share/applications/$desktop_file" "/root/Desktop/$desktop_file"
    chmod +x "/root/Desktop/$desktop_file"
  fi
done

# Add installed applications to a single XFCE panel launcher (dock-style).
mkdir -p /root/.config/autostart /root/.local/bin
cat > /root/.local/bin/setup-termux-desktop-panel <<'"'"'EOF'"'"'
#!/bin/bash
set -u
sleep 4
command -v xfconf-query >/dev/null 2>&1 || exit 0
command -v xfce4-panel >/dev/null 2>&1 || exit 0
apps=(claude-code.desktop codex.desktop antigravity-cli.desktop zcode.desktop brave-browser.desktop google-chrome-stable.desktop)
items=()
for f in "${apps[@]}"; do
  [ -f "/usr/share/applications/$f" ] && items+=("$f")
done
[ "${#items[@]}" -gt 0 ] || exit 0
# Use a dedicated high plugin ID; avoid overwriting an existing user's plugin.
plugin=98
while xfconf-query -c xfce4-panel -p "/plugins/plugin-$plugin" >/dev/null 2>&1; do
  plugin=$((plugin + 1))
  [ "$plugin" -lt 200 ] || exit 0
done
mkdir -p "$HOME/.config/xfce4/panel/launcher-$plugin"
for f in "${items[@]}"; do
  cp "/usr/share/applications/$f" "$HOME/.config/xfce4/panel/launcher-$plugin/$f"
done
panel_ids=$(xfconf-query -c xfce4-panel -p /panels 2>/dev/null | awk '/^[[:space:]]*[0-9]+[[:space:]]*$/ {gsub(/[[:space:]]/,""); print; exit}')
[ -n "$panel_ids" ] || exit 0
panel_path="/panels/panel-$panel_ids/plugin-ids"
existing=()
while IFS= read -r id; do
  [[ "$id" =~ ^[0-9]+$ ]] && existing+=("$id")
done < <(xfconf-query -c xfce4-panel -p "$panel_path" 2>/dev/null | awk '/^[[:space:]]*[0-9]+[[:space:]]*$/ {gsub(/[[:space:]]/,""); print}')
xfconf-query -c xfce4-panel -p "/plugins/plugin-$plugin" -t string -s launcher --create || exit 0
item_args=()
for f in "${items[@]}"; do item_args+=(-t string -s "$f"); done
xfconf-query -c xfce4-panel -p "/plugins/plugin-$plugin/items" "${item_args[@]}" --create || exit 0
xfconf-query -c xfce4-panel -p "$panel_path" -rR >/dev/null 2>&1 || true
panel_args=()
for id in "${existing[@]}"; do panel_args+=(-t int -s "$id"); done
panel_args+=(-t int -s "$plugin" --create)
xfconf-query -c xfce4-panel -p "$panel_path" "${panel_args[@]}" || exit 0
xfce4-panel -r >/dev/null 2>&1 || true
EOF
chmod 755 /root/.local/bin/setup-termux-desktop-panel
cat > /root/.config/autostart/termux-desktop-panel.desktop <<'"'"'EOF'"'"'
[Desktop Entry]
Type=Application
Name=Configure application shortcuts
Exec=/root/.local/bin/setup-termux-desktop-panel
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
EOF
'

# ---------- Android launcher ----------
log "Configurando o comando claude-code-desktop..."
mkdir -p "$BIN_DIR"
cat > "$LAUNCHER" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

CONTAINER="claude-code"
DISPLAY_NUMBER=":1"

command -v termux-x11 >/dev/null 2>&1 || {
  echo "ERRO: instale o pacote termux-x11-nightly no Termux."
  exit 1
}
command -v proot-distro >/dev/null 2>&1 || {
  echo "ERRO: proot-distro não encontrado. Execute novamente o instalador."
  exit 1
}
# Do not use pm path as a hard gate: Android package-manager queries can
# fail on some devices even when the Termux:X11 APK is installed.
# Validate the app by attempting to launch its activity below.

termux-wake-lock >/dev/null 2>&1 || true
termux-x11 "$DISPLAY_NUMBER" >/dev/null 2>&1 &
sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || {
  echo "ERRO: não foi possível abrir Termux:X11. Confira se o APK está instalado."
  exit 1
}
sleep 2
exec proot-distro login "$CONTAINER" --shared-tmp -- bash -lc '
export DISPLAY=:1
export PATH="$HOME/.local/bin:$PATH"
exec dbus-launch --exit-with-session xfce4-session
'
EOF
chmod 755 "$LAUNCHER"

# ---------- Final verification ----------
log "Executando verificações finais..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
node -e "const v=process.versions.node.split(\".\").map(Number); if(v[0] < 18) process.exit(1)"
npm --version >/dev/null
claude --version
codex --version
command -v xfce4-session >/dev/null
command -v xfce4-terminal >/dev/null
command -v thunar >/dev/null
test -x /usr/local/bin/claude-code-terminal
test -f /usr/share/applications/claude-code.desktop
test -x /usr/local/bin/codex-terminal
test -f /usr/share/applications/codex.desktop
test -f /usr/share/applications/antigravity-cli.desktop
'
test -x "$LAUNCHER" || die "O comando de inicialização não foi criado."

printf '\n============================================================\n'
printf ' INSTALAÇÃO E VERIFICAÇÕES CONCLUÍDAS\n'
printf '============================================================\n'
printf 'Abra a área de trabalho gráfica com:\n\n  claude-code-desktop\n\n'
printf 'No XFCE, abra o menu e selecione Claude Code.\n'
printf 'Na primeira execução, autentique-se com sua própria conta Anthropic.\n'
printf '============================================================\n'
