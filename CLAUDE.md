# CLAUDE.md — Padrão de Transcrição VTT → Markdown

## Contexto do Projeto

Base de conhecimento em Markdown para a IA, gerada a partir de legendas VTT de cursos de micropigmentação da Jay Academy Online (JAO).

O objetivo é que a IA consulte esses arquivos e responda perguntas com base **exatamente no que o professor disse** — não em resumos ou interpretações minhas.

Este projeto é compartilhado com a equipe via GitHub: `https://github.com/mktjamesolaya-cloud/base-conhecimento-academy.git`. Toda mudança precisa ir para a `main` para que a equipe veja.

---

## Sincronização com GitHub (fluxo 100% pelo chat)

**Limitação técnica:** o sandbox do Cowork onde Claude roda comandos não tem permissão para escrever em `.git/`. Por isso, operações git (`pull`, `commit`, `push`) precisam acontecer no Mac do usuário. A solução é um **launchd agent** que vigia arquivos-trigger e dispara `sync.sh` quando eles aparecem — Claude cria os triggers do sandbox, o agent reage em ~2 segundos. Resultado: usuário não precisa abrir Terminal nunca.

### Modos de sincronização

Existem dois modos. Claude detecta qual está em uso e age de acordo:

**Modo automático (padrão da equipe)** — o launchd agent está instalado e vigia dois arquivos-trigger na raiz do repo:

- `.sync-trigger` → dispara `./sync.sh "<conteúdo>"` (pull + commit + push). Conteúdo do arquivo (primeira linha) vira a mensagem de commit; vazio = mensagem auto.
- `.pull-trigger` → dispara `./sync.sh --pull`.

Claude cria esses arquivos do sandbox (`echo "msg" > .sync-trigger`), porque eles ficam fora de `.git/`. **Toda a sincronização acontece pelo chat** nesse modo.

**Modo manual (fallback raro)** — sem o agent instalado, Claude pede ao usuário para rodar `./sync.sh` no Terminal. Só usar como fallback.

**Como Claude detecta o modo:** verifica se `~/Library/LaunchAgents/com.jao.sync-trigger.plist` existe (`ls ~/Library/LaunchAgents/com.jao.sync-trigger.plist 2>/dev/null` no bash do sandbox). Existe → modo automático. Não existe → orientar instalação (ver "Configurar sincronização automática em novo Mac" abaixo).

### Fluxo obrigatório por sessão (modo automático)

**No início de cada sessão**, antes de fazer qualquer edição em arquivos do projeto, Claude deve:

1. Disparar o pull automaticamente: `echo "" > .pull-trigger` (do sandbox).
2. Aguardar ~5 segundos pra o agent processar.
3. Confirmar que o trigger sumiu (`ls .pull-trigger` deve falhar) — sinal de que o handler rodou.
4. Só então começar a editar arquivos.

Não é necessário pedir ao usuário pra rodar nada no Terminal nesse passo. Claude faz sozinho.

No **modo manual**, Claude orienta o usuário a rodar `./sync.sh --pull` no Terminal e aguarda confirmação antes de continuar.

**No final de cada sessão** (ou sempre que Claude terminar um bloco de trabalho relevante), Claude deve:

1. Listar resumidamente os arquivos que foram criados/modificados.
2. Sugerir uma mensagem de commit descritiva (ex: `"transcrever módulo 08 do Basic-Shadow"`).
3. Disparar o sync:
   - **Modo automático:** `echo "mensagem do commit" > .sync-trigger` (Claude faz, sem precisar do usuário).
   - **Modo manual:** pedir ao usuário para rodar `./sync.sh "mensagem do commit"` no Terminal.
4. Confirmar que o sync rodou — checar que `.sync-trigger` sumiu. Se quiser certeza extra, pode olhar `~/Library/Logs/jao-sync-agent.log` (mas o sandbox não tem acesso a esse log; pede ao usuário se precisar).

**Frases do usuário que disparam sync via chat (modo automático):**

- "sincroniza", "sync", "manda pro github", "joga pro github" → `.sync-trigger`
- "puxa do github", "atualiza do remoto", "puxa as mudanças" → `.pull-trigger`

### Tratamento de conflitos

O `sync.sh` cria automaticamente uma branch `backup/auto-YYYYMMDD-HHMMSS` antes de cada pull. Se o pull der conflito, a recuperação é automática:

1. Aborta o rebase em progresso.
2. Salva mudanças não-commitadas em stash com label `auto-backup`.
3. Alinha `main` local com `origin/main` (`reset --hard`).
4. Loga onde o trabalho foi preservado.

