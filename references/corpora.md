# Sketch Engine corpora — what to use for what

Sketch Engine hosts >1000 corpora across >90 languages (the exact count visible to your account depends on subscription tier and institutional licence — ~1000 is typical for a default institutional account). This file is a curated map of the ones a working linguist most commonly reaches for, and what each is suitable for.

**Two things to know before relying on any name in this file:**

1. **Always confirm corpus IDs by listing corpora before running queries** — slugs change occasionally and the friendly names below are not always the API identifiers. The actual API identifier looks like `preloaded/bnc2` or `preloaded/ententen21_tt31`, not "BNC" or "EnTenTen21".
2. **Some corpora are subscription-gated.** COCA and Hansard, for instance, are licensed separately from the standard Sketch Engine bundle and may not appear in your `get_corpora` response at all even though they're listed below as "available." If a corpus is missing on your account, that's a licensing question for your institutional admin, not a bug. The British parliamentary corpus that *is* available on a default account is `preloaded/parlamint21_gb` ("British parliamentary debates, ParlaMint 2.1") — substitute as needed.

## English — general-purpose

| Friendly name | Approx. size | What it's for |
|---|---|---|
| **EnTenTen21** / **EnTenTen20** / **EnTenTen18** | tens of billions of words | Modern English from the web. Default choice when the user wants "English" without specifying register. New EnTenTen versions appear every few years; pick the most recent unless a specific year is needed |
| **BNC2014** (written) | 100 million words | Modern British English, balanced across genres. The standard reference corpus for British English; published by Lancaster CASS |
| **Spoken BNC2014** | 11.5 million words | Modern British conversational English. Pair with written BNC2014 for register comparison |
| **BNC** (original) | 100 million words | British English from 1980s–early 1990s. Use when the user explicitly wants this period; otherwise prefer BNC2014 |
| **COCA** | 1 billion words | Contemporary American English, balanced (spoken, fiction, magazines, newspapers, academic). The canonical American counterpart to BNC |
| **NOW** | tens of billions, growing daily | News on the web from 2010 onwards. Use for currency-of-language questions ("when did 'cancel culture' enter English?") |

## English — specialised

| Friendly name | What it's for |
|---|---|
| **Hansard** | British parliamentary speeches 1802–present (~2 billion words). Use for political-discourse work, diachronic British English, formal-spoken register |
| **Susanne** | Treebanked English; small (~130k tokens) but heavily annotated. Use when grammatical structure matters more than corpus size |
| **OEC** (Oxford English Corpus) | 2 billion+ words; broad coverage; historically the corpus behind Oxford dictionaries |
| **MICASE** | Michigan Corpus of Academic Spoken English. Use for academic-spoken register questions |
| **BAWE** | British Academic Written English — student writing across disciplines and levels |

## Other languages and parallel corpora

Sketch Engine hosts substantial corpora in dozens of languages:

- **Czech**: csTenTen, SYN (Czech National Corpus subsets)
- **German**: deTenTen, DeReKo subsets
- **French**: frTenTen, Frantext-like corpora
- **Spanish**: esTenTen, EsEn parallel
- **Polish, Russian, Portuguese, Italian, Dutch, Swedish, Norwegian, Danish, Finnish, etc.** — TenTen-style web corpora exist for all major European languages

Parallel corpora are accessible via Sketch Engine's UI but **not specifically exposed by the MCP server's documented tool surface**. For ParaConc-style work, the MCP wrapper is the wrong path — use the web UI or the `corpus-tools-skill` for OPUS-based local work.

## Sub-corpora (within a single corpus)

Most large Sketch Engine corpora are split into subcorpora by genre, source, or period. The user can pass a subcorpus parameter to most tools to restrict the analysis. Examples:

- **EnTenTen21**: subcorpora by website type (news, blog, forum) and country domain
- **BNC2014**: subcorpora by genre (fiction, news, academic, e-language)
- **Hansard**: subcorpora by decade and by chamber
- **COCA**: subcorpora by genre (academic, fiction, magazine, newspaper, spoken)

Always start with the full corpus to confirm the question makes sense at scale, *then* narrow to a subcorpus if a register-specific or period-specific finding is needed.

## Choosing the right corpus — quick decision rules

- **Modern general English, no preference** → EnTenTen21
- **British English, balanced** → BNC2014 (written), Spoken BNC2014 (conversation)
- **American English, balanced** → COCA
- **Diachronic English** → COHA (American historical, ~1820–2019), Hansard (British parliamentary), CLMET (literary 1710–1920)
- **Academic English** → BAWE (student writing), MICASE (spoken), or COCA's academic subcorpus
- **News currency** → NOW
- **Treebank work** → Susanne
- **Languages other than English** → corresponding TenTen corpus is the default

## When the corpus the user wants isn't on Sketch Engine

Two paths:

1. Upload custom corpora through the Sketch Engine web UI (not the MCP). The user pays in storage and processing per their subscription
2. Use `corpus-tools-skill` to build and query a local corpus with NLTK / spaCy / CWB. No subscription, full control, no quota
