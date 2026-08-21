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
- **Error handling:** `rlang::abort()` with condition classes, prefixed `avonet_error_*` (e.g. `avonet_error_unknown_trait`, `avonet_error_not_categorical` in `get_trait_levels()`, `avonet_error_not_implemented` in `get_species()`)
- **Naming pattern:** verb_noun for exported functions (`detect_rank()`, `resolve_taxa()`); any prefix convention for internal-only functions (e.g. `.internal_helper()`)
- **Non-user-facing functions:** no `@export` tag (so they're absent from `NAMESPACE`, callable only via `avonet:::fn()`). Package helper functions with real internal complexity worth documenting for a portfolio reviewer (e.g. `get_metadata()`) keep their full roxygen block plus `@keywords internal`; trivial ones (`get_sources()`, `get_morph_traits()`, `get_eco_traits()`, `query_species_id()`) have no roxygen block at all
- **Roxygen tag order / style:** title → description → `@details` → `@param` → `@return` → `@export` (or `@keywords internal`) → `@seealso` → `@examples`. `@seealso` is used for cross-linking (e.g. `connect_db()`/`disconnect_db()`, `get_traits()` → `get_trait_list()`/`get_trait_levels()`); `@family` is not currently used. Every `@examples` block is wrapped in `\dontrun{}` — see below
- **Dependency policy:** e.g. "no readxl — direct Postgres only"; how new deps get added to `DESCRIPTION` `Imports`

## Current state

<!-- Doesn't need to be exhaustive — a rough table is enough to orient a fresh session -->

| Area | Status | Notes |
|---|---|---|
| Core connection functions, i.e. `connect_db()` / `disconnect_db()` / `get_con()` | done | connection functions |
| `detect_rank()` / `resolve_taxa()` / `apply_filters()` | done | helper functions |
| `remove_column_prefixes()` /  `remove_suffix_columns()` / `arrange_metadata()` | done | `remove_column_prefixes()` and `remove_suffix_columns()` are now called through `.tidy_species_columns()`, which owns the species-level column clean-up (prefix stripping, `name` → `species`, dropping `_src`/`_source` and `species_id`) for both `get_species()` and `get_traits()` so the two cannot drift. `arrange_metadata()` is still a refactor candidate |
| `query_species_traits()` | done | Renamed from `sql_query()` and unexported (`query_*` is now the raw-SQL layer, matching `query_species_id()`; `get_species()`/`get_traits()` are the public face). Args renamed `parameter1`/`parameter2` → `species`/`taxonomy`, SQL composed with `glue_sql()` instead of `paste()`, full `@keywords internal` roxygen block. Values are still bound via `DBI::dbBind()`, so a whole species vector is fetched in one batched call. Converts Postgres enum columns (extra `pq_*` S3 class) to factors before returning |
| `query_species_id()` | done | non-user facing so no documentation needed; possibly delete unless useful in another function call |
| `get_traits()` | done | gained `resolution = c("species", "specimen")` and `aggregate`; `resolution = "specimen"` adds a fourth `specimen_data` element (via `get_morph_traits()`) while `data` stays one row per species, and warns about species with no specimen records. Now documented and exported, with `@details` covering the filter syntax and the species-vs-specimen split |
| `get_taxonomic_info()` | done | now accepts a vector of 2+ search terms (must all be the same kind: all species binomials, or all genus/family/order); warns on unmatched terms, keeps duplicate rows when multiple terms match the same species |
| `get_species()` | done | Thin exported wrapper around `query_species_traits()`. Args renamed `x`/`y` → `species`/`taxonomy` to match `get_traits()`; only exact species binomials, no rank resolution (that is `get_traits()`). `inferred = TRUE` (traits for species created by splits/merges) is still unimplemented, but now raises `avonet_error_not_implemented` instead of `print()`ing a message and returning `NULL`. Returns the same 17 columns as `get_traits()$data` via the shared `.tidy_species_columns()` helper, and now takes the same `source_cols` argument (placed third, mirroring `get_traits()`) to keep the `_src`/`_source` columns inline (26 columns, `id` included). Fully documented |
| `get_sources()` | done | not documented because non-user facing function |
| `get_morph_traits()` | done | not documented because non-user facing function. No longer a deletion candidate — it now backs `get_traits(resolution = "specimen")`. Column selection was rewritten from hardcoded positional slices (`[1:7]`, `[23:27]`) to name-based, which fixed three latent bugs: `life_stage` and `species_id` were silently dropped, and `secondary_1` was duplicated. Species names now come from a `species_id` lookup instead of `cbind()`, which mislabelled rows for 2+ species; aggregates group by species so multi-species calls no longer pool measurements |
| `get_eco_traits()` | done | not documented because non-user facing function, more specific version of `get_traits()` with aggregates, could potentially be refactored or deleted |
| `list_traits()` | done | refactored off `readxl()`; primary_source is now derived from `_src`/`_source` columns (mode across observations, ties kept) for most tables, hardcoded to "Tobias et al. (2022)" for `morph_trait_specimen`/`mass_value`; now fully documented with a `@keywords internal` roxygen block: the old header comment was converted into `@details` covering the two `primary_source` derivations, the data-derived `value` summaries, and the `NA`/"AVOTRAITS" row filtering |
| `get_trait_list()` | done | function body needs to be cleaned up and comments removed |
| `get_trait_groups()` | done | |
| `get_trait_values()` | done | Renamed from `trait_description_query()` |
| `get_metadata()` | done | non-user-facing function |
| `get_trait_levels()` | done | wraps `get_trait_values()`; returns the unique values of `trait` for a given categorical trait (or a defs tibble via `return_defs = TRUE`); errors on unknown/non-categorical traits |
| `get_filters()` | not started | possible filters for e.g. categorical traits, likely covering the same ground as `get_trait_levels()` but across all traits at once |
| Documentation | ~95% | `get_traits()`, `get_species()` and `query_species_traits()` all now carry full roxygen blocks meeting the "done" checklist below. Every `@examples` block in the package is wrapped in `\dontrun{}`, so `check()` no longer runs examples against the live DB — they previously only passed on a machine with a local `avonet` Postgres. `list_traits()` is now documented too (internal, so it generates a hidden `.Rd`). The only gap left is `get_filters()`, once written |
| Tests | not started | please write one example test per function |

Known technical debt / mid-refactor items:
- `query_species_traits()` still hard-codes its four tables and column list. A `tables`/`columns` argument was considered and deliberately deferred: `get_traits()` assumes all three trait tables are present in its missing-species warning logic, so that has to be reworked in the same pass

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
- Don't leave scratch scripts at the package root without a matching `.Rbuildignore` entry — `playground.R` and `package_demo.R` are ignored there now, but R CMD check flags any new one as a non-standard top-level file
- (add more as you notice yourself correcting the same thing twice)

## Portfolio context

This package is being repositioned as a public GitHub portfolio piece for a
data/analytics engineering job search. Where relevant, prioritize documentation
clarity for an external reviewer over internal shorthand — e.g. `@details` sections
can carry a bit more explanatory prose than a purely internal package would need.
