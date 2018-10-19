package model.admin;

import haxe.Http;
import haxe.Json;
import hx.strings.RandomStrings;
//import tjson.TJSON;
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
class CreateUsers extends Model 
{
	public static function create(param:StringMap<String>):Void
	{
		var self:CreateUsers = new CreateUsers(param);	
		self.table = 'columns';
		Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}	

	public function getViciDialUserGroups():Array<Dynamic>
	{
		var ini:NativeArray = S.conf.get('ini');
		var vD:NativeArray = ini['vicidial'];
		//trace(ini);
		trace(S.vicidialUser);
		var url:String = Syntax.code("{0}['vicidial']['url']", ini);
		trace(url + '?className=AdminApi&action=vicidial_user_groups&user=${S.vicidialUser}&pass=xxx');
		var vUserGroups:Dynamic = Json.parse(Http.requestUrl(
		'${url}?className=AdminApi&action=vicidial_user_groups&user=${S.vicidialUser}&pass=${S.vicidialPass}'));
		return vUserGroups.rows;		
	}
	
	public function getViciDialUsers():Void
	{
		var rows:Array<Dynamic> = vicidialUsers();
		S.exit({rows:rows});		
	}
	
	public function fromViciDial():Void
	{
		var rows:Array<Dynamic> = getViciDialUserGroups();
		S.exit({rows:rows});
	}
	
	function get_end_reasons():Array<Dynamic>
	{
		var ini:NativeArray = S.conf.get('ini');
		var vD:NativeArray = ini['vicidial'];
		//trace(ini);
		trace(S.vicidialUser);
		var url:String = Syntax.code("{0}['vicidial']['url']", ini);
		trace(url + '?className=AdminApi&action=storno_grund&user=${S.vicidialUser}&pass=xxx');
		//trace(Syntax.code("file_get_contents({0})",'${url}?className=AdminApi&action=storno_grund&user=${S.vicidialUser}&pass=${S.vicidialPass}'));
		return Json.parse(Syntax.code("file_get_contents({0})",
		'${url}?className=AdminApi&action=storno_grund&user=${S.vicidialUser}&pass=${S.vicidialPass}')).rows;
		//data.rows = end_reasons.rows;		
	}
	
	public function importExternal():Void
	{
		var mandator:Int = 1;
		var sysadmin:Int = 100;
		
		/*var rows:Array<Dynamic> = get_end_reasons();
		for (iRow in rows)
		{
			//trace(iRow.grund);
			var sql = 'INSERT INTO crm.end_reasons VALUES (${iRow.id}, \'${iRow.grund}\', 100,1) ON CONFLICT DO NOTHING;';
			var res:PDOStatement = S.my.query(sql);			
			res.execute();
			trace(res.rowCount());
		}
		S.exit({data:'OK'});
		*/
		/*
		var rows:Array<Dynamic> = getViciDialUserGroups();
		for (iRow in rows)
		{
			var sql = 'INSERT INTO crm.user_groups VALUES (DEFAULT, \'${iRow.user_group}\', \'${iRow.group_name}\',DEFAULT, 1,100) ON CONFLICT DO NOTHING;';
			var res:PDOStatement = S.my.query(sql);			
			res.execute();
			trace('Inserted ${iRow.user_group}: ' + res.rowCount());
		}
		//trace(data.rows);
		//trace(Reflect.field(data.rows, 'arr'));
		//trace(Lib.toHaxeArray(data.rows));
		//S.exit({data:data.rows});
		S.exit({data:'OK'});
		*/
		var rows:Array<Dynamic> = vicidialUsers();
		for (iRow in rows)
		{
			var initialPass:String = Util.randomString(13);
			var external_text = row2jsonb(iRow);
			//id contact last_login password user_name active 	edited_by 	editing 	settings 	external 	user_group 	changePassRequired
			var sql = comment(unindent, format) /*
			WITH user_group AS (SELECT id FROM user_groups WHERE name='${iRow.user_group}') 
			INSERT INTO crm.users VALUES (DEFAULT, DEFAULT, DEFAULT, CRYPT('$initialPass', gen_salt('bf', 8)), ${iRow.user}, 
			CASE WHEN '${iRow.active}'='Y' THEN TRUE ELSE FALSE END, $sysadmin, DEFAULT,
			jsonb_object('{"initialPass", "$initialPass"}'), 
			jsonb_object('$external_text'), (SELECT * FROM user_group), TRUE) ON CONFLICT DO NOTHING;
			*/;
			trace(sql);
			var res:PDOStatement = S.my.query(sql);
			if (untyped res == false)
			{
				trace(S.my.errorInfo());
				S.exit({data:'ERROR'});
			}
			var result:Bool = res.execute();
			trace('Inserted ${iRow.user_group}: ' + res.rowCount());
			S.exit({data:'OK'});
		}
		//trace(data.rows);
		//trace(Reflect.field(data.rows, 'arr'));
		//trace(Lib.toHaxeArray(data.rows));
		//S.exit({data:data.rows});
		S.exit({data:'OK'});
	}
	
	public function vicidialUsers():Array<Dynamic>
	{
		var ini:NativeArray = S.conf.get('ini');
		var vD:NativeArray = ini['vicidial'];
		//trace(ini);
		trace(S.vicidialUser);
		var url:String = Syntax.code("{0}['vicidial']['url']", ini);
		trace(url + '?className=AdminApi&action=vicidial_users&user=${S.vicidialUser}&pass=${S.vicidialPass}');
		//var res:String = Http.requestUrl('${url}?className=AdminApi&action=vicidial_users&user=${S.vicidialUser}&pass=${S.vicidialPass}');
		var res:String =  Syntax.code("file_get_contents({0})", '$url?className=AdminApi&action=vicidial_users&user=${S.vicidialUser}&pass=${S.vicidialPass}&active=Y');
		trace(res.substr(0, 18));
		return Json.parse(res).rows;
	}
	
}