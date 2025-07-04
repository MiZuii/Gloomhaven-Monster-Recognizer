import os
import json

RAW_LABELS_PATH = os.path.join(os.path.dirname(__file__), 'raw_labels.txt')
LABELS_PATH = os.path.join(os.path.dirname(__file__), 'labels.json')


def parse_raw_labels(raw_labels_path):
    labels = {}
    current_label = None
    with open(raw_labels_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.endswith(':'):
                current_label = line[:-1]
                labels[current_label] = []
            elif current_label is not None:
                labels[current_label].append(line)
    return labels


def build_json(labels):
    data = []
    for label, files in labels.items():
        if not files:
            continue
        objects = [ f"glum_dataset/{filename}" for filename in files ]
        data.append({
            "name": label,
            "files": objects
        })
    return data


if __name__ == "__main__":
    labels = parse_raw_labels(RAW_LABELS_PATH)
    labels_json = build_json(labels)
    with open(LABELS_PATH, 'w') as f:
        json.dump(labels_json, f, indent=2)
    print(f"Wrote {len(labels_json)} labels to {LABELS_PATH}")