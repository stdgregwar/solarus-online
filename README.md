# Solarus Online Layer

This repository contains a demo and all source of an online layer to make the solarus engine online. This is still a work in progress, current features are listed below.

## Features

- server
- fully working 'async' networking
- asymetric world simulation (see below)
- movement replication primitives
- api adaptation for multiplayer aware ennemies
- network synchronised states and actions

In practice the following engine entities are synchronisable :
- hero
-- simple sword
-- no jump,lift,spin-attack
- ennemies
- respawn mechanics
- npcs
- destructibles

## Demo

The demo feature some simple maps trying to expose what's already feasible with
the current state of the engine. Synchronised ennemies are to be tested.

## How it's done

solarus-online make extensive use of the metatables to redefine the behaviour of
all net-enabled entities. A lot of the events are also usefull to grasp engine
state.

### Ennemies, NPC, movable -> a.k.a MOBS

MOBS, mobile objects, are declared to the server that then choose the player that
will simulate the entity. The other players have a logicless puppet that replicate
the movement of the remote ennemy. The reactions to attacks are computed by the
so-called 'master mob' and broadcasted back to the 'slave-mobs'

## What's to be done
- better movement replication
- better hero actions replication
-- this is not hard to do but action replication is cumbersome
- a proper save system
- state for instances
