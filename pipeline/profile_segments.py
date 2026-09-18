"""
Stage 3: every number the segment profiles are allowed to use.

    python pipeline/profile_segments.py

Reads  : lga_segments_named, lga_subsegments_named, cluster_features, lga_base
Writes : reports/segment_profile_data.md   -- GENERATED. Never edit by hand.


WHY THIS FILE EXISTS
--------------------
reports/segment_profiles.md is written by a person: eight persona paragraphs,
the limitations section, the argument. This file supplies the facts that
document is allowed to quote, and it regenerates them from the database every
time it runs.

The rule that makes the pair work, and it belongs in both files:

    RESTATE NO NUMBER YOU DID NOT GENERATE.

Where the prose needs a figure, it cites the table here rather than retyping
it. A hand-typed number drifts silently the moment the pipeline is re-run; a
generated one cannot. This project has already found one number that was true
of the data and false in the write-up, and that was enough.


WHAT IS AND IS NOT REGENERABLE HERE
------------------------------------
Almost everything is: the segment and sub-segment profiles, the names and
operating steps (from the naming tables), the K-Means/Ward agreement, the
DBSCAN outcome, the per-LGA silhouettes, and the quality flags -- because
pipeline/cluster.py stored seg_ward and seg_dbscan alongside seg_kmeans rather
than discarding them.

Three numbers are NOT stored in the database and so are not reproduced here:
the k-selection curve, the bootstrap stability, and the sub-clustering null
table. They live in the stdout of cluster.py and subcluster.py, in the commit
messages, and in reports/k_selection.png. Where the profile needs them it must
cite those, and this file says so rather than inventing a source.
"""

import sqlite3
import sys
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import adjusted_rand_score, pairwise_distances
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "processed" / "nigeria_lga.db"
OUT = ROOT / "reports" / "segment_profile_data.md"

FEATURES = [
    "elec_rate_2020", "demand_kwh_per_capita", "poverty_rate", "travel_hours",
    "mv_line_dist_km", "pct_grid_new_2030", "settled_density",
]
NICE = {
    "elec_rate_2020": "electrification rate",
    "demand_kwh_per_capita": "demand, kWh per person per year",
    "poverty_rate": "poverty rate",
    "travel_hours": "travel time to town, hours",
    "mv_line_dist_km": "distance to MV line, km",
    "pct_grid_new_2030": "share getting grid by 2030",
    "settled_density": "settlement density",
}
EXTRA = {
    "pct_standalone_pv_2030": "stand-alone solar share, 2030",
    "pct_minigrid_2030": "mini-grid share, 2030",
}
LOG_FEATURES = ["travel_hours", "settled_density"]
WINSORISE_FEATURES = ["mv_line_dist_km", "demand_kwh_per_capita"]
WINSORISE_Q = 0.99


def q(con, sql, **kw):
    return pd.read_sql(sql, con, **kw)


def load(con):
    seg = q(con, f"""
        SELECT n.lga_pcode, n.lga_name, n.state_name, n.gep_flag, n.seg_kmeans,
               n.display_order, n.segment_name, n.is_offgrid_market,
               s.seg_ward, s.seg_dbscan, s.seg_kmeans_ok_only,
               {', '.join('f.' + c for c in FEATURES + list(EXTRA))},
               f.unserved_pop_2020, f.gep_pop_2020
        FROM lga_segments_named n
        JOIN lga_segments   s ON s.lga_pcode = n.lga_pcode
        JOIN cluster_features f ON f.lga_pcode = n.lga_pcode
    """)
    names = q(con, "SELECT * FROM segment_names ORDER BY display_order")
    try:
        sub = q(con, f"""
            SELECT n.lga_pcode, n.state_name, n.gep_flag, n.sub, n.sub_order,
                   n.subsegment_name, n.full_label, n.is_offgrid_market,
                   {', '.join('f.' + c for c in FEATURES + list(EXTRA))},
                   f.unserved_pop_2020
            FROM lga_subsegments_named n
            JOIN cluster_features f ON f.lga_pcode = n.lga_pcode
        """)
        subnames = q(con, "SELECT * FROM subsegment_names ORDER BY display_order")
    except Exception:
        sub, subnames = pd.DataFrame(), pd.DataFrame()
    missing = q(con, """
        SELECT lga_pcode, lga_name, state_name, pop_total
        FROM lga_base
        WHERE lga_pcode NOT IN (SELECT lga_pcode FROM cluster_features)
        ORDER BY state_name, lga_name
    """)
    # Counted, not typed. An earlier draft wrote "of 774" as a literal, which
    # broke this file's own rule: restate no number you did not generate.
    n_lgas = int(q(con, "SELECT COUNT(*) AS n FROM lga_base").n.iloc[0])
    return seg, names, sub, subnames, missing, n_lgas


