# Crisis City

**An unofficial Arrowverse open-world sandbox.** Pick any of **72 heroes and villains** from
*Arrow*, *The Flash*, *Supergirl*, *Legends of Tomorrow*, *Batwoman*, *Black Lightning*,
*Stargirl* and *Superman & Lois*, then go loose in a bay where Star City, Central City,
National City, Freeland, Gotham City and Smallville each sit on their own island, joined by
bridges. Play the Crisis on Infinite Earths campaign, unleash your character's ultimate, steal a car. Walk into
S.T.A.R. Labs, the Arrow Bunker, Jitters, CatCo and the D.E.O.; fly the Waverider and jump
through time; run into the Speed Force or breach to other Earths. Stop crimes as a hero or cause
them as a villain, spawn anyone as your ally or enemy, lift cars, run up walls, and fly over the
skyline.

Built with **Godot 4.3** (GDScript, Compatibility renderer). Runs on **Windows, macOS and Linux**.

![Title screen](docs/screenshots/title.jpg)
![Choose from 72 characters](docs/screenshots/character_select.jpg)
![Central City and S.T.A.R. Labs](docs/screenshots/central_city.jpg)
![Star City at night](docs/screenshots/star_city_night.jpg)
![Flying over National City](docs/screenshots/national_city_flight.jpg)
![Reverse-Flash at super speed](docs/screenshots/speedster.jpg)
![Unity Park brawl](docs/screenshots/unity_park.jpg)
![Sandbox tools](docs/screenshots/sandbox_menu.jpg)
![Inside S.T.A.R. Labs](docs/screenshots/inside_star_labs.jpg)
![Flying the Waverider](docs/screenshots/waverider_flight.jpg)
![Earth-X](docs/screenshots/place_earthx.jpg)
![The Speed Force](docs/screenshots/place_speedforce.jpg)
![The bridge to Gotham City](docs/screenshots/gotham_bridge.jpg)
![Smallville](docs/screenshots/smallville.jpg)
![The Anti-Matter Universe](docs/screenshots/place_antimatter.jpg)

## Download and play

The *Test and build* GitHub Actions workflow builds Windows, macOS (universal: Apple Silicon and
Intel) and Linux versions on every push. Open the latest workflow run under **Actions** and
download the `CrisisCity-builds` artifact. Pushing a tag such as `v0.1.0` also attaches the three
zips to a GitHub Release.

| Platform | How to start |
| --- | --- |
| Windows | Unzip and run `CrisisCity.exe`. The build is unsigned, so SmartScreen may warn you: choose **More info → Run anyway**. |
| macOS | Unzip and move **Crisis City.app** to Applications. It is ad-hoc signed but not notarized, so the first time, right-click it and choose **Open**. On macOS 15, use **System Settings → Privacy & Security → Open Anyway**. |
| Linux | Unzip, then run `./CrisisCity.x86_64`. If the executable bit was lost, run `chmod +x CrisisCity.x86_64` first. |

Any GPU with OpenGL 3.3 (or the macOS equivalent) works. The game needs no internet connection.

## Run from source

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, click **Import**, and select this folder's `project.godot`.
3. Press **F5** (Run Project).

Or from a terminal: `godot --path .` to play, `godot --path . -e` to open the editor.

To build a release yourself, install Godot 4.3's export templates (**Editor → Manage Export
Templates**), then run, for example,
`godot --headless --path . --export-release "Windows" build/windows/CrisisCity.exe`.
The presets for `"Linux"`, `"Windows"` and `"macOS"` are in `export_presets.cfg`.

## Controls

| Action | Keyboard and mouse | Gamepad |
| --- | --- | --- |
| Move | W A S D | Left stick |
| Look / zoom | Mouse / mouse wheel | Right stick |
| Jump (flyers: climb) | Space | A |
| Sprint / super speed / flight boost | Shift | L3 |
| Primary attack | Left mouse | RT |
| Secondary attack (hold for beams) | Right mouse | LT |
| Special power | Q | Y |
| Grappling line, or lift and throw | E | RB |
| Take off / land (flyers) | F | LB |
| Descend while flying | Ctrl or C | B |
| Enter a door, use a console, drive a car, travel (speedsters at full speed, Vibe) | G | D-pad up |
| Ultimate (when charged) | R | R3 |
| Dodge | V | X |
| Sandbox tools | Tab | Back |
| Pause, change character, settings | Esc | Start |
| Hide HUD | F1 | |

## What's in the game

**Characters.** 41 heroes and 31 villains, each with their own costume, stats, two attacks, a
special power, often a utility power (E), and a signature **ultimate** (R):

