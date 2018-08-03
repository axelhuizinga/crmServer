package model;

import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Json;
import me.cunity.php.db.MySQLi_Result;

/**
 * ...
 * @author axel@cunity.me
 */

@:keep
class Campaigns extends Model
{
	var campaign_id:String;

	public static function create(param: StringMap<String>):EitherType<String,Bool>
	{
		var self:Campaigns = new Campaigns();	
		self.table = 'vicidial_campaigns';
		trace(param);
		return Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}
	
	public function findLeads(q:StringMap<String>):EitherType<String,Bool>
	{
		//FROM `vicidial_list` WHERE `list_id` IN( SELECT `list_id` FROM vicidial_lists WHERE campaign_id IN('KINDER') AND active='Y' ) 
		//vicidial_campaigns|KINDER,vicidial_campaigns|QCKINDER
		//var where:Array<Dynamic> = q.get('where').split(',');
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();		
		var fields:String = q.get('fields');		
		//sqlBf.add('SELECT ' + fieldFormat((fields != null ? fields.split(',').map(function(f:String) return quoteField(f)).join(',') : '*' )));
		sqlBf.add('SELECT ' + (fields != null ? fieldFormat( fields.split(',').map(function(f:String) return S.my.real_escape_string(f)).join(',') ): '*' ));
		//TODO: JOINS
		sqlBf.add(' FROM  `vicidial_list` WHERE `list_id` IN( SELECT `list_id` FROM vicidial_lists ');		
		var where:String = q.get('where');
		if (where != null)
			buildCond(where, sqlBf, phValues);
		sqlBf.add(')');
		var order:String = q.get('order');
		if (order != null)
			buildOrder(order, sqlBf);
		var limit:String = q.get('limit');
		buildLimit((limit == null?'15':limit), sqlBf);	//	TODO: CONFIG LIMIT DEFAULT
		data =  {
			rows: execute(sqlBf.toString(), phValues)
		};
		return json_encode();
	}
}