import os
from ultralytics import YOLO

from ultralytics.data.converter import convert_segment_masks_to_yolo_seg

MODELS_DIR = "yolo_models"

model = YOLO(os.path.join(MODELS_DIR, "yolo11n.pt"))

results = model.train(
    data="data.yaml",
    project="gloomhaven-monster-recognizer",
    epochs=200,
    imgsz=640,
    cache=True,
    device=0,
    degrees=0.0,
    scale=0.6,
    shear=10.0)

model.save(os.path.join(MODELS_DIR, "gmr-yolo11n.pt"))