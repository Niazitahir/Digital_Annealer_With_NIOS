import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from matplotlib.colors import PowerNorm

# ============================================================
# Configuration
# ============================================================

INPUT_FILE = Path("UAV_comparison_results.xlsx")
OUTPUT_FILE = Path("m6_vs_m12_heatmap.png")


METHODS = [
    "Gurobi",
    "FPGA + Tabu",
    "FPGA no Tabu",
    "Heuristic",
    "Random",
]


MEAN_COLUMNS = {
    "Gurobi": "Gurobi mean (%)",
    "FPGA + Tabu": "FPGA + Tabu mean (%)",
    "FPGA no Tabu": "FPGA no Tabu mean (%)",
    "Heuristic": "Heuristic mean (%)",
    "Random": "Random mean (%)",
}


# 95% confidence interval half-widths
CI_COLUMNS = {
    "Gurobi": "Gurobi CI95 +/- (pp)",
    "FPGA + Tabu": "FPGA + Tabu CI95 +/- (pp)",
    "FPGA no Tabu": "FPGA no Tabu CI95 +/- (pp)",
    "Heuristic": "Heuristic CI95 +/- (pp)",
    "Random": "Random CI95 +/- (pp)",
}


# ============================================================
# Load data
# ============================================================

def load_results(sheet_name):

    df = pd.read_excel(
        INPUT_FILE,
        sheet_name=sheet_name,
        header=3,
    )

    # Keep only rows containing numerical time values
    df = df[
        pd.to_numeric(
            df["Time (s)"],
            errors="coerce"
        ).notna()
    ].copy()

    df["Time (s)"] = pd.to_numeric(
        df["Time (s)"]
    )

    return df


df6 = load_results("m_06")
df12 = load_results("m_12")


# ============================================================
# Build mean matrices
# ============================================================

def build_mean_matrix(df):

    return np.array([
        pd.to_numeric(
            df[MEAN_COLUMNS[method]],
            errors="coerce"
        ).values
        for method in METHODS
    ])


data6 = build_mean_matrix(df6)
data12 = build_mean_matrix(df12)


# ============================================================
# Build confidence interval matrices
# ============================================================

def build_ci_matrix(df):

    return np.array([
        pd.to_numeric(
            df[CI_COLUMNS[method]],
            errors="coerce"
        ).values
        for method in METHODS
    ])


ci6 = build_ci_matrix(df6)
ci12 = build_ci_matrix(df12)


# ============================================================
# Time labels
# ============================================================

time_labels = [
    "10 ms",
    "50 ms",
    "100 ms",
    "250 ms",
    "500 ms",
    "1 s",
    "2 s",
    "3 s",
    "5 s",

]


# ============================================================
# Shared color scale
# ============================================================

# Both problem sizes use exactly the same color scale.
#
# Therefore, the same color always corresponds to the same
# normalized hovering-energy gap.
#
# Do NOT normalize the two panels independently.

vmin = min(
    np.nanmin(data6),
    np.nanmin(data12),
)

vmax = max(
    np.nanmax(data6),
    np.nanmax(data12),
)


# ============================================================
# Figure
# ============================================================

fig, axes = plt.subplots(
    1,
    2,
    figsize=(14.5, 5.8),
    sharey=True,
    gridspec_kw={
        "wspace": 0.055,
    },
)


# ============================================================
# Heatmap helper
# ============================================================
norm = PowerNorm(
    gamma=0.8,
    vmin=vmin,
    vmax=vmax,
)

