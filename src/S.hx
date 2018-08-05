package;

import haxe.crypto.Sha256;
import haxe.ds.Either;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Json;
import me.cunity.debug.Out;
import me.cunity.php.db.MySQLi;
import me.cunity.php.db.MySQLi_Result;
import me.cunity.php.db.MySQLi_STMT;
import me.cunity.php.Services_JSON;
import phprbac.Rbac;
//import model.AgcApi;
import model.App;
//import model.Campaigns;
import model.contacts.Contact;
//import model.ClientHistory;
//import model.QC;
//import model.Select;
import model.auth.User;
import php.Lib;
import me.cunity.php.Debug;
import php.NativeArray;
import php.Session;
import php.Web;

using Lambda;
using Util;
/**
 * ...
 * @author axel@cunity.me
 */

class S 
{
	static inline var debug:Bool = true;
	static var headerSent:Bool = false;
	private static var secret;
	public static var conf:StringMap<Dynamic>;
	public static var my:MySQLi;
	public static var host:String;
	public static var request_scheme:String;
	public static var user:Int;
	public static var db:String;
	public static var dbHost:String;
	public static var dbUser:String;
	public static var dbPass:String;	
	public static var vicidialUser:String;
	public static var vicidialPass:String;
	
	static function main() 
	{		
		haxe.Log.trace = Debug._trace;	
		conf =  Config.load('appData.js');
		//trace(conf);
		Session.start();

		//var pd:Dynamic = Web.getPostData();
		var now:String = DateTools.format(Date.now(), "%d.%m.%y %H:%M:%S");
		//trace(pd);
		var params:StringMap<String> = Web.getParams();
		if (params.get('debug') == '1')
		{
			Web.setHeader('Content-Type', 'text/html; charset=utf-8');
			headerSent = true;
			Lib.println('<div><pre>');
			Lib.println(params);
		}
		trace(Date.now().toString());		
		trace(params);		

		var action:String = params.get('action');
		if (action.length == 0 || params.get('className') == null)
		{
			dump( { error:"required params missing" } );
			return;
		}
			
		my = new MySQLi(dbHost, dbUser, dbPass, db);
		my.set_charset("utf8");
		//trace(my);
		var auth:Either<String,Bool> = checkAuth(params);
		
		trace (action + ':' + auth);
		var result:String = switch(auth)
		{
			case Right(r):
				r ? Model.dispatch(params) : Json.stringify({error:'AUTH FAILURE'});
			case Left(l):
				l;
		}
		
		//var result:EitherType<String,Bool> = 
			//action=='login' ? Left(auth) : Model.dispatch(params);
		
		trace(result);
		if (!headerSent)
		{
			Web.setHeader('Content-Type', 'application/json');
			headerSent = true;
		}		
		Lib.println( result);

	}
	
	static function checkAuth(params:StringMap<Dynamic>):Either<String,Bool>
	{
		var rbac:Rbac = new Rbac();
		trace(rbac);
		var newRole:Int = rbac.roles.add('SysAdmin', 'Systemadministrator');
		trace('$secret added: $newRole');
		user = params.get('user');// Session.get('PHP_AUTH_USER');
		trace(user);
		if (user == null)
		{			
			return Right(false);
		}
		var jwt = params.get('jwt');
		if (jwt != null && User.verify(jwt, user, secret))
		{
			// JWT AUTH VERIFIED
			trace('JWT AUTH VERIFIED user:$user');
			return Right(true);
		}
		var pass:String = params.get('pass');// Session.get('PHP_AUTH_PW');
		if (pass == null)
			return Right(false);

		var res:NativeArray = //StringMap<String> = Lib.hashOfAssociativeArray(
			new Model().query('SELECT id FROM ${db}.users WHERE id=$user AND password="${Sha256.encode(pass)}" AND active=1');
		trace(res);	

		if (res[0] != null)
		{
			var userData = Lib.hashOfAssociativeArray(res[0]);
			trace(userData);
			
			return Left(Json.stringify({jwt:User.login(userData.get('id'), secret)}));
			//return true;
		}
		return Right(false);
	}
	
	public static function exit(d:Dynamic):Void
	{
		if (!headerSent)
		{
			Web.setHeader('Content-Type', 'application/json');
			headerSent = true;
		}			
		var exitValue =  untyped __call__("json_encode", {'ERROR': d});
		return untyped __call__("exit", exitValue);
	}
	
	public static function dump(d:Dynamic):Void
	{
		if (!headerSent)
		{
			Web.setHeader('Content-Type', 'application/json');
			headerSent = true;
		}
		
		Lib.println(Json.stringify(d));
	}
	
	public static function edump(d:Dynamic):Void
	{
		untyped __call__("edump", d);
	}
	
	public static function newMemberID():Int {
		var res:MySQLi_Result = S.my.query(
			'SELECT  MAX(CAST(vendor_lead_code AS UNSIGNED)) FROM vicidial_list WHERE list_id=10000'
			);
		return (res.num_rows==0 ? 1:  Std.parseInt(res.fetch_array(MySQLi.MYSQLI_NUM)[0])+1);
	}
	
	public static function tableFields(table:String, db:String = 'asterisk'): Array<String>
	{		
		var res:MySQLi_Result = S.my.query(
			'SELECT GROUP_CONCAT(COLUMN_NAME) FROM information_schema.columns WHERE table_schema = "$db" AND table_name = "$table";');
		if (res.any2bool() && res.num_rows == 1)
		{
			//trace(res.fetch_array(MySQLi.MYSQLI_NUM)[0]);
			//return 'lead_id,anrede,co_field,geburts_datum,iban,blz,bank_name,spenden_hoehe,period,start_monat,buchungs_zeitpunkt,start_date'.split(',');
			return res.fetch_array(MySQLi.MYSQLI_NUM)[0].split(',');
		}
		return null;
	}
	
	static function __init__() {
		untyped __call__('require_once', '../.crm/db.php');
		untyped __call__('require_once', '../.crm/functions.php');
		untyped __call__('require_once', 'inc/PhpRbac/Rbac.php');
		//untyped __call__('require_once', '../../crm/loadAstguiclientConf.php');
		//untyped __call__('require_once', '../agc/functions.fix.php');
		Debug.logFile = untyped __php__("$appLog");
		//edump(Debug.logFile);
		//Debug.logFile = untyped __var__("GLOBALS","appLog");
		db = untyped __php__("$DB");
		dbHost = untyped __php__("$DB_server");
		dbUser = untyped __php__("$DB_user");
		dbPass = untyped __php__("$DB_pass");		
		host = Web.getHostName();
		request_scheme = untyped __php__("$_SERVER['REQUEST_SCHEME']");
		secret = untyped __php__("$secret");
		//trace(host);
		vicidialUser = untyped __php__("$user");
		vicidialPass = untyped __php__("$pass");
	}

}