**Nada se perde** — só fica num lugar diferente. Pra recuperar mudanças do backup, alguém com Terminal precisa rodar `git checkout backup/auto-XXX` e fazer merge manual. Claude deve avisar o usuário quando o log indicar conflito.

Sem conflito, a branch de backup é apagada automaticamente.

### Configurar sincronização automática em novo Mac

Quando o usuário (ou alguém da equipe) disser **"configurar sincronização"**, **"setup do sync"** ou similar, Claude orienta o fluxo **sem Terminal**:

1. Pré-requisitos: repo já clonado em algum lugar do Mac e `git push` funcionando (PAT/keychain ou SSH key configurada). Se ainda não tem, alguém da equipe precisa ajudar com isso uma vez.
2. No Finder, navegar até a pasta do repo e dar **duplo-clique no arquivo `Setup-Sincronizacao.command`** (na raiz).
3. Se o macOS bloquear na primeira vez (Gatekeeper): clique com **botão direito** no arquivo → "Abrir" → "Abrir" no diálogo.
4. Aguardar a janela do Terminal mostrar `agent carregado com sucesso.` — pode fechar.

**Esse fluxo é 100% sem comandos digitados** — só cliques. Recomendado pra equipe não-técnica.

**Fallback via Terminal (só se o `.command` falhar):**
```bash
cd /caminho/para/base-conhecimento-academy
./tools/sync-agent/install.sh
```

Documentação detalhada em `tools/sync-agent/README.md`.

### Comandos do `sync.sh`

| Comando | O que faz |
|---|---|
| `./sync.sh` | Pull + commit auto + push (uso padrão ao final da sessão) |
| `./sync.sh "mensagem"` | Igual, mas com mensagem de commit customizada |
| `./sync.sh --pull` | Só pull (uso no início da sessão) |
| `./sync.sh --status` | Só mostra estado (não modifica nada) |

### Regras adicionais

- **Nunca** Claude deve fingir que executou git push se não conseguiu — sempre confirma via desaparecimento do trigger ou pede ao usuário.
- Se houver indicação de conflito no log/output, Claude avisa o usuário e recomenda procurar quem do time tem Terminal pra resolver o backup.
- Mudanças experimentais ou que não devem ir para a equipe → Claude avisa antes para o usuário **não** rodar o sync (e, no modo automático, **não** cria o trigger).
- Os arquivos-trigger (`.sync-trigger`, `.pull-trigger`) estão no `.gitignore` e são locais de cada máquina — nunca devem ir pro repo.

---

## Regra Fundamental

> **Tom do professor, sempre. Estrutura leve, se necessário.**
>
> O conteúdo dentro de cada seção deve soar como o professor falando — primeira pessoa, vocabulário dele, ritmo dele. Não é meu texto explicando o que ele disse: é ele dizendo.
>
> Estrutura de navegação (H2 por aula, separadores `---`, **subtítulos em negrito** para organizar blocos longos) é **permitida** — desde que o texto embaixo seja a voz do professor, não um resumo meu.

A única transformação permitida além da estrutura de navegação é **limpeza técnica** do VTT (remover timestamps, números de segmento, WEBVTT header) e **junção de frases quebradas** em parágrafos coerentes.

---

## Estrutura Obrigatória dos Arquivos

### Frontmatter

```yaml
---
title: "XX — Título do Módulo"
curso: "Nome Exato do Curso"
modulo: "XX — Título do Módulo"
tags:
  - curso/slug-do-curso
  - tecnica/slug-tecnica
  - modulo/slug-modulo
aliases:
  - "Termo alternativo que a IA pode buscar"
  - "Outro sinônimo técnico relevante"
aulas:
  - nome_arquivo_vtt_sem_extensao
  - outro_arquivo_vtt_sem_extensao
---
```

- `title`: título canônico do note — usado pelo Obsidian em graph view, backlinks e busca
- `aliases`: nomes alternativos para busca — termos técnicos, sinônimos usados pelo professor, variações de ortografia
- `tags`: hierarquia `curso/slug`, `tecnica/slug`, `modulo/slug` — permite filtro e agrupamento por tema

### Hierarquia de Cabeçalhos

```
# Título do Módulo — Nome do Curso        ← H1: um por arquivo

## Título da Aula                          ← H2: um por VTT de origem
> Aula: [[nome_arquivo_vtt_sem_extensao]] ← wikilink ao VTT fonte

[conteúdo verbatim da aula]

---                                        ← separador entre aulas

## Próxima Aula
> Aula: [[proximo_arquivo_vtt]]
```

