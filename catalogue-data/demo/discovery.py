"""Conservative title-based groups for varied initial shoe discovery."""
import re

# Match explicit brand names in listings; never infer brand from the image.
BRANDS = sorted({
    'cole haan', 'new balance', 'old navy', 'polo ralph lauren', 'ralph lauren',
    'stacy adams', 'steve madden', 'sam edelman', 'dolce vita', 'marc fisher',
    'cody james', 'naturalizer', 'abercrombie & fitch', 'calvin klein',
    'dr. martens', 'dr martens', 'timberland', 'birkenstock', 'converse',
    'adidas', 'nike', 'reebok', 'puma', 'asics', 'brooks', 'hoka', 'saucony',
    'skechers', 'clarks', 'crocs', 'vans', 'ugg', 'norda', 'on', 'merrell',
    'salomon', 'keen', 'columbia', 'aerosoles', 'kizik', 'allbirds', 'ecco',
    'rockport', 'sperry', 'vionic', 'toms', 'fila', 'wolverine', 'carhartt',
}, key=len, reverse=True)


def listed_brand(title):
    title = title.lower().replace('’', "'")
    for brand in BRANDS:
        if brand == 'on' and not re.match(r'^on(?: running)?\s', title):
            continue
        if re.search(r'(?<!\w)' + re.escape(brand) + r'(?!\w)', title):
            return brand
    return None


def discovery_policy(candidates, context, active_ratings, count):
    discovery = not any(event.get('reaction') in {'like', 'dislike', 'price_works', 'too_expensive'} for event in active_ratings)
    groups = {listed_brand(product['title']) or product['id'] for product in candidates}
    # A named brand request overrides brand variety. Also relax the safeguard
    # when the eligible catalog cannot supply the requested number of groups.
    # Specific palettes/types can have too few matching brands for a large
    # opening batch. Keep variety as a prompt goal, but do not reject relevant
    # matches solely to satisfy a broad-discovery brand rule.
    narrow_request = bool(re.search(r'\b(?:white|black|blue|green|red|pink|purple|yellow|brown|navy|silver|gold|sneakers?|boots?|loafers?|sandals?|oxfords?|heels?|flats?|running|hiking|mary jane)\b', context, re.I))
    distinct_brands = discovery and not listed_brand(context) and not narrow_request and len(groups) >= count
    return {'mode': 'discovery' if discovery else 'refinement', 'distinct_brands': distinct_brands}
