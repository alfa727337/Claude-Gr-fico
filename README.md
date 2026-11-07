# Ubuntu gráfico + Claude Code no Android

Instalador automatizado para Termux em aparelhos Android ARM64. Ele cria ou reutiliza um Ubuntu 24.04 isolado, instala o ambiente gráfico XFCE e configura Claude Code, OpenAI Codex CLI, tenta instalar Antigravity CLI, ZCode da Z.ai e navegadores compatíveis.

## Antes de começar

Instale manualmente no Android:

1. **Termux** — use uma versão atual do F-Droid ou das releases oficiais do GitHub.
2. **Termux:X11** — instale o APK correspondente ao Termux. Os dois aplicativos devem vir de fontes compatíveis, para evitar conflito de assinatura.

Requisitos recomendados:
- Android ARM64 (64 bits).
- Pelo menos **4 GB livres** para iniciar a instalação; **8 GB ou mais são recomendados** para acomodar cache, atualizações e possíveis variações de tamanho.
- Conexão estável com a internet.
- Memória RAM de pelo menos 4 GB; mais memória melhora a experiência.
- Bateria/carregador: a primeira instalação pode demorar bastante. Não force o fechamento do Termux durante o processo.

O instalador verifica a arquitetura e o espaço livre mínimo. A consulta `pm path` ao Termux:X11 é apenas informativa e não bloqueia a instalação, pois o serviço de pacotes do Android pode falhar mesmo quando o APK está instalado. Se o aparelho não atender aos requisitos, ele informa o motivo antes de começar. Se o `curl` do Termux estiver quebrado por incompatibilidade entre `curl` e `libcurl` (por exemplo, erro `cannot locate symbol`), o comando de instalação tenta usar `wget` para baixar o script; em seguida, o próprio instalador detecta a falha e tenta reinstalar `curl`, `libcurl`, OpenSSL e certificados pelo gerenciador de pacotes do Termux.
A instalação usa modo não interativo para que atualizações de arquivos de configuração do sistema não parem aguardando uma resposta no teclado. Quando necessário, aplica a versão de configuração fornecida pelo pacote atualizado.

## Instalação — um único comando

Depois de instalar somente os dois APKs (**Termux** e **Termux:X11**), abra o Termux padrão. Não é necessário instalar previamente Node.js, Ubuntu, proot-distro, XFCE, Git ou qualquer outra dependência.

Cole exatamente este único comando:

```bash
curl -fsSL https://raw.githubusercontent.com/alfa727337/Claude-Gr-fico/main/install.sh | bash
```

O script baixa e configura automaticamente os pacotes necessários no Termux e, em seguida, cria o Ubuntu e instala o ambiente gráfico, runtimes e uma base ampla de desenvolvimento dentro dele, incluindo Node.js/npm, Python 3/pip/venv, Java, Go, Rust/Cargo, PHP, Ruby, ferramentas de compilação, rede e utilitários. Em instalações limpas, o Termux precisa conseguir executar o `curl` que já vem disponível no ambiente inicial e ter acesso à internet. Se a própria instalação básica do Termux estiver corrompida a ponto de o comando `curl` não iniciar, nenhum script remoto pode ser baixado por esse mesmo comando; isso é uma falha prévia do aplicativo/ambiente, não uma dependência que o instalador possa instalar antes de ser executado.

O instalador configura automaticamente:

- Repositórios e ferramentas necessárias do Termux.
- PRoot-Distro e um Ubuntu 24.04 ARM64 novo e isolado.
- XFCE (área de trabalho gráfica), terminal XFCE e Thunar (gerenciador de arquivos).
- DBus, fontes, ícones e dependências do ambiente gráfico.
- Node.js, npm, Python 3, pip, venv, cabeçalhos de desenvolvimento, Git/Git LFS, curl, wget e certificados dentro do Ubuntu.
- Toolchains e runtimes adicionais: Java (JDK), Go, Rust/Cargo, PHP e Ruby, além de GCC/G++, Make, CMake, Ninja, Clang, GDB e bibliotecas comuns de desenvolvimento.
- Utilitários ampliados: aria2, rclone, jq, yq, SQLite, clientes PostgreSQL/Redis, SSH, ferramentas de rede e compactação.
- Utilitários de sistema, rede, SSH, compactação, edição de texto, monitoramento e fontes adicionais.
- Claude Code pelo pacote npm oficial da Anthropic.
- Atalhos para Claude Code, Codex, Antigravity CLI e ZCode (quando instalados) no menu do XFCE.
- Comando de inicialização `programas-linux-desktop` no Termux.
- Verificações de versões e componentes essenciais antes de declarar sucesso.

