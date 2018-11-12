package model.auth;
import haxe.Serializer;
import haxe.crypto.Sha256;
import haxe.ds.StringMap;
import jwt.JWT;
import php.Exception;
import php.Lib;
import php.NativeArray;
import php.Web;
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
		Reflect.callMethod(self, Reflect.field(self, param.get('action')), [param]);
	}
	
	public function clientVerify(params:StringMap<String>):Void
	{
		var jwt:String = params.get('jwt');
		var userName:String = params.get('userName');
		if (verify(jwt, userName))
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
		/*data =  {
			count:count(),
			page: param.exists('page') ? Std.parseInt( param.get('page') ) : 1,
			rows: doSelect()
		};*/
		var dm:Map<String,Dynamic> = Lib.hashOfAssociativeArray(doSelect());
		trace(dm);
		S.send(dm);
	}
	
	public static function login(params:StringMap<String>, secret:String):Bool
	{
		var userName:String = params.get('userName');
		var pass = params.get('pass');

		var me:User = new User(params);	
		var res:NativeArray = me.query('SELECT user_name FROM ${S.db}.users WHERE user_name=\'$userName\' AND active=TRUE');
		trace('SELECT userName FROM ${S.db}.users WHERE userName=$userName AND active=TRUE');
		if (!cast res)
		{
			S.exit({error:'userName'});
			return false;
		}
		else{
			// ACTIVE USER EXISTS
			var sql = 'SELECT user_name FROM ${S.db}.users WHERE user_name=\'$userName\' AND password=crypt(\'$pass\',password) AND active=TRUE';
			var ares = Lib.toHaxeArray(me.query(sql));
			if (ares.length == 0 || ares[0] == null)
			{
				S.exit({error:'password'});
				return false;
			}
			var d:Float = DateTools.delta(Date.now(), DateTools.hours(11)).getTime();
			trace(d + ':' + Date.fromTime(d));
			var	jwt = JWT.sign({
					userName:userName,
					validUntil:d,
					ip: Web.getClientIP()
					//validUntil:Date.now().getTime()
				}, secret);						
			trace(JWT.extract(jwt));
			Web.setCookie('user.jwt', jwt, Date.fromTime(d));
			S.exit({jwt:jwt});
			return true;
		}
		
	}
	
	public function save():Bool
	{
		var res = update();
		trace(res);
		S.send(['content'=>'OK']);
		return true;
	}
	
	static function saveRequest(userName:String, params:StringMap<String>):Bool
	{
		var request:String = Serializer.run(params);
		var rTime:String = DateTools.format(S.last_request_time, "'%Y-%m-%d %H:%M:%S'");//,request=?
		var stmt:PDOStatement = S.my.prepare('UPDATE users SET online=TRUE,last_request_time=${rTime},"request"=:request WHERE user_name=:user_name');
		trace('UPDATE users SET last_request_time=${rTime},request=\'$request\' WHERE user_name=\'$userName\'');

		var success:Bool = Model.paramExecute(stmt, //null
		Lib.associativeArrayOfObject({':user_name': '$userName', ':request': '$request'})
		);
		trace(stmt.errorCode());
		trace(stmt.errorInfo());
		return success;
	}
	
	public static function verify(jwt:String, userName:String,?params:StringMap<String>):Bool
	{
		trace(jwt);
		try{
			var userInfo:Dynamic = JWT.extract(jwt);
			var now:Float = Date.now().getTime();
			trace('$userName==${userInfo.userName}::${userInfo.ip}:' + Date.fromTime(userInfo.validUntil) + ':${userInfo.validUntil} - $now:' + cast( userInfo.validUntil - now));
			if (userName == userInfo.userName && userInfo.ip == Web.getClientIP() && (userInfo.validUntil - Date.now().getTime()) > 0)
			{
				return switch(JWT.verify(jwt, S.secret))
				{
					case Valid(payload):
						// JWT VALID AND NOT OLDER THAN 11 h
						saveRequest(userName, params);
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