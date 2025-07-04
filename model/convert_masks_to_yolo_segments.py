import os
import cv2
import numpy as np

DATASET_DIR = "dataset"
MASKS_DIR = os.path.join(DATASET_DIR, "masks")
OUTPUT_DIR = os.path.join(DATASET_DIR, "labels")

from ultralytics.data.converter import convert_segment_masks_to_yolo_seg

for dir_name in os.listdir(MASKS_DIR):
    out_dir = os.path.join(OUTPUT_DIR, dir_name)
    os.makedirs(out_dir, exist_ok=True)
    convert_segment_masks_to_yolo_seg(os.path.join(MASKS_DIR, dir_name), out_dir, classes=47)
