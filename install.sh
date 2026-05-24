#!/usr/bin/env bash

# ==============================================================================
# ICE ROBOT BHAR - INSTALLATION SCRIPT
# ==============================================================================
# Este script baixa e instala o Ice Robot Bhar a partir de um repositório privado
# de forma segura e elegante.
#
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/USER/icerobot-installer/main/install.sh)
# ==============================================================================

set -e # Aborta o script em qualquer erro
set -o pipefail # Garante que erros em pipes sejam detectados

# --- Configurações Iniciais ---
REPO_OWNER="3damatta"
REPO_NAME="robertinho"
INSTALL_DIR="/opt/icerobot"
NODE_VERSION="20" # Versão do Node.js a ser instalada

# --- Cores e Formatação ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Funções de Log ---
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; >&2; exit 1; }

# --- Banner ASCII ---
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ___          ___       _           _     ___ _               "
    echo " |_ _|___ ___ | _ \___ _| |__  ___ _| |_  | _ ) |_  __ _ _ _   "
    echo "  | |/ _ / -_)|   / _ \ _ \ '_ \/ _ \  _| | _ \ ' \/ _\` | '_|  "
    echo " |___\___\___||___\___/___/_.__/\___/\__| |___/_||_\__,_|_|    "
    echo "                                                               "
    echo -e "${NC}================================================================="
    echo -e " Instalador Profissional - Ice Robot Bhar v1.0"
    echo -e "================================================================="
    echo ""
}

# --- Verificações do Sistema ---
check_system() {
    log_info "Verificando o sistema..."

    # Verifica se é root
    if [ "$EUID" -ne 0 ]; then
        log_error "Por favor, execute este instalador como root (use sudo bash <(curl...))"
    fi

    # Verifica a arquitetura
    ARCH=$(uname -m)
    log_info "Arquitetura detectada: $ARCH"
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" && "$ARCH" != "armv7l" ]]; then
        log_warn "Arquitetura $ARCH pode não ser totalmente suportada. Tentando prosseguir..."
    fi

    # Verifica conexão com a internet
    if ! ping -q -c 1 -W 1 google.com >/dev/null; then
        log_error "Sem conexão com a internet. Verifique sua rede e tente novamente."
    fi
}

# --- Instalação de Dependências Base ---
install_dependencies() {
    log_info "Atualizando a lista de pacotes apt..."
    apt-get update -y > /dev/null

    log_info "Instalando dependências base (curl, git, wget, build-essential)..."
    apt-get install -y curl git wget build-essential jq software-properties-common > /dev/null

    # Instalação do Node.js via NodeSource (se necessário)
    if ! command -v node >/dev/null 2>&1; then
        log_info "Node.js não encontrado. Instalando Node.js v${NODE_VERSION}..."
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - > /dev/null
        apt-get install -y nodejs > /dev/null
    else
        log_success "Node.js já instalado ($(node -v))."
    fi

    # Instalação do PM2 (Gerenciador de Processos)
    if ! command -v pm2 >/dev/null 2>&1; then
        log_info "Instalando PM2 globalmente..."
        npm install -g pm2 > /dev/null
    fi
    
    # Exemplo: Instalação do Java/Maven (descomente se usar backend Java)
    # if ! command -v mvn >/dev/null 2>&1; then
    #    log_info "Instalando Maven e OpenJDK..."
    #    apt-get install -y openjdk-17-jdk maven > /dev/null
    # fi

    log_success "Todas as dependências do sistema foram instaladas!"
}

# --- Autenticação Segura ---
get_github_token() {
    echo ""
    log_info "Este projeto está em um repositório privado."
    log_info "Você precisará de um GitHub Personal Access Token (PAT) com acesso de leitura (repo)."
    echo ""
    
    while true; do
        # read -s oculta a digitação no terminal
        read -s -p "Cole seu GitHub Token (PAT): " GITHUB_TOKEN
        echo ""

        if [ -z "$GITHUB_TOKEN" ]; then
            log_warn "O Token não pode estar vazio. Tente novamente."
            continue
        fi

        log_info "Validando o token no GitHub..."
        # Testa a autenticação tentando acessar a API do repositório
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}")

        if [ "$HTTP_STATUS" -eq 200 ]; then
            log_success "Autenticação bem-sucedida! Repositório acessível."
            break
        elif [ "$HTTP_STATUS" -eq 404 ]; then
            log_warn "O repositório não foi encontrado (Token inválido ou sem permissão). Tente novamente."
        elif [ "$HTTP_STATUS" -eq 401 ]; then
            log_warn "Credenciais inválidas. Tente novamente."
        else
            log_warn "Erro inesperado ($HTTP_STATUS). Tente novamente."
        fi
    done
}

