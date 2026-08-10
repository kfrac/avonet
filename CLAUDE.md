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
- **Error handling:** `rlang::abort()` with condition classes, prefixed `avonet_error_*` (e.g. `avonet_error_unknown_trait`, `avonet_error_not_categorical` in `get_trait_levels()`)
- **Naming pattern:** verb_noun for exported functions (`detect_rank()`, `resolve_taxa()`); any prefix convention for internal-only functions (e.g. `.internal_helper()`)
- **Roxygen tag order / style:** e.g. `@param` → `@return` → `@examples` → `@export`; whether `@family`/`@seealso` are used to cross-link
- **Dependency policy:** e.g. "no readxl — direct Postgres only"; how new deps get added to `DESCRIPTION` `Imports`

## Current state

<!-- Doesn't need to be exhaustive — a rough table is enough to orient a fresh session -->

| Area | Status | Notes |
|---|---|---|
| Core connection functions, i.e. `connect_db()` / `disconnect_db()` / `get_con()` | done | connection functions |
| `detect_rank()` / `resolve_taxa()` / `apply_filters()` | done | helper functions |
| `remove_column_prefixes()` /  `remove_suffix_columns()` / `arrange_metadata()` | done | can these helper functions be refactored or optimized in some way? |
| `sql_query()` | 80% | rename and possible refactor to be more flexible about the tables (and traits) that it queries |
| `query_species_id()` | done | non-user facing so no documentation needed; possibly delete unless useful in another function call |
| `get_traits()` | done | needs to be documented |
| `get_taxonomic_info()` | done | |
| `get_species()` | done | wrapper around `sql_query()` that includes the option for inferred data from species after splits, merges, etc. |
| `get_sources()` | done | not documented because non-user facing function |
| `get_morph_traits()` | done | not documented because non-user facing function, more specific version of `get_traits()` with aggregates, could potentially be refactored or deleted |
| `get_eco_traits()` | done | not documented because non-user facing function, more specific version of `get_traits()` with aggregates, could potentially be refactored or deleted |
| `list_traits()` | done | needs to be refactored because of use of `readxl()` and then documented |
| `get_trait_list()` | done | function body needs to be cleaned up and comments removed |
| `get_trait_groups()` | done | |
| `get_trait_values()` | done | Renamed from `trait_description_query()` |
| `get_metadata()` | done | non-user-facing function |
| `get_trait_levels()` | done | wraps `get_trait_values()`; returns the unique `trait_value`s for a given categorical trait (or a defs tibble via `return_defs = TRUE`); errors on unknown/non-categorical traits |
| `get_filters()` | not started | possible filters for e.g. categorical traits, likely covering the same ground as `get_trait_levels()` but across all traits at once |
| Documentation | ~70% | functions still missing `@examples` include `get_traits()`, `list_traits()` and the filtering functions that still need to be written |
| Tests | not started | please write one example test per function |

Known technical debt / mid-refactor items:
- `list_traits()` still relies on `readxl()` and needs to be refactored
- `sql_query()` is hard-wired with specific tables and could possibly be refactored to be more flexible

## What "done" means for remaining docs

<!-- State your bar once so you don't have to correct it every time -->

- [ ] `@param` for every argument, with type noted
- [ ] `@return` describes structure/type, not just "a data frame"
- [ ] `@examples` are runnable (wrapped in `\dontrun{}` only if they hit the live DB)
- [ ] `@family`/`@seealso` links added where relevant
- [ ] Roxygen `@details` written for external/portfolio readability, not just internal shorthand

## Things not to do

- Don't reintroduce `readxl` or file-based loading — Postgres is the only data path
- Don't use base `paste()`/`sprintf()` for SQL — always `glue_sql()`
- (add more as you notice yourself correcting the same thing twice)

## Portfolio context

This package is being repositioned as a public GitHub portfolio piece for a
data/analytics engineering job search. Where relevant, prioritize documentation
clarity for an external reviewer over internal shorthand — e.g. `@details` sections
can carry a bit more explanatory prose than a purely internal package would need.
