# Forever Themes

One place to set the look of all your Forever addons, for WoW: Forever. Pick a theme and a
colour once and every Forever addon that follows it wears it; each addon can keep a theme of its
own instead. Skins put Blizzard's own windows (character, spellbook, talents,
professions, legacy, guild & communities, collections) in the same theme, and a switch
gives Blizzard's texts and Platynator's nameplates the theme's font. Options: the minimap button
or `/forever`.

Installing it changes nothing you see: the central theme, the skins and the font switches start as
your Forever addons had them. Only without any Forever addon does it start with the author's
choices (Pitwall in red, every skin and both font switches on). A Forever addon first seen later
follows only if it already wears the central theme. Forever Unit Frames keeps a theme per profile;
the hub sets the character's active one. Switch the Platynator font off before removing the addon,
or Platynator keeps the theme's font.

The full feature list is in [docs/curseforge/description.md](docs/curseforge/description.md).

For other addons: `LibForeverThemes.Hub()` is nil without this addon, else
`{ Follows(folder), Theme(), Color(), OpenMenu(anchor), OpenOptions(), Sync() }` (the library's
DESIGN.md, §2.12).

## Development

    flock /tmp/claude-1000/forever-tests.lock tests/run   # Lua 5.1, as in the game; never parallel to other runs
    ./install "<WoW>/_forever_/Interface/AddOns"

## License note

The themes (textures, fonts, colours) come from the embedded library LibForeverThemes in
`Libs/LibForeverThemes` (source: https://github.com/StephanRosin/ForeverThemes, copied in with
its `tools/sync`; its `tools/make_themes.py` makes the textures). Its fonts in `Media/Fonts` are
under the SIL Open Font License (see `OFL.txt` and `FONTS.txt` there).
