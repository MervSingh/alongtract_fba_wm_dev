#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import numpy as np
import nibabel as nib
import dipy.tracking.streamline as dts
from dipy.segment.clustering import QuickBundles
from dipy.segment.metric import AveragePointwiseEuclideanMetric
import traceback

# Setup
tract_root = '/Users/mervynsingh/Desktop/ALONG_TRACT/template_tractseg_new/segmentations/NEW'

# Metric and clustering model
metric = AveragePointwiseEuclideanMetric()
qb = QuickBundles(np.inf, metric=metric)

def resample_streamlines(streamlines, nb_points=20):
    return [dts.set_number_of_points(sl, nb_points=nb_points) for sl in streamlines]

# Quick test: Can we write a file?
try:
    with open(os.path.join(tract_root, "write_test.txt"), "w") as f:
        f.write("Write test passed.")
    print("✅ Write test passed.\n")
except Exception as e:
    print(f"❌ Write test failed: {e}")
    exit()

# Recursively find and process all .tck files
print("🔍 Searching for .tck files...\n")
found = False
for dirpath, _, filenames in os.walk(tract_root):
    tck_files = [f for f in filenames if f.endswith('.tck')]
    for tck_file in tck_files:
        found = True
        tck_path = os.path.join(dirpath, tck_file)
        base = os.path.splitext(tck_file)[0]
        trk_path = os.path.join(dirpath, base + '.trk')
        centroid_output = os.path.join(dirpath, 'centroid-0.txt') 

        print(f"📂 Processing: {tck_path}")
        try:
            # Load and convert
            tck = nib.streamlines.load(tck_path)
            nib.streamlines.save(tck.tractogram, trk_path)

            # Load .trk streamlines
            streamlines = nib.streamlines.load(trk_path).tractogram.streamlines
            print(f"   👉 Loaded {len(streamlines)} streamlines")

            if len(streamlines) == 0:
                print("   ⚠️ No streamlines found, skipping")
                continue

            # Resample & cluster
            resampled = resample_streamlines(streamlines, nb_points=20)
            clusters = qb.cluster(resampled)
            print(f"   ✅ Found {len(clusters)} clusters")

            if len(clusters) > 0:
                np.savetxt(centroid_output, clusters[0].centroid)
                print(f"   ✏️ Saved centroid: {centroid_output}")
            else:
                print("   ⚠️ No clusters to save.")

        except Exception as e:
            print(f"   ❌ Error processing {tck_file}: {e}")
            traceback.print_exc()

if not found:
    print("❌ No .tck files found in or under:", tract_root)
