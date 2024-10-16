This repository holds some examples of my code from Blagmoz, my largest project to date and first Steam release, and Pinpoint, my current solo passion project.
Samples from each game are in their respective folders.

## Blagmoz

**Blagmoz** is an online multiplayer action platformer, and you can learn more about it on my portfolio page [here](https://www.samflemington.com/work/blagmoz). It was created in Godot 3.5.3 using GodotSteam.

### Included files:

Pickupable.gd: Class that handles the networking of physics objects that players can pick up and throw.

Potion.gd: Extends the Pickupable class. Allows players to drink the potions, and makes them break when hitting other players.

PotionManager.gd: Handles the networking aspect of applying the effects of a potion to a given player, as well as choosing which potions are spawned by various game events.

SteamNetwork.gd: Provides a high-level interface for the Steam API networking functions that mimic the behavior of Godot's built-in networking.

## Pinpoint

**Pinpoint** is a juicy roguelike action game that leans heavily into a grappling hook movement ability. I learned a lot about game architecture from Blagmoz, and wanted to make Pinpoint as modular and expandable as possible.
To do this, I use the composition design pattern which allows almost all of the code in the game to be reusable in many different scenarios.

Pinpoint is still in early development, and unlike Blagmoz, is made with Godot 4.2.2.

https://github.com/user-attachments/assets/b03c890b-5986-4bae-921f-6d9cafdcf310

### Included files:

GameWorldGenerated.gd: Generates the world from a set of premade level chunks

Player.gd: Player object code whose behavior is controlled by its components

StateMachine.gd: State machine used on both the player and enemies

State.gd: State class that is extended for different enemy and player behaviors
