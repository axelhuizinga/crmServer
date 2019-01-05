package model.auth;
import haxe.Serializer;
import haxe.crypto.Sha256;
import haxe.ds.IntMap;
import haxe.ds.Map;
import haxe.ds.StringMap;
import jwt.JWT;
import me.cunity.debug.Out;
import model.tools.DB;
import php.Exception;
import php.Lib;
import php.NativeArray;
import php.Syntax;
import php.Web;
import php.db.PDO;
import php.db.PDOStatement;

/**
 * ...
 * @author axel@bi4.me
 */

class User extends Model
{
	public static function create(param:StringMap<String>):Void
	{
		var self:User = new User(param);	
		Reflect.callMethod(self, Reflect.field(self, param.get('action')),[]);
	}
	
	public function clientVerify():Void
	{
		var jwt:String = param.get('jwt');
		var user_name:String = param.get('user_name');
		if (verify(jwt, user_name))
		{			
			data = {
				content:'OK'
			};
			json_encode();
		}
	}
	
	public function edit():Void
	{
		trace(joinSql);
		trace(filterSql);
		S.sendbytes(serializeRows(doSelect()));
	}
	
	public function getExternalUserData():Map<String, Dynamic>
	{
		return null;
	}
	
	public function userIsAuthorized():UserAuth
	{
		var stmt:PDOStatement = S.dbh.prepare('SELECT user_name FROM ${S.db}.users WHERE user_name=:user_name AND active=TRUE');
		if( !Model.paramExecute(stmt, Lib.associativeArrayOfObject({':user_name': '${param.get('user_name')}'})))
		{
			S.sendErrors(dbData,['${param.get('action')}' => stmt.errorInfo()]);
		}
		if(stmt.rowCount()>0)
		{
			//ACTIVE USER EXISTS
			stmt = S.dbh.prepare(
				'SELECT change_pass_required, last_login, user_name FROM ${S.db}.users WHERE user_name=:user_name AND password=crypt(:password,password)');
			if( !Model.paramExecute(stmt, Lib.associativeArrayOfObject({':user_name': '${param.get('user_name')}',':password':'${param.get('pass')}'})))
			{
				S.sendErrors(dbData,['${param.get('action')}' => stmt.errorInfo()]);
			}
			if (stmt.rowCount()==0)
			{
				S.sendErrors(dbData,['${param.get('action')}'=>'pass']);
			}
			var res:Map<String,Dynamic> = Lib.hashOfAssociativeArray(stmt.fetch(PDO.FETCH_ASSOC));
			dbData.dataInfo['last_login'] = res['last_login'];
			trace(res);
			//if (res == 'TRUE' || res == '1')
			if (res['change_pass_required']==1 || res['change_pass_required']==true)
				return UserAuth.PassChangeRequired;
			// USER AUTHORIZED
			return UserAuth.AuthOK;			
		}
		else
		{
			S.sendErrors(dbData,['${param.get('action')}'=>'user_name']);
			return UserAuth.NotOK;
		}
	}
	
	public static function login(params:StringMap<String>, secret:String):Bool
	{
		var me:User = new User(params);
		switch(me.userIsAuthorized())
		{
			case uath = UserAuth.AuthOK|UserAuth.PassChangeRequired:
				var d:Float = DateTools.delta(Date.now(), DateTools.hours(11)).getTime();
				trace(d + ':' + Date.fromTime(d));
				var	jwt = JWT.sign({
						user_name:params.get('user_name'),
						validUntil:d,
						ip: Web.getClientIP()
						//validUntil:Date.now().getTime()
					}, secret);						
				trace(JWT.extract(jwt));
				Web.setCookie('user.jwt', jwt, Date.fromTime(d + 86400000));
				Web.setCookie('user.user_name', jwt, Date.fromTime(d + 86400000));
				me.dbData.dataInfo['jwt'] = jwt;
				if (uath == UserAuth.PassChangeRequired)
				me.dbData.dataInfo['change_pass_required'] = true;
				S.sendInfo(me.dbData);
				return true;
			default:
				return false;
		}
	}
	
