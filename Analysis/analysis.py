import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path


# ============================================================
# Configuration
# ============================================================

INPUT_FILE = Path("UAV_comparison_results.xlsx")
OUTPUT_FILE = Path("m6_vs_m12_comparison.png")


METHODS = {
    "Gurobi": {
        "mean": "Gurobi mean (%)",
        "ci": "Gurobi CI95 +/- (pp)",
        "marker": "o",
        "color": "#0072B2",
    },

    "FPGA + Tabu": {
        "mean": "FPGA + Tabu mean (%)",
        "ci": "FPGA + Tabu CI95 +/- (pp)",
        "marker": "s",
        "color": "#D55E00",
    },

    "FPGA no Tabu": {
        "mean": "FPGA no Tabu mean (%)",
        "ci": "FPGA no Tabu CI95 +/- (pp)",
        "marker": "^",
        "color": "#009E73",
    },

    "Heuristic": {
        "mean": "Heuristic mean (%)",
        "ci": "Heuristic CI95 +/- (pp)",
        "marker": "D",
        "color": "#CC79A7",
    },

    "Random": {
        "mean": "Random mean (%)",
        "ci": "Random CI95 +/- (pp)",
        "marker": "X",
        "color": "#E69F00",
    },
}


# ============================================================
# Load workbook
# ============================================================

def load_results(sheet_name):

    df = pd.read_excel(
        INPUT_FILE,
        sheet_name=sheet_name,
        header=3,
    )

    # Remove non-data rows
    df = df[
        pd.to_numeric(
            df["Time (s)"],
            errors="coerce"
        ).notna()
    ].copy()

    df["Time (s)"] = pd.to_numeric(df["Time (s)"])

    return df


df6 = load_results("m_06")
df12 = load_results("m_12")


# ============================================================
# Create figure
# ============================================================

fig, ax = plt.subplots(
    figsize=(11, 7)
)


# ============================================================
# Plot the 5 techniques
# ============================================================

for method, cfg in METHODS.items():

    # --------------------------------------------------------
    # m = 6
    # --------------------------------------------------------

    ax.errorbar(
        df6["Time (s)"],
        df6[cfg["mean"]],
        yerr=df6[cfg["ci"]],
        color=cfg["color"],
        linestyle="-",
        linewidth=2.5,
        marker=cfg["marker"],
        markersize=7,

        # Normal / clearly visible error bars
        ecolor=cfg["color"],
        elinewidth=1.5,
        capsize=3,
        capthick=1.2,

        label=method,
    )

    # --------------------------------------------------------
    # m = 12
    # --------------------------------------------------------

    ax.errorbar(
        df12["Time (s)"],
        df12[cfg["mean"]],
        yerr=df12[cfg["ci"]],
        color=cfg["color"],
        linestyle="--",
        linewidth=2.5,
        marker=cfg["marker"],
        markersize=7,

        # Normal / clearly visible error bars
        ecolor=cfg["color"],
        elinewidth=1.5,
        capsize=3,
        capthick=1.2,
    )
# ============================================================
# Axes
# ============================================================

ax.set_xscale("log")

ax.set_xlabel(
    "Time (s)",
    fontsize=13,
)

ax.set_ylabel(
    "Normalized hovering-energy gap (%)",
    fontsize=13,
)

ax.set_title(
    "Optimization Performance for $m=6$ and $m=12$",
    fontsize=16,
    fontweight="bold",
)

ax.grid(
    True,
    which="both",
    linestyle="--",
    alpha=0.25,
)

ax.tick_params(
    axis="both",
    labelsize=11,
)


# ============================================================
# Time axis
# ============================================================

ax.set_xticks([
    0.01,
    0.05,
    0.1,
    0.25,
    0.5,
    1,
    2,
    3,
    5,
])

ax.set_xticklabels([
    "10 ms",
    "50 ms",
    "100 ms",
    "250 ms",
    "500 ms",
    "1 s",
    "2 s",
    "3 s",
    "5 s",
])

plt.xticks(rotation=45)


# ============================================================
# Technique legend
# ============================================================

legend = ax.legend(
    title="Technique",
    loc="upper right",
    fontsize=10,
    title_fontsize=11,
    frameon=True,
)

legend.get_frame().set_alpha(0.9)


# ============================================================
# Problem-size legend
# ============================================================

from matplotlib.lines import Line2D

problem_size_legend = [
    Line2D(
        [0],
        [0],
        color="black",
        linewidth=2.5,
        linestyle="-",
        label="$m=6$",
    ),

    Line2D(
        [0],
        [0],
        color="black",
        linewidth=2.5,
        linestyle="--",
        label="$m=12$",
    ),
]

legend2 = ax.legend(
    handles=problem_size_legend,
    title="Problem size",
    loc="center right",
    bbox_to_anchor=(1, 0.55),
    fontsize=10,
    title_fontsize=11,
    frameon=True,
)

legend2.get_frame().set_alpha(0.9)

# Restore technique legend
ax.add_artist(legend)


# ============================================================
# Save
# ============================================================

plt.tight_layout()

plt.savefig(
    OUTPUT_FILE,
    dpi=300,
    bbox_inches="tight",
)

plt.show()

print(f"Saved figure to: {OUTPUT_FILE}")