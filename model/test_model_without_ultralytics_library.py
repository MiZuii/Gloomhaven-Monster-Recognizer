import os
import random
import cv2
import numpy as np
import tensorflow as tf

TEST_DIR   = os.path.join(os.path.dirname(__file__), "dataset", "images", "test")
TEST_FILES = os.listdir(TEST_DIR)
RUNS_PATH  = os.path.join(os.path.dirname(__file__), "gloomhaven-monster-recognizer")


runs = [ rn for rn in os.listdir(RUNS_PATH)]
latest_run = max(runs, key=lambda x: os.path.getmtime(os.path.join(RUNS_PATH, x)))
model_path = os.path.join(RUNS_PATH, latest_run, "weights", "best_saved_model", "best_float32.tflite")

interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Load and preprocess the first test image
# img_path = os.path.join(TEST_DIR, TEST_FILES[random.randint(0, 100)])
img_path = "testimg.jpg"
img = cv2.imread(img_path)
if img is None:
    raise FileNotFoundError(f"Image not found: {img_path}")

# Preprocess image like in ultralytics
shape = img.shape[:2]  # current shape [height, width]
new_shape = (640, 640)

# Scale ratio (new / old)
r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
r = min(r, 1.0)  # only scale down, do not scale up

# Compute padding
new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
dw, dh = new_shape[1] - new_unpad[0], new_shape[0] - new_unpad[1]  # wh padding
dw /= 2  # divide padding into 2 sides
dh /= 2

if shape[::-1] != new_unpad:  # resize
    img_resized = cv2.resize(img, new_unpad, interpolation=cv2.INTER_LINEAR)
else:
    img_resized = img.copy()

top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
img_padded = cv2.copyMakeBorder(img_resized, top, bottom, left, right, cv2.BORDER_CONSTANT, value=(114, 114, 114))

img_rgb = cv2.cvtColor(img_padded, cv2.COLOR_BGR2RGB)
img_norm = img_rgb.astype(np.float32) / 255.0

# Set tensor
interpreter.set_tensor(input_details[0]['index'], [img_norm])
interpreter.invoke()

# Get detection output (NMS already applied by model)
det_output = interpreter.get_tensor(output_details[0]['index'])

print("Detection output shape:", det_output.shape)

boxes_list = []
confidences = []
class_ids = []

for x1, y1, x2, y2, conf, class_id in det_output[0]:
    if conf > 0.5:
        # Convert from normalized (0-1) to padded image coordinates
        x1_padded = x1 * new_shape[1]
        x2_padded = x2 * new_shape[1]
        y1_padded = y1 * new_shape[0]
        y2_padded = y2 * new_shape[0]

        # Remove padding and scale back to original image
        x1_unpad = (x1_padded - dw) / r
        x2_unpad = (x2_padded - dw) / r
        y1_unpad = (y1_padded - dh) / r
        y2_unpad = (y2_padded - dh) / r

        # Convert to int and clamp to image size
        x1_abs = int(max(x1_unpad, 0))
        y1_abs = int(max(y1_unpad, 0))
        x2_abs = int(min(x2_unpad, img.shape[1]))
        y2_abs = int(min(y2_unpad, img.shape[0]))

        print(f"Box: x={x1_abs}, y={y1_abs}, x2={x2_abs}, y2={y2_abs}, conf={conf:.2f}, class={class_id}")
        cv2.rectangle(img, (x1_abs, y1_abs), (x2_abs, y2_abs), (0, 255, 0), 2)
        label = f"{class_id}: {conf:.2f}"
        cv2.putText(img, label, (x1_abs, max(y1_abs-10, 0)), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0,255,0), 2)

# Show the image with bounding boxes
# preview = cv2.resize(img, (min(720, img.shape[1]), min(1280, img.shape[0])))
preview = cv2.resize(img, (min(1280, img.shape[1]), min(720, img.shape[0])))
cv2.imshow('Detections', preview)
cv2.waitKey(0)
cv2.destroyAllWindows()
