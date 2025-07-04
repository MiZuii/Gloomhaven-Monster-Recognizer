import os
import tqdm
from PIL import Image, ImageOps
import numpy as np
import yaml
import json

import matplotlib.pyplot as plt
from sam2.build_sam import build_sam2
from sam2.sam2_image_predictor import SAM2ImagePredictor


LABELS_PATH = os.path.join(os.path.dirname(__file__), 'labels.json')
YOLO_CONFIG = os.path.join(os.path.dirname(__file__), 'data.yaml')
DATASET_IMAGES_DIR = os.path.join(os.path.dirname(__file__), 'dataset/images')
DATASET_MASKS_DIR = os.path.join(os.path.dirname(__file__), 'dataset/masks')

SAM2_CHECKPOINT = os.path.join(os.path.dirname(__file__),"sam2-repo/checkpoints/sam2.1_hiera_large.pt")
MODEL_CFG = "configs/sam2.1/sam2.1_hiera_l.yaml"

names_to_class_id = {}
images_to_class_id = {}

with open(YOLO_CONFIG, 'r') as f:
    data_yaml = yaml.safe_load(f)
    class_names = data_yaml['names']

    for class_id, class_name in class_names.items():
        names_to_class_id[class_name] = class_id

with open(LABELS_PATH, 'r') as f:
    labels = json.load(f)
    for label in labels:
        for image in label['files']:
            images_to_class_id[os.path.basename(image)] = names_to_class_id[label['name']]


sam2_model = build_sam2(MODEL_CFG, SAM2_CHECKPOINT, device="cuda")
predictor = SAM2ImagePredictor(sam2_model)


def show_points(coords, labels, ax, marker_size=375):
    pos_points = coords[labels==1]
    neg_points = coords[labels==0]
    ax.scatter(pos_points[:, 0], pos_points[:, 1], color='green', marker='*', s=marker_size, edgecolor='white', linewidth=1.25)
    ax.scatter(neg_points[:, 0], neg_points[:, 1], color='red', marker='*', s=marker_size, edgecolor='white', linewidth=1.25)

def run_segmentation_tool(image_path, mask_path, class_id):

    exit_flag = False

    image = Image.open(image_path)
    image = ImageOps.exif_transpose(image)

    w, h = image.size

    predictor.set_image(image)

    input_points = []
    input_labels = []
    mask = None

    fig, ax = plt.subplots(figsize=(12, 12))

    plt.axis('off')
    ax.imshow(image)

    ax.text(0.02, -0.01, f"Segmenting {class_names[class_id]} with id {class_id}", transform=ax.transAxes, fontsize=16, color='white',
                    verticalalignment='top', bbox=dict(facecolor='black', alpha=0.7, boxstyle='round,pad=0.3'))

    color = np.array([30/255, 144/255, 255/255, 0.6])

    def update_mask_and_display():
        nonlocal mask, ax
        ax.clear()

        plt.axis('off')
        ax.imshow(image)

        score_text = None
        if input_points:
            points_np = np.array(input_points)
            labels_np = np.array(input_labels)

            show_points(points_np, labels_np, ax)

            masks, scores, logits = predictor.predict(
                point_coords=points_np,
                point_labels=labels_np,
                multimask_output=True
            )

            sorted_ind = np.argsort(scores)[::-1]
            masks = masks[sorted_ind]
            scores = scores[sorted_ind]
            mask = masks[0]
            score = scores[0]
            score_text = f"Mask score: {score:.4f}"

            h_mask, w_mask = mask.shape[-2:]
            mask_uint8 = mask.astype(np.uint8)
            mask_image = mask_uint8.reshape(h_mask, w_mask, 1) * color.reshape(1, 1, -1)
            
            ax.imshow(mask_image)

        if score_text:
            ax.text(0.02, 1.033, score_text, transform=ax.transAxes, fontsize=16, color='white',
                    verticalalignment='top', bbox=dict(facecolor='black', alpha=0.7, boxstyle='round,pad=0.3'))

        ax.text(0.02, -0.01, f"Segmenting {class_names[class_id]} with id {class_id}", transform=ax.transAxes, fontsize=16, color='white',
                    verticalalignment='top', bbox=dict(facecolor='black', alpha=0.7, boxstyle='round,pad=0.3'))

        fig.canvas.draw_idle()

    def on_click(event):
        if event.inaxes != ax:
            return
        if event.button == 1:  # Left click: foreground
            input_points.append([event.xdata, event.ydata])
            input_labels.append(1)
            update_mask_and_display()
        elif event.button == 3:  # Right click: background
            input_points.append([event.xdata, event.ydata])
            input_labels.append(0)
            update_mask_and_display()

    def on_key(event):
        nonlocal exit_flag
        if event.key == 'ctrl+z' or event.key == 'control+z':
            if input_points:
                input_points.pop()
                input_labels.pop()
                update_mask_and_display()
        elif event.key == 'n':
            plt.close(fig)
        elif event.key == 'escape':
            exit_flag = True
            plt.close(fig)

    plt.connect('button_press_event', on_click)
    plt.connect('key_press_event', on_key)

    fig.canvas.manager.window.wm_geometry("+%d+%d" % (650, 50))
    plt.show()

    if mask is None:
        return exit_flag

    h_mask, w_mask = mask.shape[-2:]
    mask_uint8 = mask.astype(np.uint8)
    mask_image = mask_uint8 * (class_id + 1)
    mask_image = Image.fromarray(mask_image)
    mask_image.save(mask_path)

    return exit_flag

if __name__ == "__main__":

    SKIP_ALREADY_SEGMENTED = True

    # start the segmentation process
    for dir_name in os.listdir(DATASET_IMAGES_DIR):
        exit_flag = False
        for image_path in os.listdir(os.path.join(DATASET_IMAGES_DIR, dir_name)):
            class_id = images_to_class_id[image_path]
            mask_path = os.path.join(DATASET_MASKS_DIR, dir_name, os.path.basename(image_path))[:-4] + '.png'
            original_image_path = os.path.join(DATASET_IMAGES_DIR, dir_name, image_path)

            if SKIP_ALREADY_SEGMENTED and os.path.exists(mask_path):
                continue

            exit_flag = run_segmentation_tool(original_image_path, mask_path, class_id)

            if exit_flag:
                break
        if exit_flag:
            break