- **Heroes:** Green Arrow, The Flash, Supergirl, Superman, The Atom, White Canary, Black Canary,
  Spartan, Speedy, Kid Flash, Vibe, Killer Frost, Firestorm, Martian Manhunter, Batwoman,
  Black Lightning, Thunder, Lightning, Mr. Terrific, Vixen, Hawkgirl, Citizen Steel, Stargirl,
  Jay Garrick, Jesse Quick, XS, Elongated Man, Guardian, Mon-El, Dreamer, Brainiac 5, Arsenal,
  Wild Dog, Heat Wave (Legend), Constantine, Zari, Nyssa al Ghul, Hawkman, the Flash of Earth-90,
  the Spectre and Jordan Kent.
- **Villains:** Malcolm Merlyn, Deathstroke, Prometheus, Damien Darhk, Reverse-Flash, Zoom,
  Savitar, The Thinker, Captain Cold, Heat Wave, Weather Wizard, Reign, Lex Luthor, Ra's al Ghul,
  Cicada, Gorilla Grodd, Vandal Savage, Black Siren, Ricardo Diaz, Alice, Captain Boomerang,
  the Anti-Monitor, Overgirl, Dark Arrow, Tobias Whale, King Shark, Mirror Master, Livewire,
  Metallo, Godspeed and Red Death.

**Ultimates.** Fighting fills a gold meter; at 100% press R. Speedsters blitz every enemy in
range, Kryptonians go invulnerable and sweep heat vision across the crowd, Green Arrow calls in
Team Arrow and White Canary the Legends, Black Lightning and Livewire call down lightning storms,
Killer Frost freezes everything solid and shatters it, Black Canary's cry hits in every direction,
Vibe drops enemies through breaches, the Atom and the Martian Manhunter grow giant, Grodd lifts
the whole street with his mind, Deathstroke dashes through everyone, and the Anti-Monitor erases
the area in a wave of anti-matter. NPCs use theirs too.

**The Crisis on Infinite Earths campaign.** Seven saved chapters: S.T.A.R. Labs, Zoom on Earth-2,
Overgirl and Dark Arrow on Earth-X, the Time Wraiths of the Speed Force, the Shadow Demons of a
dying Earth-90, the Anti-Monitor himself, and home to Earth-Prime. The HUD tracks the objective
and the minimap points the way. Restart it from the pause menu.

**Ranks.** Every point you earn counts toward a lifetime rank (1 to 20, from Rookie to Living
Legend, or Thug to God of Evil). Each rank adds 3% health and power to every character.

**Races.** Start a street race or a sky race from the Tab menu's Events tab: hit eight rings
before the clock runs out. Speedsters get a tighter clock.

**More events.** Dominator invasions drop alien soldiers from the sky, and inmates break out of
Iron Heights.

**Drive.** Press G next to any parked car, or carjack one out of traffic (heroes take heat for
it). Shift for nitro, Space for the handbrake.

![The full roster](docs/screenshots/roster.jpg)

**How they move.** Speedsters sprint at 60+ m/s, run up walls and across the bay, leaving
lightning trails. Kryptonians, Martians, Firestorm, the Atom and others fly. Archers and
vigilantes swing on grappling lines. Thunder, Vixen, Citizen Steel and Grodd super-jump. Anyone
with super strength can pick up crates and cars and throw them.

**Powers.** Arrows and explosive arrows, thrown blades and boomerangs, energy bolts, heat vision
and freeze beams, sonic cries, chain lightning, guns, dashes. Specials include Speed Force
slow motion, speed vortexes, ground slams, smoke bombs, ice/fire/lightning novas, shrinking,
invisibility, invulnerability, breach teleports and Darhk's life drain. Fire burns, ice freezes
and lightning stuns.

**The map.** Four city islands, each about 740 m across with its own architecture, sit in a bay
joined by suspension bridges:
- **Star City:** steel-and-glass towers, Queen Consolidated, Verdant and SCPD, plus the rundown
  Glades and the docks.
- **Central City:** brick and sandstone, S.T.A.R. Labs, CCPD, Jitters and Picture News.
- **National City:** white stone and blue glass, CatCo, the D.E.O., L-Corp and a palm-lined beach.
- **Freeland:** low-rise neighbourhoods, Garfield High and the clinic.
- **Gotham City:** soot-black gothic towers with spires and gargoyles under a permanent overcast,
  Wayne Tower (the Batcave is beneath it), GCPD with the Bat-Signal lit, Arkham Asylum and Crows
  Security.
- **Smallville:** farmland, Main Street, the water tower, Smallville High and the Kent Farm.

Offshore are Iron Heights prison (with its own bridge) and Lian Yu, a jungle island with a plane
wreck. There's a day/night cycle with lit windows and streetlights, plus rain, storms and fog.

