package model.tools;
import haxe.io.Bytes;
import hxbit.Serializer;
import haxe.ds.StringMap;
import php.Lib;
import php.NativeArray;
import php.Syntax;
import comments.CommentString.*;
import php.Web;
import php.db.PDO;
import php.db.PDOStatement;
import shared.DbData;
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
				SELECT id,table_name,field_name,readonly,element,"any",required,use_as_index FROM _table_fields 
				$filter 
				ORDER BY table_name,field_name
				*/;
		trace(sql);
		var stmt:PDOStatement = S.dbh.query(sql, PDO.FETCH_ASSOC);
		if (untyped stmt == false)
		{
			trace(S.dbh.errorInfo());
			//S.send(Serializer.run(['error'=>S.dbh.errorInfo()]));
		}
		var tableFields:NativeArray = stmt.fetchAll(PDO.FETCH_ASSOC);//DB.serializeRows(
		trace('tableFields found: ' + stmt.rowCount());		
	trace(untyped tableFields[0]['id'] + '<<<');
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
			for (field in fields)
			{
				sql = comment(unindent, format) /*
				INSERT INTO crm._table_fields VALUES (DEFAULT, '$tableName','$field', jsonb_build_object($fieldsSql), 1)
				ON CONFLICT (table_name) DO UPDATE SET field_names='{$fieldNames}', field_hints=jsonb_build_object($fieldsSql)
				*/;				
				trace(sql);
				var res:PDOStatement = S.dbh.query(sql);
				if (untyped res == false)
				{
					trace(S.dbh.errorInfo());
					//S.send(Serializer.run(['error'=>S.dbh.errorInfo()]));
				}
				trace('Inserted ${tableName}: ' + res.rowCount());				
			}
		}
	}		
	
	public function saveTableFields()
	{
		var dBytes:Bytes = Bytes.ofString(param.get('dbData'));
		var s:Serializer = new Serializer();
		var pData:DbData = s.unserialize(dBytes, DbData);
		trace(pData.dataParams);
		var updated:Int = 0;
		for (k in pData.dataParams.keys())
		{
			//updateFieldsTable(pData.dataParams[k];
			var fields:String = S.dbh.quote(param.get('fields'), PDO.PARAM_STR);
			
			var sql = comment(unindent, format) /*
			UPDATE crm.table_fields SET $fields WHERE id=${Std.parseInt(k)}
			*/;
			
			var stmt:PDOStatement = S.dbh.prepare(sql);
			if( !Model.paramExecute(stmt, Lib.associativeArrayOfHash(pData.dataParams[k])))
			{
				S.sendErrors(dbData,['${param.get('action')}' => stmt.errorInfo()]);
			}
			if(stmt.rowCount()==1)
			{
				updated++;
			}
		}
		S.sendInfo(dbData, ['saveTableFields' => 'OK', 'updatedRows' => updated]);
	}
}