package;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Json;
import php.Lib;
import php.NativeArray;
import model.VicidialUsers;
import model.*;
import me.cunity.php.db.*;
import sys.db.*;

using Lambda;
using Util;
/**
 * ...
 * @author axel@cunity.me
 */

typedef MConfig = 
{
	var table:String;
	
}
 
typedef MData = 
{
	@:optional var agent:String;
	@:optional var count:Int;
	@:optional var page:Int;
	@:optional var editData:NativeArray;
	@:optional var globals:Dynamic;
	@:optional var rows:NativeArray;
	@:optional var response:String;
	@:optional var choice:NativeArray;
	@:optional var fieldDefault:NativeArray;
	@:optional var fieldNames:NativeArray;
	@:optional var fieldRequired:NativeArray;
	@:optional var optionsMap:NativeArray;
	@:optional var recordings:NativeArray;
	@:optional var typeMap:NativeArray;
	@:optional var userMap:Array<UserInfo>;
};

class Model
{
	private static var KEYWORDS = {
		var h = new haxe.ds.StringMap();
		for( k in "ADD|ALL|ALTER|ANALYZE|AND|AS|ASC|ASENSITIVE|BEFORE|BETWEEN|BIGINT|BINARY|BLOB|BOTH|BY|CALL|CASCADE|CASE|CHANGE|CHAR|CHARACTER|CHECK|COLLATE|COLUMN|CONDITION|CONSTRAINT|CONTINUE|CONVERT|CREATE|CROSS|CURRENT_DATE|CURRENT_TIME|CURRENT_TIMESTAMP|CURRENT_USER|CURSOR|DATABASE|DATABASES|DAY_HOUR|DAY_MICROSECOND|DAY_MINUTE|DAY_SECOND|DEC|DECIMAL|DECLARE|DEFAULT|DELAYED|DELETE|DESC|DESCRIBE|DETERMINISTIC|DISTINCT|DISTINCTROW|DIV|DOUBLE|DROP|DUAL|EACH|ELSE|ELSEIF|ENCLOSED|ESCAPED|EXISTS|EXIT|EXPLAIN|FALSE|FETCH|FLOAT|FLOAT4|FLOAT8|FOR|FORCE|FOREIGN|FROM|FULLTEXT|GRANT|GROUP|HAVING|HIGH_PRIORITY|HOUR_MICROSECOND|HOUR_MINUTE|HOUR_SECOND|IF|IGNORE|IN|INDEX|INFILE|INNER|INOUT|INSENSITIVE|INSERT|INT|INT1|INT2|INT3|INT4|INT8|INTEGER|INTERVAL|INTO|IS|ITERATE|JOIN|KEY|KEYS|KILL|LEADING|LEAVE|LEFT|LIKE|LIMIT|LINES|LOAD|LOCALTIME|LOCALTIMESTAMP|LOCK|LONG|LONGBLOB|LONGTEXT|LOOP|LOW_PRIORITY|MATCH|MEDIUMBLOB|MEDIUMINT|MEDIUMTEXT|MIDDLEINT|MINUTE_MICROSECOND|MINUTE_SECOND|MOD|MODIFIES|NATURAL|NOT|NO_WRITE_TO_BINLOG|NULL|NUMERIC|ON|OPTIMIZE|OPTION|OPTIONALLY|OR|ORDER|OUT|OUTER|OUTFILE|PRECISION|PRIMARY|PROCEDURE|PURGE|READ|READS|REAL|REFERENCES|REGEXP|RELEASE|RENAME|REPEAT|REPLACE|REQUIRE|RESTRICT|RETURN|REVOKE|RIGHT|RLIKE|SCHEMA|SCHEMAS|SECOND_MICROSECOND|SELECT|SENSITIVE|SEPARATOR|SET|SHOW|SMALLINT|SONAME|SPATIAL|SPECIFIC|SQL|SQLEXCEPTION|SQLSTATE|SQLWARNING|SQL_BIG_RESULT|SQL_CALC_FOUND_ROWS|SQL_SMALL_RESULT|SSL|STARTING|STRAIGHT_JOIN|TABLE|TERMINATED|THEN|TINYBLOB|TINYINT|TINYTEXT|TO|TRAILING|TRIGGER|TRUE|UNDO|UNION|UNIQUE|UNLOCK|UNSIGNED|UPDATE|USAGE|USE|USING|UTC_DATE|UTC_TIME|UTC_TIMESTAMP|VALUES|VARBINARY|VARCHAR|VARCHARACTER|VARYING|WHEN|WHERE|WHILE|WITH|WRITE|XOR|YEAR_MONTH|ZEROFILL|ASENSITIVE|CALL|CONDITION|CONNECTION|CONTINUE|CURSOR|DECLARE|DETERMINISTIC|EACH|ELSEIF|EXIT|FETCH|GOTO|INOUT|INSENSITIVE|ITERATE|LABEL|LEAVE|LOOP|MODIFIES|OUT|READS|RELEASE|REPEAT|RETURN|SCHEMA|SCHEMAS|SENSITIVE|SPECIFIC|SQL|SQLEXCEPTION|SQLSTATE|SQLWARNING|TRIGGER|UNDO|UPGRADE|WHILE".split("|") )
			h.set(k.toLowerCase(),true);
		h;
	}
	public var data:MData;
	public var db:String;
	public var globals:Dynamic;
	public var table:String;
	public var primary:String;
	public var num_rows(default, null):Int;
	var joinTable:String;
	var param:StringMap<Dynamic>;
	