**Go inside (G at the door).**
- **S.T.A.R. Labs:** the Cortex, the Pipeline, a Speed Lab treadmill that takes speedsters into the
  Speed Force, and Cisco's Breach Room.
- **The Arrow Bunker** under Verdant: the salmon ladder, and the team's suits on display. Suit up
  to switch character.
- **Jitters, CatCo** (step out onto the balcony) and **the D.E.O.**
- **The Batcave** under Wayne Tower and **the Kent Barn**, with the ship that brought Kal-El.
- **The Waverider:** board it from its landing pad off the Star City bridge. Ask Gideon to plot a
  course, or take the helm.

**Fly the Waverider.** Take the helm to fly anywhere: it steers where you look, and you can boost,
climb and fire its cannons. Press Q to jump through time to 1942, the Old West, a ruined 2046 or
neon 3030.

**The multiverse.** Speedsters running flat out can press G to vibrate into the Speed Force,
where Time Wraiths hunt them, or onto another Earth. Vibe can open a breach anywhere, and so can
the S.T.A.R. Labs Breach Room. Earth-2, Earth-3, Earth-X, Earth-38, Earth-19, Earth-90 (being
erased by anti-matter), Earth-99, Earth-167 and Earth-Prime each have their own skyline, colours,
sky and locals: Zoom waits on Earth-2, the Reich patrols Earth-X. You can also reach Argo City,
the Anti-Matter Universe (Shadow Demons and the Anti-Monitor's tower), and, by Waverider,
Vanishing Point, the Time Bureau's station at the end of time.

**A living world.** Civilians walk the sidewalks and flee from fights. Traffic drives the
streets until you hit it. Police patrol, and gangs (the Ghosts, Rogues, Cadmus and the 100) stake
out corners, with more of them at night.

**Heroes and villains play differently.**
- As a **hero**, you earn *Reputation* by stopping robberies, gang wars, super-villain attacks
  and breaches. Hurting civilians or police raises your *heat*: at 2 the police turn on you,
  and at 4 other heroes come after you.
- As a **villain**, you earn *Infamy* by breaking up police raids, taking down hero patrols and
  pulling off armored-truck heists. Your heat rises with every crime, and at 3 heroes start
  hunting you.

**Sandbox tools (Tab).**
- Spawn any character as an ally who follows you or as an enemy (an "evil Supergirl" works).
- Spawn random teams, crowds, gangs, police squads, cars and crates.
- Set the time of day, freeze time, change the weather and adjust gravity.
- Start any event.
- Cheats: god mode, infinite energy, one-hit KOs and no heat.
- Teleport to any landmark, or inside any building.
- Multiverse: jump straight to any Earth, era or the Speed Force.

## Project layout

```
data/roster.json        every character: stats, movement, attacks, special, costume
scripts/core/           Game (roster, input map, settings, factions, heat) and Sfx autoloads
scripts/actors/         Actor body, procedural CharacterModel, player/AI brains, camera
scripts/combat/         Abilities, projectiles and visual effects
scripts/world/          City generator, day/night and weather, population, events, props
scripts/ui/             title, character select, HUD, minimap, pause and sandbox menus
shaders/facade.gdshader building windows that light up at night
tests/                  headless test suite
tools/shots.gd          renders the screenshots in docs/
```

All art, models, textures and sound effects are generated in code at runtime, so the repository
contains no third-party assets.

### Adding a character

Add an entry to `data/roster.json`. Copy an existing character and change its fields:

- `movement`: one of `run`, `speed`, `flight`, `grapple`, `superjump`.
- `primary` / `secondary`: an attack `kind` (`melee`, `arrow`, `explosive_arrow`, `throw`,
  `bolt`, `beam`, `sonic`, `lightning`, `gun`, `dash`) with optional `damage`, `cooldown`,
  `range`, `speed`, `color` and `element` (`fire`, `ice`, `shock`).
- `special`: a `kind` from `scripts/combat/abilities.gd`.
- `look`: suit, accent, skin and hair colours, plus costume `extras` (cape, hood, cowl, bow,
  wings, helmet and more; see `scripts/actors/character_model.gd`).

The test suite checks every entry.

## Tests

```sh
godot --headless --path . res://tests/test_runner.tscn
```

The suite validates the roster and city generation. It plays every character with every
ability, runs a 72-character AI brawl, and starts every event type. It also simulates real
input: sprinting, walking, jumping, flying, heat vision, super-jumping, grappling, shooting and
slow-mo. Finally it checks combat, factions, heat, props, traffic and the menus. CI runs it on
every push before exporting the builds.

## Disclaimer

Crisis City is a non-commercial fan project. It is not affiliated with, endorsed by or
sponsored by DC, Warner Bros. Discovery or The CW. All characters, names and related marks
belong to their respective owners.
