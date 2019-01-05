package;

import haxe.PosInfos;
//import haxe.ds.Either;
import haxe.ds.StringMap;
import haxe.io.Bytes;
import me.cunity.debug.Out;
import php.Syntax;
import php.db.PDO;
import php.db.PDOStatement;
import shared.DbData;

//import me.cunity.php.Services_JSON;
//import phprbac.Rbac;
//import model.AgcApi;
//import model.App;
//import model.Campaigns;
import model.contacts.Contact;
import model.admin.CreateHistoryTrigger;
import model.admin.CreateUsers;
import model.admin.SyncExternal;
import model.roles.Users;
import model.tools.DB;
import Model.MData;
import Model.RData;
//import model.QC;
//import model.Select;
import model.auth.User;
import php.Lib;
import me.cunity.php.Debug;
import php.NativeArray;
//import php.Session;
import php.Web;
//import tjson.TJSON;
import haxe.Json;
import haxe.extern.EitherType;
import hxbit.Serializer;
import sys.io.File;
import comments.CommentString.*;

using Lambda;
using Util;
/**
 * ...
 * @author axel@cunity.me
 */

typedef Response =
{
	?content:Dynamic,
	?error:Dynamic,
	?data:MData
}

typedef PDOResult = EitherType<Bool,PDOStatement>;

class S 
{
	static inline var debug:Bool = true;
	static var headerSent:Bool = false;
	static var response:Response;
	public static var secret:String;
	public static var conf:StringMap<Dynamic>;
	public static var dbh:PDO;
	public static var last_request_time:Date;
	public static var host:String;
	public static var request_scheme:String;
	public static var user_name:String;
	public static var db:String;
	public static var dbHost:String;
	public static var dbUser:String;
	public static var dbPass:String;	
	public static var vicidialUser:String;
	public static var viciDial: Map<String, Dynamic>;
	
	static function main() 
	{		
		haxe.Log.trace = Debug._trace;	

		//trace(conf.get('ini'));
		var ini:NativeArray = S.conf.get('ini');
		var vD:NativeArray = ini['vicidial'];
		trace(ini);
		trace(vD);
		var viciDial = Lib.hashOfAssociativeArray(vD);
		trace(viciDial['url']);
		trace(viciDial['admin']);
		trace(Syntax.code("$_SERVER['VERIFIED']"));
		//var pd:Dynamic = Web.getPostData();
		last_request_time = Date.now();
		var now:String = DateTools.format(last_request_time, "%d.%m.%y %H:%M:%S");
		response = {content:'',error:''};
		var params:Map<String,Dynamic> = Web.getParams();
		
		trace(Date.now().toString() + ' == $now' );		
		trace(params);		

		var action:String = params.get('action');
		if (action.length == 0 || params.get('className') == null)
		{
			trace(Web.getMethod());
			trace(Web.getClientHeaders());
			exit( { error:"required params action and/or className missing" } );
		}
			
		dbh = new PDO('pgsql:host=$dbHost;dbname=$db',dbUser,dbPass,Syntax.array(['client_encoding','UTF8']));
		//dbh.set_charset("utf8");
		trace(dbh);
		var jwt:String = params.get('jwt');
		var user_name:String = params.get('user_name');
		trace(jwt +':' + (jwt != null));
		if (jwt.length > 0)
		{
			if(User.verify(jwt, user_name,params))
				Model.dispatch(params);			
		}
	
		User.login(params, secret);		
		exit(response);

	}
	
	public static function add2Response(ob:Response, doExit:Bool = false)
	{
		if (ob.content != null)
			response.content += ob.content;
		if (ob.error != null)
			response.error += ob.error;
		if (doExit || ob.data != null)
		{
			response.data = ob.data;
			exit(response);
		}
	}
	
	public static function exit(r:Dynamic):Void
	{
		trace(!headerSent);
		if (!headerSent)
		{
			Web.setHeader('Content-Type', 'application/json');
			Web.setHeader("Access-Control-Allow-Headers", "access-control-allow-headers, access-control-allow-methods, access-control-allow-origin");
			Web.setHeader("Access-Control-Allow-Credentials", "true");
			Web.setHeader("Access-Control-Allow-Origin", "https://192.168.178.56:9000");
			headerSent = true;
		}			
		//var exitValue =  
		//trace( Syntax.code("json_encode({0})",r.data));
		trace(Json.stringify(r));
		//trace( Syntax.code("json_encode({0})",r));
		//Sys.print(Syntax.code("json_encode({0})",r));
		Sys.print(Json.stringify(r));
		Sys.exit(0);		
	}
	
	public static function send(r:String)
	{
		if (!headerSent)
		{
			Web.setHeader('Content-Type', 'text/plain');
			Web.setHeader("Access-Control-Allow-Headers", "access-control-allow-headers, access-control-allow-methods, access-control-allow-origin");
			Web.setHeader("Access-Control-Allow-Credentials", "true");
			Web.setHeader("Access-Control-Allow-Origin", "https://192.168.178.56:9000");
			headerSent = true;
		}			
		Sys.print(r);
		Sys.exit(0);
	}
	
	public static function sendData(dbData:DbData, data:RData):Bool
	{
		var s:Serializer = new Serializer();
		trace(data);
		if(data != null){
			dbData.dataInfo = data.info;
			Syntax.foreach(data.rows, function(k:Int, v:Dynamic)
			{
				dbData.dataRows.push(Lib.hashOfAssociativeArray(v));			
			});			
		}

		trace(dbData);
		/*var b:Bytes = s.serialize(dbData);
		var v:DbData = s.unserialize(b, DbData);
		trace(v);*/
		return sendbytes(s.serialize(dbData));
	}

