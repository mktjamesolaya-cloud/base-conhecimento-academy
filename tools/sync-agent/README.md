# sync-agent — sincronização automática com GitHub

Esse diretório instala um **launchd agent** no macOS que vigia dois arquivos-trigger na raiz do projeto e dispara o `sync.sh` automaticamente quando eles aparecem. O Claude (Cowork) consegue criar esses arquivos pelo chat, então na prática o sync acontece sozinho — você só pede.

---

## Como funciona

```
┌─ Claude (Cowork) ────────────┐        ┌─ launchd (macOS) ───────────┐
│ usuário diz "sincroniza"     │        │ vigia .sync-trigger e       │
│ ↓                            │ touch  │ .pull-trigger via WatchPaths│
│ touch .sync-trigger          │ ─────▶ │ ↓                           │
│ (dentro da pasta do repo)    │        │ chama trigger-handler.sh    │
└──────────────────────────────┘        │ ↓                           │
                                        │ trigger-handler.sh:         │
                                        │  - lê msg do trigger        │
                                        │  - apaga o trigger          │
                                        │  - chama ./sync.sh "msg"    │
                                        │  - loga em ~/Library/Logs   │
                                        └─────────────────────────────┘
```

Dois triggers, dois comportamentos:

| Arquivo | O que dispara | Quando o Claude cria |
|---|---|---|
| `.sync-trigger` | `./sync.sh "<conteúdo do arquivo>"` (pull + commit + push) | "sincroniza", "manda pro github", fim de sessão |
| `.pull-trigger` | `./sync.sh --pull` (só pull) | "puxa do github", "atualiza" |

O conteúdo do `.sync-trigger` (primeira linha) vira a mensagem de commit. Vazio = mensagem automática gerada pelo `sync.sh`.

---

## Instalação (uma vez por Mac)

Pré-requisitos: o repo já clonado e com `git push`/`git pull` funcionando manualmente (autenticação via PAT/keychain ou SSH key já configurada).

```bash
cd ~/Downloads/PROJETOS_DEV/assistente-online
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

## Uso pelo chat com o Claude

Frases que disparam o sync (Claude faz `touch` do trigger pra você):

- "sincroniza" / "sync" / "manda pro github" → `.sync-trigger` (push completo)
- "puxa do github" / "atualiza do remoto" → `.pull-trigger` (só pull)

No fim de cada sessão, se houve edições, o Claude propõe a mensagem de commit e cria o `.sync-trigger` automaticamente.

---

## Logs

Tudo cai em `~/Library/Logs/`:

- `jao-sync-agent.log` — log estruturado do handler (o que mais importa)
- `jao-sync-agent.stdout.log` / `.stderr.log` — saída crua do launchd (raramente útil)

Comandos úteis:

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

Provavelmente o handler não conseguiu achar o `sync.sh`. O `REPO_DIR` é setado pelo `install.sh` no plist — se você moveu a pasta do projeto, rode `./tools/sync-agent/install.sh` de novo na nova localização.

### Reinstalar do zero

```bash
./tools/sync-agent/uninstall.sh
./tools/sync-agent/install.sh
```

---

## Arquivos

| Arquivo | Propósito |
|---|---|
| `install.sh` | Instalador (one-shot, idempotente) |
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
