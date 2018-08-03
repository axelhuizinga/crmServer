package model;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Json;
using Lambda;
/**
 * ...
 * @author axel@cunity.me
 */
@:keep
class Select extends Input
{
	public static function create(param:StringMap<String>):EitherType<String,Bool>
	{
		var self:Select = new Select();		
		trace(param);
		return Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}
	
	public function selectCampaign(param:StringMap<String>):EitherType<String,Bool>
	{
		/*var sqlBf:StringBuf = new StringBuf();		
		var placeHolder:StringMap<Dynamic> = new StringMap();
		trace(param.get('where') + ':' );
		sqlBf.add('SELECT ');
		sqlBf.add(fieldFormat(param.get('fields')) + ' FROM ');
		sqlBf.add(param.get('table') + ' ');
		sqlBf.add(prepare(param.get('where')));
		trace(placeHolder.toString());
		if(param.exists('group'))
			sqlBf.add('GROUP BY ' +param.get('group') + ' ');
		if(param.exists('order'))
			sqlBf.add('ORDER BY ' + param.get('order') + ' ');				
		if(param.exists('limit'))
			sqlBf.add('LIMIT ' + param.get('limit'));			
			
		//trace(sqlBf.toString());
		data =  {
			rows: execute(sqlBf.toString(), placeHolder)
		}*/
		return json_encode();
	}
	
	function prepare(where:String) :String
	{
		var wParam:Array<String> = where.split(',');
		where = '';
		if (wParam.has('filter=1'))
		{
			//	TODO: CHECK4DEPS TABLE
			wParam = wParam.filter(function(f:String) return f != 'filter=1');
		}
		if (wParam.length > 0 && where == '')
			where = '';
		for (w in wParam)
		{
			if(where == '')
				where  = "WHERE " + w;
			else
				where = " AND " + w;
		}
		trace(where);
		return where;
	}
	
}