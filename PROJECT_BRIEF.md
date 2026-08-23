# Project Brief — Market Segmentation for Off-Grid Energy Expansion

**Prof. Fausat M. Ibrahim · draft, 4 August 2026**
*Stage 0 deliverable. This is a skeleton with the framing settled and the open decisions marked. 

---

## Business context

A pay-as-you-go solar company deciding where to expand next faces a problem that looks like customer targeting but operates a level up. Before it asks which household to approach, it must decide **which market to enter** — where to place agents, stock, service infrastructure and credit exposure. Enter the wrong local government area and no amount of household-level targeting recovers the cost.

Nigeria has 774 local government areas, and they differ enormously in the things that determine whether an off-grid energy business succeeds there: how many people live there, how many lack electricity, whether they can pay, and how expensive they are to serve. Treating that variation as a ranked list loses information — LGAs are not better or worse versions of each other, they are *different kinds of market*, and each kind calls for a different operating model.

## The question

> Which local government areas should an off-grid energy operator prioritise for expansion, and what does each type of market need?

The output is not a ranking. It is a **typology**: a small number of market types, each named, profiled, and paired with what an operator should do differently there.

## Who this is for

- **Primary:** an expansion or operations director at a PAYG solar company choosing next-year territories.
- **Secondary:** rural electrification agencies and development funders allocating subsidy or grant windows across states.

## Approach

1. Assembling LGA-level indicators from public sources into one analysis table, using SQL for all cleaning, joining and aggregation.
2. Comparing clustering families — K-Means, hierarchical, DBSCAN — and choosing a segmentation on evidence rather than convenience.
3. Profiling and name the segments, translating each into an operating recommendation.
4. Publishing as a dashboard for a non-technical decision-maker, plus a short written brief.

## Data

Public, citable sources only: HDX Common Operational Datasets for boundaries and population; GRID3 for settlement and infrastructure; energydata.info for electrification; Global Forest Watch for environmental pressure; optionally the NBS Multidimensional Poverty Index. Full provenance in `docs/data_provenance.md`.

Final indicator list and the coverage each achieves across the 774 LGAs.

## Unit of analysis

**Working decision:** the LGA (774 units), clustered nationally, with the seven North-West states available as a filtered view.

If LGA coverage proves too sparse across sources, fall back to the 109 senatorial districts. Decide before Stage 1 begins.

## What would make this project fail

Naming these now, so they cannot be rationalised later:

- **Segments that only recover geography.** If the clusters reduce to "north versus south," the analysis has told the reader what a map already tells them. I will report it honestly if it happens and then look for structure *within* the obvious split.
- **A broken join.** Different sources spell LGA names differently. A join that silently drops or duplicates rows corrupts every downstream number. Row-count assertions after every join, without exception.
- **Segments no operator could act on.** If a profile cannot be turned into "do this differently here," it is a description, not a segmentation.
- **False precision.** Indicators measured at state level must not be presented as though they varied by LGA.

## Deliverables

- A SQL-built, reproducible analysis table and a catalogue of 15–20 business questions with their queries and answers
- A notebook comparing clustering methods, with the chosen segmentation defended
- Named segment profiles with operating recommendations
- A published Power BI dashboard, including a map, and a one-page Excel summary
- A two-page client brief for an expansion director
- A runnable pipeline, tracked in MLflow

## Standard of honesty

Carried from the solar project: every published number traceable to the script that produced it; negative and inconvenient findings reported rather than dropped; limitations stated in the deliverable rather than left for a reader to discover.
