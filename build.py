import os
import io
import requests
import json

DB_URL = 'https://raw.githubusercontent.com/bones-bones/hellfall/main/src/data/Hellscube-Database.json'

def build():
    database = fetch_database()
    generate_inline_database(database)

    # script_parts = get_script_parts()

    pass

def get_script_parts() -> list[str]:
    files = []
    for file_path in os.listdir('./src'):
        file = io.open(file_path, 'r')
        files.append(file.readlines())
        file.close()

    return files

def fetch_database() -> dict:
    response = requests.get(DB_URL)
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

        # if c['Name'] == 'Phil Swift, the Divider':
        #     print(f'{{{",".join(lua_assignments)}}}')

        cards.append(f'{{{",".join(lua_assignments)}}}')

    return f'DATABASE = {{{",".join(cards)}}}'

def lua_escape(input) -> str:
    if not input:
        return input

    if type(input) is int:
        input = str(input)    

    return input.strip().replace('\"', '\\"').replace('\r', '\\r').replace('\n', '\\n').replace('\t', '\\t')
build()

