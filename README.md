## CombatDamage<br>A port of the AMXX Plugin by [YoshiokaHaruki](https://github.com/YoshiokaHaruki/AMXX-Floating-Damage) to SvenCoop AngelScript.
This plugin will show damange indicators to players/monsters when damaged by a player. You can toggle features/settings with the ConVars below.
### Screenshots:
![Preview](./preview.gif)
### ConVars
- `enabled` - enable/disable the plugin
- `skin` - skin for monster damage
- `skin_players` - skin for player damage (if enabled)
- `players` - enable/disable damage indicator for players (both PvP and PvE)
- `upright_only` - numbers appear vertically with no random rotation
- `max_meters` - number of models spawned per entity (default 8), reduce if suffering from buffer overflow/edict errors.
- `decay_time` - how much alpha is taken away each frame, lower number keeps the indicators around longer

ConVars can be set via `as_command cd.<cvar> <value>`

### Install
Add the following to your `default_plugins.txt` file.

```
"plugin"
{
		"name" "CombatDamage"
		"script" "CombatDamage/CombatDamage"
		"concommandns" "cd"
}
```

## font.py
A python script that can take a font file, and output a texture that can be imported into `float_damage.mdl` to have your own texture.
