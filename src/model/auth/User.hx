package model.auth;
import haxe.crypto.Sha256;
import haxe.Json;
import haxe.ds.StringMap;
import jwt.JWT;
import php.Exception;
import php.Lib;
import php.NativeArray;
import php.Web;

/**
 * ...
 * @author axel@bi4.me
 */

class User extends Model
{
	public static function create(param:StringMap<String>):Void
	{
		var self:User = new User(param);	
		//self.table = 'columns';
		self.param = param;
		//trace(param);
		Reflect.callMethod(self, Reflect.field(self, param.get('action')), [param]);
	}
	
	public function clientVerify(params:StringMap<String>):Void
	{
		var jwt:String = params.get('jwt');
		var user:Int = cast params.get('user');
		if (verify(jwt, user))
		{			
			data = {
				content:'OK'
			};
			json_encode();
		}
	}
	
	public static function login(params:StringMap<String>, secret:String):Bool
	{
		var id:Int = cast params.get('id');
		var pass = params.get('pass');

		var m:Model = new Model();	
		var res:NativeArray = m.query('SELECT id FROM ${S.db}.users WHERE id=$id AND active=1');
		if (res[0] == null)
		{
			S.exit({error:{loginError:"Benutzer $id ist nicht aktiv oder existiert nicht"}});
			return false;
		}
		else{
			// ACTIVE USER EXISTS
			var sql = 'SELECT id FROM ${S.db}.users WHERE id=$id AND password=\'${Sha256.encode(pass)}\' AND active=1';
			var ares = Lib.toHaxeArray(m.query(sql));
			trace(ares);
			if (ares.length == 0 || ares[0] == null)
			{
				S.exit({error:{loginError:'Falsches Passwort:$sql'}});
				return false;
			}
			//var userData = Lib.hashOfAssociativeArray(res[0]);		
			//var d:Float = Date.now().getTime();
			//var hours:Float = DateTools.hours(11);
			var d:Float = DateTools.delta(Date.now(), DateTools.hours(11)).getTime();
			trace(d + ':' + Date.fromTime(d));
			var	jwt = JWT.sign({
					id:id,
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
	
	public static function verify(jwt:String, id:Int):Bool
	{
		trace(jwt);
		try{
			var userInfo:Dynamic = JWT.extract(jwt);
			var now:Float = Date.now().getTime();
			trace(Date.fromTime(userInfo.validUntil) + ':${userInfo.validUntil} - $now:' + cast( userInfo.validUntil - now));
			if (id == userInfo.id && userInfo.ip == Web.getClientIP() && (userInfo.validUntil - Date.now().getTime()) > 0)
			{
				return switch(JWT.verify(jwt, S.secret))
				{
					case Valid(payload):
						// JWT VALID AND NOT OLDER THAN 11 h
						true;
					default:
						S.exit({error:{jwtError:'JWT invalid!'}});
						false;
				}
			}
			S.exit({error:{jwtError:'JWT expired!'}});			
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