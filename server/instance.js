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
}

exports.Instances = Instances;
