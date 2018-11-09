package model.settings;

import haxe.ds.StringMap;

/**
 * ...
 * @author axel@bi4.me
 */
class History extends Model 
{

	public static function create() 
	{
		var self:History = new History(param);	
		Reflect.callMethod(self, Reflect.field(self, param.get('action')), [param]);
	}
	
}