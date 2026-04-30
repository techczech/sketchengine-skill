# Common Sketch Engine task patterns

Once the MCP server is configured, these are the patterns the LLM will route to specific tools. The user can phrase requests naturally; this file is for the LLM's reference and for the user when they want to know what's possible.

## Tool status (smoke-tested 2026-04-29)

The upstream `ricCap/sketch-engine-mcp-server` binary is mid-migration between Sketch Engine's legacy CGI API and its modern REST API. Half the tools work, half are broken at the binary level. Until upstream fixes them, these are the actual capabilities accessible through this skill:

| Tool | Works? | Notes |
|---|---|---|
| `get_corpora` | ✅ | Use first to discover corpus IDs. ~1000 entries; response auto-cached. |
| `get_corpus_info` | ✅ | Rich metadata (size, attributes, structures, subcorpora, limits). |
| `get_word_sketch` | ✅ | Flagship feature. Large responses auto-cached. |
| `get_wordlist` | ✅ | Lemma / word / tag frequency lists. |
| `get_keywords` | ✅ | Contrastive analysis (target vs reference corpus). NB: `wlmaxitems` may be ignored — server returns 100 by default. |
| `get_concordance` | ❌ | `Unknown action`. See `troubleshooting.md`. |
| `get_collocations` | ❌ | `Unknown action`. |
| `get_frequency_distribution` | ❌ | `Unknown action`. |
| `execute_cql_query` | ❌ | `Unknown action`. |
| `get_word_sketch_diff` | not yet tested | Word comparison feature. |

**Avoid `format=txt`** — the binary advertises it but unconditionally JSON-parses the response, which crashes when the API returns text. Use the default `format=json` for all tools.

For broken tools (concordance, collocations, frequency, CQL), there is no workaround inside Claude — fall back to the Sketch Engine web UI for those operations.

## Always start by listing corpora

```
Use Sketch Engine to list the available corpora
```

The names returned are the **API-side identifiers** (e.g. `preloaded/ententen21_en1`). Do not assume the friendly names ("BNC", "COCA") work — they sometimes do, but the canonical lookups use these slugs.

## Concordances — find a word in context ❌ broken upstream

```
Show me 50 concordance lines for "serendipity" in EnTenTen21
Find concordances for "literally" in BNC2014
```

Would return KWIC (key word in context) lines. **Currently fails with `Unknown action`** — the binary calls a retired CGI endpoint. Use the Sketch Engine web UI for concordancing until upstream fixes the binary.

## Word sketches — typical grammatical-collocational patterns

```
Show the word sketch for "literally" in EnTenTen
Word sketch for the verb "negotiate" in COCA
```

Returns the most characteristic grammatical relations (subject of, object of, modified by, etc.) for the lemma. This is the feature Sketch Engine is named after.

## Collocations — words that co-occur ❌ broken upstream

```
Find the top 30 collocates of "climate change" in EnTenTen21
```

Would return ranked collocates with statistics (T-score, MI, logDice). **Currently fails with `Unknown action`.** Use the Sketch Engine web UI. Note: the *Word Sketch* tool (working) gives you a richer, grammatical-relations view of co-occurrence — for many tasks where users say "collocations" they actually want a Word Sketch, which is fine.

## Word lists — frequency lists

```
Generate a frequency list of nouns in the Susanne corpus
Top 100 verbs in BNC by frequency
```

Useful for: frequency dictionaries, vocabulary teaching, baseline distributions for keyword analysis.

## Word comparison — how two near-synonyms differ

```
Compare "begin" and "start" in EnTenTen21
Compare "affect" and "effect" in academic writing
```

Returns the differential collocational profile — what each word collocates with that the other doesn't. Useful for: lexicography, language teaching, contrastive analysis.

## Frequency analysis — how a word's frequency varies ❌ broken upstream

```
Show the frequency of "cancel culture" by year in EnTenTen21
```

Would support diachronic and register-sensitive distributions. **Currently fails with `Unknown action`** — `get_frequency_distribution` hits a retired endpoint. Use the Sketch Engine web UI's "Frequency" tab. As a partial substitute through this skill, you can sometimes infer the same answer from `get_keywords` against a temporally-segmented reference corpus.

## Keyword extraction — what's distinctive about one corpus vs another

```
Extract the top 50 keywords in [target corpus] vs [reference corpus]
```

Returns words over-represented in the target relative to the reference. Useful for: discourse analysis (e.g., how does parliamentary speech differ from journalism?), specialised-language description.

## Custom CQL queries — anything the above doesn't cover ❌ broken upstream

```
Run a CQL query in EnTenTen21: [pos="VV.*"] [pos="RB.*"]+ [pos="V.N"]
```

**Currently fails with `Unknown action`** — `execute_cql_query` hits a retired endpoint. Until upstream fixes this, run CQL via the Sketch Engine web UI. See [`references/cql.md`](cql.md) for syntax to take to the web UI.

## Workflow patterns the LLM should know

### "Sanity-check before quantitative work"

When the user asks a quantitative question ("how often does X mean Y?"), the right first step is usually a small concordance. Numbers without examples mislead — concordance lines anchor the count.

### "Compare-corpora always needs two passes"

Word comparison and keyword extraction return ranked lists with statistics. The user usually wants ~50 results then a focused look at the top 5–10. Don't assume a single 1000-row dump answers the question; it almost never does.

### "CQL is exposable but error-prone"

If the user dictates a CQL query, run it as-is. If the LLM is constructing the CQL, prefer high-level tools (collocates, word sketches) first; fall back to CQL only when the high-level tools don't fit.

### "Subcorpus selection matters"

Sketch Engine corpora can be subcorpus-filtered (by genre, period, source). Most tools accept a `subcorpus` parameter. When the user's question is genre-specific ("how is X used in academic writing?"), pass the relevant subcorpus rather than running on the full corpus.
