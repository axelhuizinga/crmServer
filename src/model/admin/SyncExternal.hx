package model.admin;

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
            //dbData.dataRows = [['length'=>dRows.length]];
            dbData.dataRows = [];
            var fNames:Array<String> = Reflect.fields(dRows[0]);
            trace(fNames);
            for(r in dRows)
            {
                dbData.dataRows.push(
                    [
                        for(n in fNames)
                        n => Reflect.field(r,n)
                    ]
                );
            }
            S.sendData(dbData, null);
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
        S.saveLog(info);
        return info;
		S.sendInfo(dbData, info);
	}

}