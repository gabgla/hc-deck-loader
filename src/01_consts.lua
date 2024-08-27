------ CONSTANTS
DATABASE_URL = "https://skeleton.club/hellfall/Hellscube-Database.json"

FALLBACK_DATABASE = nil
INDEX = nil

DECK_SOURCE_URL = "url"
DECK_SOURCE_NOTEBOOK = "notebook"

MAINDECK_POSITION_OFFSET = { 0.0, 0.2, 0.1286 }
MAYBEBOARD_POSITION_OFFSET = { 1.47, 0.2, 0.1286 }
SIDEBOARD_POSITION_OFFSET = { -1.47, 0.2, 0.1286 }
COMMANDER_POSITION_OFFSET = { 0.7286, 0.2, -0.8257 }
TOKENS_POSITION_OFFSET = { -0.7286, 0.2, -0.8257 }

DEFAULT_CARDBACK = "https://i.imgur.com/ovmRjIz.jpeg"
DEFAULT_LANGUAGE = "en"

LANGUAGES = {
	["en"] = "en"
}

------ UI IDs
UI_ADVANCED_PANEL = "MTGDeckLoaderAdvancedPanel"
UI_CARD_BACK_INPUT = "MTGDeckLoaderCardBackInput"
UI_LANGUAGE_INPUT = "MTGDeckLoaderLanguageInput"
UI_FORCE_LANGUAGE_TOGGLE = "MTGDeckLoaderForceLanguageToggleID"
