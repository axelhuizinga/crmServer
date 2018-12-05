package model.admin;

import haxe.ds.StringMap;
import haxe.extern.EitherType;
import php.Lib;
import php.NativeArray;
import me.cunity.php.db.*;
import php.Syntax;
import php.db.PDOStatement;
import sys.db.*;
import comments.CommentString.*;
using Lambda;
using Util;

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
		//self.table = 'columns';
		Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}

	public function run():Void
	{
		var sql:String = comment(unindent, format) /*
			SELECT string_agg(table_name, ',')
			FROM information_schema.tables 
			WHERE table_schema LIKE 'crm' GROUP BY (table_schema)
		*/;
		//trace(sql);
		var getTableNames:PDOStatement = S.dbh.query(sql);
		if (!untyped getTableNames)
		{
			trace(S.dbh.errorInfo());
			Sys.exit(0);
		}
		getTableNames.execute();
		trace(getTableNames.rowCount);

		var tableNames:Array<String> = getTableNames.fetchColumn().split(',');
		var getActiveTriggerTables:PDOStatement = S.dbh.query( comment(unindent, format) /*
		select string_agg(tbl.relname, ',') as trigger_tables
FROM pg_trigger trg JOIN pg_class tbl on trg.tgrelid = tbl.oid
WHERE trg.tgname = 'audit_trigger_row' AND  trg.tgenabled='O'
GROUP BY(trg.tgname);
		*/
		);
		getActiveTriggerTables.execute();
		var actTTNames:Array<String> = getActiveTriggerTables.fetchColumn().split(',');
		for (name in tableNames)
		{
			if (actTTNames.has(name))
			{
				trace('HistoryTrigger on Table $name is active');
				//S.add2Response({content:'$name ist aktiv'});
				Syntax.code("array_push({0},{1})", data.rows,'$name ist aktiv');
			}
			else
			{
				trace(name);
				createTrigger(name);	
				//S.add2Response({content:'$name erstellt'});
				Syntax.code("array_push({0},{1})", data.rows,'$name erstellt');
			}

		}
		trace(Syntax.code("count({0})", data.rows));
		json_encode();
	}
	
	function createTrigger(tableName:String)
	{		
		var activateTrigger = comment(unindent, format) /*
		SELECT audit.audit_table('$tableName');
		*/;		
		
		trace(activateTrigger);
		S.dbh.exec(activateTrigger);
		if (S.dbh.errorCode() != '00000')
		{
			trace(S.dbh.errorInfo());
			Sys.exit(0);
		}
		
	}
}