import json

from utils import dir
from utils.variables import config

colorscheme = {
    "catppuccin": "catppuccin.json",
    "nord": "nord.json",
    "kanagawa": "kanagawa.json",
    "everforest": "everforest.json",
    "gruvbox": "gruvbox.json",
    "dracula": "dracula.json",
}.get(config["colorscheme"], "catppuccin.json")

path = f"{dir.get()}/utils/colorscheme/{colorscheme}"

with open(path, "r") as file:
    color = json.load(file)
    file.close()
