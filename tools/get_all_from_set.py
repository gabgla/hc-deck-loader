import requests
import json

URL = "https://raw.githubusercontent.com/bones-bones/hellfall/main/src/data/Hellscube-Database.json"

response = requests.get(URL)
response.content

parsed = json.loads(response.content)

for card in parsed["data"]:
    if card["Set"] != SET:
        continue
    print("1 " + card["Name"])