### Bloco de navegação (final do arquivo)

Ao final de cada arquivo, após o último separador `---`, adicionar bloco de navegação oculto com wikilinks:

```markdown
---

%%
Anterior: [[nome-arquivo-anterior|Título Anterior]]
Próximo: [[nome-arquivo-proximo|Título Próximo]]
%%
```

O bloco `%% ... %%` fica oculto na leitura mas é indexado pelo Obsidian para navegação e backlinks.

---

## Regras de Transcrição

### O que REMOVER do VTT:
- Timestamps: `00:01:23.456 --> 00:01:25.789`
- Números de segmento (linhas com apenas um número)
- Cabeçalho `WEBVTT`

### O que PRESERVAR:
- **Todas as falas do professor**, na íntegra e em ordem
- **Perguntas de alunos** e respostas do professor (quando aparecerem)
- **Enumerações orais** do professor: "primeiro...", "segundo...", "terceiro..."
- **Referências visuais**: "olha isso aqui", "está vendo?", "dá para ver?" — fazem parte do raciocínio didático
- **Hesitações com função didática**: pausas que revelam pensamento ou ênfase
- **Repetições intencionais**: quando o professor repete para reforçar um ponto
- **Asides e digressões**: histórias, analogias, exemplos do cotidiano

### O que NÃO FAZER (proibido):

❌ Não adicionar headers em negrito para organizar o conteúdo:
```
**Pigmentação melânica racial vs. hiperpigmentação pós-inflamatória:**   ← PROIBIDO
**Estratégia de cor:**                                                    ← PROIBIDO
**Quando usar a técnica clássica?**                                       ← PROIBIDO
```

❌ Não criar bullet points com informação que o professor disse em texto corrido:
```
- Primeiro ponto que o professor mencionou    ← PROIBIDO (se ele não listou assim)
- Segundo ponto
```

❌ Não parafrasear, resumir ou condensar passagens

❌ Não criar tabelas editoriais com conteúdo da aula

❌ Não omitir Q&A, asides, repetições ou digressões do professor

❌ Não adicionar meus próprios títulos temáticos dentro do corpo do texto

❌ Não usar callouts Obsidian (`> [!note]`, `> [!warning]`, etc.) no corpo — são estrutura editorial

❌ Não usar embeds (`![[arquivo]]`) no corpo do texto — idem

---

## Formação de Parágrafos

Junte frases quebradas pelo VTT em parágrafos coerentes. A **quebra de parágrafo** deve ocorrer onde o professor naturalmente muda de assunto ou faz uma pausa longa — não onde eu acho conveniente organizar.

Se o professor enumera oralmente ("a primeira coisa é... a segunda é... a terceira é..."), mantenha em texto corrido, como ele falou — não converta em lista markdown.

**Exceção:** Se o professor diz literalmente "vou listar" e enumera itens distintos e curtos, uma lista markdown é aceitável — mas só se o professor estruturou assim oralmente.

---

## Exemplos Comparativos

### ❌ ERRADO — editorial meu

```markdown
**Pigmentação melânica racial vs. hiperpigmentação pós-inflamatória:**

As manchas hereditárias a gente chama de pigmentação melânica racial...

**Estratégia de cor:**

A gente tem sempre que se perguntar: essa mancha marrom...

**Protocolo de sessões:**

Esse tipo de lábio leva uns 6 meses...
```

### ✓ CORRETO — verbatim do professor

```markdown
As manchas hereditárias a gente chama de pigmentação melânica racial. Vocês vão ver que a gente vai ter outros lábios que têm manchas pós-inflamatórias, manchas provocadas por melasma, manchas provocadas por sol, manchas provocadas por acidez da saliva, manchas provocadas por queimaduras, por ácidos, manchas provocadas por outras coisas. Qualquer mancha que foi provocada por algum tipo de processo lesivo que machucou essa pele, a gente chama de manchas por hiperpigmentação pós-inflamatória. É uma mancha que a pessoa não nasceu com ela, não está na genética. Ela foi produzida por uma lesão. Esses são os lábios bem perigosos de a gente fazer.

Agora, esse tipo de lábio não é tão perigoso. A gente tem alguns tipos de lábios, está vendo? Olha a característica desses lábios aqui. Eu tenho o lábio pálido, frio. Pálido, mais para o quente. Eu tenho o lábio normal, rosadinho, meio alaranjado, meio salmão...

A gente tem sempre que se perguntar: essa mancha marrom que eu identifiquei neste lábio, é uma mancha que foi provocada por alguma coisa ou eu já nasci com ela? Se essa pessoa nasceu com essa mancha, sempre teve, a família tem, é genético, a gente consegue tratar com um pouco mais de segurança.

...

Esse tipo de lábio com pigmentação melânica racial é uns seis meses de tratamento, para chegar em um resultado muito bom. Se você quiser segurança, uma sessão cada dois meses é perfeito.
```