def silhouette_and_neighbour(Xs, labels):
    """Per-point silhouette plus the nearest OTHER cluster, as in
    check_subsegment_fit.py -- the b() term sklearn discards."""
    D = pairwise_distances(Xs)
    uniq = np.unique(labels)
    mean_to = np.column_stack([D[:, labels == c].mean(axis=1) for c in uniq])
    for j, c in enumerate(uniq):
        m = labels == c
        n = int(m.sum())
        if n > 1:
            mean_to[m, j] = mean_to[m, j] * n / (n - 1)
    own = np.searchsorted(uniq, labels)
    a = mean_to[np.arange(len(labels)), own]
    other = mean_to.copy()
    other[np.arange(len(labels)), own] = np.inf
    b = other.min(axis=1)
    return (b - a) / np.maximum(a, b), uniq[other.argmin(axis=1)]


def md_table(df, index=False, index_name=""):
    """
    A markdown table, written here rather than taken from
    DataFrame.to_markdown().

    to_markdown() looks like a pandas feature but depends on `tabulate`, a
    package this project does not otherwise need. Standing rule 5 is to pin the
    whole dependency tree, so a dependency added for table formatting is a
    dependency a reviewer has to install to read a report. Twelve lines is
    cheaper than that.
    """
    def cell(v):
        # A count must not print as 274.000, and a value already rounded to one
        # decimal must not gain two more. %g keeps whatever precision the value
        # actually carries.
        if isinstance(v, (bool, np.bool_)):
            return str(v)
        if isinstance(v, (int, np.integer)):
            return f"{v:,}"
        if isinstance(v, (float, np.floating)):
            if pd.isna(v):
                return "-"
            return f"{v:,.0f}" if abs(v) >= 1000 else f"{v:g}"
        return str(v)

    d = df.reset_index() if index else df
    if index and index_name:
        d = d.rename(columns={d.columns[0]: index_name})
    cols = [str(c) for c in d.columns]
    rows = [[cell(v) for v in r] for r in d.itertuples(index=False)]
    w = [max(len(c), *(len(r[i]) for r in rows)) if rows else len(c)
         for i, c in enumerate(cols)]
    out = ["| " + " | ".join(c.ljust(w[i]) for i, c in enumerate(cols)) + " |",
           "|" + "|".join("-" * (x + 2) for x in w) + "|"]
    out += ["| " + " | ".join(v.ljust(w[i]) for i, v in enumerate(r)) + " |"
            for r in rows]
    return "\n".join(out)


def prepare(df):
    X = df[FEATURES].copy()
    for c in WINSORISE_FEATURES:
        X[c] = X[c].clip(upper=X[c].quantile(WINSORISE_Q))
    for c in LOG_FEATURES:
        X[c] = np.log1p(X[c])
    return StandardScaler().fit_transform(X)


def fmt(v, dp=3):
    if pd.isna(v):
        return "-"
    return f"{v:,.0f}" if abs(v) >= 1000 else f"{v:.{dp}f}"


def profile_table(sub_df, all_df, cols, compare="national"):
    """
    Group mean beside a comparison mean, so no reader has to infer scale.

    `compare` names what the second column is. It is a parameter rather than a
    string substituted into the output afterwards: an earlier version built the
    national table and then did .replace("| national |", "| segment |") for the
    sub-segments. If the header ever changed, that replace would silently do
    nothing and the sub-segment tables would claim to compare against the
    nation while showing segment means. A mislabelled column that still renders
    is worse than a crash.
    """
    lines = [f"| indicator | this group | {compare} |", "|---|---|---|"]
    for c in cols:
        lines.append(f"| {NICE.get(c, EXTRA.get(c, c))} | "
                     f"{fmt(sub_df[c].mean())} | {fmt(all_df[c].mean())} |")
    return "\n".join(lines)


