"""Build source-labeled product details and synthetic prototype reviews."""
import re
from discovery import listed_brand

COLORS = re.compile(r'\b(?:navy blue|off-white|dark brown|light blue|navy|white|black|blue|green|red|pink|purple|yellow|orange|brown|grey|gray|beige|cream|tan|silver|gold|burgundy|olive|teal|mustard)\b', re.I)
SHAPES = ['Chelsea boot', 'Mary Jane', 'loafer', 'platform', 'high-top', 'low-top', 'slip-on', 'pointed toe', 'round toe', 'chunky', 'strappy', 'lace-up']


def product_info(product, brand=None):
    descriptions = product.get('descriptions', {})
    brand = brand or listed_brand(product['title'])
    if brand and brand.islower():
        brand = brand.title()
    colors = list(dict.fromkeys(match.group().lower() for match in COLORS.finditer(descriptions.get('color', ''))))[:3]
    palette = ' and '.join(colors)
    shape_text = descriptions.get('shape', '') + ' ' + product['title']
    shape = next((value.lower() for value in SHAPES if value.lower() in shape_text.lower()), None)
    color_review = f'The {palette} color combination is what catches my eye.' if len(colors) > 1 else f'I like the {palette} color on this pair.' if colors else 'The color palette is what catches my eye.'
    shape_review = f'The {shape} look is the detail I like most.' if shape else 'I am drawn to the overall shape of this pair.'
    features = [{'label': aspect.title(), 'text': descriptions[aspect]} for aspect in ('color', 'shape', 'style') if descriptions.get(aspect)]
    rating = product.get('rating')
    count = product.get('reviews')
    return {
        'brand': {'name': brand, 'source': 'listing_title' if brand else 'not_provided'},
        'ratings': {'value': rating, 'count': count, 'scale': 5, 'source': 'Google Shopping listing snapshot', 'is_synthetic': False},
        'product_card': {'title': product['title'], 'description': descriptions.get('style') or product['title'],
                         'price': product['price'], 'image_path': product.get('image_path'), 'product_url': product['product_url']},
        'buyer_feedback': {'kind': 'synthetic', 'label': 'Prototype reviews — generated examples',
                           'source': 'Generated from this shoe’s visual descriptions; not real buyer testimony',
                           'reviews': [{'text': text, 'author': 'Prototype shopper', 'is_synthetic': True} for text in (color_review, shape_review)]},
        'features': {'items': features, 'source': 'Gemini image descriptions', 'is_inferred': True},
        'matches': {'status': 'not_assessed', 'criteria': [], 'gaps': [], 'source': 'Session-specific original-prompt assessment'},
    }
