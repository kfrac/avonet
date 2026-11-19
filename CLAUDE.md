# CLAUDE.md

Context for Claude when working on this package. Keep this file current — update it
whenever a convention changes or a milestone is hit, rather than letting it drift.

## Project overview

<!-- 3-5 sentences. What does the package do, who uses it, what's the one
     architectural decision that shapes everything else? -->

- Package name: avonet
- Purpose: The R package avonet allows users to query the Postgres database of bird traits directly in their R session, making data exploration and analysis in R much easier. The Avonet database combines specimen-level measurement data of birds together with species-level classifications of ecological, geographical, reproductive and social data to create a comprehensive database of bird traits.
- Key architectural decision: Functions in the package query Postgres directly via DBI/glue_sql instead of loading data from flat files — all functions assume a live connection.

## Environment & setup

- DB connection: User credentials are supplied via the R package `keyring`. Right now there is only a production DB, but a test DB with the next version of the database is envisioned and in the pipeline.
- Load package for dev: `devtools::load_all()`
- Run checks: `devtools::check()`
- Regenerate docs: `devtools::document()`
- Run tests: `devtools::test()` / `testthat::test_file(...)`
- Any DB fixtures or seed data needed before tests will pass

> Note for Claude: I can't execute R/DBI code directly against your database in this
> chat. When we're debugging something that needs a live run, tell me the exact
> command to run and paste back the output (or error) rather than me guessing at
> results.

## Conventions actually in use

<!-- The highest-leverage section. Be concrete, point to real files. -->

