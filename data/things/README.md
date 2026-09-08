# Adding client versions

Create a version folder and drop your sprite files or assets in it.

The repository intentionally does not ship a version directory. Add the game
assets locally after downloading the client; for example, use
`data/things/1530/` for protocol 15.30. The shared `assets.json.sha256` file is
kept outside that directory so source archives and runtime packages do not
contain an otherwise empty `1530` folder.

For the list of supported client versions see `modules/gamelib/game.lua`

# Example configurations

spr/dat:
`data/things/860/ (spr and dat files there)`

assets:
`data/things/1340/ (catalog-content.json and all asset files)`