---

## Outro Exemplo

### ❌ ERRADO — anatomia com headers editoriais

```markdown
**Estrutura da Pele:**

Estruturalmente, a pele é composta por duas camadas...

**Epiderme:**
A epiderme é a camada mais superficial...

**Derme:**
- Colágeno (70% a 80%) — confere resistência
- Elastina (1% a 3%) — responsável pela elasticidade
```

### ✓ CORRETO — verbatim

```markdown
Estruturalmente, a pele é composta por duas camadas interdependentes — a epiderme (mais externa) e a derme (mais profunda). Ambas repousam sobre a hipoderme (ou panículo adiposo), o tecido adjacente, permitindo que a pele se movimente livremente sobre as estruturas mais profundas do corpo.

A epiderme é a camada mais superficial da pele, formada por um epitélio pavimentoso e estratificado, queratinizado, com espessura variando de 0,04 até 1,5 mm conforme a região. Cerca de 95% das células da epiderme são queratinócitos, organizados em cinco camadas que se renovam continuadamente: basal (germinativa), espinhosa, granulosa, lúcida e córnea.

A camada basal é a mais profunda, apresenta atividade mitótica com células-mãe, originando duas células-filhas...

A derme fica logo abaixo da epiderme, formada por um denso estroma fibro-elástico de tecido conjuntivo. Serve de suporte para extensas redes vasculares, nervosas e para os anexos cutâneos. É composta principalmente por colágeno (70% a 80%), que confere resistência, elastina (1% a 3%), responsável pela elasticidade, e proteoglicanos, que reconstituem substâncias amorfas em torno das fibras.
```

---

## Processamento de VTTs

### Fluxo de trabalho:

1. Ler o(s) arquivo(s) VTT de origem
2. Remover: timestamps, números de segmento, "WEBVTT"
3. Juntar frases quebradas em parágrafos naturais
4. Escrever o `.md` com o frontmatter correto + conteúdo verbatim
5. **Não adicionar nenhuma estrutura que não existia na fala**

### Arquivos fonte:

| Curso | VTTs | Qtde | Status |
|---|---|---|---|
| Basic Nanofios | `Legendas/BasicNanoFios/` | 53 | ✅ transcrito |
| Lips-Sense | `Legendas/Lips-Sense/` | 62 | ✅ transcrito |
| Basic Shadow | `Legendas/Basic-Shadow/` | 73 | ✅ transcrito (saída: `Basic-Magic-Shadow/`) |
| Colorimetria Sobrancelhas | `Legendas/ColorimetriaSobrancelhas/` | 3 | ✅ transcrito |
| Colorimetria Lips | `Legendas/ColorimetriaLips/` | 4 | ✅ transcrito |
| Fio a Fio Realista (Dermógrafo) | `Legendas/FioRealista/` | 80 | ✅ transcrito (65 VTTs do curso oficial; bônus JamesFlix/Lives — 15 VTTs fora da lista oficial — não transcritos) |
| Profissão Remove | `Legendas/ProfissaoRemove/` | 67 | ✅ transcrito (12 módulos, todos os 67 VTTs) |

Raiz dos VTTs: `/Users/lucasferreira/PROJETOS_DEV/base-conhecimento-academy/Legendas/`

### Arquivos de saída:

| Curso | MDs |
|---|---|
| Basic Nanofios | `JayoAcademyOnline/Basic-Nanofios/` |
| Lips-Sense | `JayoAcademyOnline/Lips-Sense/` |
| Basic Magic Shadow | `JayoAcademyOnline/Basic-Magic-Shadow/` |
| Colorimetria Sobrancelhas | `JayoAcademyOnline/ColorimetriaSobrancelhas/` |
| Colorimetria Lips | `JayoAcademyOnline/ColorimetriaLips/` |
| Fio a Fio Realista (Dermógrafo) | `JayoAcademyOnline/Fio-a-Fio-Realista/` |
| Profissão Remove | `JayoAcademyOnline/Profissao-Remove/` |

Raiz dos MDs: `/Users/lucasferreira/PROJETOS_DEV/base-conhecimento-academy/JayoAcademyOnline/`

> Bônus Colorimetria do curso Fio a Fio Realista: usar o curso separado `ColorimetriaSobrancelhas/` como referência (mesmo conteúdo).