- **Connection management:** `set_con()` / `get_con()` / `close_con()` — see `R/connect.R`
- **SQL construction:** always `glue_sql()`, never `paste()`/`sprintf()` for queries
- **NSE / R CMD check compliance:** `.data$` pronouns inside dplyr verbiage — see `R/resolve_taxa.R`
- **Error handling:** `rlang::abort()` with condition classes, prefixed `avonet_error_*` (e.g. `avonet_error_unknown_trait`, `avonet_error_not_categorical` in `get_trait_levels()`, `avonet_error_not_implemented` in `get_species()`, and five in `apply_filters()`: `avonet_error_unknown_filter`, `avonet_error_taxonomic_filter`, `avonet_error_ambiguous_filter`, `avonet_error_invalid_filter`, `avonet_error_invalid_operator`; `avonet_error_unknown_group` in `get_trait_list()`; `avonet_error_invalid_aggregate` in `validate_aggregate()` and `avonet_error_invalid_taxonomy` in `get_morph_traits()`). Prefer `rlang::abort()` over base `stop()` for anything a user can trigger
- **Naming pattern:** `verb_noun` for every function, whether exported or not. Internal functions get no special marking — no leading dots, no prefixes. A function is internal purely because it has no `@export` tag, so it never reaches `NAMESPACE` and can only be called as `avonet:::fn()`. Leading dots are reserved for *argument* names, where they stop a user's own column called `con` or `data` from clashing with ours (`.con` in `glue_sql()`, `.data` in dplyr verbs)
- **Non-user-facing functions:** no `@export` tag (so they're absent from `NAMESPACE`, callable only via `avonet:::fn()`). Package helper functions with real internal complexity worth documenting for a portfolio reviewer (`get_metadata()`, `query_species_traits()`, `list_traits()`, and all six documented helpers in `helper_functions.R`) keep their full roxygen block plus `@keywords internal`, which generates a hidden `.Rd` reachable via `?fn` but absent from the package index; trivial ones (`get_sources()`, `get_morph_traits()`) have no roxygen block at all
- **Roxygen tag order / style:** title → description → `@details` → `@param` → `@return` → `@export` (or `@keywords internal`) → `@seealso` → `@examples`. `@seealso` is used for cross-linking (e.g. `connect_db()`/`disconnect_db()`, `get_traits()` → `get_trait_list()`/`get_trait_levels()`); `@family` is not currently used. Every `@examples` block is wrapped in `\dontrun{}` — see below
- **Postgres enums:** enum columns arrive from `RPostgres` with an extra `pq_*` S3 class over the underlying vector. Any query result that reaches a user passes through `convert_enum_columns()` (`helper_functions.R`) so they become plain factors — currently `query_species_traits()`, `get_morph_traits()` and `get_sources()`. Results that are only summarized to strings (`list_traits()`) or whose enum columns are dropped before returning (`get_metadata()`, `get_taxonomic_info()`) deliberately skip it. `get_trait_values()` skips it because `trait_info_detailed` has no enum columns at all (verified 2026-11-19, all seven are `character`) — worth re-checking if that table ever gains one, since three callers join or `unique()` on its columns and would shift behaviour if they became factors
- **Dependency policy:** e.g. "no readxl — direct Postgres only"; how new deps get added to `DESCRIPTION` `Imports`

## Current state

<!-- Doesn't need to be exhaustive — a rough table is enough to orient a fresh session -->

| Area | Status | Notes |
|---|---|---|
| Core connection functions, i.e. `connect_db()` / `disconnect_db()` / `get_con()` | done | connection functions |
| `detect_rank()` / `resolve_taxa()` / `apply_filters()` | done | Helper functions, now carrying full `@keywords internal` roxygen converted from their `# ---` header comments. `apply_filters()` no longer keeps a hardcoded list of 33 filterable columns — it derives them from `names(data)`, minus taxonomic and `_id`/`_src`/`_source` columns, so the list cannot drift from what `query_species_traits()` selects. All five error paths now use classed `rlang::abort()` calls. Its `@details` is the canonical description of the filter syntax that `get_traits()` re-states for users |
| `remove_column_prefixes()` /  `remove_suffix_columns()` / `arrange_metadata()` | done | `remove_column_prefixes()` and `remove_suffix_columns()` are now called through `tidy_species_columns()`, which owns the species-level column clean-up (prefix stripping, `name` → `species`, dropping `_src`/`_source` and `species_id`) for both `get_species()` and `get_traits()` so the two cannot drift. `arrange_metadata()`, `remove_column_prefixes()` and `remove_suffix_columns()` are the only functions in `helper_functions.R` left with plain inline comments rather than roxygen — deliberately, as they are small enough to read at a glance, though `arrange_metadata()` is borderline. It is still a refactor candidate |
| `query_species_traits()` | done | Renamed from `sql_query()` and unexported (`query_*` is now the raw-SQL layer; `get_species()`/`get_traits()` are the public face). Args renamed `parameter1`/`parameter2` → `species`/`taxonomy`, SQL composed with `glue_sql()` instead of `paste()`, full `@keywords internal` roxygen block. Values are still bound via `DBI::dbBind()`, so a whole species vector is fetched in one batched call. Only matches `species_name`; rank support is deferred — see "Deferred: rank support" below. Converts Postgres enum columns (extra `pq_*` S3 class) to factors before returning, now through the shared `convert_enum_columns()` in `helper_functions.R` that `get_morph_traits()` also calls |
| `get_traits()` | done | gained `resolution = c("species", "specimen")` and `aggregate`; `resolution = "specimen"` adds a fourth `specimen_data` element (via `get_morph_traits()`) while `data` stays one row per species, and warns about species with no specimen records. Now documented and exported, with `@details` covering the filter syntax and the species-vs-specimen split. Its missing-species warning (step 2b) is dead code — see "Deferred: rank support" below. `aggregate` is now validated by `validate_aggregate()` before the species-level query runs, instead of after every specimen row had been fetched, and supplying it with `resolution = "species"` warns rather than being silently ignored. |
| `get_taxonomic_info()` | done | now accepts a vector of 2+ search terms (must all be the same kind: all species binomials, or all genus/family/order); warns on unmatched terms, keeps duplicate rows when multiple terms match the same species |
| `get_species()` | done | Thin exported wrapper around `query_species_traits()`. Args renamed `x`/`y` → `species`/`taxonomy` to match `get_traits()`; only exact species binomials, no rank resolution (that is `get_traits()`). `inferred = TRUE` (traits for species created by splits/merges) is still unimplemented, but now raises `avonet_error_not_implemented` instead of `print()`ing a message and returning `NULL`. Returns the same 17 columns as `get_traits()$data` via the shared `tidy_species_columns()` helper, and now takes the same `source_cols` argument (placed third, mirroring `get_traits()`) to keep the `_src`/`_source` columns inline (26 columns, `id` included). Does not resolve family/order, which is the main open usability gap — see "Deferred: rank support" below. Fully documented |
| `get_sources()` | done | not documented because non-user facing function. Now passes its result through the shared `convert_enum_columns()`: `detailed_sources` was still handing users `pq_trait_source_types` and `pq_literature_types` columns after the specimen-level fix landed |
| `get_morph_traits()` | done | not documented because non-user facing function. No longer a deletion candidate — it now backs `get_traits(resolution = "specimen")`. Column selection was rewritten from hardcoded positional slices (`[1:7]`, `[23:27]`) to name-based, which fixed three latent bugs: `life_stage` and `species_id` were silently dropped, and `secondary_1` was duplicated. Aggregates group by species, so multi-species calls no longer pool measurements, and the five near-identical aggregate branches collapsed into one driven by the shared `morph_aggregate_columns()` lookup. Rewritten 2026-11-19 from per-species `dbBind()` parameter sets to a single set-based `glue_sql()` query that joins `morph_trait_detailed` → `source_specimen_species` → `species`: one execution for the whole vector instead of one per species (~250 for Accipitridae, ~6,500 for Passeriformes), and each row now carries the species it is actually linked to. The old query filtered on `source_id IN (sources linked to species X)` and then stamped every returned row with X via a scalar subquery, so it was only correct while each `source_id` maps to exactly one species — an assumption that turns out to hold, but only because every query filters `species_tax` — see "Verified: specimen source cardinality" below. Verified against production 2026-11-19: output identical to the old code for `Buteo buteo`, correct per-species labels for a three-species call, and `get_traits("Accipitridae", 1, resolution = "specimen")` returning 1,452 rows for 248 of 250 species in ~4.2 s. Enum columns are now unwrapped to factors through the shared `convert_enum_columns()`, as `query_species_traits()` already did, so `specimen_data` and `data` behave the same way downstream |
| `list_traits()` | done | refactored off `readxl()`; primary_source is now derived from `_src`/`_source` columns (mode across observations, ties kept) for most tables, hardcoded to "Tobias et al. (2022)" for `morph_trait_specimen`/`mass_value`; now fully documented with a `@keywords internal` roxygen block: the old header comment was converted into `@details` covering the two `primary_source` derivations, the data-derived `value` summaries, and the `NA`/"AVOTRAITS" row filtering |
| `get_trait_list()` | done | Body cleaned up: the commented-out dead code and the inline `trait_groups_dict` are gone, replaced by the shared `trait_group_tables()` lookup. Unknown group names now raise `avonet_error_unknown_group` instead of silently returning an empty tibble, and validation happens before any query. Naming one group now reads one table instead of all four. Roxygen corrected — it previously omitted `"social"` from the valid groups |
| `get_trait_groups()` | done | Now returns `names(trait_group_tables())`, the internal mapping of group name to database table that `get_trait_list()` also reads. Having one source of truth is what stops the two drifting, which is how `"social"` went missing from the `get_trait_list()` docs |
| `get_trait_values()` | done | Renamed from `trait_description_query()` |
| `get_metadata()` | done | non-user-facing function |
| `get_trait_levels()` | done | wraps `get_trait_values()`; returns the unique values of `trait` for a given categorical trait (or a defs tibble via `return_defs = TRUE`); errors on unknown/non-categorical traits |
| `get_filters()` | deferred | Deliberately not built. The original idea — list categorical levels across all traits — duplicates `get_trait_list()`, whose `value` column already holds exactly that, and `get_trait_levels()` for one trait in detail. The real gap it was reaching for was `apply_filters()` offering columns that were never queried, which is now fixed at the source instead. If it is ever built it should be a filter *contract* (short name, full column, type, levels or numeric range) that `apply_filters()` itself consumes, not a fourth list to keep in sync. Revisit only after deciding whether `query_species_traits()` will join the social/reproduction tables |
| Documentation | done | `get_traits()`, `get_species()` and `query_species_traits()` all now carry full roxygen blocks meeting the "done" checklist below. Every `@examples` block in the package is wrapped in `\dontrun{}`, so `check()` no longer runs examples against the live DB — they previously only passed on a machine with a local `avonet` Postgres. `list_traits()` is now documented too (internal, so it generates a hidden `.Rd`). With `get_filters()` deferred, every function in the package is now documented |
| Tests | deferred | Deliberately deferred (2026-08-22). Still nothing written: no `tests/`, no testthat scaffolding, no `Suggests: testthat`. Goal when picked up is still one example test per function — see "Deferred: test suite" below |

Removed 2026-08-22: `query_species_id()` and `get_eco_traits()`. Neither had a
single caller anywhere in `R/`, and both had been flagged as deletion
candidates since this file was written. `get_eco_traits()` was a narrower
`get_traits()` with aggregates, superseded by `get_traits(filter = ...)`;
`query_species_id()` was superseded by `resolve_taxa()`. Both are recoverable
from git history if a use ever turns up. No calls to either remain anywhere in
the repo.

Known technical debt / mid-refactor items:
- `query_species_traits()` still hard-codes its four tables and column list. A `tables`/`columns` argument was considered and deliberately deferred. The original reason for deferring — that `get_traits()` assumes all three trait tables in its missing-species warning — no longer holds, since that warning turns out to be dead code (see below); revisit the deferral on that basis

### Verified: specimen source cardinality (2026-11-19)

`get_morph_traits()` reaches specimens by joining
`morph_trait_detailed.source_id` through `source_specimen_species` to
`species`. How many species one `source_id` maps to decides whether the
rewrite is equivalent to the old per-species query. Checked against
production:

```
sources  max_species_per_source  shared_sources
  90019                       3           89838
```

Read naively this says almost every source is shared, which would mean the old
code was mislabelling specimens. It is a **taxonomy artefact**: `species` holds
one row per (name, `species_tax`), so a single source maps to up to three
`species_id` values -- the same bird under BirdLife, eBird and BirdTree. Hence
the maximum of exactly 3. Every query in the package filters `sp.species_tax`,
so the join picks one of the three and no duplication occurs.

The evidence that this is the right reading: old and new `get_morph_traits()`
return identical output for `Buteo buteo` (19 x 23, same rows after sorting),
and a three-species call returns 19 / 18 / 8 rows with no `NA` species label.
If sources were genuinely shared *within* a taxonomy, the new join would
duplicate rows and the two would diverge.

Confirmed within a single taxonomy, which is the only way the package ever
queries: 89,682 sources, `max_species_per_source` = 1, 0 shared.

```sql
SELECT COUNT(*) AS sources, MAX(n) AS max_species_per_source,
       SUM(CASE WHEN n > 1 THEN 1 ELSE 0 END) AS shared_sources
FROM (SELECT sss.source_id, COUNT(DISTINCT sss.species_id) AS n
      FROM source_specimen_species AS sss
      JOIN species AS sp ON sp.species_id = sss.species_id
      WHERE sp.species_tax = 1
      GROUP BY sss.source_id) t;
```

The join is therefore 1:1 by construction, and keying specimens on `source_id`
is safe. Re-run the query above against any new database version before
trusting this: if it ever returns more than 1, a specimen from a multi-species
source will appear once per linked species and `get_morph_traits()` will need
to key on specimen identity instead.

### Deferred: rank support in `query_species_traits()` (decide later)

Right now `query_species_traits()` only matches `species_name`. Family and order
already work, but only through `get_traits()`, which calls `resolve_taxa()` to
expand any rank into a species vector first. `get_species()` never calls
`resolve_taxa()`, so `get_species("Accipitridae", 1)` returns zero rows — that
is the user-visible gap.

The stronger argument for change is cost, not API surface: `dbBind()` executes
the statement once per species, so an order like Passeriformes runs ~6,500
executions where `WHERE sp.species_order = 'Passeriformes'` would be one.
`package_demo.R` already prototypes a hand-written `IN (...)` version worth
benchmarking against the current path.

**Verified facts** (from `get_traits("Accipitridae", 1)`, 250 species):

- The missing-species warning in `get_traits()` is **dead code**. With LEFT
  joins, any species in `species` returns a row (NAs in the trait columns), and
  `resolve_taxa()` draws names from that same table with the same
  `species_tax` filter — so `missing_species` can never be non-empty. 250
  resolved species returned 250 rows and no warning.
- Its message is also wrong about the cause: the per-table detail queries use
  INNER joins, so a species genuinely absent from `species` would be reported
  as missing from all three trait tables.
- The LEFT joins are 1:1 — 250 species gave exactly 250 rows, so no species has
  multiple `mass_species` / `geo_data_species` rows. A rank-aware `WHERE`
  depends on this.
- `dbBind()` does accumulate results across parameter sets; the batched fetch
  works as documented.

**Suggested order when this is picked up:**

1. Delete the dead warning (`get_traits.R`, step 2b) and replace it with an
   all-`NA` check across the `ect_*` / `mass_*` / `spd_*` columns. That is the
   condition the warning was actually reaching for, it is reachable, and it
   costs no extra queries — the current version fires three `LIMIT 1` queries
   per missing species that never run.
2. Add a `rank` argument to `query_species_traits()` so the `WHERE` filters on
   `species_name` / `species_family` / `species_order` directly (genus via
   `LIKE 'X %'`, mirroring `resolve_taxa()`), and let `get_species()` pass it
   through. This was the recommended starting point: contained, fixes the
   `get_species()` gap, and leaves `get_traits()` untouched.
3. Only then decide whether `get_traits()` should switch over. Two things it
   currently gets for free from `resolve_taxa()` would need rebuilding: mixed
   rank calls such as `c("Buteo", "Falco peregrinus", "Accipitridae")`, which
   one `WHERE` cannot express without OR-groups or a query per name; and
   deduplication of overlapping taxa (`c("Buteo", "Accipitridae")`), currently
   handled by `unique()`. A middle path keeps `resolve_taxa()` as a cheap
   "expected species" lookup while the heavy fetch goes rank-aware.

`detect_rank()` is unaffected either way — auto-detection still costs up to
three `LIMIT 1` queries per name.

Note there are still no tests, so any `get_traits()` rewrite has no safety net
and a regression would surface as a silently wrong row count rather than an
error. Worth writing tests for `get_traits()` before step 3.

### Deferred: test suite (decide later)

Deferred on 2026-08-22. Nothing is written yet — no `tests/` directory, no
testthat scaffolding, no `Suggests: testthat` in DESCRIPTION. The goal remains
one example test per function.

**Decide first: how to handle the connection.** Either mock the DBI connection,
or gate DB-touching tests behind a `skip_if_not()` on a reachable database. That
choice shapes everything else, so make it before writing the first test.

**A good share of the package needs no database at all.** Recent refactors
pushed logic out of the SQL, so these are all testable against plain data frames
or fail before any query is issued:

- `tidy_species_columns()` — 17 columns out, 26 with `source_cols = TRUE`
- `apply_filters()` — all five error classes, plus the short-name and
  `mass_value` resolution
- `summarize_trait_value()` — `"numeric"`, sorted levels, `NA` sorting last
- `derive_source_map()` — the shared-leftover fallback and
  `avonet_error_unresolved_source`
- `get_trait_list()` — `avonet_error_unknown_group`, which is raised before any
  query
- `get_species()` — `avonet_error_not_implemented` for `inferred = TRUE`
- `validate_aggregate()` — `avonet_error_invalid_aggregate`, raised before any
  query and with no connection needed at all
- `detect_rank()` — the single-word vs binomial branch, if the connection is
  mocked

**Why this matters more than it looks.** Every `@examples` block is wrapped in
`\dontrun{}`, so `R CMD check` has never executed one against the database —
they are syntax-checked only. The knitted README is currently the only
end-to-end proof the package works against real data, and nothing runs it
automatically. Until tests exist, a regression in query or column-handling code
surfaces as a silently wrong row count rather than an error.

Relevant to the rank-support decision above: step 3 there rewrites the control
flow of `get_traits()`, the main entry point, with no safety net. Tests for
`get_traits()` should come before that.

## What "done" means for remaining docs

<!-- State your bar once so you don't have to correct it every time -->

- [ ] `@param` for every argument, with type noted
- [ ] `@return` describes structure/type, not just "a data frame"
- [ ] `@examples` are always wrapped in `\dontrun{}`
- [ ] `@family`/`@seealso` links added where relevant
- [ ] Roxygen `@details` written for external/portfolio readability, not just internal shorthand

## Things not to do

- Don't reintroduce `readxl` or file-based loading — Postgres is the only data path
- Don't use base `paste()`/`sprintf()` for SQL — always `glue_sql()`
- Don't leave scratch scripts at the package root without a matching `.Rbuildignore` entry — `package_demo.R` is ignored there now (`playground.R` was deleted 2026-08-22), but R CMD check flags any new one as a non-standard top-level file
- Don't put a leading dot on a new internal function name. Leaving off `@export` is what makes it internal; a dot only hides the name from `ls()` and buys nothing else
- (add more as you notice yourself correcting the same thing twice)

## Portfolio context

This package is being repositioned as a public GitHub portfolio piece for a
data/analytics engineering job search. Where relevant, prioritize documentation
clarity for an external reviewer over internal shorthand — e.g. `@details` sections
can carry a bit more explanatory prose than a purely internal package would need.
