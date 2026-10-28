"""Fetch genuine World Bank annual observations; never fill gaps or invent prices.

Install tools/requirements-data.txt, then run this script. --commodity-file can
use a previously downloaded official workbook. The downloaded source is hashed.
"""
import argparse
import datetime as dt
import hashlib
import io
import json
import math
from pathlib import Path
import shutil
import urllib.request

import openpyxl

ROOT = Path(__file__).resolve().parents[1]
COMMODITIES = 'https://thedocs.worldbank.org/en/doc/5d903e848db1d1b83e0ec8f744e55570-0350012021/related/CMO-Historical-Data-Annual.xlsx'
LICENSE = 'https://data.worldbank.org/summary-terms-of-use'
COUNTRIES = {'DEU': 'Deutschland', 'ESP': 'Spanien', 'USA': 'USA', 'FRA': 'Frankreich', 'GBR': 'Großbritannien'}
INDICATORS = {'inflation': 'FP.CPI.TOTL.ZG', 'military': 'MS.MIL.XPND.CD', 'gdp': 'NY.GDP.MKTP.CD'}


def fetch(url):
    with urllib.request.urlopen(url, timeout=45) as response:
        raw = response.read(15 * 1024 * 1024 + 1)
    if len(raw) > 15 * 1024 * 1024:
        raise ValueError('Source exceeds download limit')
    return raw


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('--commodity-file', type=Path)
    args = args.parse_args()
    fetched = dt.datetime.now(dt.timezone.utc).isoformat()
    raw = args.commodity_file.read_bytes() if args.commodity_file else fetch(COMMODITIES)
    workbook = openpyxl.load_workbook(io.BytesIO(raw), read_only=True, data_only=True)
    sheet = workbook['Annual Prices (Nominal)']
    rows = list(sheet.iter_rows(max_row=300, values_only=True))
    headers = list(rows[6])
    series = []
    for symbol, label in [('gold', 'Gold'), ('silver', 'Silver')]:
        col = headers.index(label)
        points = [{'year': r[0], 'value': r[col]} for r in rows[8:]
                  if isinstance(r[0], int) and 1800 <= r[0] <= dt.date.today().year
                  and isinstance(r[col], (int, float)) and math.isfinite(r[col]) and r[col] > 0]
        if len(points) < 2 or any(a['year'] >= b['year'] for a, b in zip(points, points[1:])):
            raise ValueError('Invalid commodity year sequence')
        series.append({'id': symbol, 'name': 'Gold' if symbol == 'gold' else 'Silber',
                       'group': 'Edelmetalle', 'unit': 'USD/Feinunze', 'currency': 'USD', 'points': points})
    end = min(s['points'][-1]['year'] for s in series)
    sources = [{'name': 'World Bank Commodity Price Data (Pink Sheet)', 'url': COMMODITIES,
                'sha256': hashlib.sha256(raw).hexdigest(), 'sourceUpdated': str(rows[3][0]),
                'aggregation': 'Annual arithmetic mean, nominal USD per troy ounce'}]

    def indicator(code, countries):
        url = f'https://api.worldbank.org/v2/country/{countries}/indicator/{code}?format=json&per_page=1000'
        body = fetch(url)
        payload = json.loads(body)
        if not isinstance(payload, list) or len(payload) != 2 or payload[0]['pages'] != 1:
            raise ValueError(f'Unexpected indicator payload: {code}')
        sources.append({'name': f'World Development Indicators {code}', 'url': url,
                        'sha256': hashlib.sha256(body).hexdigest(), 'sourceUpdated': payload[0]['lastupdated']})
        return payload[1]

    cpi = sorted([{'year': int(p['date']), 'value': p['value']} for p in indicator('FP.CPI.TOTL', 'USA')
                  if p['value'] is not None and 1960 <= int(p['date']) <= end], key=lambda p: p['year'])
    if len(cpi) < 2:
        raise ValueError('Missing US CPI')
    macro_values = {key: indicator(code, ';'.join(COUNTRIES)) for key, code in INDICATORS.items()}
    macro = []
    for country, name in COUNTRIES.items():
        item = {'country': name}
        for key, records in macro_values.items():
            value = next((p['value'] for p in records if p['countryiso3code'] == country and int(p['date']) == end), None)
            item[key] = value / 1e9 if value is not None and key != 'inflation' else value
        macro.append(item)
    dataset = {'schemaVersion': 1, 'kind': 'import', 'asOf': f'{end}-12-31',
               'source': f'Weltbank Pink Sheet: Gold/Silber Jahresmittel 1960–{end}; US-CPI und Makrolage: World Development Indicators. CC BY 4.0 mit Weltbank-Zusatzbedingungen.',
               'cpiRegion': 'USA (Jahresmittel, 2010=100)', 'cpi': cpi, 'series': series, 'macro': macro,
               'metadata': {'fetchedAt': fetched, 'frequency': 'annual', 'sources': sources,
                            'licenseUrl': LICENSE, 'coverage': 'Gold und Silber; keine Aktien- oder Immobilienkurse.',
                            'notes': 'Keine Interpolation, keine Devisenumrechnung. Makrowerte beziehen sich ausschließlich auf das angegebene Berichtsjahr; fehlende Werte bleiben null.'}}
    target = ROOT / 'shared/market-data.json'
    temp = target.with_suffix('.tmp')
    temp.write_text(json.dumps(dataset, ensure_ascii=False, indent=2, allow_nan=False) + '\n')
    temp.replace(target)
    for folder in ['web/assets', 'android/app/src/main/assets', 'ios/CRISIS/Resources']:
        shutil.copyfile(target, ROOT / folder / target.name)
    print(f'Validated source extraction: 2 real annual price series, {len(cpi)} CPI observations, 5 countries, through {end}.')


if __name__ == '__main__':
    main()
