#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

CONTAINER="claude-code"
DISPLAY_NUM=":1"
PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
BIN_DIR="$PREFIX_DIR/bin"
LAUNCHER="$BIN_DIR/claude-code-desktop"

log() { printf '\n[SETUP] %s\n' "$*"; }
die() { printf '\n[ERRO] %s\n' "$*" >&2; exit 1; }
trap 'die "A instalação foi interrompida na linha $LINENO. Corrija a conexão/armazenamento e execute novamente este instalador."' ERR

[ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux ] || die "Este instalador deve ser executado dentro do Termux."
[ "$(uname -m)" = "aarch64" ] || die "Este instalador foi preparado para Android ARM64 (aarch64)."

if ! command -v pkg >/dev/null 2>&1; then
  die "Gerenciador pkg do Termux não encontrado."
fi

log "Atualizando o Termux e instalando Node.js, proot-distro e suporte gráfico..."
pkg update -y
pkg install -y x11-repo
pkg update -y
pkg install -y proot-distro termux-x11-nightly nodejs-lts git curl wget ca-certificates termux-tools

command -v termux-x11 >/dev/null 2>&1 || die "termux-x11 não foi instalado. Confira se o APK Termux:X11 também está instalado."
command -v proot-distro >/dev/null 2>&1 || die "proot-distro não foi instalado."

if proot-distro list 2>/dev/null | grep -Eq "^[[:space:]]*${CONTAINER}([[:space:]]|$)"; then
  die "Já existe um ambiente chamado '${CONTAINER}'. Nada foi apagado ou sobrescrito. Remova-o manualmente se quiser reinstalar."
fi

log "Baixando Ubuntu 24.04 ARM64 em um ambiente novo..."
proot-distro install --name "$CONTAINER" ubuntu:24.04

log "Instalando XFCE, terminal, gerenciador de arquivos, Node.js e dependências no Ubuntu..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  xfce4 xfce4-terminal thunar dbus-x11 dbus-user-session \
  xterm fonts-dejavu-core nodejs npm git curl wget ca-certificates \
  file procps psmisc sudo xdg-utils
'

log "Instalando Claude Code pelo instalador oficial da Anthropic..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
export PATH="$HOME/.local/bin:$PATH"
curl -fsSL https://claude.ai/install.sh | bash
command -v claude >/dev/null 2>&1 || test -x "$HOME/.local/bin/claude"
'

log "Configurando o atalho Claude Code no menu do XFCE..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
mkdir -p /usr/share/applications
cat > /usr/local/bin/claude-code-terminal <<'"'"'EOF'"'"'
#!/bin/bash
exec xfce4-terminal --title="Claude Code" --command="bash -lc \"export PATH=\$HOME/.local/bin:\$PATH; claude; exec bash\""
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
'

log "Criando o comando de inicialização da área de trabalho..."
cat > "$LAUNCHER" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
command -v termux-x11 >/dev/null 2>&1 || { echo "Instale o APK Termux:X11 e o pacote termux-x11-nightly."; exit 1; }
command -v proot-distro >/dev/null 2>&1 || { echo "proot-distro não encontrado."; exit 1; }
termux-wake-lock >/dev/null 2>&1 || true
if ! pgrep -f 'termux-x11 :1' >/dev/null 2>&1; then
  termux-x11 :1 -ac >/dev/null 2>&1 &
  sleep 2
fi
am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
sleep 2
exec proot-distro login claude-code --shared-tmp -- bash -lc 'export DISPLAY=:1; export PATH="$HOME/.local/bin:$PATH"; dbus-launch --exit-with-session startxfce4'
EOF
chmod 755 "$LAUNCHER"

log "Verificando instalação..."
proot-distro login "$CONTAINER" -- bash -lc '
set -e
node --version
npm --version
claude --version
test -x /usr/local/bin/claude-code-terminal
'

printf '\n==================================================\n'
printf ' INSTALAÇÃO CONCLUÍDA\n'
printf '==================================================\n'
printf 'Para abrir a área de trabalho gráfica, execute:\n\n'
printf '  claude-code-desktop\n\n'
printf 'No XFCE, abra o ícone/menu "Claude Code" e entre na sua própria conta.\n'
printf 'O APK Termux:X11 precisa estar instalado no Android.\n'
printf '==================================================\n'
