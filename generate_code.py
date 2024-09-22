import sys
import os
import io
import requests
import json
import glob
import re
import yaml

DB_URL = 'https://raw.githubusercontent.com/bones-bones/hellfall/main/src/data/Hellscube-Database.json'
SCAN_DIR = './src'
CONFIG_PATH = './config/layout_overrides.yml'

numbers = re.compile(r'(\d+)')

def main():
    build(sys.argv[1])

def build(destination_path):
    database = fetch_database(DB_URL)
    add_basics(database)

    database_code_block = generate_inline_database(database)
    layout_config = generate_layout_config(CONFIG_PATH)
    script_parts = get_script_parts(SCAN_DIR)
    proxy_script = get_proxy_script(os.path.join(SCAN_DIR, 'cards/proxy.lua'))
    card_script = generate_card_script(os.path.join(SCAN_DIR, 'cards/generic.lua'), proxy_script)

    script = '\n'.join([database_code_block] + [layout_config] + [card_script] + [proxy_script] + script_parts)

    with open(destination_path, 'w') as new_script:
        new_script.write(script)
        new_script.close()

def get_script_parts(scan_path) -> list[str]:
    files = []
    path = os.path.join(scan_path, '*.lua')
    for file_name in sorted(glob.glob(path), key=numerical_sort):
        print(file_name)

        file = io.open(file_name, 'r')
        files.append(file.read())
        file.close()

    return files

def generate_card_script(path, proxy_script) -> str:
    with open(path, 'r') as file:
       script = file.read()
       file.close()

    return f'CARD_SCRIPT="{lua_escape(proxy_script)} {lua_code_escape(script)}"'

def get_proxy_script(path) -> str:
    with open(path, 'r') as file:
       script = file.read()
       file.close()

    return f'PROXY_SCRIPT="{lua_code_escape(script)}"'

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

def add_basics(database):
    basics = [
        {
            'Name': 'Plains',
            'Image': 'https://lh3.googleusercontent.com/d/15NJUlWG7iT0MxFKjNSc9-AFMXXOdOqYs',
            'Text': '({T}: Add {W}.)'
        },
        {
            'Name': 'Island',
            'Image': 'https://lh3.googleusercontent.com/d/1h9cl7YVFPOtsRATXgcEqH5vtLcLMl0YY',
            'Text': '({T}: Add {U}.)'
        },
        {
            'Name': 'Swamp',
            'Image': 'https://lh3.googleusercontent.com/d/1uozfnTiv8CsZ3Zbi4dyyZoRdUbEuVhn3',
            'Text': '({T}: Add {B}.)'
        },
        {
            'Name': 'Mountain',
            'Image': 'https://lh3.googleusercontent.com/d/14FY_SJAY0H2RzR83UhJ4Jm7jEbv2rkg7',
            'Text': '({T}: Add {R}.)'
        },
        {
            'Name': 'Forest',
            'Image': 'https://lh3.googleusercontent.com/d/1PcvE0Gd_e77EAeSREDGpjYnE81SRT73u',
            'Text': '({T}: Add {G}.)'
        },
        {
            'Name': 'Wastes',
            'Image': 'https://lh3.googleusercontent.com/d/1EWnR5znfta8yMZpicTS4yATwUPnzIbjH',
            'Text': '({T}: Add {C}.)'
        }
    ]

    for b in basics:
        database['data'].append({
            'Name': b['Name'],
            'Image': b['Image'],
            'Creator': 'et al',
            'Set': 'HC4',
            'Constructed': 'Legal',
            'Rulings': '',
            'CMC': 0,
            'Color(s)': '',
            'Supertype(s)': ['Basic', None, None, None],
            'Card Type(s)': ['Land', None, None, None],
            'Subtype(s)': [b['Name'] if b['Name'] != 'Wastes' else None, None, None, None],
            'power': [None, None, None, None],
            'toughness': [None, None, None, None],
            'Loyalty': [None, None, None, None],
            'Text Box': [b['Text'], None, None, None]
        })


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
        
        def append_side(pos): sides.append(list(f'["{f}"]="{lua_escape(c[f][pos]) if f in c else ""}"' for f in side_fields))

        # Small optimisation: Don't bother processing empty faces
        if 'Card Type(s)' in c:
            for i, t in enumerate(c['Card Type(s)']):
                if t is None or t == "":
                    continue
                append_side(i)
            
        # Fallback to Cost
        if len(sides) == 0 and 'Cost' in c:
            for i, t in enumerate(c['Cost']):
                if t is None or t == "":
                    continue
                append_side(i)

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

# This is dumb, improve later
def lua_code_escape(input) -> str:
    return input \
        .strip() \
        .replace('\\', '\\\\') \
        .replace('"', '\\"') \
        .replace('\n', ' ') \
        # .replace('  ', ' ') \
        # .replace('  ', ' ') \
        # .replace('  ', ' ') \
        # .replace('  ', ' ') \
        # .replace('  ', ' ') \

# Fix this on the DB
def process_edge_cases(c):
    if c['Name'] == 'Spork Elemental':
        c['Text Box'][0] = 'Trample, haste\nAt the beginning of the next end step, sacrifice a Food or a creature. This only happens once.'

def numerical_sort(value):
    parts = numbers.split(value)
    parts[1::2] = map(int, parts[1::2])
    return parts

if __name__ == '__main__':
    main()
