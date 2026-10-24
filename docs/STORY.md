# Crisis City: the Story Mode campaign

*Every Earth. Every legend. Every enemy. One final crisis.*

This is how the campaign in `scripts/world/missions.gd` is laid out. The mission data lives in
`Missions.MISSIONS`, so you can add or rewrite missions without touching the code that runs
them.

## How Story Mode works

- Choose **Story Mode** on the title screen. A new story starts straight away as Green Arrow;
  **Continue Story** picks up where you left off.
- You start with **only Green Arrow**. Each mission unlocks more heroes. In Act IV, the villains
  you've beaten join the resistance and become playable. Finishing the story unlocks everyone,
  The Architect included.
- **Sandbox** mode turns the story off and unlocks every character, as before.
- Locked characters show a padlock on the character select screen.
- Every character still has their own three-part **spotlight** missions (shown in blue on the
  HUD), in both modes.

## The antagonist: The Architect

An original villain who exists outside normal time. He believes the multiverse is broken
because heroes keep undoing the consequences of their actions. His answer is to merge every
Earth into one controlled reality: **Crisis City**.

He recruits villains by offering each one their greatest desire. Reverse-Flash gets a timeline
where Barry never existed. Damien Darhk gets one where his family never died. Savitar gets one
where he is the only Flash. Reign gets a humanity that asks to be judged. His real plan is to
erase free will itself.

## The campaign

| # | Act | Mission | Play as | What happens | Unlocks |
| --- | --- | --- | --- | --- | --- |
| P | Prologue | The End of Everything | Green Arrow | Oliver's voice-over on black. Star City fractures; Felicity on comms; the Monitor's warning. Title card. | |
| 1 | I · The Cities Fall | A City Without Tomorrow | Green Arrow | Start on a rooftop; reach the evacuation zone (SCPD); free civilians from the rubble; Diggle's radio warning; fight the shadow creatures; find the disturbance at Queen Consolidated; boss: **Malcolm Merlyn**, who vanishes in a green flash. | Spartan, Overwatch, Black Canary, Speedy, Arsenal · Star City open world |
| 2 | I | The Fastest Man Alive | Green Arrow, then The Flash | Reach S.T.A.R. Labs; Team Flash briefing; the story hands you Barry; boss: **Reverse-Flash**, who names the Architect. | The Flash, Vibe, Killer Frost, Iris, Joe, Kid Flash, Elongated Man, Chester, Allegra |
| 3 | I | Girl of Steel | Supergirl | Save the people trapped at CatCo; boss: **Reign** at the D.E.O. | J'onn, Sentinel, Dreamer, Brainy, Lena, Guardian, Mon-El |
| 4 | II · The Broken Timeline | The Broken Timeline | White Canary | Board the Waverider; Gideon's briefing; jump to 1942; boss: **Vandal Savage**. | The Atom, Mick, Zari, Gideon, Constantine, Nate, Behrad, Ava, Rip, Amaya, Mona |
| 5 | II | Speed Force Collapse | The Flash | Run into the Speed Force; Time Wraiths; boss: **Savitar**. | Jay Garrick, Jesse Quick, XS, the Flash of Earth-90 |
| 6 | II | The Temporal Zone | White Canary | The Vanishing Point; boss: **Damien Darhk**. | Nora Darhk, Charlie, Astra, Spooner, Hawkgirl, Hawkman, Vixen |
| 7 | III · War of the Earths | Earth-2 Is Burning | The Flash | Breach to Earth-2; boss: **Zoom**. | Pariah |
| 8 | III | The Reich of Earth-X | Supergirl | Breach to Earth-X; bosses: **Overgirl** and **Dark Arrow**. | The Ray, Superman |
| 9 | III | Smallville Falls | Superman | Lois's warning; boss: **Doomsday** at the Kent Farm. | Jordan, Steel, Lois, Natalie Irons |
| 10 | III | Gotham's Darkest Night | Batwoman | Boss: **Alice** at Arkham Asylum. | Ryan Wilder, Batwing |
| 11 | III | Lightning in Freeland | Black Lightning | Boss: **Tobias Whale**. Then the Architect merges the worlds. | Thunder, Lightning, Grace Choi |
| 12 | IV · The Villains' Victory | The Villains' Victory | anyone | The heroes lost. Star City, Central City, National City and Gotham are **occupied**. Liberate three districts. | Every villain you've beaten |
| 13 | IV | Rebuild the Resistance | anyone | Stargirl calls for help; free the JSA from **Icicle** and Brainwave. | The whole Justice Society |
| 14 | V · One Last Tomorrow | One Last Tomorrow | rotates | The final battle on separate fronts: Green Arrow leads the ground assault (Prometheus, Deathstroke); the Flash stops the temporal engine (Godspeed, Red Death); Supergirl breaks the cosmic defenses (Cyborg Superman, Metallo); Batwoman holds Gotham (Black Mask, Hush); Constantine breaks the spell on the Citadel Beyond Time (Neron). Then Oliver faces **The Architect**, with the exchange from the script. | Everyone |
| | | The Final Strike | your choice | Pick anyone you've unlocked to deliver the final strike. Your choice decides the ending. | |

Endings are written for Green Arrow, the Flash, Supergirl, Superman, White Canary, Batwoman,
Black Lightning, Constantine and Stargirl. Anyone else gets a general ending in their name.

## Boss fights

Every story boss gets an intro cutscene, using its scripted exchange where there is one, then a
fight in three phases:

1. Full health down to 2/3.
2. At 2/3: a **clash** QTE (mash attack).
3. At 1/3: the boss enrages and unleashes a **combo** you counter by hitting the keys in order.

Near the end comes a **FINISH THEM** prompt (G) for a cinematic finisher. The boss bar shows
the boss's name, show, phase and status. Bosses that escape (Malcolm in Mission 01) say their
piece and vanish instead.

## Crisis Events

From Act I's second mission on, while you're roaming Earth-1, a crisis breaks out in another
city and a three-minute clock starts. The world remembers what you do:

- **Get there in time** and beat the attackers, and the city is safe. If they were holding a
  hero from an erased timeline, that hero is freed and **unlocked**.
- **Ignore it**, and that district is **occupied**. The HUD marks it, and walking in brings
  its occupation force. Beat their lieutenant to **liberate** it.
- Occupied districts and the villains you've beaten are saved.

## Character spotlights

Every hero and villain has a three-part personal storyline: hand-written for the main characters,
and built from their team, home city and nemesis for everyone else. Story Mode adds the
campaign appearances above. Characters from the planning roster who aren't in the game yet can
be added to `tools/make_roster.py`; their spotlight missions are generated automatically.

## What's not in yet

From the original plan, these are still to do:

- Choices with long-term consequences ("save a villain's family", deals that turn allies against
  you).
- Who survives or is absent changing the final battle.
- A villain seizing territory after another villain is beaten.
- A full character-by-character campaign bible.
