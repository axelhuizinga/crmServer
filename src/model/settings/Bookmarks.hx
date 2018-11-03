package model.settings;

/**
 * ...
 * @author axel@bi4.me
 */

class Bookmarks extends Model 
{

	public static function create() 
	{
		var self:User = new Bookmarks(param);	
		Reflect.callMethod(self, Reflect.field(self, param.get('action')), [param]);
	}
	
}