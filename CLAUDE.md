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
- **Error handling:** `rlang::abort()` with condition classes, prefixed `avonet_error_*` (e.g. `avonet_error_unknown_trait`, `avonet_error_not_categorical` in `get_trait_levels()`, `avonet_error_not_implemented` in `get_traits()`, and five in `apply_filters()`: `avonet_error_unknown_filter`, `avonet_error_taxonomic_filter`, `avonet_error_ambiguous_filter`, `avonet_error_invalid_filter`, `avonet_error_invalid_operator`; `avonet_error_unknown_group` in `get_trait_list()`; `avonet_error_specimen_filter_resolution` in `get_traits()`; `avonet_error_invalid_aggregate` in `validate_aggregate()` and `avonet_error_invalid_taxonomy` in `get_morph_traits()`). Prefer `rlang::abort()` over base `stop()` for anything a user can trigger
- **Naming pattern:** `verb_noun` for every function, whether exported or not. Internal functions get no special marking — no leading dots, no prefixes. A function is internal purely because it has no `@export` tag, so it never reaches `NAMESPACE` and can only be called as `avonet:::fn()`. Leading dots are reserved for *argument* names, where they stop a user's own column called `con` or `data` from clashing with ours (`.con` in `glue_sql()`, `.data` in dplyr verbs)
- **Non-user-facing functions:** no `@export` tag (so they're absent from `NAMESPACE`, callable only via `avonet:::fn()`). Package helper functions with real internal complexity worth documenting for a portfolio reviewer (`get_metadata()`, `query_species_traits()`, `query_trait_values()`, `list_traits()`, and all six documented helpers in `helper_functions.R`) keep their full roxygen block plus `@keywords internal`, which generates a hidden `.Rd` reachable via `?fn` but absent from the package index; trivial ones (`get_sources()`, `get_morph_traits()`) have no roxygen block at all
- **Roxygen tag order / style:** title → description → `@details` → `@param` → `@return` → `@export` (or `@keywords internal`) → `@seealso` → `@examples`. `@seealso` is used for cross-linking (e.g. `connect_db()`/`disconnect_db()`, `get_traits()` → `get_trait_list()`/`get_trait_levels()`); `@family` is not currently used. Every `@examples` block is wrapped in `\dontrun{}` — see below
- **One decision about where data comes from:** no function calls `get_con()` to fetch data directly any more. Whole-table reads go through `db_table()`, and the two joined queries plus the taxonomic lookups branch on `using_example_data()`, which is simply "is there a usable connection?" — a connection means the database, no connection means the bundled `avonet_example` data. There is deliberately no option and no toggle: the bundle is a snapshot, so letting anything prefer it over a live connection would mean serving stale rows once the database moves on. `connect_db()` is the only thing that changes the answer. Adding a table to the bundle is all it takes to make its `db_table()` callers work offline
- **Stated lookups over derived ones:** where a mapping cannot be inferred reliably from column names, it is written down once as a small function and read from there: `trait_group_tables()` (group to table), `morph_aggregate_columns()` (aggregate name to grouping column), `species_trait_sources()` (trait to source column) and `modal_source()` (source column to its modal citation). Each sits at the top of the file that owns the concept, with a plain comment rather than roxygen. Deriving these from name patterns is what produced the `"social"` doc drift, the `spatial_source` pseudo-trait and the mass hardcode
- **Joins on data-derived keys:** pass `na_matches = "never"` to any `*_join()` whose key comes from the data rather than from column names. A `NULL` source or ID is "unknown", not a value to match on, but dplyr's default (`na_matches = "na"`) treats `NA` as equal to `NA` and fans one row out into one per `NA`-keyed row in the lookup table — see the `get_metadata()` row. The other two joins in the package (`get_metadata()` on `trait`, `list_traits()` on `trait_name`) key on column names, which are never `NA`, so they are safe as written and deliberately left alone
- **Postgres enums:** enum columns arrive from `RPostgres` with an extra `pq_*` S3 class over the underlying vector. Any query result that reaches a user passes through `convert_enum_columns()` (`helper_functions.R`) so they become plain factors — currently `query_species_traits()`, `get_morph_traits()` and `get_sources()`. Results that are only summarized to strings (`list_traits()`) or whose enum columns are dropped before returning (`get_metadata()`, `get_taxonomic_info()`) deliberately skip it. `query_trait_values()` skips it because `trait_info_detailed` has no enum columns at all (verified 2026-11-19, all seven are `character`) — worth re-checking if that table ever gains one, since three callers join or `unique()` on its columns and would shift behaviour if they became factors
- **Dependency policy:** e.g. "no readxl — direct Postgres only"; how new deps get added to `DESCRIPTION` `Imports`

## Current state

<!-- Doesn't need to be exhaustive — a rough table is enough to orient a fresh session -->

| Area | Status | Notes |
|---|---|---|
| Core connection functions, i.e. `connect_db()` / `disconnect_db()` / `get_con()` | done | connection functions |
| `detect_rank()` / `resolve_taxa()` / `apply_filters()` | done | Helper functions, now carrying full `@keywords internal` roxygen converted from their `# ---` header comments. `apply_filters()` no longer keeps a hardcoded list of 33 filterable columns — it derives them from `names(data)`, minus taxonomic and `_id`/`_src`/`_source` columns, so the list cannot drift from what `query_species_traits()` selects. All five error paths now use classed `rlang::abort()` calls. Its column resolution was extracted on 2026-11-20 into `filterable_columns()` (short name to full column, derived from `names(data)`) and `filter_matches_frame()`, so the same code describes the species-level and specimen-level frames and `get_traits()` can ask which resolution a filter name belongs to. `apply_filters()` gained a `what` argument so its "Filter retained N of M" message says "species" or "specimens". Its `@details` is the canonical description of the filter syntax that `get_traits()` re-states for users |
| `remove_column_prefixes()` /  `remove_suffix_columns()` / `arrange_metadata()` | done | `remove_column_prefixes()` and `remove_suffix_columns()` are now called through `tidy_species_columns()`, which owns the species-level column clean-up (prefix stripping, `name` → `species`, dropping `_src`/`_source` and `species_id`) for `get_traits()`. It was shared with `get_species()` until that function was removed on 2026-11-19, which is why its `` still reads as a contract between two callers. `remove_column_prefixes()` and `remove_suffix_columns()` are the only functions in `helper_functions.R` left with plain inline comments rather than roxygen — deliberately, as they are small enough to read at a glance. `arrange_metadata()`, long flagged here as a refactor candidate, was deleted on 2026-11-19: the `get_metadata()` rewrite was its only caller |
| `query_species_traits()` | done | Renamed from `sql_query()` and unexported (`query_*` is now the raw-SQL layer; `get_traits()` is the public face). Args renamed `parameter1`/`parameter2` → `species`/`taxonomy`, SQL composed with `glue_sql()` instead of `paste()`, full `@keywords internal` roxygen block. Values are still bound via `DBI::dbBind()`, so a whole species vector is fetched in one batched call. Only matches `species_name`; rank support is deferred — see "Deferred: rank support" below. Converts Postgres enum columns (extra `pq_*` S3 class) to factors before returning, now through the shared `convert_enum_columns()` in `helper_functions.R` that `get_morph_traits()` also calls |
| `get_traits()` | done | gained `resolution` and `aggregate`; `resolution = "specimen"` adds a fourth `specimen_data` element (via `get_morph_traits()`) while `data` stays one row per species, and warns about species with no specimen records. Now documented and exported, with `@details` covering the filter syntax and the species-vs-specimen split. Its step 2b warning was dead code until 2026-11-19 and now checks what it was reaching for: a resolved species with no ecological, mass or geographical values comes back as an all-`NA` row under the LEFT joins, so the check is `rowSums(!is.na(...)) > 0` over the `ect_*` / `mass_*` / `spd_*` columns, costing no queries where the old version fired three `LIMIT 1` queries per species that never ran. Verified reachable on 2026-11-19, which the old one never was: 159, 163 and 1 species in taxonomies 1, 2 and 3 respectively have no value in any of the 13 trait columns, so the warning fires on real data. None of them are in Accipitridae, which is why the README examples stay silent. `con <- get_con()` became a bare `get_con()` with it, since the dead block held its only use. Filters may now mix the two resolutions in one list (2026-11-20): each name is matched against the species-level columns first and the specimen-level ones second, species-level conditions run before the specimen fetch so only surviving species are queried, and a specimen-level condition narrows `data` as well as `specimen_data` so both keep describing the same species. A specimen-level condition with `resolution = "species"` raises `avonet_error_specimen_filter_resolution` rather than passing silently, and a name matching neither resolution errors once with both column lists. Aggregation moved out of `get_morph_traits()` into `aggregate_specimens()` so it can run after the specimen filter. `aggregate` is validated by `validate_aggregate()` before the species-level query runs, instead of after every specimen row had been fetched, and supplying it with `resolution = "species"` warns rather than being silently ignored. On 2026-11-19 `resolution` flipped to default `"specimen"`, since the specimen-level morphology is the part of AVONET a species checklist cannot give, and an `inferred` argument was added (default `FALSE`, raising `avonet_error_not_implemented` for anything else) carried over from the removed `get_species()` so the signature will not change when inferred traits land. |
| `get_taxonomic_info()` | done | now accepts a vector of 2+ search terms (must all be the same kind: all species binomials, or all genus/family/order); warns on unmatched terms, keeps duplicate rows when multiple terms match the same species |
| `get_sources()` | done | not documented because non-user facing function. Now passes its result through the shared `convert_enum_columns()`: `detailed_sources` was still handing users `pq_trait_source_types` and `pq_literature_types` columns after the specimen-level fix landed |
| `get_morph_traits()` | done | not documented because non-user facing function. No longer a deletion candidate — it now backs `get_traits(resolution = "specimen")`. Column selection was rewritten from hardcoded positional slices (`[1:7]`, `[23:27]`) to name-based, which fixed three latent bugs: `life_stage` and `species_id` were silently dropped, and `secondary_1` was duplicated. Aggregates group by species, so multi-species calls no longer pool measurements, and the five near-identical aggregate branches collapsed into one driven by the shared `morph_aggregate_columns()` lookup. Rewritten 2026-11-19 from per-species `dbBind()` parameter sets to a single set-based `glue_sql()` query that joins `morph_trait_detailed` → `source_specimen_species` → `species`: one execution for the whole vector instead of one per species (~250 for Accipitridae, ~6,500 for Passeriformes), and each row now carries the species it is actually linked to. The old query filtered on `source_id IN (sources linked to species X)` and then stamped every returned row with X via a scalar subquery, so it was only correct while each `source_id` maps to exactly one species — an assumption that turns out to hold, but only because every query filters `species_tax` — see "Verified: specimen source cardinality" below. Verified against production 2026-11-19: output identical to the old code for `Buteo buteo`, correct per-species labels for a three-species call, and `get_traits("Accipitridae", 1, resolution = "specimen")` returning 1,452 rows for 248 of 250 species in ~4.2 s. Enum columns are now unwrapped to factors through the shared `convert_enum_columns()`, as `query_species_traits()` already did, so `specimen_data` and `data` behave the same way downstream |
| `list_traits()` | done | refactored off `readxl()`; primary_source is derived from `_src`/`_source` columns (mode across observations, ties kept) through the shared `modal_source()` helper, and hardcoded to "Tobias et al. (2022)" only for `morph_trait_specimen`, which has no per-measurement source column because AVONET measured those specimens itself. `mass_value` was hardcoded the same way until 2026-11-19, which was wrong: `mass_species.mass_trait_src` is populated, and the derived answer is Dunning (2008) with 25,678 of 28,947 rows — "Tobias et al. (2022)" sources none of them, being the citation for the dataset rather than for the measurements; now fully documented with a `@keywords internal` roxygen block: the old header comment was converted into `@details` covering the two `primary_source` derivations, the data-derived `value` summaries, and the `NA`/"AVOTRAITS" row filtering |
| `get_trait_list()` | done | Body cleaned up: the commented-out dead code and the inline `trait_groups_dict` are gone, replaced by the shared `trait_group_tables()` lookup. Unknown group names now raise `avonet_error_unknown_group` instead of silently returning an empty tibble, and validation happens before any query. Naming one group now reads one table instead of all four. Roxygen corrected — it previously omitted `"social"` from the valid groups |
| `get_trait_groups()` | done | Now returns `names(trait_group_tables())`, the internal mapping of group name to database table that `get_trait_list()` also reads. Having one source of truth is what stops the two drifting, which is how `"social"` went missing from the `get_trait_list()` docs |
| `query_trait_values()` | done | Renamed from `trait_description_query()`, then from `get_trait_values()` and unexported on 2026-11-19. It was a bare `SELECT * FROM trait_info_detailed` returning the schema's own column names, with three internal callers, no mention in the README tour, and nothing a user could learn from it that `get_trait_list()` (every trait, data-derived values) or `get_trait_levels(return_defs = TRUE)` (one trait's levels and their definitions) does not give in the package's own vocabulary. The `query_*` prefix now marks it as the raw-SQL layer, matching `query_species_traits()`. Gained a full `@keywords internal` roxygen block in the process |
| Example data (`avonet_example`) | done | Added 2026-11-19. Accipitriformes (order) and Sylviidae (family) across every taxonomy that carries them, built by `data-raw/make_example_data.R` and documented in `R/data.R`. `species_traits` and `specimens` are snapshots of `query_species_traits()` and `get_morph_traits()` output rather than of raw tables, so the offline path filters a stored result instead of re-implementing the joins — the trade-off is that they must be re-extracted when those queries change shape. `raw_tables` holds the per-group tables keyed by database table name, so `db_table()` and `modal_source()` use the same names offline that they put in their SQL. `DESCRIPTION` gained `LazyData: true`, which `example_bundle()` depends on to find the object in the namespace. 120 KB on disk. Coverage as extracted: BirdLife 252 Accipitriformes / 69 Sylviidae, eBird 252 / **0**, BirdTree 251 / 294. The eBird zero is an artefact of the extraction, not of the data: eBird suffixes family names with a common-name gloss -- `Accipitridae (Hawks, Eagles, and Kites)`, `Pandionidae (Osprey)` -- so the extraction's `species_family = 'Sylviidae'` matched nothing. This is also the explanation for the "tax2 returns no result --> due to family names" note left in `package_demo.R`, and it is a package-level gap rather than a bundling one: `resolve_taxa()` matches `species_family` with `=`, so **no** family query works in taxonomy 2 against the live database either. See "Open: family names in eBird" below. A second bug, found on 2026-11-20 and fixed the same day: the bundled `specimens` frame originally dropped `species_tax` and was de-duplicated across taxonomies, on the reasoning that a specimen is a physical bird and its name identifies the taxonomy's view of it. That is wrong. 269 of the 637 example species names occur in all three taxonomies under different `species_id`s, and where two taxonomies attach different specimens to the same name a name-only filter pools them -- `get_traits("Accipitridae", 1)` returned 1,500 specimen rows offline against the database's 1,452. The frame now carries `species_tax`, is not de-duplicated across taxonomies, and `get_morph_traits()` filters on both name and taxonomy, dropping the column again so the offline shape matches the database path. Comparing an offline count against a live one is the only way this surfaces, so it is worth doing for any new bundled frame. One trap found in testing and fixed with `warn_example_coverage()`: a taxon *wider* than a bundled one silently returns the bundled part as though it were the whole, because `get_traits("Passeriformes", 1)` matches the Sylviidae rows that sit inside that order. Taxa at or below a bundled taxon need no warning, both bundled taxa being complete |\n| `using_example_data()` / `db_table()` / `match_example_taxa()` | done | The offline plumbing, in `R/example_data.R`, all internal — the package gained no new exports. A three-way `avonet.data_source` option and an exported `use_example_data()` toggle were built on 2026-11-19 and removed the same day: the fallback is wanted, the configurability was not, since every value other than "use the database when you have one" either serves stale data or just errors. `match_example_taxa()` is the single offline matcher that `detect_rank()`, `resolve_taxa()` and `get_taxonomic_info()` all read, so the `ILIKE` / `CASE` semantics they mirror are reimplemented once rather than three times — the first version had them in three places, which is unmaintainable in a package with no tests |\n| `get_metadata()` | done | non-user-facing function. Rewritten 2026-11-19 to take the whole `query_species_traits()` frame and read `species_trait_sources()`, the stated trait-to-source lookup, instead of deriving pseudo-trait names by stripping suffixes off the source columns. That derivation produced one row per *source column* rather than per trait: the five geographic traits collapsed into a single row called `spatial_source` (a column name, not a trait) and were otherwise unmentioned, and `mass_trait_src` became `mass`, which matches nothing in the dictionary. It now returns 12 traits with dictionary-matching names, 11 of which resolve a description — `mass_value` has no `trait_info_detailed` entry at all, a database gap rather than a code one. `derive_source_map()` could not be reused: it assumes a single table and aborts on the joined frame, where `mass_trait_src` and `spd_spatial_source` are both unclaimed. Also fixed: its `trait_source_detailed` join now passes `na_matches = "never"`. `trait_source_detailed` holds two rows with no `trait_src_id` ("Collar 2014" and "Pigot et al. (2020)", dataset-level citations), and dplyr treats `NA` as equal to `NA`, so any trait whose source column was `NULL` matched both and came back as two rows naming papers that say nothing about it. `get_traits("Bermuteo avivorus", 1)` returned a 16-row `metadata_summary` for 8 traits, while `detailed_sources` was empty — `get_sources()` resolves the same values in SQL, where `NULL` never matches `NULL`, so the two halves disagreed. dplyr 1.1.4 flags the join as an unexpected many-to-many, which was the available hint |
| `get_trait_levels()` | done | wraps `query_trait_values()`; returns the unique values of `trait` for a given categorical trait (or a defs tibble via `return_defs = TRUE`); errors on unknown/non-categorical traits |
| `get_filters()` | deferred | Deliberately not built. The original idea — list categorical levels across all traits — duplicates `get_trait_list()`, whose `value` column already holds exactly that, and `get_trait_levels()` for one trait in detail. The real gap it was reaching for was `apply_filters()` offering columns that were never queried, which is now fixed at the source instead. If it is ever built it should be a filter *contract* (short name, full column, type, levels or numeric range) that `apply_filters()` itself consumes, not a fourth list to keep in sync. Revisit only after deciding whether `query_species_traits()` will join the social/reproduction tables |
| Documentation | done | `get_traits()` and `query_species_traits()` both now carry full roxygen blocks meeting the "done" checklist below. Every `@examples` block in the package is wrapped in `\dontrun{}`, so `check()` no longer runs examples against the live DB — they previously only passed on a machine with a local `avonet` Postgres. `list_traits()` is now documented too (internal, so it generates a hidden `.Rd`). With `get_filters()` deferred, every function in the package is now documented |
| Tests | deferred | Deliberately deferred (2026-08-22). Still nothing written: no `tests/`, no testthat scaffolding, no `Suggests: testthat`. Goal when picked up is still one example test per function — see "Deferred: test suite" below |

