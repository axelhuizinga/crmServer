package model.admin;

import haxe.Http;
import haxe.Json;
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

	public function fromViciDial():Void
	{
		var conf:NativeArray = Syntax.code("$conf");
		trace(conf);
		var vUserGroups:Dynamic = Json.parse(Http.requestUrl(conf['url']+'?className=AdminApi&action=vicidial_user_groups&user=${conf["user"]}&pass=${conf["pass"]}'));
		data.rows = vUserGroups.rows;
		json_encode();
	}
	
}