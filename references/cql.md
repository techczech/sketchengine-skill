# CQL — Corpus Query Language cheatsheet for Sketch Engine

CQL is the query language inherited from the IMS Open Corpus Workbench (CWB) and used in Sketch Engine, NoSketch Engine, KonText, and #LancsBox X. The syntax below is the Sketch Engine dialect — minor variants exist across implementations.

## Token-level patterns

A token in CQL is `[attribute="value"]`. The minimum useful attributes:

```
[word="literally"]                 # exact word form
[lemma="run"]                      # lemma (covers run/runs/ran/running)
[lc="literally"]                   # lowercased word form
[tag="V.N"]                        # POS tag (Penn-Treebank-ish in English Sketch Engine)
[pos="VERB"]                       # universal POS (where supported)
```

Boolean combinators use `&` (and), `|` (or), `!` (not):

```
[lemma="run" & tag="V.*"]          # the verb run, not the noun
[lemma="run" & !tag="VVN"]         # run-verb but not past participle
```

Regex on the value (PCRE-ish) — quote a regex like a string:

```
[word=".*ization"]                 # words ending in -ization
[lemma="walk|run|jog"]             # any of three lemmas
```

## Sequences

Tokens are juxtaposed; whitespace separates them.

```
[lemma="break"] [word="the"] [lemma="ice"]      # break the ice (and inflections)
```

## Quantifiers

Repetition follows the token in `{m,n}` form:

```
[lemma="be"] [tag="RB.*"]{0,3} [tag="V.N"]      # passive with up to 3 adverbs
[lemma="not"] []{1,5} [lemma="ever"]            # not ... ever, up to 5 tokens between
```

Common shortcuts:

```
[]                  # any one token
[]+                 # one or more tokens
[]*                 # zero or more
[]?                 # zero or one
```

## Anchoring within structure

Sketch Engine corpora have structural attributes (`<s>` sentence, `<p>` paragraph, `<doc>`, etc.). Use `within` for boundary scope and `<element/>` for element start:

```
"<s>" [lemma="however"]                          # sentence-initial however
[lemma="however"] within <s/>                    # however anywhere in a sentence
```

## Common worked patterns

### Active vs passive verbs

```
# Active: subject + lexical verb (no auxiliary be)
[tag="N.*"] [lemma!="be" & tag="V.*"]

# Passive: be + past participle
[lemma="be"] [tag="RB.*"]{0,3} [tag="V.N"]
```

### N-grams of a particular shape

```
[tag="JJ"] [tag="JJ"] [tag="N.*"]                # adj adj noun (e.g. "big red ball")
[tag="N.*"] [lemma="of"] [tag="N.*"]             # N of N (e.g. "loss of life")
```

### Discourse markers in initial position

```
"<s>" [lemma="however|therefore|moreover|furthermore"]
```

### Modal-perfect constructions

```
[lemma="can|could|may|might|must|should|will|would"] [lemma="have"] [tag="V.N"]
```

### Bracket-and-coordination patterns

```
[lemma="research|study|investigation"] [lemma="and"] [lemma="research|study|investigation"]
```

## Output controls

In Sketch Engine, the API call provides separate parameters for context width, sort order, and output format. CQL only describes *what to match*; format is configured around it.

Common configuration paired with a CQL query:

- **Context width**: ±5 tokens default; widen to ±20 for discourse work
- **Sort by**: left context, right context, frequency
- **Subcorpus**: filter to genre / period / source
- **Negative filter**: exclude lines matching another CQL query

## Tag/POS dialects — important quirk

The POS tagset varies per corpus. EnTenTen and BNC use Penn-Treebank-ish tags (`NN`, `VBD`, `JJ`, etc.). Some Sketch Engine corpora use the universal POS set (`NOUN`, `VERB`, `ADJ`). When unsure, run a small probe:

```
"[anyword]" within <s/>
```

Then look at the returned attributes to see what tagset is in play.

## Useful Sketch Engine CQL extras

- `meet([lemma="X"], [lemma="Y"], -5, 5)` — proximity in either direction within ±5
- Capturing groups in some corpora support targeted output of specific positions

## When CQL is the wrong tool

- Word sketches and word comparison have dedicated APIs that do better than hand-rolled CQL
- Keyword extraction is a corpus-level computation, not a CQL match
- Concordance summaries ("how often is X used in irony?") are interpretive — the user (or Claude) reads concordance lines; CQL just retrieves them

## Reference

- Sketch Engine CQL guide: https://www.sketchengine.eu/documentation/corpus-querying/
- IMS CWB CQP manual (the spec CQL inherits from): https://cwb.sourceforge.io/files/CQP_Manual/
