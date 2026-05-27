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
    echo -e " Instalador Automático - Ice Robot Bhar v1.4.20"
    echo -e "================================================================="
    echo ""
}

# --- Verificações do Sistema ---
check_system() {
    log_info "Verificando o sistema para ver se tudo esta pronto pro ROBERTINHO"

    # Verifica se é root
    if [ "$EUID" -ne 0 ]; then
        log_error "Por favor, execute este instalador como root (use sudo bash <(curl...))"
    fi

    # Verifica a arquitetura
    ARCH=$(uname -m)
    log_info "Arquitetura do ROBERTINHO detectada: $ARCH"
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" && "$ARCH" != "armv7l" ]]; then
        log_warn "Arquitetura $ARCH pode não ser totalmente suportada. Tentando prosseguir..."
    fi

    # Verifica conexão com a internet
    if ! curl -s --connect-timeout 5 https://www.google.com >/dev/null; then
        log_error "Sem conexão com a internet. Verifique sua rede e tente novamente."
    fi
}

# --- Instalação de Dependências Base ---
install_dependencies() {
    log_info "Atualizando a lista de pacotes apt do ROBERTINHO..."
    apt-get update -y > /dev/null

    log_info "Instalando dependências base (curl, git, wget, build-essential)..."
    apt-get install -y curl git wget build-essential jq > /dev/null

    # Instalação do Node.js via NodeSource (se necessário)
    if ! command -v node >/dev/null 2>&1; then
        log_info "Node.js não encontrado. Instalando Node.js v${NODE_VERSION}..."
        apt-get install -y ca-certificates gnupg > /dev/null
        mkdir -p /etc/apt/keyrings
        # Remove a chave antiga se existir para evitar erro de gravação do gpg
        rm -f /etc/apt/keyrings/nodesource.gpg
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list > /dev/null
        apt-get update -y > /dev/null
        apt-get install -y nodejs > /dev/null
    else
        log_success "Node.js já instalado ($(node -v))."
    fi

    # Instalação do PM2 (Gerenciador de Processos)
    if ! command -v pm2 >/dev/null 2>&1; then
        log_info "Instalando PM2 globalmente..."
        npm install -g pm2 > /dev/null
    fi
    
    # Instalação do Java/Maven
    if ! command -v mvn >/dev/null 2>&1; then
        log_info "Instalando Maven..."
        apt-get install -y maven > /dev/null
    fi

    # Garante que temos o Java 17+ instalado
    if ! command -v java >/dev/null 2>&1 || ! java -version 2>&1 | grep -q "17"; then
        log_info "Instalando OpenJDK 17..."
        if ! apt-get install -y openjdk-17-jdk > /dev/null 2>&1; then
            log_warn "openjdk-17-jdk não disponível via apt. Baixando JDK 17 diretamente da Adoptium..."
            
            # Detecta arquitetura do processador
            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
                JDK_ARCH="x64"
            elif [ "$ARCH" = "aarch64" ]; then
                JDK_ARCH="aarch64"
            elif [[ "$ARCH" == armv* ]]; then
                JDK_ARCH="arm"
            else
                JDK_ARCH="x64"
            fi
            
            JDK_URL="https://api.adoptium.net/v3/binary/latest/17/ga/linux/${JDK_ARCH}/jdk/hotspot/normal/eclipse?project=jdk"
            if curl -L -s -o /tmp/jdk17.tar.gz "$JDK_URL"; then
                mkdir -p /opt/jdk-17
                tar -xzf /tmp/jdk17.tar.gz -C /opt/jdk-17 --strip-components=1
                
                # Configura alternativas do sistema para apontar para o JDK 17 baixado
                update-alternatives --install /usr/bin/java java /opt/jdk-17/bin/java 1000 || true
                update-alternatives --install /usr/bin/javac javac /opt/jdk-17/bin/javac 1000 || true
                
                # Garante que eles estão ativos como prioridade
                update-alternatives --set java /opt/jdk-17/bin/java || true
                update-alternatives --set javac /opt/jdk-17/bin/javac || true
                
                rm -f /tmp/jdk17.tar.gz
                log_success "JDK 17 instalado com sucesso via Adoptium!"
            else
                log_error "Falha ao baixar o JDK 17 da Adoptium. Instale o Java 17 manualmente."
            fi
        else
            log_success "OpenJDK 17 instalado com sucesso via apt!"
        fi
    fi

    log_success "ROBERTINHO ESTÁ PRONTO PARA DESPERTAR"
}

