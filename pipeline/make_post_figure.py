"""
One figure, built for communication rather than for the deliverable.

    python pipeline/make_post_figure.py

Reads  : lga_segments_named, cluster_features
Writes : reports/post_confidence.png


WHY THIS EXISTS AND WHY IT IS NOT IN visualise.py
--------------------------------------------------
reports/segment_silhouette.png draws one bar per LGA -- 769 of them. That is
the right figure for the report, because a reader who wants to interrogate the
result can see the whole distribution and count the tail themselves.

It is the wrong figure for a post, a slide, or anything read at thumbnail
size. 769 hairline bars turn into a blue smear; the eye gets texture where it
needs a number.

So this draws the SAME data summarised: for each segment, the middle half of
its silhouette scores, the full 10th-90th spread, and the median. Five rows.
Legible at any size, and it still shows the thing that matters -- which
segments sit clear of zero and which straddle it.

It lives in its own file because the deliverable's figures should not quietly
become prettier and less complete over time. If a reader ever asks "where does
that summary come from", segment_silhouette.png is the answer, unchanged.


HONESTY CONSTRAINT
------------------
A summary may compress. It may not flatter. So:
  - the zero line is drawn and labelled, never cropped out of frame
  - the count below zero is printed on every row, including the zeros
  - the axis is not trimmed to hide the left tail
If a future edit makes this chart look better by removing one of those three,
it has stopped being a summary of the report and started disagreeing with it.
"""

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "processed" / "nigeria_lga.db"
REPORTS = ROOT / "reports"

# Same tokens as pipeline/visualise.py. One categorical series, so no legend
# is needed and no colour-pair separation question arises.
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
BLUE = "#2a78d6"
BLUE_PALE = "#9ec5f4"
GRID = "#e8e6e0"
MUTED = "#dedcd6"

FEATURES = [
    "elec_rate_2020", "demand_kwh_per_capita", "poverty_rate", "travel_hours",
    "mv_line_dist_km", "pct_grid_new_2030", "settled_density",
]


def load() -> pd.DataFrame:
    if not DB.exists():
        sys.exit(f"{DB} not found.")
    con = sqlite3.connect(DB)
    try:
        df = pd.read_sql(f"""
            SELECT n.lga_pcode, n.seg_kmeans, n.display_order, n.segment_name,
                   {', '.join('f.' + c for c in FEATURES)}
            FROM lga_segments_named n
            JOIN cluster_features f ON f.lga_pcode = n.lga_pcode
        """, con)
    except Exception as exc:
        sys.exit(f"Could not read lga_segments_named / cluster_features: {exc}\n"
                 f"Run sql/09_segment_names.sql in DB Browser, then WRITE CHANGES.")
    finally:
        con.close()
    return df


def silhouettes(df) -> np.ndarray:
    """Identical preparation to visualise.py, so the two figures cannot drift."""
    from sklearn.metrics import silhouette_samples
    from sklearn.preprocessing import StandardScaler

    X = df[FEATURES].copy()
    for col in ["mv_line_dist_km", "demand_kwh_per_capita"]:
        X[col] = X[col].clip(upper=X[col].quantile(0.99))
    for col in ["travel_hours", "settled_density"]:
        X[col] = np.log1p(X[col])
    Xs = StandardScaler().fit_transform(X)
    # On the CLUSTER labels, never the display order -- renumbering is cosmetic.
    return silhouette_samples(Xs, df["seg_kmeans"].values)


def draw(df, vals, plt):
    u = (df.drop_duplicates("display_order")
           .sort_values("display_order")[["display_order", "segment_name"]])
    rows = [(int(o), nm) for o, nm in u.itertuples(index=False)]

    fig, ax = plt.subplots(figsize=(9.2, 4.4), facecolor=SURFACE)

    # Row 1 at the top: matplotlib's y axis grows upward, so plot in reverse.
    ypos = {o: len(rows) - 1 - i for i, (o, _) in enumerate(rows)}

    ax.axvspan(min(-0.02, vals.min() - 0.05), 0, color=MUTED, alpha=0.45, lw=0)

    labels, notes = [], []
    for order, name in rows:
        v = vals[df.display_order.values == order]
        y = ypos[order]
        p10, p25, p50, p75, p90 = np.percentile(v, [10, 25, 50, 75, 90])

        ax.plot([p10, p90], [y, y], color=BLUE_PALE, lw=2.0,
                solid_capstyle="round", zorder=2)
        ax.plot([p25, p75], [y, y], color=BLUE, lw=8.0,
                solid_capstyle="round", zorder=3)
        ax.plot([p50], [y], "o", ms=9, color=SURFACE, mec=BLUE, mew=2.2,
                zorder=4)

        n_neg = int((v < 0).sum())
        labels.append((y, f"{order}  {name}"))
        notes.append((y, p90, f"{len(v)} LGAs  ·  {n_neg} below zero"))

    for y, x, txt in notes:
        ax.text(x + 0.018, y, txt, va="center", fontsize=8.5, color=INK_2)

    ax.axvline(0, color=INK_2, lw=1.2, zorder=1)
    ax.text(0, len(rows) - 0.42, "  0 = sits on the boundary between two segments",
            fontsize=8.5, color=INK_2, va="bottom", ha="left")

    ax.set_yticks([y for y, _ in labels])
    ax.set_yticklabels([t for _, t in labels], fontsize=9)
    ax.set_ylim(-0.75, len(rows) - 0.15)
    ax.set_xlim(min(-0.06, vals.min() - 0.04), vals.max() + 0.22)
    ax.xaxis.grid(True, color=GRID, lw=1)
    ax.set_axisbelow(True)
    ax.set_facecolor(SURFACE)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.tick_params(colors=INK_2, labelsize=8.5, length=0)

    ax.set_title("How well does each segment actually hold together?",
                 color=INK, fontsize=13, loc="left", pad=22)
    ax.text(0, 1.045, "silhouette score per local government area  ·  "
                      "bar = middle half  ·  line = 10th-90th  ·  dot = median",
            transform=ax.transAxes, color=INK_2, fontsize=8.5, va="bottom")

    n_neg = int((vals < 0).sum())
    ax.set_xlabel(f"higher = the segment fits that place better    ·    "
                  f"{n_neg} of {len(vals)} LGAs ({100*n_neg/len(vals):.1f}%) "
                  f"fall below zero",
                  color=INK_2, fontsize=9, labelpad=10)

    fig.tight_layout()
    out = REPORTS / "post_confidence.png"
    fig.savefig(out, dpi=180, facecolor=SURFACE)
    plt.close(fig)
    print(f"  {out.relative_to(ROOT)}")
    print(f"  {n_neg} of {len(vals)} LGAs below zero -- must match "
          f"segment_silhouette.png exactly")


def main():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size": 9, "figure.facecolor": SURFACE,
                         "text.color": INK, "axes.labelcolor": INK_2})

    REPORTS.mkdir(exist_ok=True)
    df = load()
    print(f"Loaded {len(df)} LGAs in {df.display_order.nunique()} segments.")
    vals = silhouettes(df)
    draw(df, vals, plt)


if __name__ == "__main__":
    main()
