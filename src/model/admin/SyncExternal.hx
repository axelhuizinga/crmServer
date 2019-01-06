package model.admin;

import shared.DbData;
import haxe.macro.Type.Ref;
import haxe.ds.Map;
import php.db.Mysqli;
import haxe.Http;
import haxe.Json;
import php.db.PDO;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import php.Lib;
import php.NativeArray;
import me.cunity.php.db.*;
import php.Syntax;
import php.db.PDOStatement;
import sys.db.*;
import comments.CommentString.*;
using Lambda;
using Util;

/**
 * ...
 * @author axel@bi4.me
 */

@:keep
class SyncExternal extends Model 
{
	public static function create(param:StringMap<String>):Void
	{
		var self:SyncExternal = new SyncExternal(param);	
		//self.table = 'columns';
        trace('calling ${param.get("action")}');
		Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}	

    public function syncUserDetails(?user:Dynamic):Void
    {
        var info:Map<String,Dynamic>  = getViciDialData();
        var req:Http = new Http(info['syncApi']);
        trace(info['syncApi']);
        req.addParameter('pass', info['pass']);
        req.addParameter('user', info['admin']);
        req.addParameter('action', info['syncUserDetails']);
        req.onData = function(data:String)
        {
            //S.saveLog(data);
            var dRows:Array<Dynamic> = Json.parse(data);
            trace(dRows.length);
            //trace(dRows[dRows.length-2]);
            trace(data.indexOf('phone_data'));
            //dbData.dataRows = [['length'=>dRows.length]];
            dbData.dataRows = [];
            var fNames:Array<String> = Reflect.fields(dRows[0]);
            if(!fNames.has('phone_data'))
                fNames.push('phone_data');
            trace(fNames.has('phone_data'));
            for(r in dRows)
            {
                dbData.dataRows.push(
                    [
                        for(n in fNames)
                        n => Reflect.field(r,n)
                    ]
                );
            }
            S.sendData(saveUserDetails(), null);
        };
        req.onError = function (msg:String)
        {
            trace(msg);
        }
        req.onStatus = function (s:Int)
        { trace(s);}
        req.request(true);
        trace('done');
    }

    function saveUserDetails():DbData
    {
        var updated:Int = 0;
        //dbData = new DbData();
        var stmt:PDOStatement = null;
        trace(dbData.dataRows[dbData.dataRows.length-2]);
        for(dR in dbData.dataRows)
        {
           /* var sql:String = 'SELECT external FROM users WHERE user_name = \'${dR['user']}\'';
            var q:EitherType<PDOStatement,Bool> = S.dbh.query(sql);
            if(!q)
            {
                dbData.dataErrors = ['${param.get('action')}' => S.dbh.errorInfo()];
                return dbData;
            }
            var eStmt:PDOStatement = cast(q, PDOStatement);

            var external:NativeArray = eStmt.fetch();
            trace(sql);
            //trace(Type.typeof(external));

            if(1 == updated++)
            trace(external);*/
            var external_text = row2jsonb(Lib.objectOfAssociativeArray(Lib.associativeArrayOfHash(dR)));
            var sql = comment(unindent, format) /*
            UPDATE crm.users SET active='${dR['active']}',edited_by=101, external = jsonb_object('{$external_text}')::jsonb WHERE user_name='${dR['user']}'
            */;
            
            var q:EitherType<PDOStatement,Bool> = S.dbh.query(sql);
            if(!q)
            {
               dbData.dataErrors = ['${param.get('action')}' => S.dbh.errorInfo()];
               return dbData;
            } 
        }        
        dbData.dataInfo = ['saveUserDetails' => 'OK', 'updatedRows' => updated];
        trace(dbData.dataInfo);
		return dbData; 
    }

    public function getViciDialData():Map<String,Dynamic> 
	{		        
        S.saveLog(S.conf.get('ini'));
        var ini:NativeArray = S.conf.get('ini');
        ini = ini['vicidial'];
        var fields:Array<String> = Reflect.fields(Lib.objectOfAssociativeArray(ini));
        var info:Map<String,Dynamic> = [
            for(f in fields)
            f => ini[f]
        ];
        //S.saveLog(info);
        return info;
		S.sendInfo(dbData, info);
	}

}