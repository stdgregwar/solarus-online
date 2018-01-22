var term = require('terminal-kit').terminal;


function cmd(d,s,f) {
    return {
        description:d,synops:s,exec:f
    };
}

function help_cmd() {
    for(const cname in commands) {
        const cmd = commands[cname];
        term.bold(cname)('\t')(cmd.description)(' synops : ')(cmd.synops)('\n');
    }
}

function list_cmd(terminal) {
    const n = Object.keys(terminal.clients).length;
    term('There are ').bold(''+n)(' clients :\n');
    for(const guid in terminal.clients) {
        const client = terminal.clients[guid];
        term(`${client.name}, `);
        if(client.map) {
            term(`on map "${client.map.map_id}", `);
        }
        term(`guid : ${client.guid})\n`);
    }
}

function stats_cmd(terminal, tokens) {
    term(`stat with category ${tokens[0]}\n`);
}

function stop_cmd(terminal) {
    terminal.server.stop();
}

function log_level_cmd(terminal,tokens) {
    const lvl = parseInt(tokens[0]);
    terminal.log_level = lvl;
}

var commands = {
    help:cmd('display this help message','help',help_cmd),
    list:cmd('list all players','list',list_cmd),
    stats:cmd('display server stats','stats [category]',stats_cmd),
    stop:cmd('stop the server', 'stop',stop_cmd),
    set_log_level:cmd('set the importance that a msg need to get printed','set_log_level level(int)',log_level_cmd)
};

var cmd_array = [];

for (const cname in commands) {
    cmd_array.push(cname);
}

class Terminal {
    constructor(clients,handlers,instances,server) {
        this.clients = clients;
        this.handlers = handlers;
        this.instances = instances;
        this.server = server;
        this.ps2 = '>';
        this.log_level = 2;
        this.welcome = 'Solarus cmd opened. Type "help" for a list of commands';
        this.history = [];
    }

    start_terminal() {
        term.green(this.welcome)('\n');
        this.repl();
    }

    repl(text,cursor) {
        var dtext = text || '';
        var dcursor = cursor || 0;
        term(this.ps2);
        this.input = term.inputField({
            echo:true,
            default:dtext,
            cursorPosition:dcursor,
            history:this.history,
            autoComplete:cmd_array,
            autoCompleteMenu:true
        },(error,input)=>{
            if(!error) {
                this.exec(input);
            } else {
                this.error(error);
            }
        });
    }

    exec(line) {
        var tokens = line.split(' ');
        if(tokens.length < 1) {
            this.error('no cmd');
            return;
        }
        const cmd_name = tokens[0];
        tokens.splice(0,1);
        if(cmd_name in commands) {
            const cmd = commands[cmd_name];
            term('\n');
            cmd.exec(this,tokens);
            this.history.push(line);
        } else {
            this.error(`no such command ${cmd_name}`);

        }
        this.repl();
    }

    error(error) {
        term('\n').red(error)('\n');
    }

    log(level,msg) {
        if(level >= this.log_level) {
            var text = this.input.getInput();
            var cursor = this.input.getCursorPosition();
            this.input.abort();
            term.eraseLine();
            term.left(cursor+1);
            term(msg)('\n');
            this.repl(text,cursor);
        }
    }

    stop() {
        term.processExit();
    }
}

exports.Terminal = Terminal;
