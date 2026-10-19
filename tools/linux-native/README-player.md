# Chex Trek for Linux

Chex Trek is a total conversion for Doom 3. This AppImage is the whole game for 64-bit Linux:
the dhewm3 1.5.5 engine, the Chex Trek game code built for it, and the Chex Trek maps, models,
sounds and textures. It does not include any of Doom 3's own data. You need your own copy of
classic Doom 3.

## Requirements

- 64-bit (x86_64) Linux with glibc 2.35 or newer. Ubuntu 22.04, Debian 12, Fedora 36 and later
  all qualify.
- Classic Doom 3 (the 2004 release, patched to 1.3.1, from Steam, GOG or a retail disc).
  Doom 3 BFG Edition does not work: it has a different data format.
- OpenGL graphics drivers, as for any 3D game.
- FUSE, which most desktop distributions already have. Without it, see "No FUSE" below.

## Running it

```
chmod +x ChexTrek-x86_64.AppImage
./ChexTrek-x86_64.AppImage
```

The first launch looks for Doom 3 in the usual Steam locations (including other Steam library
folders and the Flatpak and Snap versions of Steam), in `~/GOG Games/Doom 3`, and in
`/usr/local/games/doom3` and `/usr/share/games/doom3`. If it is somewhere else, give the folder
that contains `base/pak000.pk4`:

```
./ChexTrek-x86_64.AppImage --doom3 "/path/to/Doom 3"
```

The folder is remembered, so later launches (including from a file manager) don't need it. To
use a folder for one launch only, set `CHEXTREK_DOOM3_DIR` instead. If Doom 3 can't be found,
the AppImage prints one line saying so and exits.

Any other argument goes to the engine unchanged, for example
`./ChexTrek-x86_64.AppImage +set r_fullscreen 0` for a window.

## Where your files go

- Saves, screenshots and the engine log (`dhewm3log.txt`): `~/.local/share/dhewm3/chextrek/`
  and `~/.local/share/dhewm3/`.
- Settings (`dhewm.cfg`): `~/.config/dhewm3/chextrek/`.
- The remembered Doom 3 folder: `~/.config/chextrek/doom3-dir`.

These are dhewm3's standard locations (`$XDG_DATA_HOME` and `$XDG_CONFIG_HOME` are honored).
Nothing is written into the AppImage or into your Doom 3 folder.

## No FUSE

If the AppImage fails to start with a FUSE error, run it without mounting:

```
./ChexTrek-x86_64.AppImage --appimage-extract-and-run
```

## Licenses

dhewm3 and the Chex Trek game code are GPLv3 (with id Software's additional terms). SDL2 is
zlib-licensed and OpenAL Soft is LGPL. The license texts are inside the AppImage under
`usr/share/doc/chextrek/` (`./ChexTrek-x86_64.AppImage --appimage-extract` unpacks it).
