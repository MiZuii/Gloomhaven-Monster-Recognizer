import os
import shutil
import ultralytics
import json

RUNS_PATH  = os.path.join( os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)), "model", "gloomhaven-monster-recognizer")
TARGET_DIR = os.path.join( os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)), "app", "gloomhaven_monster_recognizer_app", "assets", "models")
LABELS_DIR = os.path.join( os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)), "model")

def main():

    with open(os.path.join(LABELS_DIR, 'labels.json'), 'r') as file:
        labels = json.load(file)

    with open(os.path.join(TARGET_DIR, 'labels.txt'), 'w') as file:
        for label in map(lambda e : e['name'], labels):
            file.write(label + '\n')

    runs = [ rn for rn in os.listdir(RUNS_PATH)]

    # get the latest run
    latest_run = max(runs, key=lambda x: os.path.getmtime(os.path.join(RUNS_PATH, x)))

    # export the model to the app asset
    model = ultralytics.YOLO(os.path.join(RUNS_PATH, latest_run, "weights", "best.pt"))
    model.export(format="tflite", nms=True)
    model.export(format="coreml", nms=True)

    # rename and move models to assets
    shutil.copy(os.path.join(RUNS_PATH, latest_run, "weights", "best_saved_model", "best_float32.tflite"), os.path.join(TARGET_DIR, "gmr-yolo11s-seg.tflite"))
    shutil.copy(os.path.join(RUNS_PATH, latest_run, "weights", "best.mlpackage", "Data", "com.apple.CoreML", "model.mlmodel"), os.path.join(TARGET_DIR, "gmr-yolo11s-seg.mlmodel"))


if __name__ == "__main__":
    main()