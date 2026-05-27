# Ice Robot Bhar - Installer 🍸🤖

Bem-vindo ao repositório público de instalação do **Ice Robot Bhar**. 
Este projeto utiliza uma arquitetura de segurança onde este repositório atua apenas como a **porta de entrada pública**, enquanto o código-fonte proprietário real reside em um repositório privado acessível apenas a operadores autorizados.

# 1. Cria o script do kiosk com delay seguro
sudo bash -c 'cat > /opt/icerobot/kiosk.sh << EOL
#!/bin/bash
sleep 7
export DISPLAY=:0
chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run http://localhost:8080 &
EOL'
sudo chmod +x /opt/icerobot/kiosk.sh

# 2. Configura no autostart do Wayfire (se seu RPi usar Bookworm/Wayland)
WAYFIRE_FILE=~/.config/wayfire.ini
if [ -f "$WAYFIRE_FILE" ]; then
    if ! grep -q "icerobot_kiosk" "$WAYFIRE_FILE"; then
        if grep -q "\[autostart\]" "$WAYFIRE_FILE"; then
            sed -i "/\[autostart\]/a icerobot_kiosk = /opt/icerobot/kiosk.sh" "$WAYFIRE_FILE"
        else
            echo -e "\n[autostart]\nicerobot_kiosk = /opt/icerobot/kiosk.sh" >> "$WAYFIRE_FILE"
        fi
    fi
fi

# 3. Configura no autostart do LXDE (se usar RPi 3B+ antigo)
for dir in "LXDE-pi" "LXDE"; do
    LXDE_DIR=~/.config/lxsession/$dir
    mkdir -p "$LXDE_DIR"
    if ! grep -q "kiosk.sh" "$LXDE_DIR/autostart" 2>/dev/null; then
        echo "@/opt/icerobot/kiosk.sh" >> "$LXDE_DIR/autostart"
    fi
done

# 4. Configura no Autostart Universal
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/kiosk.desktop << EOL
[Desktop Entry]
Type=Application
Name=Ice Robot Kiosk
Exec=/opt/icerobot/kiosk.sh
Terminal=false
X-GNOME-Autostart-enabled=true
EOL
chmod +x ~/.config/autostart/kiosk.desktop



---

## ⚡ Instalação Rápida (One-Line Install)

Para instalar o sistema completo em um novo ambiente Linux ou Raspberry Pi (Debian/Ubuntu/Raspbian), basta executar o comando abaixo no seu terminal:

```bash
curl -fsSL -H "Cache-Control: no-cache" -o install.sh https://raw.githubusercontent.com/3damatta/robertozinho/main/install.sh && sudo bash install.sh
```

> [!IMPORTANT]
> O instalador solicitará um **GitHub Personal Access Token (PAT)** durante o processo. Veja na seção abaixo como gerar o seu.

### O que o instalador faz?
1. 🔍 Verifica o sistema e arquitetura.
2. 📦 Instala dependências nativas (Node.js, PM2, Git, Curl).
3. 🔐 Solicita seu GitHub Token de forma invisível.
4. 📥 Clona o repositório privado para `/opt/icerobot` ocultando suas credenciais.
5. 🏗️ Compila o Frontend/Backend automaticamente.
6. 🖥️ Configura o **Kiosk Mode** (inicialização automática do Chromium em tela cheia no boot do SO, compatível com LXDE/X11 e Labwc/Wayland).
7. 🚀 Configura o PM2 para iniciar o backend automaticamente no boot do SO.

---

## 🔄 Atualização Segura

Para buscar as últimas novidades do código proprietário e atualizar seu sistema sem perder dados, você pode usar uma das seguintes formas:

### 1. Pelo Painel Administrativo (Recomendado)
Acesse a aba **System** na interface administrativa do painel, insira o seu GitHub PAT (Token) no campo correspondente e clique em buscar atualização. Se houver novidades, você poderá disparar a atualização diretamente pela UI. O token é mantido temporariamente em memória apenas durante o processo de atualização.

### 2. Pelo Terminal do SO
Execute o comando abaixo no terminal da máquina:

```bash
curl -fsSL -H "Cache-Control: no-cache" -o update.sh https://raw.githubusercontent.com/3damatta/robertozinho/main/update.sh && sudo bash update.sh
```

> [!TIP]
> **Rollback Automático:** O script de atualização cria um backup automático de toda a pasta `/opt/icerobot` antes de fazer o download. Se a compilação ou o download falhar, ele restaura a versão anterior instantaneamente!

---

## 🔑 Como gerar o GitHub Token (PAT)

Como o projeto principal é privado, você precisará de uma "chave" para que o instalador baixe os arquivos.

1. Acesse o GitHub e vá em **Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**.
   * *Link direto: [Generate new token](https://github.com/settings/tokens/new)*
2. No campo **Note**, digite um nome (ex: `IceRobot Totem Kiosk`).
3. Em **Expiration**, selecione "No expiration" (ou uma data de sua preferência).
4. Na lista de permissões (Scopes), marque **APENAS** a opção:
   - [x] `repo` (Full control of private repositories)
5. Clique em **Generate token** no final da página.
6. **Copie o código gerado!** Você colará este código no terminal quando o `install.sh` pedir.

> [!WARNING]
> Nunca compartilhe seu Token publicamente. O instalador garante que ele jamais será salvo em arquivos de histórico `.bash_history` ou no diretório do git.

---

## 🛠 Solução de Problemas

### O instalador diz "Credenciais inválidas"
O seu token provavelmente expirou ou foi copiado incompleto. Gere um novo token seguindo os passos acima. Lembre-se que você não deve digitar sua *senha*, e sim o *Token Gerado*.

### O terminal travou durante "Compilando..."
Dependendo do modelo do seu Raspberry Pi, compilações NPM ou Maven podem demorar de 2 a 15 minutos e utilizar 100% da CPU. Apenas aguarde o término.

### Como paro o sistema?
Como o sistema roda nativamente via gerenciador de processos (PM2), você pode usar os seguintes comandos no terminal:
- Parar: `pm2 stop icerobot-app`
- Reiniciar: `pm2 restart icerobot-app`
- Ver os logs em tempo real: `pm2 logs icerobot-app`

---
*Ice Robot Bhar © Todos os direitos reservados.*
