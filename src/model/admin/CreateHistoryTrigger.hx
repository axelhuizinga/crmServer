package model.admin;

import haxe.ds.StringMap;
import php.Lib;
import php.NativeArray;
import me.cunity.php.db.*;
import php.db.PDOStatement;
import sys.db.*;
import comments.CommentString.*;
using Lambda;

/**
 * ...
 * @author axel@bi4.me
 */

@:keep
class CreateHistoryTrigger extends Model 
{
	public static function create(param:StringMap<String>):Void
	{
		var self:CreateHistoryTrigger = new CreateHistoryTrigger(param);	
		self.table = 'columns';
		//self.param = param;
		//trace(param);
		Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}

	public function run():Void
	{
		var getTableNames:PDOStatement = S.my.query('SELECT GROUP_CONCAT(TABLE_NAME) AS "tableNames" FROM information_schema.`TABLES` WHERE `TABLE_SCHEMA` LIKE "crm" AND TABLE_NAME NOT LIKE "\\_%" GROUP BY TABLE_SCHEMA');
		if (!untyped getTableNames)
		{
			trace(S.my.errorInfo());
			Sys.exit(0);
		}
		getTableNames.execute();
		trace(getTableNames.rowCount);
		//trace(getTableNames.fetch_row());
		//
		var tNames:String = getTableNames.fetchColumn();
		trace(tNames);
		//Sys.exit(0);
		var tableNames:Array<String> = tNames.split(',');
		for (name in tableNames)
		{
			trace(name);
			createTrigger(name);
		}
		data = {
			tableNames:tableNames
		};
		json_encode();
	}
	
	function createTrigger(tableName:String)
	{
		var fieldResult:PDOStatement = S.my.query('SELECT GROUP_CONCAT(`COLUMN_NAME`) FROM information_schema.`COLUMNS` WHERE `TABLE_SCHEMA`="crm" AND TABLE_NAME="$tableName" GROUP BY TABLE_NAME');
		fieldResult.execute();
		var cNames:String = fieldResult.fetchColumn();
		var columnNames:Array<String> = cNames.split(',');
		
		var columnPairs:Array<String> = new Array();
		for (cName in columnNames)
		{
			columnPairs.push('"$cName",NEW.`$cName`');
		}
		trace(columnNames);
		var dSelect:String = columnPairs.join(',');
		var activateTrigger = comment(unindent, format) /**
	blah
END;
		**/;		
		
		trace(activateTrigger);
		
		Sys.exit(1);
		
	}
}