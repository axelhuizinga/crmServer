package;

import haxe.ds.Either;
import haxe.ds.StringMap;
import me.cunity.debug.Out;
import php.Syntax;
import php.db.PDO;
import php.db.PDOStatement;
//import me.cunity.php.db.MySQLi;
//import me.cunity.php.db.MySQLi_Result;
//import me.cunity.php.db.MySQLi_STMT;
import me.cunity.php.Services_JSON;
import phprbac.Rbac;
//import model.AgcApi;
//import model.App;
//import model.Campaigns;
import model.contacts.Contact;
import model.admin.CreateHistoryTrigger;
import model.admin.CreateUsers;
import Model.MData;
//import model.QC;
//import model.Select;
import model.auth.User;
import php.Lib;
import me.cunity.php.Debug;
import php.NativeArray;
import php.Session;
import php.Web;
//import tjson.TJSON;
import haxe.Json;

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

class S 
{
	static inline var debug:Bool = true;
	static var headerSent:Bool = false;
	static var response:Response;
	public static var secret;
	public static var conf:StringMap<Dynamic>;
	public static var my:PDO;
	public static var host:String;
	public static var request_scheme:String;
	public static var userName:String;
	public static var db:String;
	public static var dbHost:String;
	public static var dbUser:String;
	public static var dbPass:String;	
	public static var vicidialUser:String;
	public static var vicidialPass:String;
	
	static function main() 
	{		
		haxe.Log.trace = Debug._trace;	

		//trace(conf.get('ini'));		
		trace(vicidialUser);
		//trace(conf);
		//Session.start();

		//var pd:Dynamic = Web.getPostData();
		var now:String = DateTools.format(Date.now(), "%d.%m.%y %H:%M:%S");
		response = {content:'',error:''};
		var params:StringMap<String> = Web.getParams();
		
		trace(Date.now().toString() + ' == $now' );		
		trace(params);		

		var action:String = params.get('action');
		if (action.length == 0 || params.get('className') == null)
		{
			exit( { error:"required params action and/or className missing" } );
		}
			
		my = new PDO('pgsql:host=$dbHost;dbname=$db',dbUser,dbPass,Syntax.array(['client_encoding','UTF8']));
		//my.set_charset("utf8");
		trace(my);
		var jwt:String = params.get('jwt');
		var userName:String = params.get('userName');
		if (jwt.length > 0)
		{
			if(User.verify(jwt, userName))
				Model.dispatch(params);			
		}
		
		//var pass = params.get('pass');		
		User.login(params, secret);		
		exit(response);

	}
	
	public static function add2Response(ob:Response, ex:Bool = false)
	{
		if (ob.content != null)
			response.content += ob.content;
		if (ob.error != null)
			response.error += ob.error;
		if (ex || ob.data != null)
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
			Web.setHeader("Access-Control-Allow-Origin", "*");
			headerSent = true;
		}			
		//var exitValue =  
		//trace( Syntax.code("json_encode({0})",r.data));
		//trace(r);
		//trace( Syntax.code("json_encode({0})",r));
		//Sys.print(Syntax.code("json_encode({0})",r));
		Sys.print(Json.stringify(r));
		Sys.exit(0);		
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
		var stmt:PDOStatement = S.my.query(
			'SELECT  MAX(CAST(vendor_lead_code AS UNSIGNED)) FROM vicidial_list WHERE list_id=10000'
			);
		return (stmt.rowCount()==0 ? 1: stmt.fetch(PDO.FETCH_COLUMN)+1);
	}
	
	public static function tableFields(table:String, db:String = 'asterisk'): Array<String>
	{		
		var stmt:PDOStatement = S.my.query(
			'SELECT GROUP_CONCAT(COLUMN_NAME) FROM information_schema.columns WHERE table_schema = "$db" AND table_name = "$table";');
		if (stmt.rowCount() == 1)
		{
			return stmt.fetchColumn().split(',');
		}
		return null;
	}
	
	static function __init__() {
		Syntax.code('require_once({0})', '../.crm/db.php');
		Syntax.code('require_once({0})', '../.crm/functions.php');
		Syntax.code('require_once({0})', 'inc/PhpRbac/Rbac.php');
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
		vicidialUser = Syntax.code("$user");
		vicidialPass = Syntax.code("$pass");
		conf =  Config.load('appData.js');
		var ini:NativeArray = Syntax.code("$ini");
		conf.set('ini', ini);		
	}

}