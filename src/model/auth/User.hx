package model.auth;
import haxe.Json;
import jwt.JWT;
import php.Exception;

/**
 * ...
 * @author axel@bi4.me
 */

class User 
{
	

	public static function login(id:Int, secret:String):String
	{
		trace(secret);
		return JWT.sign({
			user:id,
			login:Date.now().getTime()
		}, secret
		);
	}
	
	public static function verify(jwt:String, user:Int, secret:String):Bool
	{
		try{
			var userInfo:Dynamic = JWT.extract(jwt);
			if (user == userInfo.user && Date.now().getTime() - userInfo.login < 42000)
			{
				return switch(JWT.verify(jwt, secret))
				{
					case Valid(payload):
						// JWT VALID AND NOT OLDER THAN 42000 s
						true;
					default:
						false;
				}
				
			}
			return false;
		}
		catch (ex:Exception)
		{
			trace(ex.getMessage());
			return false;
		}
		
	}
	
}