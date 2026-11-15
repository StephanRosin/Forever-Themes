# Forever Themes

One place to set the look of all your Forever addons, for WoW: Forever. Pick a theme and a
colour once and every Forever addon that follows it wears it; each addon can keep a theme of its
own instead. Skins (on from the start) put Blizzard's own windows (character, spellbook, talents,
professions, legacy, guild & communities, collections) in the same theme, and a switch
gives Blizzard's texts and Platynator's nameplates the theme's font. Options: the minimap button
or `/forever`.

The full feature list is in [docs/curseforge/description.md](docs/curseforge/description.md).

For other addons: `LibForeverThemes.Hub()` is nil without this addon, else
`{ Follows(folder), Theme(), Color(), OpenMenu(anchor), OpenOptions() }` (the library's
DESIGN.md, §2.12).

## Development

    tests/run                    # Lua 5.1, as in the game (never in parallel with other test runs)
    ./install "<WoW>/_forever_/Interface/AddOns"

## License note

The themes (textures, fonts, colours) come from the embedded library LibForeverThemes in
`Libs/LibForeverThemes` (source: https://github.com/StephanRosin/ForeverThemes, copied in with
its `tools/sync`; its `tools/make_themes.py` makes the textures). Its fonts in `Media/Fonts` are
under the SIL Open Font License (see `OFL.txt` and `FONTS.txt` there).
