# =========================================================
# PUBLICATION-STYLE COLORBARS (FIXED)
# =========================================================

import matplotlib.pyplot as plt
import matplotlib as mpl
import numpy as np

# =========================================================
# SETTINGS
# =========================================================

vmin = -0.03
vmax =  0.03

ticks = np.linspace(vmin, vmax, 7)

# Blue → White → Red
cmap = mpl.cm.coolwarm

# Center at zero
norm = mpl.colors.TwoSlopeNorm(
    vmin=vmin,
    vcenter=0,
    vmax=vmax
)

# =========================================================
# VERTICAL COLORBAR
# =========================================================

fig = plt.figure(figsize=(2.5, 8))

# IMPORTANT:
# Explicit axis position for colorbar
ax = fig.add_axes([0.25, 0.05, 0.28, 0.9])

# Create colorbar
cb = mpl.colorbar.ColorbarBase(
    ax,
    cmap=cmap,
    norm=norm,
    orientation='vertical',
    ticks=ticks
)

# Label
cb.set_label(
    'Age Effect (Estimate)',
    fontsize=28,
    rotation=90,
    labelpad=35
)

# Tick styling
cb.ax.tick_params(
    labelsize=24,
    width=2.5,
    length=16,
    pad=12
)

# Border thickness
cb.outline.set_linewidth(2.5)

# Save
plt.savefig(
    "/PATH/TO/OUTPUT/vertical_colorbar.png",
    dpi=600,
    bbox_inches='tight',
    transparent=True
)

plt.show()

# =========================================================
# HORIZONTAL COLORBAR
# =========================================================

fig = plt.figure(figsize=(8, 2.5))

# IMPORTANT:
# Explicit axis position
ax = fig.add_axes([0.08, 0.45, 0.84, 0.22])

# Create horizontal colorbar
cb = mpl.colorbar.ColorbarBase(
    ax,
    cmap=cmap,
    norm=norm,
    orientation='horizontal',
    ticks=ticks
)

# Label
cb.set_label(
    'Age Effect (Estimate)',
    fontsize=24,
    labelpad=15
)

# Tick styling
cb.ax.tick_params(
    labelsize=20,
    width=2.5,
    length=10,
    pad=8
)

# Border thickness
cb.outline.set_linewidth(2.5)

# Save
plt.savefig(
    "/PATH/TO/OUTPUT/horizontal_colorbar.png",
    dpi=600,
    bbox_inches='tight',
    transparent=True
)

plt.show()