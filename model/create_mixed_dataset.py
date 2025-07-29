from functools import lru_cache
import os
import numpy as np
import cv2
import tqdm

BASIC_DATASET_PATH = os.path.join(os.path.dirname(__file__), "basic_dataset")
DATASET_PATH = os.path.join(os.path.dirname(__file__), "dataset")
SPLITS = {'train': 0.8, 'val': 0.1, 'test': 0.1}
SEED = 1

def ensure_dirs():
    for split in SPLITS.keys():
        split_dir = os.path.join(BASIC_DATASET_PATH, "images", split)
        os.makedirs(split_dir, exist_ok=True)

def load_labels(path: str) -> str:
    with open(path, 'r') as f:
        label_line = f.readline().strip().split()
        class_id = int(label_line[0])

@lru_cache(maxsize=128)
def load_image(split, name):
    src_dir  = os.path.join(BASIC_DATASET_PATH, "images", split)
    mask_dir = os.path.join(BASIC_DATASET_PATH, "masks",  split)
    return (cv2.imread(os.path.join(src_dir, name)),
            cv2.imread(os.path.join(mask_dir, name[:-4] + ".png"), cv2.IMREAD_GRAYSCALE))

def transform_dataset():
    for split in SPLITS.keys():
        if split == "train":
            continue
        src_dir  = os.path.join(BASIC_DATASET_PATH, "images", split)
        out_img_dir = os.path.join(DATASET_PATH, "images", split)
        out_mask_dir = os.path.join(DATASET_PATH, "masks", split)
        out_label_dir = os.path.join(DATASET_PATH, "labels", split)
        os.makedirs(out_img_dir, exist_ok=True)
        os.makedirs(out_mask_dir, exist_ok=True)
        os.makedirs(out_label_dir, exist_ok=True)
        avail_images = os.listdir(src_dir)
        np.random.seed(SEED)


        for mix_idx in tqdm.tqdm(range(len(avail_images))):
            img = np.zeros((4000, 2252, 3), dtype=np.uint8)
            mask = np.zeros((4000, 2252), dtype=np.uint8)
            yolo_labels = []

            perc = 0.2
            if split != "train":
                perc = 0.7

            for sub_img_idx in tqdm.tqdm(np.random.choice(len(avail_images), int(perc*len(avail_images)), replace=False)):
                for _ in range(3): # repeat three times to increase density of validation images
                    sub_img, sub_img_mask = load_image(split, avail_images[sub_img_idx])
                    class_id = sub_img_mask[sub_img_mask > 0][0] - 1

                    scale = 5.5 + np.random.rand()
                    new_w = int(sub_img.shape[1] / scale)
                    new_h = int(sub_img.shape[0] / scale)
                    scaled_img = cv2.resize(sub_img, (new_w, new_h), interpolation=cv2.INTER_AREA)
                    scaled_mask = cv2.resize(sub_img_mask, (new_w, new_h), interpolation=cv2.INTER_NEAREST)
                    
                    # Random rotation
                    angle = np.random.uniform(0, 360)
                    center = (new_w // 2, new_h // 2)
                    rot_mat = cv2.getRotationMatrix2D(center, angle, 1.0)
                    rotated_img = cv2.warpAffine(scaled_img, rot_mat, (new_w, new_h), flags=cv2.INTER_LINEAR, borderValue=(0,0,0))
                    rotated_mask = cv2.warpAffine(scaled_mask, rot_mat, (new_w, new_h), flags=cv2.INTER_NEAREST, borderValue=0)
                    
                    # Random placement with validation
                    max_x = img.shape[1] - new_w
                    max_y = img.shape[0] - new_h
                    if max_x <= 0 or max_y <= 0:
                        continue
                    
                    # Try up to 10 times to find a valid placement
                    valid_placement = False
                    for _ in range(10):
                        x0 = np.random.randint(0, max_x)
                        y0 = np.random.randint(0, max_y)
                        
                        # Check if placement covers enough clear background
                        region = (rotated_mask > 0)
                        if not np.any(region):
                            continue
                        
                        # Get the background area that would be covered
                        background_region = mask[y0:y0+new_h, x0:x0+new_w]
                        clear_background_pixels = np.sum((background_region == 0) & region)
                        total_region_pixels = np.sum(region)
                        
                        if total_region_pixels > 0 and clear_background_pixels / total_region_pixels >= 0.5:
                            valid_placement = True
                            break
                    
                    # Skip this image if no valid placement found
                    if not valid_placement:
                        continue
                    
                    # Paste masked region
                    img[y0:y0+new_h, x0:x0+new_w][region] = rotated_img[region]
                    mask[y0:y0+new_h, x0:x0+new_w][region] = class_id + 1  # avoid 0 as background
                    
                    # Bounding box for YOLO
                    ys, xs = np.where(region)
                    if len(xs) == 0 or len(ys) == 0:
                        continue
                    x_min = x0 + xs.min()
                    x_max = x0 + xs.max()
                    y_min = y0 + ys.min()
                    y_max = y0 + ys.max()
                    x_center = (x_min + x_max) / 2 / img.shape[1]
                    y_center = (y_min + y_max) / 2 / img.shape[0]
                    w = (x_max - x_min) / img.shape[1]
                    h = (y_max - y_min) / img.shape[0]
                    yolo_labels.append(f"{class_id} {x_center:.6f} {y_center:.6f} {w:.6f} {h:.6f}")

                    if split == "train":
                        break

            # Save outputs
            out_img_name = f"mix_{mix_idx:04d}.jpg"
            out_mask_name = f"mix_{mix_idx:04d}.png"
            out_label_name = f"mix_{mix_idx:04d}.txt"
            cv2.imwrite(os.path.join(out_img_dir, out_img_name), img)
            cv2.imwrite(os.path.join(out_mask_dir, out_mask_name), mask)
            with open(os.path.join(out_label_dir, out_label_name), 'w') as f:
                f.write("\n".join(yolo_labels))


if __name__ == '__main__':
    ensure_dirs()
    transform_dataset()