# EscortAutoQuest

A World of Warcraft Forever addon that automatically hands in the prerequisite quests for escort quests, then leaves the escort itself alone so you get the "start escort" popup when another party member begins it.

## What it does

- Accepts and turns in whitelisted prerequisite quests automatically.
- Never accepts the escort quest. It is declined at the quest window, so it stays available.
- Picks up the prerequisite from gossip menus as well as direct quest windows.
- Leaves reward choices to you if a quest offers more than one.

## Supported quests

| Area | Prerequisite | Escort (never accepted) |
| --- | --- | --- |
| Razorfen Downs | Scourge of the Downs | Extinguishing the Idol |
| Blackrock Depths | A Shred of Hope | Jail Break! |
| Tanaris | Find OOX-17/TN! | Rescue OOX-17/TN! |
| The Hinterlands | Find OOX-09/HL! | Rescue OOX-09/HL! |
| Feralas | Find OOX-22/FE! | Rescue OOX-22/FE! |
| Dustwallow Marsh | Lieutenant Paval Reethe | Questioning Reethe |
| Feralas | The Giant Guardian | Wandering Shay |

## Installation

1. Extract the folder named `EscortAutoQuest` to your AddOns directory:
   `World of Warcraft/_forever_/Interface/AddOns/`
2. Restart the game or type `/rl`.

## Usage

It works automatically. Hold **Shift** when talking to an NPC to bypass it.

| Command | Effect |
| --- | --- |
| `/eaq` or `/escortauto` | Show status and help |
| `/eaq toggle` | Turn the addon on or off for the session |
| `/eaq debug` | Toggle diagnostic messages |

## Known limitations / issues

- Use `/eaq debug` if a quest isn't being picked up.
- Session settings (`toggle`, `debug`) are not saved between logins.

## Licence

MIT License

Copyright (c) [2026] [ridai260]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.