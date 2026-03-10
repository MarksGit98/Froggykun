# Audio Drop Zones

The `AudioManager` autoload discovers files by prefix, so you can add `.ogg`, `.wav`, or `.mp3` files here without changing code.

Music:
- `assets/audio/music/world_theme_01.ogg`
- `assets/audio/music/intro_level_theme_01.ogg`
- `assets/audio/music/dungreed_level_theme_01.ogg`

Player SFX:
- `assets/audio/sfx/player/player_jump_01.ogg`
- `assets/audio/sfx/player/player_dash_01.ogg`
- `assets/audio/sfx/player/player_swing_01.ogg`
- `assets/audio/sfx/player/player_hit_confirm_01.ogg`
- `assets/audio/sfx/player/player_defend_queue_01.ogg`
- `assets/audio/sfx/player/player_defend_block_01.ogg`
- `assets/audio/sfx/player/player_hurt_01.ogg`
- `assets/audio/sfx/player/player_death_01.ogg`

Goblin SFX:
- `assets/audio/sfx/enemies/goblin/goblin_attack_01.ogg`
- `assets/audio/sfx/enemies/goblin/goblin_hurt_01.ogg`
- `assets/audio/sfx/enemies/goblin/goblin_death_01.ogg`

UI SFX:
- `assets/audio/sfx/ui/ui_confirm_01.ogg`
- `assets/audio/sfx/ui/ui_back_01.ogg`
- `assets/audio/sfx/ui/ui_pause_01.ogg`

World/ambient staging:
- `assets/audio/sfx/world/`

You can add multiple numbered variations like `player_swing_02.ogg` and `player_swing_03.ogg`; the manager picks randomly and applies the cue's configured pitch/volume variation and cooldown rules.
