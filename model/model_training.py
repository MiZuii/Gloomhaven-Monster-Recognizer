import os
from ultralytics import YOLO

from ultralytics.data.converter import convert_segment_masks_to_yolo_seg

MODELS_DIR = "yolo_models"

model = YOLO(os.path.join(MODELS_DIR, "yolo11s-seg.pt"))

results = model.train(
    data="data.yaml",
    project="gloomhaven-monster-recognizer",
    epochs=100,
    imgsz=640,
    cache=True,
    device=0,
    degrees=180.0,
    scale=0.3,
    shear=10.0,
    cutmix=1,
    copy_paste=1,
    copy_paste_mode="mixup",)

model.save(os.path.join(MODELS_DIR, "gmr-yolo11s-seg.pt"))