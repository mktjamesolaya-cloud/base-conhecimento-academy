# CLAUDE.md — Padrão de Transcrição VTT → Markdown

## Contexto do Projeto

Base de conhecimento em Markdown para a IA **Athena**, gerada a partir de legendas VTT de cursos de micropigmentação da Jay Academy Online (JAO).

O objetivo é que a Athena consulte esses arquivos e responda perguntas com base **exatamente no que o professor disse** — não em resumos ou interpretações minhas.

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
curso: "Nome Exato do Curso"
modulo: "XX — Título do Módulo"
tags: [curso/slug-do-curso, tag1, tag2, tag3]
aulas:
  - nome_arquivo_vtt_sem_extensao
  - outro_arquivo_vtt_sem_extensao
---
```

### Hierarquia de Cabeçalhos

```
# Título do Módulo — Nome do Curso        ← H1: um por arquivo

## Título da Aula                          ← H2: um por VTT de origem
> Aula: nome_arquivo_vtt_sem_extensao     ← referência ao VTT

[conteúdo verbatim da aula]

---                                        ← separador entre aulas

## Próxima Aula
> Aula: proximo_arquivo_vtt
```

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

- **BasicNanoFios VTTs**: `/Users/lucasferreira/Downloads/PROJETOS_DEV/assistente-online/Legendas/BasicNanoFios/`
- **Lips-Sense VTTs**: `/Users/lucasferreira/Downloads/PROJETOS_DEV/assistente-online/Legendas/Lips-Sense/`
- **ColorimetriaLips VTTs**: `/Users/lucasferreira/Downloads/PROJETOS_DEV/assistente-online/Legendas/ColorimetriaLips/`

### Arquivos de saída:

- **BasicNanoFios MDs**: `/Users/lucasferreira/Downloads/PROJETOS_DEV/assistente-online/JayoAcademyOnline/Basic-Nanofios/`
- **Lips-Sense MDs**: `/Users/lucasferreira/Downloads/PROJETOS_DEV/assistente-online/JayoAcademyOnline/Lips-Sense/`