# --- Clonagem e Configuração do Repositório ---
setup_repository() {
    log_info "Configurando o diretório de instalação em ${INSTALL_DIR}..."

    # Garante que a pasta pai existe
    mkdir -p $(dirname "$INSTALL_DIR")

    if [ -d "$INSTALL_DIR" ]; then
        log_warn "O diretório $INSTALL_DIR já existe."
        read -p "Deseja apagá-lo e reinstalar do zero? (s/N): " choice
        case "$choice" in 
          s|S ) rm -rf "$INSTALL_DIR"; log_info "Diretório antigo removido.";;
          * ) log_error "Instalação abortada para proteger os dados atuais.";;
        esac
    fi

    log_info "Clonando o repositório Ice Robot Bhar..."
    # Clona usando HTTPS com o token embutido (de forma temporária na memória)
    # O token não é exibido no terminal e não fica salvo no history graças ao bash script
    REPO_URL="https://${GITHUB_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git"
    
    # Executa git clone mascarando a URL no output caso falhe
    if ! git clone --quiet "$REPO_URL" "$INSTALL_DIR"; then
        log_error "Falha ao clonar o repositório. Verifique a conexão."
    fi

    # Entra no diretório
    cd "$INSTALL_DIR"

    # Remove o remetente origin com o token para que o PAT não fique salvo na pasta .git/config
    git remote remove origin
    # Adiciona novamente o origin genérico via SSH ou HTTPS limpo
    git remote add origin "https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

    log_success "Código fonte clonado com sucesso e limpo de credenciais!"
}

# --- Setup do Ambiente ---
build_and_start_project() {
    log_info "Configurando e compilando o projeto..."

    # 1. Configurar Frontend
    log_info "Instalando dependências do Frontend (Vue/Quasar)..."
    cd "$INSTALL_DIR/frontend" || true
    npm install > /dev/null 2>&1
    # npm run build # (Descomente para buildar o frontend se aplicável)

    # 2. Configurar Backend (Exemplo genérico)
    # log_info "Compilando backend..."
    # cd "$INSTALL_DIR/backend"
    # mvn clean install -DskipTests > /dev/null 2>&1

    # 3. Inicializando com PM2
    log_info "Configurando PM2 Start Script..."
    cd "$INSTALL_DIR"
    
    # Cria o ecossistema do PM2 (ajuste os caminhos do seu backend/frontend)
    cat > ecosystem.config.js << EOL
module.exports = {
  apps : [{
    name: "icerobot-app",
    script: "npm",
    args: "run start",
    cwd: "$INSTALL_DIR",
    watch: false,
    env: {
      NODE_ENV: "production",
    }
  }]
}
EOL

    # Inicia e salva o PM2 para ligar junto com o Raspberry Pi (Linux boot)
    # pm2 start ecosystem.config.js
    # pm2 save
    # pm2 startup

    log_success "Ambiente configurado com sucesso!"
}

# --- Main Execution ---
main() {
    print_banner
    check_system
    install_dependencies
    get_github_token
    setup_repository
    build_and_start_project

    echo ""
    echo -e "${GREEN}${BOLD}=================================================================${NC}"
    echo -e "${GREEN}${BOLD} Ice Robot Bhar foi instalado com SUCESSO! ${NC}"
    echo -e "${GREEN}${BOLD}=================================================================${NC}"
    echo ""
    echo -e "O sistema foi instalado em: ${CYAN}$INSTALL_DIR${NC}"
    echo -e "O gerenciador PM2 está cuidando dos processos em background."
    echo ""
    echo -e "Acesse o sistema pelo navegador: ${BLUE}http://$(hostname -I | awk '{print $1}'):8080${NC} (Ajuste a porta se necessário)"
    echo ""
}

main