Removed 2026-08-22: `query_species_id()` and `get_eco_traits()`. Neither had a
single caller anywhere in `R/`, and both had been flagged as deletion
candidates since this file was written. `get_eco_traits()` was a narrower
`get_traits()` with aggregates, superseded by `get_traits(filter = ...)`;
`query_species_id()` was superseded by `resolve_taxa()`. Both are recoverable
from git history if a use ever turns up. No calls to either remain anywhere in
the repo.

Removed 2026-11-19: `arrange_metadata()`, whose only caller was the
`get_metadata()` rewrite, and `get_species()`. It returned exactly what
`get_traits()$data` returns — both ended in the same `tidy_species_columns()`
call — for the only input it accepted, exact binomials. It also had two
problems of its own: `get_species("Accipitridae", 1)` returned zero rows
silently, because it never called `resolve_taxa()`, and `inferred` existed
only to raise `avonet_error_not_implemented`. Its three remaining advantages
over `get_traits()` were all properties of `get_traits()` doing extra work
rather than reasons for a second entry point: one query instead of `2N + 4`
(rank detection and resolution run per name, metadata and sources are a fixed
`+4`), a bare data frame instead of `$data`, and silence instead of four
progress messages. If the cheap path is ever wanted back, it belongs as a
`metadata = FALSE` argument on `get_traits()`, not as a parallel function. The
`inferred` argument was carried over to `get_traits()`; `avonet_error_not_implemented`
therefore survives the removal.

