package model.admin;

import haxe.Http;
import haxe.Json;
import hx.strings.RandomStrings;
import php.db.PDO;
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
		//self.table = 'columns';
		Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}	
	
	public function addContact(contact:Dynamic):Int
	{
		trace(contact.user);
		var name:Array<String> = contact.full_name != null ? contact.full_name.split(" "):['', ''];
		if (name.length == 1)
			name.unshift('');
		var sql = comment(unindent, format) /*
			WITH new_contact AS (
				INSERT INTO crm.contacts (mandator,phone_number,first_name,last_name,edited_by)
				VALUES (1, '${contact.phone_number}', '${name[0]}', '${name[1]}', 100)
				ON CONFLICT DO NOTHING
				returning id)
				select id from new_contact;
			*/;
		trace(sql);
		var res:PDOStatement = S.my.query(sql,PDO.FETCH_ASSOC);
		if (untyped res == false)
		{
			trace(S.my.errorInfo());
			S.exit({data:'ERROR'});
		}
		trace('Inserted ? ' + res.rowCount());
		trace('Inserted ${contact.full_name}: ' + res.rowCount());
		if (res.rowCount() == 1)
		{
			@:arrayAccess
			var added:NativeArray = res.fetch();
			trace(added);
			return added['id'];
		}
		sql = comment(unindent, format) /*		
		SELECT id FROM contacts WHERE phone_number='${contact.phone_number}' AND first_name='${name[0]}' AND last_name='${name[1]}'
		*/;
		res = S.my.query(sql, PDO.FETCH_ASSOC);
		if (res.rowCount() == 1)
		{
			@:arrayAccess
			var found:NativeArray = res.fetch();
			trace(found);
			return found['id'];
		}		
		trace(sql +':' + S.my.errorInfo());
		return null;		
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
			if (iRow.user.indexOf('V') == 0)
				continue;
			var contactId:Int = addContact(iRow);
			if (contactId == null)
			{
				S.exit({data:'ERROR'});
			}
			var initialPass:String = Util.randomString(13);
			var external_text = row2jsonb(iRow);
			//id contact last_login password user_name active 	edited_by 	editing 	settings 	external 	user_group 	changePassRequired
			var sql = comment(unindent, format) /*
			WITH user_group AS (SELECT id FROM user_groups WHERE name='${iRow.user_group}') 
			INSERT INTO crm.users VALUES (DEFAULT, $contactId, DEFAULT, CRYPT('$initialPass', gen_salt('bf', 8)), ${iRow.user}, 
			CASE WHEN '${iRow.active}'='Y' THEN TRUE ELSE FALSE END, $sysadmin, DEFAULT,
			jsonb_object('{"initialPass", "$initialPass"}'), 
			jsonb_build_object('1', jsonb_object('{$external_text}')::jsonb), (SELECT * FROM user_group), TRUE)  
			ON CONFLICT (user_name) DO UPDATE SET contact=$contactId 
			*/;
			trace(sql);
			var res:PDOStatement = S.my.query(sql);
			if (untyped res == false)
			{
				trace(S.my.errorInfo());
				S.exit({data:'ERROR'});
			}
			trace('Inserted ${iRow.user_group}: ' + res.rowCount());
			//S.exit({data:'OK'});
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