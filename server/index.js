var net = require('net');
var Guid = require('guid');
var log = console.log;

const settings = require('./server_settings.js').settings;
var mm = require('./map.js');
var insts = require('./instance.js');
var State = require('./state.js').State;
var maps_by_id = {};

var maps = new mm.Maps();
var instances = new insts.Instances();

instances.create_instance('main'); //add main instance
var clients_by_guid = {};

function broadcast_on_map(socket,msg) {
    //msg.guid = socket.guid;
    if(socket.map) {
        socket.map.broadcast(msg,socket);
    } else {
        log('socket ' + socket.guid + ' has no map');
    }
}

function send_to_mob_master(socket,msg) {
    if(socket.map) {
        socket.map.send_to_mob_master(msg.mob_id,msg);
    }
}

function hero_state(socket,msg) {
    socket.state.update_from_msg(msg,
                                 (p)=>broadcast_on_map(socket,p)
                                );
}

const handlers = {
    hello : (socket,msg)=>{
        const guid = Guid.raw();
        log("Guid for player " + msg.name + " : " + guid);
        socket.guid = guid;
        socket.name = msg.name;
        socket.send({type:'guid', guid:guid,time:Date.now()});
        //By default client is in main instance
        instances.client_arrives(socket,'main');
        clients_by_guid[guid] = socket;
    },
    hero_arrival : function(socket,msg) {
        log('Hero has changed map to ' + msg.map_id);
        socket.x = msg.x;
        socket.y = msg.y;
        socket.layer = msg.layer;
        socket.dir = msg.dir;
        socket.speed = msg.speed;
        socket.instance.maps.client_arrives(socket,msg.map_id);
    },
    hero_pos : broadcast_on_map,
    hero_move : broadcast_on_map,
    hero_state : hero_state,
    mob_move : broadcast_on_map,
    hero_action : broadcast_on_map,
    mob_action : broadcast_on_map,
    mob_attacked : send_to_mob_master,
    mob_activated : broadcast_on_map,
    mob_death : broadcast_on_map,
    get_new_instance : function(socket,msg) {
        //returns a new instance token
        const inst_token = instances.create_instance();
        socket.send({type:'instance_token',token:inst_token});
    },
    change_instance : function(socket,msg) {
        var answer = 'denied';
        var reason = 'no such instance';
        if(instances.can_change_to_instance(socket,msg.token)) {
            instances.client_arrives(socket,msg.token);
            answer = 'done';
            reason = '';
        }
        socket.send({type:'instance_change',
                     token:msg.token,
                     reason:reason,
                     answer:answer});
    },
    send_to : function(socket,msg) {
        var to_send = msg.msg;
        to_send.from = socket.guid;
        if(msg.to in clients_by_guid) {
            const to = clients_by_guid[msg.to];
            to.send(to_send);
        } else {
            socket.send({type:'error',error:`no such client : ${msg.to}`});
        }
    },
    has_mob : function(socket,msg) {
        socket.map.has_mob(socket,msg.mob_id);
    },
    has_not_mob : function(socket,msg) {
        socket.map.has_not_mob(socket,msg.mob_id);
    },
    mob_state : function(socket,msg) {
        socket.map.mob_state_change(msg.mob_id,msg);
        broadcast_on_map(socket,msg);
    },
    get_mob_state : function(socket,msg) {
        const state = socket.map.get_mob_state(msg.mob_id);
        socket.send({type:'get_mob_state_qa',qn:msg.qn,state:state});
    },
    get_hero_state : (socket,msg) => {
        const state = socket.state.get_raw();
        socket.send({type:'get_hero_state_qa',qn:msg.qn,state:state});
    },
    get_map_state : function(socket,msg) {
        const map = socket.instance.maps.maps_by_id[msg.map_id];
        if(typeof map == 'object') {
            socket.send({type:'get_map_state_qa',qn:msg.qn,state:map.state.get_raw()});
        }
    },
    map_state : function(socket,msg) {
        socket.map.map_state(socket,msg);
    },
    map_action : broadcast_on_map,
    get_header: function(socket,msg) {
        socket.send({type:'server_header',header:{description:settings.description}});
    }
};

function message_handler(socket,msg) {
    if(msg.type in handlers) {
        handlers[msg.type](socket,msg);
    }
}

const log_blacklist = {
    mob_move : true,
    hero_move : true
};

var server = net.createServer(function(socket) {
    socket.send = function(obj) {
        const str = JSON.stringify(obj);
        if(!(obj.type in log_blacklist)) log('Sending ' + str);
        socket.write(str + '\n');
    };
    socket.state = new State();
    var buf = '';
    const terminator = '\n';
    socket.on('data', function(data) {
        buf += data;
        if(buf.indexOf(terminator) >= 0) {
            const datas = buf.split(terminator);
            for (var i = 0; i < datas.length -1; ++i) {
                var dt = datas[i];
                try{
                    const msg = JSON.parse(dt);
                    if(!(msg.type in log_blacklist))console.log('Received ' + dt);
                    message_handler(socket,msg);
                } catch(e) {
                    log("Error " + e);
                    if(e.stack) {
                        log('\n========Stack========');
                        log(e.stack);
                    }
                }
            }
            buf = datas[datas.length-1];
        }
    });
    socket.on('close',function(data) {
        //remove_hero_from_map(socket,socket.map_id);
        if(socket.map !== undefined) {socket.map.client_leaves(socket);}
        delete clients_by_guid[socket.guid];
    });
    socket.on('error',function(err) {
        console.error(err);
        log("Continuing after error");
    });
});

log(`Started server for quest ${settings.quest_name}! listening on port : ${settings.port}`);
server.listen(settings.port);
