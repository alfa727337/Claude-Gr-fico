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

# Use the documented npm installation path rather than the native installer,
# which Anthropic currently labels as alpha.
log "Instalando Claude Code pelo pacote oficial da Anthropic..."
proot-distro login "$CONTAINER" -- bash -lc '
set -Eeuo pipefail
npm install -g @anthropic-ai/claude-code
command -v claude
claude --version
'

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
command -v xfce4-session >/dev/null
command -v xfce4-terminal >/dev/null
command -v thunar >/dev/null
test -x /usr/local/bin/claude-code-terminal
test -f /usr/share/applications/claude-code.desktop
'
test -x "$LAUNCHER" || die "O comando de inicialização não foi criado."

printf '\n============================================================\n'
printf ' INSTALAÇÃO E VERIFICAÇÕES CONCLUÍDAS\n'
printf '============================================================\n'
printf 'Abra a área de trabalho gráfica com:\n\n  claude-code-desktop\n\n'
printf 'No XFCE, abra o menu e selecione Claude Code.\n'
printf 'Na primeira execução, autentique-se com sua própria conta Anthropic.\n'
printf '============================================================\n'