def top_states(df, n=5):
    g = (df.groupby("state_name")["unserved_pop_2020"].agg(["size", "sum"])
           .sort_values("sum", ascending=False).head(n))
    return ", ".join(f"{s} ({int(r['size'])} LGAs, {r['sum']/1e6:.1f}M)"
                     for s, r in g.iterrows())


def main():
    if not DB.exists():
        sys.exit(f"{DB} not found.")
    con = sqlite3.connect(DB)
    try:
        seg, names, sub, subnames, missing, n_lgas = load(con)
    except Exception as exc:
        sys.exit(f"Could not read the segment tables: {exc}\n"
                 f"\nIf a VIEW is missing: run sql/09_segment_names.sql (and "
                 f"sql/11 for the sub-types) in DB Browser, then WRITE "
                 f"CHANGES.\nIf a COLUMN is missing: the feature table was "
                 f"built by an older sql/07 or sql/08 -- rerun those.")
    finally:
        con.close()

    Xs = prepare(seg)
    sil, nearest = silhouette_and_neighbour(Xs, seg["seg_kmeans"].values)
    seg["sil"] = sil
    seg["nearest_seg"] = nearest
    label = dict(zip(names.seg_kmeans, names.display_order.astype(str)
                     + " " + names.segment_name))

    total_unserved = seg.unserved_pop_2020.sum()
    L = []
    w = L.append

    w(f"# Segment profile data\n")
    w(f"**GENERATED FILE — do not edit.** Regenerate with "
      f"`python pipeline/profile_segments.py`.\n")
    w(f"Generated {date.today().isoformat()} from "
      f"`data/processed/nigeria_lga.db`.\n")
    w("Every number in `reports/segment_profiles.md` must come from here or "
      "from a source this file names. Restate no number you did not "
      "generate.\n")
    w("---\n")

    # ---- headline -------------------------------------------------------
    w("## 1. The five market types\n")
    rows = []
    for _, n in names.iterrows():
        d = seg[seg.seg_kmeans == n.seg_kmeans]
        rows.append({
            "#": n.display_order, "market type": n.segment_name,
            "LGAs": len(d),
            "unserved (M)": round(d.unserved_pop_2020.sum() / 1e6, 1),
            "% of segmented unserved": round(100 * d.unserved_pop_2020.sum()
                                   / total_unserved, 1),
            "electrified": round(d.elec_rate_2020.mean(), 3),
            "stand-alone PV": round(d.pct_standalone_pv_2030.mean(), 3),
            "suspect": int((d.gep_flag == "suspect").sum()),
            "off-grid market": "yes" if n.is_offgrid_market else "no",
        })
    head = pd.DataFrame(rows)
    w(md_table(head) + "\n")

    og = names[names.is_offgrid_market == 1].seg_kmeans
    ogd = seg[seg.seg_kmeans.isin(og)]
    w(f"Off-grid markets: **{len(og)} of {len(names)}**, holding "
      f"**{ogd.unserved_pop_2020.sum()/1e6:.1f}M** of "
      f"{total_unserved/1e6:.1f}M unserved "
      f"(**{100*ogd.unserved_pop_2020.sum()/total_unserved:.1f}%**).\n")

    # ---- limits ---------------------------------------------------------
    w("---\n")
    w("## 2. What this does not tell you\n")
    w(f"**Coverage.** {len(seg)} of {n_lgas} LGAs are segmented. The "
      f"{len(missing)} that "
      f"{'is' if len(missing) == 1 else 'are'} not:\n")
    for _, m in missing.iterrows():
        pop = "no population figure" if pd.isna(m.pop_total) else \
              f"{m.pop_total:,.0f} people, no settlement clusters"
        w(f"- {m.lga_name} ({m.state_name}) — {pop}")
    w("")

    neg = seg[seg.sil < 0]
    w(f"**Boundary cases.** {len(neg)} of {len(seg)} LGAs "
      f"({100*len(neg)/len(seg):.1f}%) have a negative silhouette — they sit "
      f"closer to a market type other than their own. Mean silhouette "
      f"{seg.sil.mean():.3f}. By segment:\n")
    t = (seg.assign(seg=seg.seg_kmeans.map(label))
            .groupby("seg")
            .agg(LGAs=("sil", "size"), mean_silhouette=("sil", "mean"),
                 below_zero=("sil", lambda v: int((v < 0).sum())))
            .sort_index())
    t["mean_silhouette"] = t.mean_silhouette.round(3)
    t["% below zero"] = (100 * t.below_zero / t.LGAs).round(1)
    t = t.rename(columns={"mean_silhouette": "mean silhouette",
                          "below_zero": "below zero"})
    w(md_table(t, index=True, index_name="market type") + "\n")

    # TWO DIFFERENT CHECKS, AND THEY MUST NOT BE CONFLATED. An earlier
    # commit message and the README reported the dual-track figure as though
    # it were the Ward comparison. Both are computed here, each labelled with
    # what it actually compares, so the mistake cannot be repeated from memory.
    ward = adjusted_rand_score(seg.seg_kmeans, seg.seg_ward)
    okm = seg[seg.seg_kmeans_ok_only.notna()]
    dual = adjusted_rand_score(okm.seg_kmeans, okm.seg_kmeans_ok_only)
    n_db = seg.seg_dbscan[seg.seg_dbscan >= 0].nunique()
    noise = int((seg.seg_dbscan < 0).sum())
    w(f"**Second opinion 1 — a different algorithm.** Ward agglomerative "
      f"clustering on the same matrix agrees with K-Means at "
      f"**ARI {ward:.3f}** across all {len(seg)} LGAs. ARI is 0 for chance "
      f"agreement and 1 for identical partitions. Interpretation belongs in "
      f"the profile, not here -- a generated file that judges its own numbers "
      f"would have to be rewritten every time they moved.\n")
    w(f"**Second opinion 2 — the data-quality dual track.** Re-clustering only "
      f"the {len(okm)} LGAs whose GEP data is flagged `ok`, and comparing "
      f"against their assignment in the full run, gives **ARI {dual:.3f}**. "
      f"This is the check that tests the sql/04 finding directly: it asks "
      f"whether excluding the {len(seg) - len(okm)} LGAs with suspect GEP "
      f"data changes where the clean ones land.\n")
    w(f"**Second opinion 3 — density.** DBSCAN returns "
      f"**{n_db} cluster(s) and {noise} noise points** — there are no density "
      f"gaps in this data. These are divisions of a continuum, not natural "
      f"kinds.\n")

    w(f"**Data quality.** Every electrification figure carries a `gep_flag`. "
      f"Suspect rates differ sharply by segment, and the least trustworthy "
      f"data sits where the access gap looks smallest:\n")
    fl = (seg.assign(seg=seg.seg_kmeans.map(label))
             .pivot_table(index="seg", columns="gep_flag", values="lga_pcode",
                          aggfunc="count", fill_value=0))
    fl["% suspect"] = (100 * fl.get("suspect", 0) / fl.sum(axis=1)).round(1)
    w(md_table(fl, index=True, index_name="market type") + "\n")

    w("**Not regenerable here** — cite the source, do not retype from memory: "
      "the k-selection curve and bootstrap stability (`pipeline/cluster.py` "
      "stdout, `reports/k_selection.png`), and the sub-clustering null table "
      "(`pipeline/subcluster.py` stdout). The poverty layer is a 2013 release; "
      "that vintage belongs beside every poverty figure.\n")

    # ---- per segment ----------------------------------------------------
    w("---\n")
    w("## 3. Each market type\n")
    for _, n in names.iterrows():
        d = seg[seg.seg_kmeans == n.seg_kmeans]
        w(f"### {n.display_order}. {n.segment_name}\n")
        w(f"*{len(d)} LGAs · {d.unserved_pop_2020.sum()/1e6:.1f}M unserved · "
          f"{100*d.unserved_pop_2020.sum()/total_unserved:.1f}% of the "
          f"national total · "
          f"{'an off-grid market' if n.is_offgrid_market else 'NOT an off-grid market'}*\n")
        w(f"**Defining fact.** {n.defining_fact}\n")
        w(f"**Operating step.** {n.operating_step}\n")
        if isinstance(n.caveat, str) and n.caveat.strip():
            w(f"**Caveat.** {n.caveat}\n")
        w(profile_table(d, seg, FEATURES + list(EXTRA)) + "\n")
        w(f"**Where.** {top_states(d)}\n")
        near = (d.nearest_seg.map(label).value_counts(normalize=True) * 100).round(0)
        w(f"**Fit.** mean silhouette {d.sil.mean():.3f} · "
          f"{int((d.sil < 0).sum())} of {len(d)} below zero · "
          f"{int((d.gep_flag == 'suspect').sum())} flagged suspect "
          f"({100*(d.gep_flag == 'suspect').mean():.0f}%)\n")
        w(f"**Nearest alternative** (informative only where the fit is poor): "
          + ", ".join(f"{k} {v:.0f}%" for k, v in near.head(3).items()) + "\n")

    # ---- sub-segments ---------------------------------------------------
    if len(sub):
        w("---\n")
        w("## 4. Inside the largest segment\n")
        parent = sub.full_label.iloc[0].split(" -> ")[0]
        sub_tot = sub.unserved_pop_2020.sum()
        w(f"Parent: **{parent}** — {len(sub)} LGAs, "
          f"{sub_tot/1e6:.1f}M unserved.\n")
        rows = []
        for _, n in subnames.iterrows():
            d = sub[sub["sub"] == n["sub"]]
            rows.append({
                "#": n.display_order, "sub-type": n.subsegment_name,
                "LGAs": len(d),
                "unserved (M)": round(d.unserved_pop_2020.sum() / 1e6, 1),
                "% of segment": round(100 * d.unserved_pop_2020.sum()
                                      / sub_tot, 1),
                "stand-alone PV": round(d.pct_standalone_pv_2030.mean(), 3),
                "grid by 2030": round(d.pct_grid_new_2030.mean(), 3),
                "suspect": int((d.gep_flag == "suspect").sum()),
                "off-grid market": "yes" if n.is_offgrid_market else "no",
            })
        w(md_table(pd.DataFrame(rows)) + "\n")
        for _, n in subnames.iterrows():
            d = sub[sub["sub"] == n["sub"]]
            w(f"### {parent} -> {n.subsegment_name}\n")
            w(f"*{len(d)} LGAs · {d.unserved_pop_2020.sum()/1e6:.1f}M "
              f"unserved · "
              f"{'an off-grid market' if n.is_offgrid_market else 'NOT an off-grid market'}*\n")
            w(f"**Defining fact.** {n.defining_fact}\n")
            w(f"**Operating step.** {n.operating_step}\n")
            if isinstance(n.caveat, str) and n.caveat.strip():
                w(f"**Caveat.** {n.caveat}\n")
            w(profile_table(d, sub, FEATURES + list(EXTRA),
                            compare="segment") + "\n")
            w(f"**Where.** {top_states(d)}\n")

    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text("\n".join(L), encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)}  ({len(seg)} LGAs, "
          f"{len(names)} segments, {len(subnames)} sub-types)")
    print(f"  negative silhouette : {len(neg)} of {len(seg)} "
          f"({100*len(neg)/len(seg):.1f}%)")
    print(f"  ARI K-Means vs Ward : {ward:.3f}   (all {len(seg)} LGAs)")
    print(f"  ARI dual-track      : {dual:.3f}   (ok-only, {len(okm)} LGAs)")
    print(f"  DBSCAN              : {n_db} cluster(s), {noise} noise")
    print("\nCross-check these against segment_silhouette.png and the "
          "cluster.py commit message. If they disagree, stop.")


if __name__ == "__main__":
    main()
