#!/usr/bin/env python3
"""Describe a balanced shoe sample with Gemini and embed each aspect separately."""
import argparse
import base64
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
import mimetypes
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
ASPECTS = ("color", "shape", "style")
DESCRIPTION_MODEL = "gemini-3.5-flash-lite"
EMBEDDING_MODEL = "gemini-embedding-2"
DIMENSIONS = 768
EMBEDDING_PREFIX = "task: sentence similarity | query: "
API = "https://generativelanguage.googleapis.com/v1beta"
SHAPE_COLOR_WORDS = re.compile(r"\b(?:off-white|navy blue|light blue|dark blue|forest-green|red|blue|black|white|green|yellow|pink|purple|orange|brown|grey|gray|cream|beige|silver|gold|navy|tan|burgundy)\b", re.IGNORECASE)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n")
    temporary.replace(path)


def read_key():
    values = dict(os.environ)
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            name, separator, value = line.strip().partition("=")
            if separator and name in {"GEMINI_API_KEY", "GOOGLE_API_KEY"} and not values.get(name):
                values[name] = value.strip().strip("\"'")
    for name in ["GEMINI_API_KEY", "GOOGLE_API_KEY"]:
        key = values.get(name, "").strip()
        if key and "replace_with" not in key:
            return key
    raise ValueError("Add GEMINI_API_KEY to catalogue/.env first. The SerpApi key cannot authenticate Gemini.")


