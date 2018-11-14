package model.tools;
import haxe.Serializer;
import haxe.ds.StringMap;
import php.Lib;
import php.NativeArray;
import php.Syntax;
import comments.CommentString.*;
import php.db.PDOStatement;

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
	
	public function buildFieldList():Map<String,String>
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
		return tableFields;
	}
	
	public function createFieldList()
	{
		var tableFields:Map<String,String> = buildFieldList();
		trace(tableFields);
		if (param.get('update')=='1')
		{
			updateFieldsTable(tableFields);
		}
		S.send(Serializer.run(tableFields));	
	}
	
	public function updateFieldsTable(tableFields:Map<String,String>)
	{
		var tableNames:Iterator<String> = tableFields.keys();
		while (tableNames.hasNext())
		{
			var tableName:String = tableNames.next();
			var fieldNames:String = tableFields[tableName];
			var fields:Array<String> = fieldNames.split(',');
			var sqlFields:Array<String> = fields.map(function(f:String){
				var s:String = comment(unindent, format) /*
				'${f}','{}'::jsonb
				*/;
				return s;
			});
			
			var fieldsSql = sqlFields.join(",");
			var sql = comment(unindent, format) /*
			INSERT INTO crm._table_fields VALUES (DEFAULT, '$tableName','{$fieldNames}', jsonb_build_object($fieldsSql), 1)
			ON CONFLICT (table_name) DO UPDATE SET field_names='{$fieldNames}', field_hints=jsonb_build_object($fieldsSql)
			*/;
			trace(sql);
			var res:PDOStatement = S.my.query(sql);
			if (untyped res == false)
			{
				trace(S.my.errorInfo());
				S.send(Serializer.run(['ERROR'=>S.my.errorInfo()]));
			}
			trace('Inserted ${tableName}: ' + res.rowCount());
		}
	}	
	
	public static function serializeRows(rows:NativeArray):String
	{
		//var sRows:Serializer = new Serializer();
		var sRows:Array<StringMap<String>> = new Array();
		Syntax.foreach(rows, function(k:Int, v:Dynamic)
		{
			sRows.push(Lib.hashOfAssociativeArray(v));
		});
		return Serializer.run(sRows);
	}
	
}