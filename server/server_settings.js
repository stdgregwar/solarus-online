const settings = {
    port:1337,
    description:'solarus-online demo',
    quest_name:'solarus-online',
    db_connection : { //See knex documentation 
        dialect : 'sqlite3',
        connection : {
            filename : './world.db'
        }
    }
};

exports.settings = settings;
