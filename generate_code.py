import os
import io
import requests
import json
import logging
import glob
import re
import yaml

DB_URL = 'https://raw.githubusercontent.com/bones-bones/hellfall/main/src/data/Hellscube-Database.json'
SCAN_DIR = './src'
CONFIG_PATH = './config/layout_overrides.yml'

numbers = re.compile(r'(\d+)')

def build():
    database = fetch_database(DB_URL)
    database_code_block = generate_inline_database(database)
    layout_config = generate_layout_config(CONFIG_PATH)
    script_parts = get_script_parts(SCAN_DIR)

    return '\n'.join([database_code_block] + [layout_config] + script_parts)


def get_script_parts(scan_path) -> list[str]:
    files = []
    path = os.path.join(scan_path, '*.lua')
    for file_name in sorted(glob.glob(path), key=numerical_sort):
        logging.warning(file_name)

        file = io.open(file_name, 'r')
        files.append(file.read())
        file.close()

    return files

def generate_layout_config(config_path):
    with open(config_path, 'r') as file:
       config = yaml.safe_load(file)
       file.close()

    entries = []

    for c in config:
        parts = []

        parts.append(f'type="{c["type"]}"')
        parts.append(f'sides={c["sides"]}')

        if 'aspect' in c:
            parts.append(f'aspect="{c["aspect"]}"')

        if 'rotation' in c:
            parts.append(f'rotation={c["rotation"]}')

        if 'grid' in c:
            parts.append(f'grid={{x={c["grid"]["x"]},y={c["grid"]["y"]}}}')

        entry = f'["{lua_escape(c["name"])}"]={{{",".join(parts)}}}'
        entries.append(entry)

    return f'LAYOUTS = {{{",".join(entries)}}}'

def fetch_database(db_url) -> dict:
    response = requests.get(db_url)
    return json.loads(response.content)

def generate_inline_database(database: dict) -> str:
    fields = [
        'Name',
        'Image',
        'Creator',
        'Set',
        'Constructed',
        'Rulings',
        'CMC',
        'Color(s)',
        'Tags'
    ]

    side_fields = [
        'Cost',
        'Supertype(s)',
        'Card Type(s)',
        'Subtype(s)',
        'power',
        'toughness',
        'Loyalty',
        'Text Box',
        'Flavor Text'
    ]

    cards = []

    for c in database['data']:

        process_edge_cases(c)

        sides = []
        
        # Small optimisation: Don't bother processing empty faces

        if 'Card Type(s)' in c:
            for i, t in enumerate(c['Card Type(s)']):
                if t is None or t == "":
                    continue

                sides.append(list(f'["{f}"]="{lua_escape(c[f][i]) if f in c else ""}"' for f in side_fields))

        side_assignments = (f'{{{",".join(s)}}}' for s in sides)
        lua_assignments = list(f'["{f}"]="{lua_escape(c[f]) if f in c else ""}"' for f in fields) 
        lua_assignments.append(f'Sides={{{",".join(side_assignments)}}}')

        cards.append(f'{{{",".join(lua_assignments)}}}')

    return f'DATABASE = {{{",".join(cards)}}}'

def lua_escape(input) -> str:
    if not input:
        return ''

    if type(input) is int:
        input = str(input)

    return input \
        .strip() \
        .replace('\\', '\\\\') \
        .replace('\"', '\\"') \
        .replace('\r', '\\r') \
        .replace('\n', '\\n') \
        .replace('\t', '\\t') \
        # .replace('\\m', '\\\\m')
        # .replace('\\N', '\\\\N') \

def process_edge_cases(c):
    if c['Name'] == 'Spork Elemental':
        c['Text Box'][0] = 'Trample, haste\nAt the beginning of the next end step, sacrifice a Food or a creature. This only happens once.'

def numerical_sort(value):
    parts = numbers.split(value)
    parts[1::2] = map(int, parts[1::2])
    return parts

print(build())