	public static function dispatch(param:StringMap<Dynamic>):EitherType<String,Bool>
	{
		var cl:Class<Dynamic> = Type.resolveClass('model.' + param.get('className'));
		//trace(cl);
		if (cl == null)
		{
			trace('model.'+param.get('className') + ' ???');
			return false;
		}
		var fl:Dynamic = Reflect.field(cl, 'create');
		//trace(fl);
		if (fl == null)
		{
			trace(cl + 'create is null');
			return false;
		}
		var iFields:Array<String> = Type.getInstanceFields(cl);
		//trace(iFields);
		if (iFields.has(param.get('action')))
		{
			trace('calling create ' + cl);
			return Reflect.callMethod(cl, fl, [param]);
		}
		else 
		{
			trace('not calling create ');
			return false;
		}
	}
	
	public function count(q:StringMap<String>, sqlBf:StringBuf, phValues:Array<Array<Dynamic>>):Int
	{
		var fields:String = q.get('fields');		
		trace ('table:' + q.get('table') + ':' + (q.get('table').any2bool() ? q.get('table') : table));
		//sqlBf.add('SELECT ' + fieldFormat((fields != null ? fields.split(',').map(function(f:String) return quoteField(f)).join(',') : '*' )));
		sqlBf.add('SELECT COUNT(*) AS count');
		var qTable:String = (q.get('table').any2bool() ? q.get('table') : table);
		var joinCond:String = (q.get('joincond').any2bool() ? q.get('joincond') : null);
		var joinTable:String = (q.get('jointable').any2bool() ? q.get('jointable') : null);

		sqlBf.add(' FROM ' + S.my.real_escape_string(qTable));		
		var where:String = q.get('where');
		if (where != null)
			buildCond(where, sqlBf, phValues);

		return Lib.hashOfAssociativeArray(execute(sqlBf.toString(), phValues)[0]).get('count');
		//return Lib.hashOfAssociativeArray(execute(sqlBf.toString(), q, phValues)[0]).get('count');
	}
	
