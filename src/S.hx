package;

import haxe.ds.Either;
import haxe.ds.StringMap;
import haxe.Json;
import me.cunity.debug.Out;
import me.cunity.php.db.MySQLi;
import me.cunity.php.db.MySQLi_Result;
import me.cunity.php.db.MySQLi_STMT;
import me.cunity.php.Services_JSON;
import phprbac.Rbac;
//import model.AgcApi;
//import model.App;
//import model.Campaigns;
import model.contacts.Contact;
//import model.ClientHistory;
import Model.MData;
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

typedef Response =
{
	?content:Dynamic,
	?error:Dynamic
}

class S 
{
	static inline var debug:Bool = true;
	static var headerSent:Bool = false;
	static var response:Dynamic;
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
		//Session.start();

		//var pd:Dynamic = Web.getPostData();
		var now:String = DateTools.format(Date.now(), "%d.%m.%y %H:%M:%S");
		response = {content:[],error:[]};
		var params:StringMap<String> = Web.getParams();
		Web.setHeader("Access-Control-Allow-Origin", "*");
		if (params.get('debug') == '1')
		{
			Web.setHeader('Content-Type', 'text/html; charset=utf-8');
			headerSent = true;
			Lib.println('<div><pre>');
			Lib.println(params);
		}
		trace(Date.now().toString() + ' == $now' );		
		trace(params);		

		var action:String = params.get('action');
		if (action.length == 0 || params.get('className') == null)
		{
			exit( { error:"required params action and/or className missing" } );
		}
			
		my = new MySQLi(dbHost, dbUser, dbPass, db);
		my.set_charset("utf8");

		var jwt:String = params.get('jwt');
		var user:Int = cast params.get('user');
		if (jwt.length > 0)
		{
			if(User.verify(jwt, user, secret))
				Model.dispatch(params);			
		}
		
		var pass = params.get('pass');		
		User.login(params, secret);		
		exit(response);

	}
	
	public static function add2Response(ob:Response, ex:Bool = false)
	{
		if (ob.content != null)
			response.content.push(ob.content);
		if (ob.error != null)
			response.error.push(ob.error);
		if (ex)
		{
			exit(response);
		}
	}
	
	public static function exit(d:MData):Void
	{
		if (!headerSent)
		{
			Web.setHeader('Content-Type', 'application/json');
			headerSent = true;
		}			
		var exitValue =  untyped __call__("json_encode", d);
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