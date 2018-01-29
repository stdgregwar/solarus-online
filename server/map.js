var State = require('./state.js').State;
var db = require('./db.js').db;

class Worker{
    constructor(id,client) {
        this.state = {};
        this.id = id;
        this.client = client;
    }
}

class Maps{
    constructor(){
        this.maps_by_id = {};
    }

    get_map_promise(map_id) {
        if(!(map_id in this.maps_by_id)) {
            return db.get_map_state(map_id).then((state)=>{
                var map = new Map(map_id,state);
                this.maps_by_id[map_id] = map;
                return map;
            });
        } else {
            return Promise.resolve(this.maps_by_id[map_id]);
        }
    }

    //TODO garbage collect maps that are empty to much time
    client_arrives(client, map_id) {
        if(client.map !== undefined) {
            client.map.client_leaves(client);
        }
        this.get_map_promise(map_id).then((map)=>{
            map.client_arrives(client);
        });
    }

    save() {
        const promises = Object.keys(this.maps_by_id).map((k)=>{
            const map = this.maps_by_id[k];
            return map.save();
        });
        return Promise.all(promises);
    }
}


/**
   Maps are like rooms in a chat, it defines a group of players that share the same
   bit of world, npcs, mobs.

   Map class allow for clean gestions of 'who compute what' and make sure clients stay
   in sync
   **/
class Map{
    constructor(map_id,state) {
        this.map_id = map_id;
        this.heroes = [];
        this.workers = {};
        this.workers_by_clients = {};
        this.mob_states = {};
        this.state = new State(state);
    }

    make_arrival(arriving) {
        return {
            type:'hero_arrival',
            guid:arriving.guid,
            name:arriving.name,
            x:arriving.x,
            y:arriving.y,
            layer:arriving.layer,
            dir:arriving.dir,
            speed:arriving.speed
        };
    }

    notify_client_removal(removed) {
        this.broadcast({type:'hero_removal',guid:removed.guid},removed);
    }

    notify_client_all_alter(client) {
        for(const alter of this.heroes) {
            client.send(this.make_arrival(alter));
        }
    }

    //Notify clients a new client is arriving on the map
    client_arrives(client) {
        this.notify_client_all_alter(client);
        this.broadcast(this.make_arrival(client));
        this.heroes.push(client);
        client.map_id = this.map_id;
        client.map = this;
        this.send_map_own(client,'map_state_init');
        log(1,`${client.name} (${client.guid}) arrived in "${this.map_id}"`);
    }

    send_map_own(client,type) {
        client.send({type:type,map_id:this.map_id,state:this.state.get_raw()});
    }

    choose_new_master(old) {
        delete this.master;
        for(var other of this.heroes) {
            if(other != old) {
                this.master = other;
                break;
            }
        }
        //Situation changed?
        if(this.master && this.master != old) {
            this.send_map_own(this.master,'map_master');
            if(old != undefined) {
                this.send_map_own(old,'map_slave');
            }
        }
        //restore old master if needed
        this.master = this.master || old;
    }

    //Notify other clients the client is leaving, balance worker of this client
    client_leaves(client) {
        const i = this.heroes.indexOf(client);
        if(i != -1) {
            this.heroes.splice(i,1);
            this.notify_client_removal(client);
            if(this.master == client) {
                //Client is master and must be replaced
                this.choose_new_master();
            }
            log(1,`${client.name} (${client.guid}) leaved "${this.map_id}"`);
            //TODO redistribute workers of this client
            //TODO figure out how to do from has not mob
        }
    }

    //Client declare new mob and server decide by who this mob is simulated
    has_mob(client,mob_id) {
        if(mob_id in this.workers) {
            //Worker already exist for this mob
            client.send({type:'remote_mob',
                         mob_id:mob_id,
                         map_id:client.map_id,
                         state:this.get_mob_state(mob_id)});
        } else {
            //Client is the new worker for this mob
            this.workers[mob_id] = client;
            var wbc = this.workers_by_clients[client.guid];
            wbc = wbc ? wbc : [];
            wbc.push(mob_id);
            this.workers_by_clients[client.guid] = wbc;
            client.send({type:'master_mob',
                         mob_id:mob_id,
                         map_id:client.map_id,
                         state:this.get_mob_state(mob_id)});
        }
    }

    //Client declare he don't need mob anymore
    has_not_mob(client,mob_id) {
        if(this.workers[mob_id] == client) { //Client was mob master
            log(0,'client ' + client.guid + "can't simulate " + mob_id + ' anymore...');
            delete this.workers[mob_id];
            var wbc = this.workers_by_clients[client.guid];
            const i = wbc.indexOf(mob_id);
            if(i != -1) {
                wbc.splice(i,1);
            }
            for(var other of this.heroes) {
                if(other != client) {
                    log('client ' + client.guid + ' has taken ' + mob_id + ' in mastery');
                    this.has_mob(other,mob_id);
                    return; //Put first available client as master
                }
            }
            //If no other client was found mob is master-less until someone
            //claims it again
            log(0,'mob ' + mob_id + 'is no longer simulated');
        } else {
            //Don't do anything TODO : discrimintate mob send on map based on
            //client mob havingness
        }
    }

    get_mob_state(mob_id) {
        //TODO replace with a BDD
        this.mob_states[mob_id] = this.mob_states[mob_id] || new State();
        return this.mob_states[mob_id].get_raw();
    }

    mob_state_change(mob_id,msg) {
        this.mob_states[mob_id].update_from_msg(msg,(p)=>{});
    }

    send_to_mob_master(mob_id,msg) {
        if(mob_id in this.workers) {
            this.workers[mob_id].send(msg);
        }
    }

    map_state(client,msg) {
        this.state.update_from_msg(msg,
                                   (p)=>this.broadcast(p,client)
                                  );
    }

    /**
       Send message to all client of the map, with optional except arg
    */
    broadcast(msg,except) {
        for(var hero of this.heroes) {
            if(hero != except) {
                hero.send(msg);
            }
        }
    }

    save() {
        return db.save_map_state(this.map_id,this.state.get_raw());
    }
}


exports.Maps = Maps;