	public function countJoin(q:StringMap<String>, sqlBf:StringBuf, phValues:Array<Array<Dynamic>>):Int
	{
		var fields:String = q.get('fields');		
		
		trace ('table:' + q.get('table') + ':' +  (q.get('table').any2bool() ? q.get('table') : table));
		//sqlBf.add('SELECT ' + fieldFormat((fields != null ? fields.split(',').map(function(f:String) return quoteField(f)).join(',') : '*' )));
		sqlBf.add('SELECT COUNT(*) AS count');
		var qTable:String = (q.get('table').any2bool() ? q.get('table') : table);
		var joinCond:String = (q.get('joincond').any2bool() ? q.get('joincond') : null);
		joinTable = (q.get('jointable').any2bool() ? q.get('jointable') : null);
		
		var filterTables:String = '';
		if (q.get('filter').any2bool() )
		{
			filterTables = q.get('filter_tables').split(',').map(function(f:String) return 'fly_crm.' + S.my.real_escape_string(f)).join(',');			
			sqlBf.add(' FROM $filterTables,' + S.my.real_escape_string(qTable));
		}
		else
			sqlBf.add(' FROM ' + S.my.real_escape_string(qTable));		
		
		if (joinTable != null)
			sqlBf.add(' INNER JOIN $joinTable');
		if (joinCond != null)
			sqlBf.add(' ON $joinCond');
		var where:String = q.get('where');
		if (where != null)
			buildCond(where, sqlBf, phValues);
		// add filter conditions
		if (q.get('filter').any2bool())
		{			
			buildCond(q.get('filter').split(',').map( function(f:String) return 'fly_crm.' + S.my.real_escape_string(f) 
			).join(','), sqlBf, phValues, false);
			if (joinTable == 'vicidial_users')
				sqlBf.add(' ' + filterTables.split(',').map(function(f:String) return 'AND $f.client_id=vicidial_list.vendor_lead_code').join(' '));
			else
				sqlBf.add(' ' + filterTables.split(',').map(function(f:String) return 'AND $f.client_id=clients.client_id').join(' '));
		}
		//var hash =  Lib.hashOfAssociativeArray(execute(sqlBf.toString(), q, phValues)[0]);
		//trace(hash + ': ' + (hash.exists('count') ? 'Y':'N') );
		return Lib.hashOfAssociativeArray(execute(sqlBf.toString(), phValues)[0]).get('count');
		//return Lib.hashOfAssociativeArray(execute(sqlBf.toString(), q, phValues)[0]).get('count');
	}
	
	public function doJoin(q:StringMap<String>, sqlBf:StringBuf, phValues:Array<Array<Dynamic>>):NativeArray
	{
		var fields:String = q.get('fields');		
		trace ('table:' + q.get('table') + ':' + (q.get('table').any2bool() ? q.get('table') : table));
		//sqlBf.add('SELECT ' + fieldFormat((fields != null ? fields.split(',').map(function(f:String) return quoteField(f)).join(',') : '*' )));
		sqlBf.add('SELECT ' + (fields != null ? fieldFormat( fields.split(',').map(function(f:String) return S.my.real_escape_string(f)).join(',') ): '*' ));
		var qTable:String = (q.get('table').any2bool() ? q.get('table') : table);
		var joinCond:String = (q.get('joincond').any2bool() ? q.get('joincond') : null);
		var joinTable:String = (q.get('jointable').any2bool() ? q.get('jointable') : null);
		var filterTables:String = '';
		if (q.get('filter').any2bool() )
		{
			filterTables = q.get('filter_tables').split(',').map(function(f:String) return 'fly_crm.' + S.my.real_escape_string(f)).join(',');			
			sqlBf.add(' FROM $filterTables,' + S.my.real_escape_string(qTable));
		}
		else
			sqlBf.add(' FROM ' + S.my.real_escape_string(qTable));		
		//sqlBf.add(' FROM ' + S.my.real_escape_string(qTable));		
		if (joinTable != null)
			sqlBf.add(' INNER JOIN $joinTable');
		if (joinCond != null)
			sqlBf.add(' ON $joinCond');
		var where:String = q.get('where');
		if (where != null)
			buildCond(where, sqlBf, phValues);
			
		if (q.get('filter').any2bool())
		{			
			buildCond(q.get('filter').split(',').map( function(f:String) return 'fly_crm.' + S.my.real_escape_string(f) 
			).join(','), sqlBf, phValues, false);
						
			if (joinTable == 'vicidial_users')
				sqlBf.add(' ' + filterTables.split(',').map(function(f:String) return 'AND $f.client_id=vicidial_list.vendor_lead_code').join(' '));
			else
				sqlBf.add(' ' + filterTables.split(',').map(function(f:String) return 'AND $f.client_id=clients.client_id').join(' '));
		}		
		
		var groupParam:String = q.get('group');
		if (groupParam != null)
			buildGroup(groupParam, sqlBf);
		//TODO:HAVING
		var order:String = q.get('order');
		if (order != null)
			buildOrder(order, sqlBf);
			
		var limit:String = q.get('limit');
		buildLimit((limit == null?'15':limit), sqlBf);	//	TODO: CONFIG LIMIT DEFAULT
		return execute(sqlBf.toString(), phValues);
		//return execute(sqlBf.toString(), q, phValues);
	}
	