	public function changePassword():Bool
	{
		if (param.get('new_pass') == param.get('pass'))
		{
			dbData.dataErrors['changePassword'] = 'Das Passwort wurde nicht geändert!';
			S.sendInfo(dbData);
		}
		switch (userIsAuthorized())
		{
			default:
			trace('UPDATE ${S.db}.users SET password=crypt(:new_password,gen_salt(\'bf\',8)),change_pass_required=false WHERE user_name=:user_name AND password=CRYPT(:pass, password)');
			var stmt:PDOStatement = S.dbh.prepare(
				'UPDATE ${S.db}.users SET password=crypt(:new_password,gen_salt(\'bf\',8)),change_pass_required=false WHERE user_name=:user_name AND password=CRYPT(:pass, password)');
			if ( !Model.paramExecute(stmt, Lib.associativeArrayOfObject(
				{':user_name': '${param.get('user_name')}',':new_password':'${param.get('new_pass')}',':pass':'${param.get('pass')}'})))
			{
				S.sendErrors(dbData,['changePassword' => stmt.errorInfo()]);
			}
			if (stmt.rowCount()==0)
			{
				S.sendErrors(dbData,['changePassword'=>'Das Passwort ist nicht korrekt!']);
			}
		}		
		dbData.dataInfo['changePassword'] = 'OK';
		S.sendInfo(dbData);
		return true;
	}
	
	public function save():Bool
	{
		var res = update();
		trace(res);
		S.sendbytes(serializeRows(doSelect()));
		//S.send('OK');
		return true;
	}
	
	static function saveRequest(user_name:String, params:StringMap<String>):Bool
	{
		var request:String = Serializer.run(params);
		var rTime:String = DateTools.format(S.last_request_time, "'%Y-%m-%d %H:%M:%S'");//,request=?
		var stmt:PDOStatement = S.dbh.prepare('UPDATE users SET online=TRUE,last_request_time=${rTime},"request"=:request WHERE user_name=:user_name');
		//trace('UPDATE users SET last_request_time=${rTime},request=\'$request\' WHERE user_name=\'$user_name\'');
		var success:Bool = Model.paramExecute(stmt, //null
			Lib.associativeArrayOfObject({':user_name': '$user_name', ':request': '$request'})
		);
		trace(stmt.errorCode());
		trace(stmt.errorInfo());
		return success;
	}

	public static function getViciDialPassword(jwt:String, user_name:String,?params:StringMap<String>):String
	{
		return '';
	}
	
	public static function verify(jwt:String, user_name:String,?params:StringMap<String>):Bool
	{
		trace(jwt);
		//Out.dumpStack(Out.aStack());
		try{
			var userInfo:Dynamic = JWT.extract(jwt);
			var now:Float = Date.now().getTime();
			trace('$user_name==${userInfo.user_name}::${userInfo.ip}::${Web.getClientIP()}:' + Date.fromTime(userInfo.validUntil) + ':${userInfo.validUntil} - $now:' + cast( userInfo.validUntil - now));
			if (user_name == userInfo.user_name && userInfo.ip == Web.getClientIP() && (userInfo.validUntil - Date.now().getTime()) > 0)
			{
				return switch(JWT.verify(jwt, S.secret))
				{
					case Valid(payload):
						// JWT VALID AND NOT OLDER THAN 11 h
						saveRequest(user_name, params);
						true;
					default:
						S.exit({error:'JWT invalid!'});
						false;
				}
			}
			S.exit({error:'JWT expired!'});			
			return false;
		}
		catch (ex:Dynamic)
		{
			trace(ex);
			S.exit({error:Std.string(ex)});
			return false;
		}
		
	}
	
}

enum UserAuth{
	AuthOK;
	PassChangeRequired;
	NotOK;
}