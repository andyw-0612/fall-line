#!/usr/bin/env python3
"""Refine Vision cutouts without regenerating or recoloring product details.

Uniform studio backgrounds use conservative border-connected color extraction.
This avoids Vision occasionally mistaking a pale sole for background. Textured
and gradient backgrounds use the foreground model. Originals are read-only.
Requires Pillow, NumPy, OpenCV; these are preparation tools, not app dependencies.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def clean_image(original, cutout):
    rgb = np.asarray(original.convert('RGB'))
    h, w = rgb.shape[:2]
    size = max(3, min(h, w) // 30)
    patches = [rgb[:size, :size], rgb[:size, -size:], rgb[-size:, :size], rgb[-size:, -size:]]
    corners = np.array([np.median(p.reshape(-1, 3), axis=0) for p in patches])
    background = np.median(corners, axis=0)
    uniform = np.max(np.abs(corners - background)) <= 8 and max(float(np.std(p, axis=(0, 1)).max()) for p in patches) < 8
    if uniform:
        distance = np.max(np.abs(rgb.astype(np.float32) - background), axis=2)
        # Only the flat backdrop and a narrow edge transition are changed.
        # A white shoe's outlines and gray sole details retain their source pixels.
        tolerance = 2.0
        transition = 4.0
        candidates = (distance <= tolerance + transition).astype(np.uint8)
        _, labels = cv2.connectedComponents(candidates, connectivity=8)
        border_labels = np.unique(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1])))
        border_labels = border_labels[border_labels != 0]
        connected = np.isin(labels, border_labels)
        alpha = np.ones((h, w), dtype=np.float32)
        alpha[connected] = np.clip((distance[connected] - tolerance) / transition, 0, 1)
        result = np.rint(rgb * alpha[..., None] + 255 * (1 - alpha[..., None])).astype(np.uint8)
        return Image.fromarray(result), 'border-connected studio background'
    return cutout.convert('RGB'), 'Vision foreground extraction'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalogue_root', type=Path)
    parser.add_argument('vision_directory', type=Path)
    parser.add_argument('output_directory', type=Path)
    args = parser.parse_args()
    catalogue = args.catalogue_root / 'data/enriched-450/catalogue.json'
    products = json.loads(catalogue.read_text())['products']
    args.output_directory.mkdir(parents=True, exist_ok=True)
    overrides_path = Path(__file__).with_name('shoe-background-overrides.json')
    overrides = json.loads(overrides_path.read_text()) if overrides_path.is_file() else {}
    records = {}
    methods = Counter()
    for product in products:
        source = (catalogue.parent / product['image_path']).resolve()
        if not source.is_relative_to((args.catalogue_root / 'data/images').resolve()):
            raise ValueError('Invalid source image path')
        destination = args.output_directory / (product['id'] + '.png')
        with Image.open(source) as original, Image.open(args.vision_directory / destination.name) as cutout:
            if original.size != cutout.size:
                raise ValueError('Image dimensions changed: ' + product['id'])
            cleaned, method = clean_image(original, cutout)
            override = overrides.get(product['id'])
            if override:
                if override['source_sha256'] != hashlib.sha256(source.read_bytes()).hexdigest():
                    raise ValueError('Review background correction for changed photo: ' + product['id'])
                from PIL import ImageDraw
                draw = ImageDraw.Draw(cleaned)
                w, h = cleaned.size
                for x0, y0, x1, y1 in override['clear_background_rectangles']:
                    draw.rectangle((round(x0*w), round(y0*h), round(x1*w)-1, round(y1*h)-1), fill='white')
                method += ' + reviewed background cleanup'
            cleaned.save(destination, optimize=True)
        methods[method] += 1
        records[product['id']] = dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            output_sha256=hashlib.sha256(destination.read_bytes()).hexdigest(), method=method, size=cleaned.size)
    manifest = dict(version=1, product_count=len(records), methods=dict(methods), products=records)
    (args.output_directory / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(json.dumps(dict(prepared=len(records), methods=dict(methods))))


if __name__ == '__main__':
    main()