def select_sample(products, limit, data_root):
    buckets = defaultdict(list)
    for product in products:
        relative = product.get("image_path")
        if relative and (data_root / relative).is_file():
            queries = product.get("discovery_queries") or ["other"]
            buckets[queries[0]].append(product)
    limit = min(limit, sum(map(len, buckets.values())))
    allocations = {key: 0 for key in buckets}
    while sum(allocations.values()) < limit:
        for key, bucket in buckets.items():
            if allocations[key] < len(bucket) and sum(allocations.values()) < limit:
                allocations[key] += 1
    selected = []
    groups = []
    for key, bucket in buckets.items():
        bucket = sorted(bucket, key=lambda item: (item["price"], item["id"]))
        count = allocations[key]
        if count == 1:
            groups.append([bucket[len(bucket) // 2]])
        elif count > 1:
            groups.append([bucket[round(index * (len(bucket) - 1) / (count - 1))] for index in range(count)])
    for index in range(max(map(len, groups), default=0)):
        selected.extend(group[index] for group in groups if index < len(group))
    return selected


def description_request(image_bytes, mime_type, prompt, model=DESCRIPTION_MODEL):
    schema = {
        "type": "object", "properties": {name: {"type": "string"} for name in ASPECTS},
        "required": list(ASPECTS), "additionalProperties": False,
    }
    thinking = {"thinkingBudget": 0} if model.startswith("gemini-2.5-") else {"thinkingLevel": "low"}
    return {
        "contents": [{"role": "user", "parts": [
            {"text": prompt},
            {"inlineData": {"mimeType": mime_type, "data": base64.b64encode(image_bytes).decode()}},
        ]}],
        "generationConfig": {
            "responseMimeType": "application/json", "responseJsonSchema": schema,
            "thinkingConfig": thinking, "maxOutputTokens": 4096,
        },
    }


def parse_generation_json(payload):
    candidates = payload.get("candidates", [])
    if not candidates:
        raise ValueError("Gemini returned no description candidate.")
    candidate = candidates[0]
    if candidate.get("finishReason") != "STOP":
        raise ValueError(f"Description did not complete: {candidate.get('finishReason', 'unknown')}")
    parts = candidate.get("content", {}).get("parts", [])
    text = "".join(part.get("text", "") for part in parts if not part.get("thought"))
    return json.loads(text)


def validate_descriptions(result):
    if not isinstance(result, dict) or set(result) != set(ASPECTS):
        raise ValueError("Description must contain exactly color, shape, and style.")
    for aspect, value in result.items():
        if not isinstance(value, str) or not 8 <= len(value.strip()) <= 650:
            raise ValueError(f"Invalid {aspect} description length or type.")
        result[aspect] = value.strip()
    return result


def parse_descriptions(payload):
    return validate_descriptions(parse_generation_json(payload))


def isolate_shape(descriptions):
    cleaned = dict(descriptions)
    # Shape feedback must not carry explicit color preferences. Preserve the
    # unedited model response in the cache and record any edits in provenance.
    cleaned["shape"] = " ".join(SHAPE_COLOR_WORDS.sub("", cleaned["shape"]).split())
    return validate_descriptions(cleaned)


def normalize_vector(values, dimensions=DIMENSIONS):
    if not isinstance(values, list) or len(values) != dimensions:
        raise ValueError(f"Expected a {dimensions}-dimensional embedding.")
    if any(isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value) for value in values):
        raise ValueError("Embedding contains invalid numbers.")
    length = math.sqrt(sum(value * value for value in values))
    if length < 1e-10:
        raise ValueError("Embedding has zero length.")
    return [value / length for value in values]


class GeminiClient:
    def __init__(self, key, interval=1.0):
        self.key = key
        self.interval = interval
        self.last_request = 0.0
        self.requests = 0
        self.usage = Counter()

    def post(self, model, method, body):
        for attempt in range(4):
            remaining = self.interval - (time.monotonic() - self.last_request)
            if remaining > 0:
                time.sleep(remaining)
            request = Request(f"{API}/models/{model}:{method}", data=json.dumps(body).encode(), method="POST",
                              headers={"Content-Type": "application/json", "x-goog-api-key": self.key})
            self.last_request = time.monotonic()
            self.requests += 1
            try:
                with urlopen(request, timeout=120) as response:
                    payload = json.load(response)
                for name, value in payload.get("usageMetadata", {}).items():
                    if isinstance(value, int):
                        self.usage[f"{model}:{name}"] += value
                return payload
            except HTTPError as error:
                raw = error.read().decode(errors="replace").replace(self.key, "[REDACTED]")
                try:
                    detail = json.loads(raw).get("error", {})
                    message = detail.get("message", f"HTTP {error.code}")
                except ValueError:
                    detail, message = {}, f"HTTP {error.code}"
                if error.code in {429, 500, 502, 503, 504} and attempt < 3:
                    delay = min(60, 10 * (2 ** attempt))
                    for item in detail.get("details", []):
                        retry = re.fullmatch(r"([\d.]+)s", str(item.get("retryDelay", "")))
                        if retry:
                            delay = min(60, max(delay, float(retry.group(1)) + 1))
                    print(f"Gemini HTTP {error.code}: {message[:180]} Retrying in {delay:g}s.", flush=True)
                    time.sleep(delay)
                    continue
                raise ValueError(f"Gemini {model}: {message}") from None
            except (URLError, TimeoutError):
                raise ValueError("Gemini request failed or timed out. Completed work is cached; rerun to resume.") from None


def describe_product(product, data_root, prompt, model, cache, client):
    image = data_root / product["image_path"]
    image_bytes = image.read_bytes()
    fingerprint = {"model": model, "prompt": prompt, "image_sha256": hashlib.sha256(image_bytes).hexdigest()}
    cache_file = cache / "descriptions" / (digest(fingerprint) + ".json")
    if cache_file.exists():
        return json.loads(cache_file.read_text())
    mime_type = product.get("image_content_type") or mimetypes.guess_type(image.name)[0]
    if mime_type not in {"image/jpeg", "image/png", "image/webp", "image/gif", "image/avif"}:
        raise ValueError(f"Unsupported image type for product {product['id']}")
    response = client.post(model, "generateContent", description_request(image_bytes, mime_type, prompt, model))
    result = {"descriptions": parse_descriptions(response), "model": model,
              "model_version": response.get("modelVersion"), "image_sha256": fingerprint["image_sha256"],
              "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(), "usage": response.get("usageMetadata", {})}
    write_json(cache_file, result)
    return result


def describe_batch(products, data_root, prompt, model, cache, client):
    results, pending = {}, []
    for product in products:
        image_bytes = (data_root / product["image_path"]).read_bytes()
        image_hash = hashlib.sha256(image_bytes).hexdigest()
        fingerprint = {"model": model, "prompt": prompt, "image_sha256": image_hash}
        cache_file = cache / "descriptions" / (digest(fingerprint) + ".json")
        if cache_file.exists():
            result = json.loads(cache_file.read_text())
            validate_descriptions(result["descriptions"])
            results[product["id"]] = result
        else:
            pending.append((product, image_bytes, image_hash, cache_file))
    if not pending:
        return results
    batch_prompt = prompt + "\n\nBATCH RESPONSE FORMAT: Apply the aspect rules and examples independently to EACH labeled image below. " \
        "The three-field instruction above refers to each shoe's aspects. For this batch, return a JSON object with a products array. " \
        "Each array entry must have exactly id, color, shape, and style. Copy the image's id exactly. Include every labeled shoe once. " \
        "Keep each description grounded in its own image; never transfer a detail from another image."
    parts = [{"text": batch_prompt}]
    for product, image_bytes, _, _ in pending:
        mime_type = product.get("image_content_type") or mimetypes.guess_type(product["image_path"])[0]
        parts.extend([{"text": f"Product id: {product['id']}"},
                      {"inlineData": {"mimeType": mime_type, "data": base64.b64encode(image_bytes).decode()}}])
    entry = {"type": "object", "properties": {"id": {"type": "string", "enum": [product["id"] for product, _, _, _ in pending]},
             **{aspect: {"type": "string"} for aspect in ASPECTS}}, "required": ["id", *ASPECTS], "additionalProperties": False}
    body = {"contents": [{"role": "user", "parts": parts}], "generationConfig": {
        "responseMimeType": "application/json", "responseJsonSchema": {
            "type": "object", "properties": {"products": {"type": "array", "items": entry}},
            "required": ["products"], "additionalProperties": False},
        "thinkingConfig": {"thinkingLevel": "low"}, "maxOutputTokens": 8192}}
    response = client.post(model, "generateContent", body)
    entries = parse_generation_json(response).get("products", [])
    by_id = {entry.get("id"): entry for entry in entries}
    if len(entries) != len(pending) or set(by_id) != {product["id"] for product, _, _, _ in pending}:
        raise ValueError("Description batch IDs do not match the labeled input images.")
    validated = {identity: validate_descriptions({key: value for key, value in entry.items() if key != "id"})
                 for identity, entry in by_id.items()}
    for product, _, image_hash, cache_file in pending:
        result = {"descriptions": validated[product["id"]], "model": model, "model_version": response.get("modelVersion"),
                  "image_sha256": image_hash, "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
                  "batch_prompt_sha256": hashlib.sha256(batch_prompt.encode()).hexdigest(), "batch_size": len(pending),
                  "batch_usage": response.get("usageMetadata", {})}
        write_json(cache_file, result)
        results[product["id"]] = result
    return results


def embed_products(products, model, dimensions, cache, client, batch_size=30):
    missing = {}
    for product in products:
        product["embeddings"] = {}
        for aspect in ASPECTS:
            text = EMBEDDING_PREFIX + product["descriptions"][aspect]
            identity = digest({"model": model, "dimensions": dimensions, "text": text})
            path = cache / "embeddings" / (identity + ".json")
            if path.exists():
                product["embeddings"][aspect] = normalize_vector(json.loads(path.read_text())["values"], dimensions)
            else:
                entry = missing.setdefault(identity, {"text": text, "path": path, "targets": []})
                entry["targets"].append((product, aspect))
    entries = list(missing.values())
    for start in range(0, len(entries), batch_size):
        batch = entries[start:start + batch_size]
        requests = [{"model": f"models/{model}", "content": {"parts": [{"text": entry["text"]}]},
                     "outputDimensionality": dimensions} for entry in batch]
        payload = client.post(model, "batchEmbedContents", {"requests": requests})
        embeddings = payload.get("embeddings", [])
        if len(embeddings) != len(batch):
            raise ValueError("Embedding response count does not match the separate aspect inputs.")
        vectors = [normalize_vector(embedding.get("values"), dimensions) for embedding in embeddings]
        for entry, vector in zip(batch, vectors):
            write_json(entry["path"], {"model": model, "dimensions": dimensions, "text": entry["text"], "values": vector})
            for product, aspect in entry["targets"]:
                product["embeddings"][aspect] = vector
        print(f"Embedded {min(start + batch_size, len(entries))}/{len(entries)} new unique aspect descriptions.", flush=True)


def similarity_report(products):
    examples = []
    anchors = [products[round(index * (len(products) - 1) / min(7, len(products) - 1))]
               for index in range(min(8, len(products)))] if len(products) > 1 else []
    for anchor in anchors:
        for aspect in ASPECTS:
            vector = anchor["embeddings"][aspect]
            neighbors = sorted(({
                "id": candidate["id"], "title": candidate["title"],
                "description": candidate["descriptions"][aspect],
                "cosine": sum(a * b for a, b in zip(vector, candidate["embeddings"][aspect])),
            } for candidate in products if candidate["id"] != anchor["id"]), key=lambda row: row["cosine"], reverse=True)[:3]
            examples.append({"id": anchor["id"], "title": anchor["title"], "aspect": aspect,
                             "description": anchor["descriptions"][aspect], "neighbors": neighbors})
    return examples


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalogue", type=Path, default=ROOT / "data/catalogue.json")
    parser.add_argument("--output", type=Path, default=ROOT / "data/enriched-450")
    parser.add_argument("--limit", type=int, default=450)
    parser.add_argument("--description-model", default=DESCRIPTION_MODEL)
    parser.add_argument("--embedding-model", default=EMBEDDING_MODEL)
    parser.add_argument("--dimensions", type=int, default=DIMENSIONS)
    parser.add_argument("--description-batch-size", type=int, default=5, help="Images per synchronous description request.")
    parser.add_argument("--embedding-batch-size", type=int, default=20, help="Separate aspect inputs per synchronous embedding request.")
    parser.add_argument("--interval", type=float, default=13.0, help="Minimum seconds between API request starts.")
    parser.add_argument("--plan", action="store_true", help="Write the sample manifest without calling Gemini.")
    args = parser.parse_args()
    if args.limit < 1 or args.dimensions not in {768, 1536, 3072} or args.interval < 0:
        parser.error("Use a positive limit, dimensions 768/1536/3072, and a nonnegative interval.")
    if not 1 <= args.description_batch_size <= 10:
        parser.error("--description-batch-size must be between 1 and 10.")
    if not 1 <= args.embedding_batch_size <= 100:
        parser.error("--embedding-batch-size must be between 1 and 100.")
    if args.embedding_model != EMBEDDING_MODEL:
        parser.error("This pipeline uses Gemini Embedding 2 formatting. Do not mix models within this space.")
    source = json.loads(args.catalogue.read_text())
    selected = select_sample(source["products"], args.limit, args.catalogue.parent)
    if len(selected) != args.limit:
        raise ValueError(f"Only {len(selected)} products with local images are available for the requested {args.limit}.")
    prompt = (ROOT / "prompts/describe-shoe.txt").read_text()
    manifest = {"product_count": len(selected), "embedding_count": len(selected) * len(ASPECTS),
                "description_model": args.description_model, "embedding_model": args.embedding_model,
                "dimensions": args.dimensions, "embedding_format": EMBEDDING_PREFIX,
                "description_batch_size": args.description_batch_size,
                "embedding_batch_size": args.embedding_batch_size,
                "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
                "sampling": "Equal query coverage with price quantiles inside each query bucket",
                "queries": dict(Counter((product.get("discovery_queries") or ["other"])[0] for product in selected)),
                "product_ids": [product["id"] for product in selected]}
    write_json(args.output / "sample.json", manifest)
    if args.plan:
        print(json.dumps(manifest, indent=2))
        return
    client = GeminiClient(read_key(), args.interval)
    cache = ROOT / "data/gemini-cache"
    products = []
    for start in range(0, len(selected), args.description_batch_size):
        batch = selected[start:start + args.description_batch_size]
        if args.description_batch_size == 1:
            product = batch[0]
            results = {product["id"]: describe_product(product, args.catalogue.parent, prompt, args.description_model, cache, client)}
        else:
            results = describe_batch(batch, args.catalogue.parent, prompt, args.description_model, cache, client)
        for product in batch:
            result = results[product["id"]]
            descriptions = isolate_shape(result["descriptions"])
            edits = {aspect: {"original": result["descriptions"][aspect], "cleaned": descriptions[aspect]}
                     for aspect in ASPECTS if result["descriptions"][aspect] != descriptions[aspect]}
            relative = os.path.relpath(args.catalogue.parent / product["image_path"], args.output)
            products.append(dict(product, image_path=relative, descriptions=descriptions,
                                 description_provenance={**{key: value for key, value in result.items() if key != "descriptions"},
                                                         "aspect_isolation_edits": edits}))
        write_json(args.output / "descriptions.json", {"metadata": manifest, "products": products})
        print(f"Described {len(products)}/{len(selected)} shoes.", flush=True)
    embed_products(products, args.embedding_model, args.dimensions, cache, client, batch_size=args.embedding_batch_size)
    for product in products:
        if set(product["embeddings"]) != set(ASPECTS):
            raise ValueError("A product is missing an aspect embedding.")
        for aspect in ASPECTS:
            product["embeddings"][aspect] = normalize_vector(product["embeddings"][aspect], args.dimensions)
    manifest.update({"completed_at": datetime.now(timezone.utc).isoformat(), "api_requests_this_run": client.requests,
                     "generation_usage_this_run": dict(client.usage), "l2_normalized": True})
    write_json(args.output / "catalogue.json", {"metadata": manifest, "products": products})
    write_json(args.output / "similarity-checks.json", similarity_report(products))
    print(f"Saved {len(products)} described shoes and {len(products) * 3} normalized embeddings to {args.output}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
