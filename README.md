# Solarus Online Layer

This repository contains a demo and all source of an online layer to make the [solarus engine](https://github.com/solarus-games/solarus) online. This is still a work in progress, current features are listed below.

![screenshot](https://github.com/stdgregwar/solarus-online/raw/master/screen1.png)

## Features

- server
- fully working 'async' networking
- asymetric mob simulation (see below)
- symetric map,object simulation
- movement replication primitives
- api adaptation for multiplayer aware ennemies
- network synchronised states and actions

In practice the following engine entities are synchronisable :
- hero
  - simple sword
  - no jump,lift
- ennemies
  - respawn mechanics
- npcs
- destructibles
- maps

## Dependencies

### Client
In addition to solarus-engine, the following lua libraries must be in your lua5.1 path:
- luasocket
- luajson

### Server

Server runs on nodejs. You need nodejs and npm to install packages.

## Running the server

```
#in 'server' folder
#installing server dependencies
npm install
#running the server
node index.js
```

You can edit 'server_settings' to choose port and welcome message for your server.

## Connecting to a server

The serverlist.lua file contains a list of three servers that shows in the server
selection menu. You can then select your server directly in game.

## Demo

The demo feature some simple maps, including a short 'dungeon', trying to expose what's already feasible with
the current state of the layer.

Lot of the ennemies and hud code is adapted from [ZSDX](https://github.com/solarus-games/zsdx)
full credit for the ressources and scripts goes to their respective owners.

## How it's done

solarus-online make extensive use of the metatables to redefine the behaviour of
all net-enabled entities. A lot of the events are also usefull to grasp engine
state.

### Ennemies, NPC, movable -> a.k.a MOBS

MOBS, mobile objects, are declared to the server that then choose the player that
will simulate the entity. The other players have a logicless puppet that replicate
the movement of the remote ennemy. The reactions to attacks are computed by the
so-called 'master mob' and broadcasted back to the 'slave-mobs'

### Maps

When writing online-map scripts, you provide information about how your map react
to state change and how actions of you player alter map state. As the state is
synchronised between clients. This is sufficient to garantee a synced map.

## What's to be done
- better movement replication
- better hero actions replication
  - this is not hard but action replication is cumbersome
- a proper save system
- sync use of equipement
- make every solarus entities work, or provide workaround
- state for instances
- a proper hud and chat