# --- Autenticação Segura ---
get_github_token() {
    echo ""
    log_info "Este projeto está em um repositório privado."
    log_info "PARA LIBERAR TODOS OS PODERES DO ROBERTINHO"
    log_info "Você precisará de um GitHub Personal Access Token (PAT) com acesso de leitura (repo)."
    echo ""
    
    while true; do
        # read -s oculta a digitação no terminal
        read -s -p "Cole seu GitHub Token (PAT): " GITHUB_TOKEN </dev/tty
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
        read -p "Deseja apagá-lo e reinstalar do zero? (s/N): " choice </dev/tty
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

    # Inicializa submodules
    log_info "Inicializando submódulos do Git..."
    if ! git submodule update --init --recursive; then
        log_warn "Falha ao inicializar submódulos via Git. O projeto pode apresentar falhas de build."
    fi

    # Remove o remetente origin com o token para que o PAT não fique salvo na pasta .git/config
    git remote remove origin
    # Adiciona novamente o origin genérico via SSH ou HTTPS limpo
    git remote add origin "https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

    log_success "Código fonte clonado com sucesso e limpo de credenciais!"
}

# --- Setup do Kiosk Mode ---
setup_kiosk_mode() {
    log_info "Configurando o modo Kiosk do Chromium..."
    
    # Identifica o usuário não-root (geralmente 'pi' ou o usuário que rodou o sudo)
    REAL_USER=${SUDO_USER:-$USER}
    USER_HOME=$(eval echo ~$REAL_USER)

    # Cria a pasta de instalação caso não exista
    mkdir -p "$INSTALL_DIR"

    # Cria o script de inicialização do Kiosk com delay para evitar race conditions
    KIOSK_SCRIPT="$INSTALL_DIR/kiosk.sh"
    cat > "$KIOSK_SCRIPT" << EOL
#!/bin/bash
# Aguarda o ambiente gráfico e rede estarem totalmente prontos
sleep 7
export DISPLAY=:0
chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run http://localhost:8080 &
EOL
    chmod +x "$KIOSK_SCRIPT"
    chown $REAL_USER:$REAL_USER "$KIOSK_SCRIPT"
    log_info "Script de Kiosk (/opt/icerobot/kiosk.sh) criado com sucesso."
    
    # 1. Caso seja Wayland/Wayfire (Debian Bookworm padrão no RPi 4/5)
    WAYFIRE_FILE="$USER_HOME/.config/wayfire.ini"
    if [ -f "$WAYFIRE_FILE" ]; then
        if ! grep -q "icerobot_kiosk" "$WAYFIRE_FILE" 2>/dev/null; then
            if grep -q "\[autostart\]" "$WAYFIRE_FILE" 2>/dev/null; then
                sed -i '/\[autostart\]/a icerobot_kiosk = /opt/icerobot/kiosk.sh' "$WAYFIRE_FILE"
            else
                echo -e "\n[autostart]\nicerobot_kiosk = /opt/icerobot/kiosk.sh" >> "$WAYFIRE_FILE"
            fi
            log_success "Autostart do Kiosk configurado para Wayland (Wayfire)."
        fi
    fi

    # 2. Caso seja Wayland/Labwc (Debian Bookworm alternativo)
    LABWC_DIR="$USER_HOME/.config/labwc"
    if [ -d "$USER_HOME/.config" ]; then
        mkdir -p "$LABWC_DIR"
        AUTOSTART_FILE="$LABWC_DIR/autostart"
        if ! grep -q "kiosk.sh" "$AUTOSTART_FILE" 2>/dev/null; then
            echo "/opt/icerobot/kiosk.sh &" >> "$AUTOSTART_FILE"
            chown -R $REAL_USER:$REAL_USER "$LABWC_DIR"
            log_success "Autostart do Kiosk configurado para Wayland (Labwc)."
        fi
    fi

    # 3. Caso seja X11/LXDE (Debian Bullseye/Buster no RPi 3B+ ou x86_64)
    for dir in "LXDE-pi" "LXDE"; do
        LXDE_DIR="$USER_HOME/.config/lxsession/$dir"
        if [ -d "$USER_HOME/.config" ]; then
            mkdir -p "$LXDE_DIR"
            AUTOSTART_LXDE="$LXDE_DIR/autostart"
            if ! grep -q "kiosk.sh" "$AUTOSTART_LXDE" 2>/dev/null; then
                echo "@/opt/icerobot/kiosk.sh" >> "$AUTOSTART_LXDE"
                chown -R $REAL_USER:$REAL_USER "$LXDE_DIR"
                log_success "Autostart do Kiosk configurado para X11 ($dir)."
            fi
        fi
    done

    # 4. Método Universal XDG Autostart (.desktop)
    XDG_AUTOSTART_DIR="$USER_HOME/.config/autostart"
    if [ -d "$USER_HOME/.config" ]; then
        mkdir -p "$XDG_AUTOSTART_DIR"
        cat > "$XDG_AUTOSTART_DIR/kiosk.desktop" << EOL
[Desktop Entry]
Type=Application
Name=Ice Robot Kiosk
Exec=/opt/icerobot/kiosk.sh
Terminal=false
X-GNOME-Autostart-enabled=true
EOL
        chmod +x "$XDG_AUTOSTART_DIR/kiosk.desktop"
        chown -R $REAL_USER:$REAL_USER "$XDG_AUTOSTART_DIR"
        log_success "Autostart do Kiosk configurado via XDG Desktop Entry."
    fi
}

