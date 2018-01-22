class State {
    constructor(base) {
        this.state = base || {};
    }

    get_raw() {
        return this.state;
    }

    set(state) {
        this.state = state;
    }

    update(diff) {
        if('new' in diff) {
            for(const k in diff.new) {
                this.state[k] = diff.new[k];
            }
        }
        if('mod' in diff) {
            for(const k in diff.mod) {
                this.state[k] = diff.mod[k];
            }
        }
        if('rem' in diff) {
            for(const k in diff.rem) {
                delete this.state[k];
            }
        }
        //console.log('updated state : ' + JSON.stringify(this.state));
    }

    update_from_msg(msg,send) {
        if('diff' in msg) {
            this.update(msg.diff);
            send(msg);
        } else if('state' in msg) {
            this.set(msg.state);
            send(msg);
        }
    }
}

exports.State = State;