Known technical debt / mid-refactor items:
- `query_species_traits()` still hard-codes its four tables and column list. A `tables`/`columns` argument was considered and deliberately deferred. The original reason for deferring — that `get_traits()` assumes all three trait tables in its missing-species warning — no longer holds, since that warning was dead code and has since been replaced with an all-NA check (see below); revisit the deferral on that basis
- `get_metadata()` built its per-trait rows with a scalar `trait` against a column of values, which errored on a zero-row frame ("arguments imply differing number of rows: 1, 0"). Any filter that removed every species hit it -- `get_traits("Accipitridae", 1, filter = list(habitat = "Nonexistent"))` crashed rather than returning an empty result. Fixed 2026-11-20 with `rep(..., nrow(data))`, and `get_sources()` now returns the table shape with no rows rather than binding an empty `IN (...)`. An empty result is now empty in all four elements
- **Seven traits are empty across the whole database** (verified 2026-11-20). Six are morphological: `gape_width`, `beak_depth_max`, `tail_graduation`, `tarsus_diameter_sag`, `tarsus_diameter_lat` and `back_toe` all hold 0 values in 90,019 rows of `morph_trait_specimen`. The nine that do carry data — `beak_length_culmen`, `beak_length_nares`, `beak_width`, `beak_depth_nares`, `wing_length`, `kipps_distance`, `secondary_1`, `tail_length`, `tarsus_length` — are exactly the linear measurements AVONET publishes, so the six look like schema provision for a wider protocol that was never filled in. `get_trait_list()` used to advertise all fifteen identically, with `value` reading "numeric" for every one; `summarize_trait_value()` now reports `"no values"`, which is the only thing standing between a user and a filter that silently returns nothing. The traits are deliberately still listed: the columns exist, and `value` is the honest place to say the data does not. The seventh is `geo_data_species.spd_distribution`, 0 of 20,995 rows, which puts one of the six geographical traits in the same position. `eco_trait_species` and `social_trait_species` are fully populated, so the gap is confined to those two tables
- **Database content, not code:** `trait_info_detailed.trait_description` for `min_latitude` reads "Minimum latitude of spcies' range (breeding & resident)" — a typo in the database. `max_latitude` has it right, so it is a one-off. It was always there but only became visible on 2026-11-19, when the `get_metadata()` rewrite started listing the geographic traits in `metadata_summary` at all. Needs an `UPDATE trait_info_detailed SET trait_description = ... WHERE trait_name = 'min_latitude'`, not a code change. Worth reading all 47 rows of `SELECT DISTINCT trait_name, trait_description FROM trait_info_detailed` at the same time, since nothing has ever proof-read them and they are user-facing through `get_trait_list()` and `metadata_summary`