	public function doSelect(q:StringMap<Dynamic>, sqlBf:StringBuf, phValues:Array<Array<Dynamic>>):NativeArray
	{
		var fields:String = q.get('fields');		
		trace ('table:' + q.get('table') + ':' + (q.get('table').any2bool() ? q.get('table') : table));
		//sqlBf.add('SELECT ' + fieldFormat((fields != null ? fields.split(',').map(function(f:String) return quoteField(f)).join(',') : '*' )));
		//sqlBf.add('SELECT ' + (fields != null ? fieldFormat( fields.split(',').map(function(f:String) return S.my.real_escape_string(f)).join(',') ): '*' ));
		sqlBf.add('SELECT ' + (fields != null ? fieldFormat(fields): '*' ));
		var qTable:String = (q.get('table').any2bool() ? q.get('table') : table);
		//TODO: JOINS
		sqlBf.add(' FROM ' + S.my.real_escape_string(qTable));		
		var where:String = q.get('where');
		if (where != null)
			buildCond(where, sqlBf, phValues);
		var groupParam:String = q.get('group');
		if (groupParam != null)
			buildGroup(groupParam, sqlBf);
		//TODO:HAVING
		var order:String = q.get('order');
		if (order != null)
			buildOrder(order, sqlBf);
		var limit:String = q.get('limit');
		buildLimit((limit == null?'15':limit), sqlBf);	//	TODO: CONFIG LIMIT DEFAULT
		return execute(sqlBf.toString(), phValues);
		//return execute(sqlBf.toString(), q, phValues);
	}
	
	public function fieldFormat(fields:String):String
	{
		var fieldsWithFormat:Array<String> = new Array();
		var sF:Array<String> = fields.split(',');
		var dbQueryFormats:StringMap<Array<String>> = Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject((S.conf.get('dbQueryFormats'))));
		trace(dbQueryFormats);
		
		var qKeys:Array<String> = new Array();
		var it:Iterator<String> = dbQueryFormats.keys(); 
		while (it.hasNext())
		{
			qKeys.push(it.next());
		}
	
