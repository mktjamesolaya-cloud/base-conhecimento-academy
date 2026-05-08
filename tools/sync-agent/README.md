# sync-agent — sincronização automática com GitHub

Esse diretório instala um **launchd agent** no macOS que vigia dois arquivos-trigger na raiz do projeto e dispara o `sync.sh` automaticamente quando eles aparecem. O Claude (Cowork) consegue criar esses arquivos pelo chat, então na prática o sync acontece sozinho — você só pede.

---

## Pra equipe (sem Terminal)

Se você não tem familiaridade com Terminal, é assim que se configura em um Mac novo:

1. Garante que o repo `base-conhecimento-academy` já está clonado no Mac e o `git push` funciona (alguém da equipe já fez isso pra você, ou pede ajuda uma vez).
2. Abre o Finder e vai até a pasta do repo.
3. Acha o arquivo **`Setup-Sincronizacao.command`** na raiz.
4. Dá **duplo-clique** nele.
   - Se o macOS bloquear ("não foi possível abrir porque o desenvolvedor não pode ser verificado"): clique com **botão direito** no arquivo → "Abrir" → confirma "Abrir" no diálogo. Só precisa fazer isso na primeira vez.
5. Uma janela de Terminal abre, roda alguns comandos sozinha, e mostra `agent carregado com sucesso.`
6. Pode fechar a janela. Pronto.

**A partir desse momento**, no Cowork você pode mandar mensagens como:

- "sincroniza" / "manda pro github" → envia suas mudanças pra equipe.
- "puxa do github" / "atualiza do remoto" → traz o que a equipe mandou.

E o Claude faz tudo sozinho, sem você precisar abrir Terminal.

---

## Como funciona (parte técnica)

```
┌─ Claude (Cowork) ────────────┐        ┌─ launchd (macOS) ───────────┐
│ usuário diz "sincroniza"     │        │ acorda a cada 2s            │
│ ↓                            │  poll  │ (StartInterval) e checa se  │
│ echo "msg" > .sync-trigger   │ ─────▶ │ tem trigger.                │
│ (dentro da pasta do repo)    │        │ ↓                           │
└──────────────────────────────┘        │ trigger-handler.sh:         │
                                        │  - sem trigger → exit 0     │
                                        │  - com trigger → lê msg,    │
                                        │    apaga, chama ./sync.sh,  │
                                        │    loga em ~/Library/Logs   │
                                        └─────────────────────────────┘
```

**Por que polling e não `WatchPaths`?** O `WatchPaths` do launchd usa FSEvents do kernel macOS, e arquivos criados pelo mount do Cowork (de onde o Claude escreve) não geram FSEvents nativos — então o WatchPaths nunca dispararia. Polling de 2s funciona pra ambos os casos: trigger criado pelo sandbox **e** trigger criado manualmente do Terminal. O custo é ínfimo (handler sai em ~5ms quando não há trigger). O `WatchPaths` fica como atalho extra: se você criar o trigger do Terminal, dispara instantâneo (em paralelo ao polling).

Dois triggers, dois comportamentos:

| Arquivo | O que dispara | Quando o Claude cria |
|---|---|---|
| `.sync-trigger` | `./sync.sh "<conteúdo do arquivo>"` (pull + commit + push) | "sincroniza", "manda pro github", fim de sessão |
| `.pull-trigger` | `./sync.sh --pull` (só pull) | "puxa do github", "atualiza", início de sessão |

O conteúdo do `.sync-trigger` (primeira linha) vira a mensagem de commit. Vazio = mensagem automática gerada pelo `sync.sh`.

---

## Tratamento de conflitos

O `sync.sh` cria uma branch `backup/auto-YYYYMMDD-HHMMSS` automaticamente antes de cada pull. Se o pull der conflito:

1. Aborta o rebase em progresso.
2. Salva mudanças não-commitadas em stash com label `auto-backup`.
3. Alinha `main` local com `origin/main` (`reset --hard`).
4. Loga onde tudo foi preservado.

**Nada se perde** — só fica num lugar diferente. Pra recuperar trabalho que foi mandado pro backup, alguém com Terminal precisa rodar:

```bash
git checkout backup/auto-YYYYMMDD-HHMMSS
# inspeciona o que tinha lá, copia o que importa, faz merge ou cherry-pick
```

Sem conflito, a branch de backup é apagada na hora pra não acumular.

---

## Instalação manual (fallback via Terminal)

Se o `Setup-Sincronizacao.command` falhar por algum motivo, ou se você prefere Terminal:

```bash
cd /caminho/para/base-conhecimento-academy
./tools/sync-agent/install.sh
```

O script:

1. Gera `~/Library/LaunchAgents/com.jao.sync-trigger.plist` a partir do template, com os caminhos corretos pra essa máquina.
2. Carrega o agent com `launchctl load`.
3. Confirma que apareceu em `launchctl list`.

É **idempotente** — pode rodar de novo (depois de um `git pull` que mudou o template, por exemplo) que ele descarrega a versão antiga primeiro.

### Teste manual

Depois de instalar, na pasta do repo:

```bash
echo "teste de sync agent" > .sync-trigger
```

Em ~2 segundos o arquivo deve sumir e aparecer um commit novo no GitHub. Se não acontecer, veja `Troubleshooting` abaixo.

---

## Logs

Tudo cai em `~/Library/Logs/`:

- `jao-sync-agent.log` — log estruturado do handler (o que mais importa)
- `jao-sync-agent.stdout.log` / `.stderr.log` — saída crua do launchd (raramente útil)

Comandos úteis (Terminal):

```bash
tail -f ~/Library/Logs/jao-sync-agent.log    # acompanha em tempo real
tail -50 ~/Library/Logs/jao-sync-agent.log   # últimas 50 linhas
```

---

## Troubleshooting

### "criei o trigger e nada aconteceu"

1. Confere que o agent está carregado:
   ```bash
   launchctl list | grep jao
   ```
   Tem que aparecer `com.jao.sync-trigger`.

2. Confere os logs (`tail -50 ~/Library/Logs/jao-sync-agent.log`).

3. `WatchPaths` do launchd dispara em criação **e** modificação. Se você só salvou um arquivo vazio que já existia, ele pode não disparar — deleta e cria de novo.

### "git push falhou: authentication"

O agent roda como você, então usa as mesmas credenciais do seu Terminal. Se `git push` manual funciona mas pelo agent não, provavelmente é problema de PATH ou de keychain não estar acessível em sessão non-interactive.

Verifique:

```bash
git config --get credential.helper
# deveria retornar: osxkeychain (macOS) ou store
```

Se estiver vazio, configura:

```bash
git config --global credential.helper osxkeychain
```

E faz um `git push` manual uma vez pra cachear o PAT.

### "sync.sh: command not found" no log

Provavelmente o handler não conseguiu achar o `sync.sh`. O `REPO_DIR` é setado pelo `install.sh` no plist — se você moveu a pasta do projeto, dá duplo-clique no `Setup-Sincronizacao.command` de novo na nova localização.

### "houve conflito durante o pull"

O `sync.sh` automaticamente preservou seu trabalho em uma branch `backup/auto-XXX` (e possivelmente em um stash). Veja a seção "Tratamento de conflitos" acima — alguém com Terminal precisa fazer o merge manual.

### Reinstalar do zero

```bash
./tools/sync-agent/uninstall.sh
./tools/sync-agent/install.sh
```

Ou simplesmente rode o `Setup-Sincronizacao.command` de novo (o `install.sh` é idempotente).

---

## Arquivos

| Arquivo | Propósito |
|---|---|
| `../../Setup-Sincronizacao.command` | Instalador clicável pra equipe sem Terminal |
| `install.sh` | Instalador via Terminal (one-shot, idempotente) |
| `uninstall.sh` | Remove o agent |
| `com.jao.sync-trigger.plist.tmpl` | Template do launchd com placeholders `__REPO_DIR__` e `__HOME__` |
| `trigger-handler.sh` | Script chamado pelo launchd quando triggers aparecem |
| `README.md` | Esse arquivo |

---

## Desinstalar

```bash
./tools/sync-agent/uninstall.sh
```

Remove o plist e descarrega o agent. Logs antigos ficam em `~/Library/Logs/` — apaga manualmente se quiser.