### Open: family names in eBird (decide later)

eBird (taxonomy 2) labels families with a common-name gloss appended:

```
taxonomy 1  Accipitridae
taxonomy 2  Accipitridae (Hawks, Eagles, and Kites), Pandionidae (Osprey)
taxonomy 3  Accipitridae
```

`resolve_taxa()` matches `species_family` with `=`, so a family query in
taxonomy 2 finds nothing -- `get_traits("Accipitridae", taxonomy = 2)` errors
with "No species found", against the live database as well as the bundle. That
is the "tax2 returns no result --> due to family names" note in
`package_demo.R`, finally pinned down (2026-11-20). Genus, species and order
queries are unaffected; only family matching is exact-equality against a
column whose values differ in form between taxonomies.

Three ways out, none chosen:

1. Match families with `LIKE 'X%'` the way genus already does with
   `LIKE 'X %'`. Cheap, and it makes `"Accipitridae"` work everywhere, but it
   would also match a family whose name merely starts the same way.
2. Normalize on read, stripping ` (...)` from `species_family` in the queries
   that return it. Keeps matching exact, but the package would then report a
   family name the database does not hold.
3. Fix the data, so taxonomy 2 carries bare family names and the gloss lives
   in its own column. The cleanest, and the only one that helps anything
   querying the database outside this package.

