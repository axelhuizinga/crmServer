package model.tools;
import hxbit.Serializer;
import haxe.ds.StringMap;
import org.msgpack.MsgPack;
import php.Lib;
import php.NativeArray;
import php.Syntax;
import comments.CommentString.*;
import php.Web;
import php.db.PDO;
import php.db.PDOStatement;
import sys.io.File;

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
		var filter:String = (true?'':"WHERE table_name NOT LIKE '\\_%'");	
		
		var sql =  comment(unindent, format) /*
				SELECT table_name,field_name, readonly, element, "any" FROM _table_fields 
				$filter 
				ORDER BY table_name
				*/;
		trace(sql);
		var stmt:PDOStatement = S.my.query(sql, PDO.FETCH_ASSOC);
		if (untyped stmt == false)
		{
			trace(S.my.errorInfo());
			//S.send(Serializer.run(['error'=>S.my.errorInfo()]));
		}
		var tableFields:NativeArray = stmt.fetchAll(PDO.FETCH_ASSOC);//DB.serializeRows(
		trace('tableFields found: ' + stmt.rowCount());		
		sendRows(tableFields);
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
				//S.send(Serializer.run(['error'=>S.my.errorInfo()]));
			}
			trace('Inserted ${tableName}: ' + res.rowCount());
		}
	}	
	
	public function sendRows(rows:NativeArray):Bool
	{
		//var sRows:Serializer = new Serializer();
		//var sRows:Array<StringMap<String>> = new Array();
		//trace(rows);
		var s:Serializer = new Serializer();
		
		Syntax.foreach(rows, function(k:Int, v:Dynamic)
		{
			dbData.dataRows.push(Lib.hashOfAssociativeArray(v));			
		});
		trace(dbData.dataRows[29]);
		//Web.setHeader('Content-Type', 'text/plain');
		Web.setHeader('Content-Type', 'text/html charset=utf-8');
		Web.setHeader("Access-Control-Allow-Headers", "access-control-allow-headers, access-control-allow-methods, access-control-allow-origin");
		Web.setHeader("Access-Control-Allow-Credentials", "true");
		Web.setHeader("Access-Control-Allow-Origin", "https://192.168.178.56:9000");
		var out = File.write("php://output", true);
		out.bigEndian = true;
		//out.write(MsgPack.encode(sRows));
		out.write(s.serialize(dbData));
		//trace(MsgPack.encode(sRows).toString());
		//trace(MsgPack.decode(MsgPack.encode(sRows)));
		//return MsgPack.encode(sRows).toString();
		//return Serializer.run(sRows);
		Sys.exit(0);
		return true;
	}
	
	/*public static function serializeRows(rows:NativeArray):Void
	{
		var s:Serializer = new Serializer();
		Syntax.foreach(rows, function(k:Int, v:Dynamic)
		{
			dbData.dbRows.push(Lib.hashOfAssociativeArray(v));
		});
		s.serialize(sRows);
	}	*/
}