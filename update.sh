#!/usr/bin/env bash

# ==============================================================================
# ICE ROBOT BHAR - UPDATE SCRIPT
# ==============================================================================
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/USER/icerobot-installer/main/update.sh)
# ==============================================================================

set -e

# --- Configurações Iniciais ---
REPO_OWNER="3damatta"
REPO_NAME="robertinho"
INSTALL_DIR="/opt/icerobot"
BACKUP_DIR="/opt/icerobot_backup_$(date +%Y%m%d_%H%M%S)"

# --- Cores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; >&2; exit 1; }

# --- Pré-cheques ---
if [ "$EUID" -ne 0 ]; then
    log_error "Por favor, execute como root (sudo)."
fi

if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Instalação não encontrada em $INSTALL_DIR. Use o install.sh primeiro."
fi

# --- Autenticação Segura ---
get_github_token() {
    if [ -n "$GITHUB_TOKEN" ]; then
        log_info "Token do GitHub fornecido via ambiente."
        return
    fi
    echo ""
    log_info "Para atualizar, precisamos do GitHub Personal Access Token."
    read -s -p "Cole seu GitHub Token (PAT): " GITHUB_TOKEN </dev/tty
    echo ""

    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "O Token não pode estar vazio."
    fi
}

# --- Backup de Segurança ---
create_backup() {
    log_info "Criando backup de segurança atual em ${BACKUP_DIR}..."
    cp -r "$INSTALL_DIR" "$BACKUP_DIR"
    log_success "Backup criado."
}

# --- Restaurar Backup (Rollback) ---
restore_backup() {
    log_error "Atualização falhou! Iniciando Rollback automático..."
    rm -rf "$INSTALL_DIR"
    mv "$BACKUP_DIR" "$INSTALL_DIR"
    log_info "Backup restaurado com sucesso. O sistema está como antes."
    
    # Reinicia o serviço caso tenha sido parado
    # pm2 restart icerobot-app || true
    exit 1
}

# Em caso de falha, aciona o restore_backup
trap 'restore_backup' ERR

# --- Atualização do Git ---
pull_updates() {
    cd "$INSTALL_DIR"
    
    log_info "Buscando atualizações no repositório..."
    REPO_URL="https://${GITHUB_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git"
    
    # Adiciona a origin temporária com autenticação
    git remote set-url origin "$REPO_URL"

    # Faz o pull
    if ! git pull origin main --quiet; then
        # Se falhar, limpa o origin e aciona erro
        git remote set-url origin "https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
        false
    fi

    # Remove o token imediatamente após o pull para manter a segurança
    git remote set-url origin "https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
    
    log_success "Código atualizado com sucesso!"
}

# --- Rebuild e Restart ---
rebuild_project() {
    log_info "Reconstruindo o Frontend..."
    cd "$INSTALL_DIR/frontend"
    npm install > /dev/null 2>&1
    npm run build > /dev/null 2>&1
    
    log_info "Reconstruindo o Backend..."
    cd "$INSTALL_DIR"
    mvn clean install -DskipTests > /dev/null 2>&1
    
    log_info "Reiniciando os serviços no PM2..."
    pm2 restart icerobot-app || pm2 start ecosystem.config.js
    pm2 save
}

# --- Main ---
main() {
    echo -e "${BLUE}${BOLD}=== Atualizador Ice Robot Bhar ===${NC}"
    get_github_token
    create_backup
    pull_updates
    rebuild_project
    
    # Remove a armadilha de erro já que tudo deu certo
    trap - ERR

    log_success "Ice Robot Bhar foi ATUALIZADO com sucesso!"
    log_info "O backup de segurança (${BACKUP_DIR}) será mantido por precaução."
    echo ""
}

main
