#!/usr/bin/env python3
"""Package the public catalogue and runtime; credentials are never copied."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

source, destination = map(Path, sys.argv[1:3])
catalogue = source / 'data/enriched-450/catalogue.json'
data = json.loads(catalogue.read_text())
if len(data['products']) != 450:
    raise SystemExit('Expected the complete 450-shoe catalogue.')
destination.mkdir(parents=True, exist_ok=True)
(destination / 'vendor/demo/prompts').mkdir(parents=True, exist_ok=True)
(destination / 'data/enriched-450').mkdir(parents=True, exist_ok=True)
(destination / 'data/images').mkdir(parents=True, exist_ok=True)
(destination / 'data/images-white').mkdir(parents=True, exist_ok=True)
white_images = Path(__file__).resolve().parent.parent / 'Resources/CatalogueWhiteImages'
image_manifest = json.loads((white_images / 'manifest.json').read_text())
if image_manifest['product_count'] != len(data['products']):
    raise SystemExit('Prepare the complete white-background image set before building.')
for filename in ['ai_ranker.py', 'catalogue_filters.py', 'discovery.py', 'product_info.py']:
    shutil.copy2(source / 'demo' / filename, destination / 'vendor/demo' / filename)
shutil.copy2(source / 'enrich.py', destination / 'vendor/enrich.py')
shutil.copy2(source / 'demo/prompts/rank-and-profile.txt', destination / 'vendor/demo/prompts/rank-and-profile.txt')
shutil.copy2(catalogue, destination / 'data/enriched-450/catalogue.json')
for product in data['products']:
    image = (catalogue.parent / product['image_path']).resolve()
    if not image.is_relative_to((source / 'data/images').resolve()) or not image.is_file():
        raise SystemExit('Missing or invalid catalogue image: ' + product['id'])
    shutil.copy2(image, destination / 'data/images' / image.name)
    cleaned = white_images / (product['id'] + '.png')
    prepared = image_manifest['products'].get(product['id'], {})
    if prepared.get('source_sha256') != hashlib.sha256(image.read_bytes()).hexdigest():
        raise SystemExit('White-background image needs refreshing: ' + product['id'])
    if not cleaned.is_file() or prepared.get('output_sha256') != hashlib.sha256(cleaned.read_bytes()).hexdigest():
        raise SystemExit('Missing or modified white-background image: ' + product['id'])
    shutil.copy2(cleaned, destination / 'data/images-white' / cleaned.name)
shutil.copy2(Path(__file__).resolve().parent.parent / 'catalogue/bridge.py', destination / 'bridge.py')
(destination / 'source-location.txt').write_text(str(source.resolve()))
identity = data['metadata'].get('dataset_id') or hashlib.sha256(catalogue.read_bytes()).hexdigest()[:20]
(destination / 'manifest.json').write_text(json.dumps({'dataset_id': identity, 'product_count': len(data['products'])}))
print('Packaged 450 shoes, original and white-background images, and the catalogue recommendation runtime.')