Whichever is chosen, the extraction script needs the same treatment: its
`species_family = {EXAMPLE_FAMILY}` is why the bundle has 0 eBird Sylviidae.
Worth first confirming that eBird does hold them under a glossed name:

```sql
SELECT DISTINCT species_family FROM species
 WHERE species_tax = 2 AND species_family LIKE 'Sylviidae%';
```

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
expand any rank into a species vector first. The user-visible gap this section
was written around — `get_species("Accipitridae", 1)` returning zero rows —
disappeared with `get_species()` on 2026-11-19. Every exported path now
resolves ranks, so what remains here is purely an argument about cost.

The stronger argument for change is cost, not API surface: `dbBind()` executes
the statement once per species, so an order like Passeriformes runs ~6,500
executions where `WHERE sp.species_order = 'Passeriformes'` would be one.
`package_demo.R` already prototypes a hand-written `IN (...)` version worth
benchmarking against the current path.

**Verified facts** (from `get_traits("Accipitridae", 1)`, 250 species):

- The missing-species warning in `get_traits()` was **dead code**, and was
  replaced on 2026-11-19 (see step 1 below). With LEFT joins, any species in
  `species` returns a row (NAs in the trait columns), and `resolve_taxa()`
  draws names from that same table with the same `species_tax` filter — so
  `missing_species` could never be non-empty. 250 resolved species returned
  250 rows and no warning.