	public static function sendErrors(dbData:DbData, ?err:Map<String,Dynamic>):Bool
	{
		var s:Serializer = new Serializer();
		if (err != null)
		{
			for (k in err.keys())
			{
				dbData.dataErrors[k] = err[k];
			}
		}
		return sendbytes(s.serialize(dbData));
	}
	
	public static function sendInfo(dbData:DbData, ?info:Map<String,Dynamic>):Bool
	{
		var s:Serializer = new Serializer();
		if (info != null)
		{
			for (k in info.keys())
			{
				dbData.dataInfo[k] = info[k];
			}
		}
		return sendbytes(s.serialize(dbData));
	}
	
	public static function sendbytes(b:Bytes):Bool
	{		
		Web.setHeader('Content-Type', 'text/plain');
		//trace(b.toString());
		/*var s:Serializer = new Serializer();
		var v:DbData = s.unserialize(b, DbData);
		trace(v);*/
		trace('OK');
		//Web.setHeader('Content-Type', 'application/octet-stream');
		Web.setHeader("Access-Control-Allow-Headers", "access-control-allow-headers, access-control-allow-methods, access-control-allow-origin");
		Web.setHeader("Access-Control-Allow-Credentials", "true");
		Web.setHeader("Access-Control-Allow-Origin", "https://192.168.178.56:9000");
		
		var out = File.write("php://output", true);
		out.bigEndian = true;
		out.write(b);
		Sys.exit(0);
		return true;
	}
	
	public static function dump(d:Dynamic):Void
	{
		if (!headerSent)
		{
			Web.setHeader('Content-Type', 'application/json');
			headerSent = true;
		}
		
		Lib.println(Json.stringify(d));
		//Lib.println(TJSON.encode(d));
	}
	
	public static function edump(d:Dynamic):Void
	{
		Syntax.code("edump({0})", d);
	}
	
	public static function newMemberID():Int {
		var stmt:PDOStatement = S.dbh.query(
			'SELECT  MAX(CAST(vendor_lead_code AS UNSIGNED)) FROM vicidial_list WHERE list_id=10000'
			);
		return (stmt.rowCount()==0 ? 1: stmt.fetch(PDO.FETCH_COLUMN)+1);
	}
	
	public static function tables(db:String = 'crm'): Array<String>
	{
		var sql:String = comment(unindent, format) /*
			SELECT string_agg(TABLE_NAME,',') FROM information_schema.tables WHERE table_schema = '$db'
			*/;
		trace(sql);
		var stmt:PDOStatement = S.dbh.query(
			//'SELECT string_agg(TABLE_NAME,\',\') FROM information_schema.tables WHERE table_schema = "$db";'
			sql
		);
		/*if (stmt == false)
		{
			exit({error:S.dbh.errorInfo()});
		}*/
		if (S.dbh.errorCode() != '00000')
		{
			trace(S.dbh.errorCode());
			trace(S.dbh.errorInfo());
			Sys.exit(0);
		}
		if (stmt.rowCount() == 1)
		{
			return stmt.fetchColumn().split(',');
		}
		return null;
	}

	public static function dumpNativeArray(a:NativeArray, ?i:PosInfos):String
	{
		var d:String = '';
		trace(Reflect.fields(a),i);
		trace(Type.getClass(a),i);
		//var m:Map<String,Dynamic>
		//names = (Type.getClass(ob) != null) ?
			//Type.getInstanceFields(Type.getClass(ob)):
			//Reflect.fields(ob);
		//if (Type.getClass(ob) != null)
		return d;
	}


	public static function saveLog(what:Dynamic,?pos:PosInfos):Void
	{
		//trace(pos.fileName + ':' + pos.lineNumber + '::' + pos.methodName);
		trace(what);
		return;
		dumpNativeArray(what, pos);
	}
	
	public static function tableFields(table:String, db:String = 'crm'): Array<String>
	{
		var sql:String = comment(unindent, format) /*
			SELECT string_agg(COLUMN_NAME,',') FROM information_schema.columns WHERE table_schema = '$db' AND table_name = '$table'
			*/;
		var stmt:PDOStatement = S.dbh.query(
			comment(unindent, format) /*
			SELECT string_agg(COLUMN_NAME,',') FROM information_schema.columns WHERE table_schema = '$db' AND table_name = '$table'
			*/			
		);
		if (S.dbh.errorCode() != '00000')
		{
			trace(S.dbh.errorCode());
			trace(S.dbh.errorInfo());
			Sys.exit(0);
		}		
		if (stmt.rowCount() == 1)
		{
			return stmt.fetchColumn().split(',');
		}
		return null;
	}
	
	static function __init__() {
		Syntax.code('require_once({0})', '../.crm/db.php');
		Syntax.code('require_once({0})', '../.crm/functions.php');
		//Syntax.code('require_once({0})', 'inc/PhpRbac/Rbac.php');
		Debug.logFile = untyped Syntax.code("$appLog");
		//edump(Debug.logFile);
		//Debug.logFile = untyped __var__("GLOBALS","appLog");
		db = Syntax.code("$DB");
		dbHost = Syntax.code("$DB_server");
		dbUser = Syntax.code("$DB_user");
		dbPass = Syntax.code("$DB_pass");		
		host = Web.getHostName();
		request_scheme = Syntax.code("$_SERVER['REQUEST_SCHEME']");
		secret = Syntax.code("$secret");
		//edump(Syntax.code("$conf"));

		conf =  Config.load('appData.js');
		var ini:NativeArray = Syntax.code("$ini");
		conf.set('ini', ini);		
		Out.skipFields = ['admin','pass','password'];
	}

}