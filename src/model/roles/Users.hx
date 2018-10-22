package model.roles;
import haxe.ds.StringMap;

/**
 * ...
 * @author axel@bi4.me
 */

class Users extends Model
{
	public static function create(param:StringMap<String>):Void
	{
		var self:Users = new Users(param);	
		Reflect.callMethod(self, Reflect.field(self, param.get('action')), [param]);
	}

	public function list() 
	{
		trace(param);
		find();
	}
	
}