O processo baixa os componentes diretamente de seus repositórios oficiais. O tempo depende da conexão, do armazenamento e do aparelho.

## Abrir a área de trabalho

Depois que o instalador terminar, execute no Termux:

```bash
programas-linux-desktop
```

O Termux:X11 abrirá a tela gráfica. No XFCE, use o menu de aplicativos ou os ícones da área de trabalho para abrir as ferramentas e navegadores que tenham sido instalados com sucesso. Claude Code, Codex e Antigravity CLI abrem em terminais; o ZCode é o aplicativo gráfico da Z.ai. Na primeira execução, faça login com sua própria conta em cada serviço; nenhuma conta ou credencial é fornecida pelo projeto.

Na primeira execução, faça login com sua própria conta Anthropic. O instalador não inclui contas, tokens, chaves, credenciais ou dados de terceiros.

## Se a instalação for interrompida

O instalador foi preparado para poder ser executado novamente. Ele verifica também o diretório real do Ubuntu instalado, preserva o container `claude-code` que já existir e continua a configuração sem tentar criá-lo novamente. Isso evita o erro `container is busy` que pode ocorrer quando uma sessão anterior do Ubuntu ainda está aberta.

Se uma sessão anterior estiver usando arquivos do Ubuntu e houver conflito durante a configuração, feche essa sessão pelo próprio Termux e execute novamente o mesmo comando. Não é necessário apagar o container nem instalar tudo do zero.

Se houver outra falha, leia a mensagem exibida, corrija a causa (por exemplo, conexão ou espaço insuficiente) e execute novamente o mesmo comando de instalação.

**Não apague manualmente o diretório do Termux nem o container para tentar corrigir uma falha.** Isso pode remover dados locais.

## Isolamento e limites

- O Ubuntu é criado do zero dentro do PRoot-Distro.
- Nenhum backup de outro aparelho ou ambiente é importado.
- O instalador não copia histórico, configurações, credenciais ou arquivos pessoais de outra instalação.
- O container se chama `claude-code`. Se já existir um container com esse nome, ele será preservado e reutilizado.
- O ambiente gráfico depende do Termux:X11 e das limitações do Android/PRoot. Não é uma máquina virtual com kernel próprio nem o aplicativo Claude Desktop oficial.
- Claude Code exige autenticação e acesso à internet para seus recursos de IA. O uso depende do plano/conta e das condições da Anthropic.
- O desempenho varia conforme processador, RAM, armazenamento, versão do Android e gerenciamento de bateria do fabricante.

## Fontes técnicas

- [Termux](https://github.com/termux/termux-app)
- [Termux:X11 — instruções oficiais](https://github.com/termux/termux-x11)
- [PRoot-Distro](https://github.com/termux/proot-distro)
- [Documentação oficial do Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started)\n- [OpenAI Codex CLI](https://github.com/openai/codex)\n- [Google Antigravity — CLI e downloads](https://antigravity.google/download/linux)\n- [ZCode — instalação oficial Linux ARM64](https://zcode.z.ai/en/docs/install)\n- [Brave — instalação Linux](https://brave.com/pt-br/linux/)\n- [Google Chrome — requisitos e instalação](https://support.google.com/chrome/answer/95346?hl=pt-BR)

Este projeto não é afiliado à Anthropic, ao Termux ou ao projeto Termux:X11.

## Compatibilidade das ferramentas gráficas

A instalação de aplicativos gráficos adicionais é uma tentativa controlada e não deve interromper a instalação principal:

- **ZCode:** o instalador baixa o pacote DEB ARM64 oficial da Z.ai (versão 3.17.2 nesta revisão). A Z.ai oferece build Linux ARM64, mas isso não garante funcionamento dentro do Android/PRoot; aceleração gráfica, sandbox e dependências do Electron podem limitar a abertura. O login e a conexão com Z.ai/BigModel/API Key são feitos pelo próprio usuário no aplicativo.
- **Brave e Google Chrome:** o instalador tenta usar os repositórios oficiais para ARM64. Em PRoot, os navegadores podem exigir flags de compatibilidade e ter limitações de sandbox, GPU, áudio ou desempenho.
- **Antigravity:** o instalador adiciona o CLI oficial e um atalho de terminal. Isso não equivale a instalar/garantir a IDE gráfica completa.
- **Painel XFCE:** o instalador cria um grupo de atalhos no painel inferior na primeira sessão gráfica. Se o painel personalizado do usuário impedir a configuração automática, os atalhos continuam disponíveis no menu e na área de trabalho.

A instalação pode exigir bastante armazenamento adicional. A disponibilidade de pacotes ARM64 e a execução gráfica devem ser verificadas no aparelho. Cada usuário autentica suas próprias contas na primeira abertura.