- Its message was also wrong about the cause: the per-table detail queries used
  INNER joins, so a species genuinely absent from `species` would have been
  reported as missing from all three trait tables.
- The LEFT joins are 1:1 — 250 species gave exactly 250 rows, so no species has
  multiple `mass_species` / `geo_data_species` rows. A rank-aware `WHERE`
  depends on this.
- `dbBind()` does accumulate results across parameter sets; the batched fetch
  works as documented.

**Suggested order when this is picked up:**

1. ~~Delete the dead warning (`get_traits.R`, step 2b) and replace it with an
   all-`NA` check across the `ect_*` / `mass_*` / `spd_*` columns.~~ Done
   2026-11-19. The check is now `rowSums(!is.na(species_data[trait_cols])) > 0`
   over the trait columns minus their `_src` / `_source` partners, naming any
   species with nothing recorded against it. It costs no queries, where the
   old version fired three `LIMIT 1` queries per missing species that never
   ran. Note this is a *different* warning from the specimen one added with
   `resolution = "specimen"`: that one is about missing morphology, this one
   about missing species-level traits.

   Reachability was checked rather than assumed, since replacing dead code
   with more dead code would have been easy to miss. Mirroring the R check in
   SQL — the 13 `ect_*` / `mass_*` / `spd_*` columns, minus their `_src` and
   `_source` partners, all `IS NULL` — gives, as of 2026-11-19:

   | taxonomy | species with no trait values |
   |---|---|
   | 1 (BirdLife) | 159 |
   | 2 (eBird) | 163 |
   | 3 (BirdTree) | 1 |

   The warning is therefore live in all three taxonomies. BirdTree's single
   species stands out sharply against the other two; that has not been looked
   into, and may say more about how that taxonomy was loaded than about the
   completeness of its data. Worth a glance if anyone touches this area.
2. Add a `rank` argument to `query_species_traits()` so the `WHERE` filters on
   `species_name` / `species_family` / `species_order` directly (genus via
   `LIKE 'X %'`, mirroring `resolve_taxa()`). This was the recommended
   starting point while `get_species()` existed and needed it; with that
   function gone it is only worth doing as groundwork for step 3.
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
- `summarize_trait_value()` — `"no values"` for an all-`NA` column, `"numeric"`, sorted levels, `NA` sorting last
- `derive_source_map()` — the shared-leftover fallback and
  `avonet_error_unresolved_source`
- `get_trait_list()` — `avonet_error_unknown_group`, which is raised before any
  query
- `get_traits()` — `avonet_error_not_implemented` for `inferred = TRUE`, raised before any query
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
- [ ] `@examples` are wrapped in `\dontrun{}` **unless they run against the bundled example data**, which needs no connection. `avonet_example` is the first block in the package that `R CMD check` actually executes; previously every example was skipped, so none had ever run. New examples that need only the bundled taxa should follow it and leave `\dontrun{}` off
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
