var mm = require('./map.js');
var guid = require('guid');

class Instances{
    constructor() {
        this.instances = {};
    }

    create_instance(hint_id) {
        const new_id = hint_id || guid.raw();
        if(new_id in this.instances) {
            throw 'instance already exists!';
        }
        this.instances[new_id] = new Instance(new_id);
        return new_id;
    }

    can_change_to_instance(socket,inst_id) {
        return inst_id in this.instances; //TODO discriminate better
    }

    client_arrives(client,inst_id) {
        if(client.instance !== undefined) {
            client.instance.client_leaves(client);
        }
        this.instances[inst_id].client_arrives(client);
    }

    instance(id) {
        return this.instances[id];
    }
}

class Instance{
    constructor(id) {
        this.inst_id = id;
        this.maps = new mm.Maps();
    }

    client_arrives(client) {
        client.instance = this;
    }

    client_leaves(client) {
        client.instance = undefined;
    }

    save() {
        //TODO save instance state as well
        return this.maps.save();
    }

    broadcast(msg,except) {
        for(const map_id in this.maps.maps_by_id) {
            let map = this.maps.maps_by_id[map_id];
            map.broadcast(msg,except);
        }
    }
}

exports.Instances = Instances;