# --- Setup do Ambiente ---
build_and_start_project() {
    log_info "Configurando e compilando o projeto..."

    # Garante que o arquivo de swap local criado esteja ativo (pode ter desativado ao reiniciar)
    if [ -f "/swapfile" ] && ! swapon --show | grep -q "/swapfile"; then
        log_info "Reativando arquivo de swap /swapfile para compilação..."
        swapon /swapfile || true
    fi

    # 1. Configurar Frontend
    log_info "Instalando dependências do Frontend (Vue/Quasar)..."
    cd "$INSTALL_DIR/frontend" || true
    if ! npm install > /tmp/frontend_install.log 2>&1; then
        echo -e "${RED}[ERROR] Falha ao instalar dependências do Frontend. Últimas linhas do log:${NC}"
        tail -n 30 /tmp/frontend_install.log
        exit 1
    fi
    
    log_info "Gerando build de produção do Frontend..."
    if ! NODE_OPTIONS="--max-old-space-size=1024" npm run build > /tmp/frontend_build.log 2>&1; then
        echo -e "${RED}[ERROR] Falha na compilação do Frontend. Últimas linhas do log:${NC}"
        tail -n 30 /tmp/frontend_build.log
        exit 1
    fi

    # 2. Configurar Backend (Maven)
    log_info "Compilando backend Java com Maven (gerando JAR)..."
    cd "$INSTALL_DIR"
    if ! mvn clean install -DskipTests > /tmp/backend_build.log 2>&1; then
        echo -e "${RED}[ERROR] Falha na compilação do Backend. Últimas linhas do log:${NC}"
        tail -n 30 /tmp/backend_build.log
        exit 1
    fi

    # 3. Inicializando com PM2
    log_info "Configurando PM2 Start Script..."
    cd "$INSTALL_DIR"
    
    # Cria o ecossistema do PM2 rodando o jar compilado
    cat > ecosystem.config.js << EOL
module.exports = {
  apps : [{
    name: "icerobot-app",
    script: "java",
    args: "-jar backend/target/server.jar",
    cwd: "$INSTALL_DIR",
    watch: false,
    env: {
      NODE_ENV: "production",
    }
  }]
}
EOL

    # Inicia e salva o PM2 para ligar junto com o Raspberry Pi (Linux boot)
    pm2 start ecosystem.config.js
    pm2 save
    
    # Executa a configuração de startup do PM2 de forma automática para o root
    pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || true

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
    setup_kiosk_mode

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
