# Drop-in character models

Put a rigged 3D model here named after a character's id (see `data/roster.json`),
for example `flash.glb`, `supergirl.glb` or `green_arrow.gltf`. The game then uses
it instead of the built-in body for that character, in the world and in character
select. Open the project in the Godot editor (or run `godot --headless --import`)
once so Godot imports the file.

- **Formats:** `.glb` / `.gltf` (recommended), or a Godot scene (`.tscn` / `.scn`).
- **Size and facing:** the model is scaled to about 1.85 m tall with its feet on the
  ground, and turned to face the way the character walks (glTF and Mixamo models
  face +Z). Override per character in the roster look with `model_height` and
  `model_yaw`.
- **Animations** are picked by name from the model's AnimationPlayer, so a Mixamo
  export works as is: anything containing `idle`, `walk`, `run`/`jog`, `sprint`,
  `fly`/`hover`, `fall`/`jump`, `punch`/`attack`/`kick`/`cast`/`shoot` and
  `death`/`die`. Missing ones fall back to idle or run.
- Disguises and civilian clothes still use the built-in body.
