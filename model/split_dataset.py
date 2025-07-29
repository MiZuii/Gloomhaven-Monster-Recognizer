import os
import json
import random
import shutil
import tqdm
from pathlib import Path

# Config
LABELS_PATH = 'labels.json'
GLUM_DATASET_DIR = 'glum_dataset'
DATASET_IMAGES_DIR = 'basic_dataset/images'
DATASET_MASKS_DIR = 'basic_dataset/masks'
SPLITS = {'train': 0.8, 'val': 0.1, 'test': 0.1}
SEED = 1

# Ensure reproducibility
random.seed(SEED)

# Read class names from data.yaml
import yaml
with open('data.yaml', 'r') as f:
    data_yaml = yaml.safe_load(f)
    class_names = data_yaml['names']

# Read labels.json
with open(LABELS_PATH, 'r') as f:
    labels = json.load(f)

# Prepare split directories
def ensure_dirs():
    for split in SPLITS.keys():
        split_dir = os.path.join(DATASET_IMAGES_DIR, split)
        os.makedirs(split_dir, exist_ok=True)
        split_mask_dir = os.path.join(DATASET_MASKS_DIR, split)
        os.makedirs(split_mask_dir, exist_ok=True)

# Split and copy images
def split_and_copy():
    for class_name, images in tqdm.tqdm(labels.items()):
        random.shuffle(images)
        n = len(images)

        n_val = max(1,int(n * SPLITS['val']))
        n_test = max(1,int(n * SPLITS['test']))
        n_train = n - n_test - n_val

        split_counts = {'train': n_train, 'val': n_val, 'test': n_test}
        split_images = {
            'train': images[:n_train],
            'val': images[n_train:n_train+n_val],
            'test': images[n_train+n_val:]
        }
        for split, split_imgs in split_images.items():
            for img_rel_path in split_imgs:
                img_name = os.path.basename(img_rel_path)
                src_path = os.path.join(GLUM_DATASET_DIR, img_name)
                dst_path = os.path.join(DATASET_IMAGES_DIR, split, img_name)
                if not os.path.exists(src_path):
                    print(f"Warning: {src_path} does not exist!")
                    continue
                shutil.copy2(src_path, dst_path)

if __name__ == '__main__':
    ensure_dirs()
    split_and_copy()