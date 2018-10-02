package model.auth;

import haxe.ds.StringMap<String>;

/**
 * ...
 * @author axel@bi4.me
 */
class Net extends Model 
{

	public function create(?param:StringMap<String>) 
	{
		var self:Net = new Net(param);	
		self.table = 'columns';
		Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);		
		
	}
	
}