def draw_heatmap(ax, data, ci, title):

    image = ax.imshow(
        data,
        aspect="auto",
        interpolation="nearest",
        cmap="viridis_r",
        norm=norm,
    )

    # --------------------------------------------------------
    # Title
    # --------------------------------------------------------

    ax.set_title(
        title,
        fontsize=15,
        fontweight="bold",
        pad=12,
    )

    # --------------------------------------------------------
    # X axis
    # --------------------------------------------------------

    ax.set_xticks(
        np.arange(len(time_labels))
    )

    ax.set_xticklabels(
        time_labels,
        rotation=45,
        ha="right",
        fontsize=9,
    )

    ax.set_xlabel(
        "Time",
        fontsize=12,
        labelpad=8,
    )

    # --------------------------------------------------------
    # Y axis
    # --------------------------------------------------------

    ax.set_yticks(
        np.arange(len(METHODS))
    )

    ax.set_yticklabels(
        METHODS,
        fontsize=10.5,
    )

    # --------------------------------------------------------
    # Cell boundaries
    # --------------------------------------------------------

    ax.set_xticks(
        np.arange(-0.5, len(time_labels), 1),
        minor=True,
    )

    ax.set_yticks(
        np.arange(-0.5, len(METHODS), 1),
        minor=True,
    )

    ax.grid(
        which="minor",
        color="white",
        linewidth=1.2,
    )

    ax.tick_params(
        which="minor",
        bottom=False,
        left=False,
    )

    # --------------------------------------------------------
    # Remove outer frame
    # --------------------------------------------------------

    for spine in ax.spines.values():
        spine.set_visible(False)

    # --------------------------------------------------------
    # Cell values + confidence intervals
    # --------------------------------------------------------

    for i in range(data.shape[0]):

        for j in range(data.shape[1]):

            value = data[i, j]
            error = ci[i, j]

            if np.isnan(value):
                continue

            # ------------------------------------------------
            # Format mean
            # ------------------------------------------------

            if abs(value) < 1e-6:
                mean_text = "0"
            elif value < 1:
                mean_text = f"{value:.2f}"
            else:
                mean_text = f"{value:.1f}"

            # ------------------------------------------------
            # Format confidence interval
            # ------------------------------------------------

            if np.isnan(error):
                ci_text = ""
            elif error < 1:
                ci_text = f"±{error:.2f}"
            else:
                ci_text = f"±{error:.1f}"

            # ------------------------------------------------
            # Determine text color
            # ------------------------------------------------

            normalized = (
                value - vmin
            ) / (
                vmax - vmin
            )

            text_color = (
                "white"
                if normalized > 0.55
                else "black"
            )

            # ------------------------------------------------
            # Mean value
            # ------------------------------------------------

            ax.text(
                j,
                i - 0.10,
                mean_text,
                ha="center",
                va="center",
                fontsize=8.5,
                fontweight="bold",
                color=text_color,
            )

            # ------------------------------------------------
            # 95% CI half-width
            # ------------------------------------------------

            if ci_text:

                ax.text(
                    j,
                    i + 0.19,
                    ci_text,
                    ha="center",
                    va="center",
                    fontsize=6.5,
                    color=text_color,
                    alpha=0.85,
                )

    return image


# ============================================================
# Draw panels
# ============================================================

im1 = draw_heatmap(
    axes[0],
    data6,
    ci6,
    r"$m=6$",
)

draw_heatmap(
    axes[1],
    data12,
    ci12,
    r"$m=12$",
)


# ============================================================
# Shared Y axis
# ============================================================

axes[0].set_ylabel(
    "Optimization technique",
    fontsize=12,
    labelpad=10,
)


# Do not duplicate technique labels
axes[1].tick_params(
    axis="y",
    left=False,
    labelleft=False,
)


# ============================================================
# Colorbar
# ============================================================

cbar = fig.colorbar(
    im1,
    ax=axes,
    orientation="horizontal",
    fraction=0.055,
    pad=0.18,
    aspect=45,
)

cbar.set_label(
    "Normalized hovering-energy gap (%)",
    fontsize=11,
    labelpad=7,
)

cbar.ax.tick_params(
    labelsize=9,
)


# ============================================================
# Overall title
# ============================================================

fig.suptitle(
    "Optimization Convergence Across Problem Sizes",
    fontsize=16,
    fontweight="bold",
    y=0.98,
)


# ============================================================
# Layout
# ============================================================

fig.subplots_adjust(
    left=0.10,
    right=0.96,
    top=0.86,
    bottom=0.27,
    wspace=0.055,
)


# ============================================================
# Save
# ============================================================

plt.savefig(
    OUTPUT_FILE,
    dpi=400,
    bbox_inches="tight",
)

plt.show()

print(f"Saved figure to: {OUTPUT_FILE}")