		for (f in sF)
		{
			if (qKeys.has(f))
			{
				var format:Array<String> = dbQueryFormats.get(f);
				//trace(format);
				if (format[0] == 'ALIAS')
				fieldsWithFormat.push(S.my.real_escape_string( f ) + ' AS ' + format[1]);	
				else
				fieldsWithFormat.push(format[0] + '(' + S.my.real_escape_string(f) + ', "' + format[1] + '") AS `' + f + '`');
			}
			else
				fieldsWithFormat.push(S.my.real_escape_string( f ));				
		}
		//trace(fieldsWithFormat);
		return fieldsWithFormat.join(',');
	}
	
	public function find(param:StringMap<String>):EitherType<String,Bool>
	{	
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		//trace(param);
		var count:Int = countJoin(param, sqlBf, phValues);
		
		sqlBf = new StringBuf();
		phValues = new Array();
		trace( 'count:' + count + ' page:' + param.get('page')  + ': ' + (param.exists('page') ? 'Y':'N'));
		data =  {
			count:count,
			page: param.exists('page') ? Std.parseInt( param.get('page') ) : 1,
			rows: doSelect(param, sqlBf, phValues)
		};
		return json_encode();
	}
	
	//public function execute(sql:String, param:StringMap<Dynamic>, ?phValues:Array<Array<Dynamic>>):NativeArray
	public function execute(sql:String, ?phValues:Array<Array<Dynamic>>):NativeArray
	{
		trace(sql);	
		var stmt =  S.my.stmt_init();
		//var success:Bool = stmt.prepare(sql);
		var success:EitherType<MySQLi_STMT ,Bool> = stmt.prepare(sql);
		trace (success);
		if (!success)
		{
			trace(stmt.error);
			return null;
		}		
		var bindTypes:String = '';
		var values2bind:NativeArray = null;
		var dbFieldTypes:StringMap<String> =  Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject(S.conf.get('dbFieldTypes')));
		
		var qObj:Dynamic = { };
		//var qVars:String = 'qVar_';
		var i:Int = 0;
		for (ph in phValues)
		{
			var type:String = dbFieldTypes.get(ph[0]);
			bindTypes += (type.any2bool()  ?  type : 's');
			values2bind[i++] = ph[1];
		}

		trace(Std.string(values2bind));
		if (phValues.length > 0)
		{
			success = untyped __call__('myBindParam', stmt, values2bind, bindTypes);
			trace ('success:' + success);
			if (success)
			{
				//var fieldNames:Array<String> =  param.get('fields').split(',');
				var data:NativeArray = null;
				success = stmt.execute();
				if (!success)
				{
					trace(stmt.error);
					return null;
				}
				
				var result:EitherType<MySQLi_Result,Bool> = stmt.get_result();
				if (result)
				{
					num_rows = cast(result, MySQLi_Result).num_rows;
					data = cast(result, MySQLi_Result).fetch_all(MySQLi.MYSQLI_ASSOC);
				}			
				return(data);		
			}			
		}
		else {
			var data:NativeArray = null;
			success = stmt.execute();
			if (!success)
			{
				trace(stmt.error);
				return untyped __call__("array", 'ERROR', stmt.error);
			}
			var result:EitherType<MySQLi_Result,Bool> = stmt.get_result();
			if (result)
			{
				var res:MySQLi_Result = cast(result, MySQLi_Result);
				num_rows = res.num_rows;
				data = res.fetch_all(MySQLi.MYSQLI_ASSOC);				
			}			
			return(data);	
		}

		return untyped __call__("array", 'ERROR', stmt.error);
	}
	
	public  function query(sql:String):NativeArray
	{
		trace(sql.split('password')[0]);
		//var res:EitherType <MySQLi_Result , Bool > = S.my.real_query(sql, MySQLi.MYSQLI_USE_RESULT);
		var ok:Bool = S.my.real_query(sql);
		//if (res && sql.indexOf('UPDATE')==-1)
		if (ok && S.my.field_count > 0)
		{
			var res:MySQLi_Result = S.my.store_result();
			trace(res);
			var data:NativeArray = res.fetch_all(MySQLi.MYSQLI_ASSOC);
			res.free();
			return(data);		
		}
		else
			trace(ok?'OK':'NOTOK' + S.my.error);
		if (S.my.connect_error != null)
			trace(S.my.connect_error);
		return null;
	}
	
	public function buildCond(whereParam:String, sob:StringBuf, phValues:Array<Array<Dynamic>>, ?first:Bool=true):Bool
	{
		var sqlBf:StringBuf = new StringBuf();
		var where:Array<Dynamic> = whereParam.split(',');
		//trace(where);
		if (where.length == 0)
			return false;
		//var first:Bool = true;
		for (w in where)
		{
			
			var wData:Array<String> = w.split('|');
			var values:Array<String> = wData.slice(2);
			
			var filter_tables:Array<String> = null;
			if (param.any2bool() && param.exists('filter_tables') && param.get('filter_tables').any2bool())
			{
				var jt:String = param.get('filter_tables');
				filter_tables = jt.split(',');
			}
			
			trace(wData + ':' + joinTable + ':' +  filter_tables);
			
			if (first)
				sqlBf.add(' WHERE ' );
			else
				sqlBf.add(' AND ');
			first = false;			
			
			switch(wData[1].toUpperCase())
			{
				case 'BETWEEN':
					if (!(values.length == 2) && values.foreach(function(s:String) return s.any2bool()))
						S.exit( 'BETWEEN needs 2 values - got only:' + values.join(','));
					sqlBf.add(quoteField(wData[0]));
					sqlBf.add(' BETWEEN ? AND ?');
					phValues.push([wData[0], values[0]]);
					phValues.push([wData[0], values[1]]);
				case 'IN':					
					sqlBf.add(quoteField(wData[0]));					
					sqlBf.add(' IN(');
					sqlBf.add( values.map(function(s:String) { 
						phValues.push([wData[0], values.shift()]);
						return '?'; 
						} ).join(','));							
					sqlBf.add(')');
				case 'LIKE':					
					sqlBf.add(quoteField(wData[0]));
					sqlBf.add(' LIKE ?');
					phValues.push([wData[0], wData[2]]);
				case _:
					sqlBf.add(quoteField(wData[0]));
					if (~/^(<|>)/.match(wData[1]))
					{
						var eR:EReg = ~/^(<|>)/;
						eR.match(wData[1]);
						var val = Std.parseFloat(eR.matchedRight());
						sqlBf.add(eR.matched(0) + '?');
						phValues.push([wData[0],val]);
						continue;
					}
					//PLAIN VALUE
					if( wData[1] == 'NULL' )
						sqlBf.add(" IS NULL");
					else {
						sqlBf.add(" = ?");
						phValues.push([wData[0],wData[1]]);	
					}			
			}			
		}
		sob.add(sqlBf.toString());
		return true;
	}

	public function buildGroup(groupParam:String, sqlBf:StringBuf):Bool
	{
		//TODO: HANDLE expr|position
		var fields:Array<String> = groupParam.split(',');
		if (fields.length == 0)
			return false;
		sqlBf.add(' GROUP BY ');
		sqlBf.add(fields.map(function(g:String) return  quoteField(g)).join(','));
		return true;
	}
	
	public function buildOrder(orderParam:String, sqlBf:StringBuf):Bool
	{
		var fields:Array<String> = orderParam.split(',');
		if (fields.length == 0)
			return false;
		sqlBf.add(' ORDER BY ');
		sqlBf.add(fields.map(function(f:String)
		{
			var g:Array<String> = f.split('|');
			return  quoteField(g[0]) + ( g.length == 2 && g[1] == 'DESC'  ?  ' DESC' : '');
		}).join(','));
		return true;
	}
	
	public function buildLimit(limitParam:String, sqlBf:StringBuf):Bool
	{
		sqlBf.add(' LIMIT ' + (limitParam.indexOf(',') > -1 ? limitParam.split(',').map(function(s:String):Int return Std.parseInt(s)).join(',') 
			: Std.string(Std.parseInt(limitParam))));
		return true;
	}
	
	function quoteField(f : String) {
		return KEYWORDS.exists(f.toLowerCase()) ? "`"+f+"`" : f;
	}	
	
	public function new(?param:StringMap<String>) {
		this.param = param;
		if (param != null && param.get('firstLoad') == 'true')
		{
			trace('firstLoad');
			globals = { };
			globals.users = query("SELECT full_name, user, active, user_group FROM vicidial_users");
		}
	}
	
	public function json_encode():EitherType<String,Bool>
	{	
		data.agent = cast S.user;
		data.globals = globals;
		return untyped __call__("json_encode", data, 64|256);//JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE
	}
	
	public function json_response(res:String):EitherType<String,Bool>
	{
		return untyped __call__("json_encode", {response:res}, 64);//JSON_UNESCAPED_SLASHES
	}
	
	function getEditorFields(?table_name:String):StringMap<Array<StringMap<String>>>
	{
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		var param:StringMap<String> = new StringMap();
		param.set('table', 'fly_crm.editor_fields');
		
		param.set('where', 'field_cost|>-2' + (table_name != null ? 
		',table_name|' + S.my.real_escape_string(table_name): ''));
		param.set('fields', 'field_name,field_label,field_type,field_options,table_name');
		param.set('order', 'table_name,field_rank,field_order');
		param.set('limit', '100');
		//trace(param);
		var eFields:Array<Dynamic> = Lib.toHaxeArray( doSelect(param, sqlBf, phValues));
		//var eFields:NativeArray = doSelect(param, sqlBf, phValues);
		//var eFields:Dynamic = doSelect(param, sqlBf, phValues);
		//trace(eFields);
		//trace(eFields.length);
		var ret:StringMap<Array<StringMap<String>>> = new StringMap();
		//var ret:Array<StringMap<String>> = new Array();
		for (ef in eFields)
		{
			var table:String = untyped ef['table_name'];
			if (!ret.exists(table))
			{
				ret.set(table, []);
			}
			//var field:StringMap<String> = Lib.hashOfAssociativeArray(ef);
			//trace(field.get('field_label')+ ':' + field);
			var a:Array<StringMap<String>> = ret.get(table);
			a.push(Lib.hashOfAssociativeArray(ef));
			ret.set(table, a);
			//return ret;
		}
		//trace(ret);
		return ret;
	}
	
}