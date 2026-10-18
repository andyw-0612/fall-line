"""Integration tests against the packaged, unmodified public catalogue assets."""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'Build/Marking Menu.app/Contents/Resources/Catalogue'
spec = importlib.util.spec_from_file_location('bridge', ROOT / 'bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)
bridge.configure_ranker()
PRODUCTS = bridge.load_products()
BY_ID = {p['id']: p for p in PRODUCTS}

class CatalogueBridgeTests(unittest.TestCase):
    def body(self, **kwargs):
        return dict(initial_context='blue running shoes', events=[], excluded_ids=[], gender_filter='all', variant=19, count=11, **kwargs)

    def test_entire_catalogue_and_images(self):
        self.assertEqual(len(BY_ID), 450)
        for p in PRODUCTS:
            self.assertTrue((ROOT / 'data/images' / Path(p['image_path']).name).is_file())

    def test_local_unique_and_hard_filters(self):
        body = self.body(max_price=40)
        body['gender_filter'] = 'women'
        result = bridge.local_rank(body, PRODUCTS)
        ids = [p['id'] for p in result['recommendations']]
        self.assertEqual(len(ids), 11)
        self.assertEqual(len(set(ids)), 11)
        self.assertTrue(all(BY_ID[i]['price'] <= 40 and bridge.matches_gender(BY_ID[i], 'women') for i in ids))
        body['excluded_ids'] = ids
        self.assertFalse(set(ids) & {p['id'] for p in bridge.local_rank(body, PRODUCTS)['recommendations']})

    def test_exhaustion_is_empty(self):
        body = self.body()
        body['excluded_ids'] = list(BY_ID)
        self.assertEqual(bridge.local_rank(body, PRODUCTS)['recommendations'], [])

    def test_all_aspects_chronology_and_price_directions(self):
        p = PRODUCTS[0]
        events = [dict(sequence=i+1,type='rating',productId=p['id'],aspect=a,value=-1,reason='too_cheap') for i,a in enumerate(bridge.ASPECTS)]
        body = self.body();body['events'] = events
        prepared = bridge.ai_ranker.prepare_request(body, PRODUCTS)
        self.assertEqual(len(prepared['latest_explicit_ratings_per_product_aspect']), 9)
        self.assertEqual(next(e for e in prepared['feedback_oldest_to_newest'] if e['aspect']=='price')['reaction'], 'too_cheap')
        body['events'] += [dict(sequence=10,type='clear_aspect',aspect='color'),dict(sequence=11,type='rating',productId=p['id'],aspect='price',value=-1,reason='too_expensive')]
        prepared = bridge.ai_ranker.prepare_request(body, PRODUCTS)
        active = prepared['latest_explicit_ratings_per_product_aspect']
        self.assertFalse(any(e['aspect']=='color' for e in active))
        self.assertEqual(next(e for e in active if e['aspect']=='price')['reaction'], 'too_expensive')
        body['events'].append(dict(sequence=12,type='clear_all'))
        self.assertEqual(bridge.ai_ranker.prepare_request(body, PRODUCTS)['latest_explicit_ratings_per_product_aspect'], [])

    def test_extended_model_contract_and_no_review_leakage(self):
        body = self.body()
        body['events'] = [dict(sequence=1,type='rating',productId=PRODUCTS[0]['id'],aspect='brand',value=1)]
        prepared = bridge.ai_ranker.prepare_request(body, PRODUCTS)
        request = bridge.ai_ranker.build_body(prepared, bridge.ai_ranker.MODEL)
        self.assertEqual(set(request['generationConfig']['responseJsonSchema']['properties']['profile']['required']),set(bridge.ASPECTS))
        text = request['contents'][0]['parts'][0]['text']
        self.assertIn('too_cheap means prefer a higher price',text)
        self.assertNotIn('buyer_feedback',text)
        feedback = bridge.ai_ranker.aspect_only_events(prepared['feedback_oldest_to_newest'])[0]
        self.assertNotIn('product_name',feedback)
        self.assertNotIn('price',feedback)

if __name__ == '__main__': unittest.main()
