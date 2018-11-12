package model.tools;
import haxe.ds.StringMap;

/**
 * ...
 * @author axel@bi4.me
 */
class DB extends Model
{
	public static function create(param:StringMap<String>):Void
	{
		var self:DB = new DB(param);	
		Reflect.callMethod(self, Reflect.field(self, param.get('action')), [param]);
	}
	
	public function createFieldList()
	{
		var tableNames:Array<String> = S.tables();
		var tableFields:Map<String,String> = new Map();
		//trace(tableNames);
		for (table in tableNames)
		{
			var fieldNames = S.tableFields(table);
			trace(fieldNames.join(','));
			tableFields[table] = fieldNames.join(',');
		}
		trace(tableFields);
		S.send(tableFields);
		data.fieldNames = tableFields;
		json_encode();		
	}
	
}