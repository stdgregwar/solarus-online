var knex_builder = require('knex');
var settings = require('./server_settings.js').settings;

class DB{
    constructor(connection) {
        this.connection = connection;
    }

    init() {
        this.knex = knex_builder(this.connection);
        return this.knex.schema.hasTable('users').then((exists)=>{
            if(!exists){
                return this.createSchema();
            } else {
                return Promise.resolve();
            }
        });
    }

    createSchema() {
        return this.knex.schema.createTable('users',(table)=>{
            table.string('guid').primary().notNullable();
            table.string('name').notNullable();
            table.json('json_state').notNullable();
        }).createTable('instances',(table)=>{
            table.string('instance_id').notNullable().primary();
            table.json('json_state').notNullable();
        }).createTable('maps',(table)=>{
            table.string('map_id').notNullable().primary();
            table.json('json_state').notNullable();
        });
    }

    has_user(guid) {
        return this.has_row('users','guid',guid);
    }

    create_user(guid,name,state) {
        return this.knex('users')
            .insert({
                guid:guid,
                name:name,
                json_state:JSON.stringify(state)});
    }

    save_user_state(guid,state) {
        return this.knex('users')
            .where('guid','=',guid)
            .update({json_state:JSON.stringify(state)});
    }

    save_instance_state(instance_id, state) {
        return this.save_state('instances','instance_id',instance_id,state);
    }

    save_map_state(map_id,state) {
        return this.save_state('maps','map_id',map_id,state);
    }

    get_map_state(map_id) {
        return this.get_state('maps','map_id',map_id);
    }

    get_instance_state(instance_id) {
        return this.get_state('instances','instance_id',instance_id);
    }

    get_user_state(guid) {
        return this.get_state('users','guid',guid);
    }

    has_row(table,id_key,id) {
        return this.knex.select(id_key)
            .from(table)
            .where(id_key,'=',id)
            .then((rows)=>{
                return rows.length > 0;
            });
    }

    save_state(table,id_key,id,state) {
        return this.has_row(table,id_key,id).then((has)=>{
            if(has){
                return this.update_state(table,id_key,id,state);
            } else {
                return this.create_row(table,{
                    [id_key]:id,
                    json_state:JSON.stringify(state)
                });
            }
        });
    }

    create_row(table,content) {
        return this.knex(table)
            .insert(content);
    }

    update_state(table,id_key,id,state) {
        return this.knex(table)
            .where(id_key,'=',id)
            .update({json_state:JSON.stringify(state)});
    }

    get_state(table,id_key,id) {
        return this.knex.select('json_state')
            .from(table)
            .where(id_key,'=',id)
            .then((rows)=>{
                if(rows.length == 1) {
                    return JSON.parse(rows[0].json_state);
                } else {
                    return {};
                }
            });
    }
}

exports.db = new DB(settings.db_connection);
exports.DB = DB;
