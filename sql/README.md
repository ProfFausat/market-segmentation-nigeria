# SQL — query catalogue

Scripts run in numbered order against `../segmentation.db`, built from the raw
files listed in `../DATA_ACQUISITION_CHECKLIST.md`.

| Script | What it does |
|---|---|
| `00_schema.sql` | Table definitions, grain and source of each |
| `01_explore.sql` | First look at each table |
| `02_quality_checks.sql` | Key uniqueness, duplicates, missingness |
| `03_name_reconciliation.sql` | Matching LGA names across sources |
| `04_aggregate.sql` | Rolling sub-LGA rows up to the LGA |
| `05_ctes.sql` | Chained transformations |
| `06_windows.sql` | Ranking and percentiles within state |
| `07_analysis_table.sql` | The tidy table clustering consumes |
| `08_business_queries.sql` | The 15–20 questions below |

## Business questions

*One section per question: the question in plain language, the query, the result,
and two sentences of interpretation. This is the part a reviewer reads without
running anything — write it for them.*

<!-- 1. … -->
