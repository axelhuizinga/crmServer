package model.admin;

import haxe.Http;
import haxe.Json;
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

	public function getViciDialUsers():Void
	{
		var ini:NativeArray = S.conf.get('ini');
		var vD:NativeArray = ini['vicidial'];
		//trace(ini);
		trace(S.vicidialUser);
		var url:String = Syntax.code("{0}['vicidial']['url']", ini);
		trace(url + '?className=AdminApi&action=vicidial_users&user=${S.vicidialUser}&pass=${S.vicidialPass}');
		//var res:String = Http.requestUrl('${url}?className=AdminApi&action=vicidial_users&user=${S.vicidialUser}&pass=${S.vicidialPass}');
		var res:String =  Syntax.code("file_get_contents({0})", '$url?className=AdminApi&action=vicidial_users&user=${S.vicidialUser}&pass=${S.vicidialPass}');
		trace(res.substr(0, 100));
		var vUsers:Dynamic = Json.parse(res);
		//var vUsers:Dynamic = Json.parse(Http.requestUrl(res));
		//var vUsers:Dynamic = Json.parse(Http.requestUrl('${url}?className=AdminApi&action=vicidial_users&user=${S.vicidialUser}&pass=${S.vicidialPass}'));
		data.rows = vUsers.rows;
		json_encode();		
	}
	
	public function fromViciDial():Void
	{
		var ini:NativeArray = S.conf.get('ini');
		var vD:NativeArray = ini['vicidial'];
		//trace(ini);
		trace(S.vicidialUser);
		var url:String = Syntax.code("{0}['vicidial']['url']", ini);
		trace(url + '?className=AdminApi&action=vicidial_user_groups&user=${S.vicidialUser}&pass=xxx');
		var vUserGroups:Dynamic = Json.parse(Http.requestUrl(
		'${url}?className=AdminApi&action=vicidial_user_groups&user=${S.vicidialUser}&pass=${S.vicidialPass}'));
		data.rows = vUserGroups.rows;
		json_encode();
	}
	
}