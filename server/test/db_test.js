var expect = require('chai').expect;
var DB = require('../db.js').DB;

var con = {
    dialect : 'sqlite3',
    connection : {
        filename : ':memory:'
    }
};

describe('init database',function() {
    it('should create the tables', function() {
        var db = new DB(con);
        db.init().then(()=>{
            return db.knex.schema.hasTable('users');
        }).then((exists)=>{
            expect(exists).to.be.equal(true);
        });
    });
});

describe('test user state create',function() {
    it('should serialize and unserialize user state', function(){
        var userid = 'anid';
        var username = 'aname';
        var state = {
            test:'state',
            with:'several',
            fields:'?'
        };
        var db = new DB(con);
        db.init().then(()=>{
            return db.create_user(userid,username,state);
        }).then(()=>{
            return db.get_user_state(userid);
        }).then((astate)=>{
            expect(astate).to.deep.equal(state);
        });
    });
});

describe('test map state set-get', function() {
    it('should ser and unser map state',()=>{
        var db = new DB(con);
        var map_state = {
            test:'state',
            with:'several',
            fields:'?'
        };
        var map_id = 'a_map_in_the_world';
        db.init().then(()=>{
            return db.save_map_state(map_id,map_state);
        }).then(()=>{
            return db.get_map_state(map_id);
        }).then((astate)=>{
            expect(astate).to.deep.equal(map_state);
        });
    });
});
