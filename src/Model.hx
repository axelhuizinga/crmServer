package;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Json;
import php.Lib;
import php.NativeArray;
import model.VicidialUsers;
import model.*;
import me.cunity.php.db.*;
import php.Syntax;
import php.db.PDO;
import php.db.PDOStatement;
import sys.db.*;

using Lambda;
using Util;
/**
 * ...
 * @author axel@cunity.me
 */


typedef MData = 
{
	@:optional var count:Int;
	@:optional var error:Dynamic;
	@:optional var page:Int;
	@:optional var editData:NativeArray;
	@:optional var globals:Dynamic;
	@:optional var rows:NativeArray;
	@:optional var content:String;
	@:optional var choice:NativeArray;
	@:optional var fieldDefault:NativeArray;
	@:optional var fieldNames:NativeArray;
	@:optional var fieldRequired:NativeArray;
	@:optional var jwt:String;
	@:optional var optionsMap:NativeArray;
	@:optional var recordings:NativeArray;
	@:optional var tableNames:Array<String>;
	@:optional var typeMap:NativeArray;
	@:optional var userMap:Array<UserInfo>;
	@:optional var userName:String;
};

class Model
{
	public var data:MData;
	public var db:String;
	public var globals:Dynamic;
	public var table:String;
	public var primary:String;
	public var num_rows(default, null):Int;
	var joinTable:String;
	var param:StringMap<Dynamic>;
	
	public static function dispatch(param:StringMap<Dynamic>):Void
	{
		var cl:Class<Dynamic> = Type.resolveClass('model.' + param.get('className'));
		//trace(cl);
		if (cl == null)
		{
			trace('model.' + param.get('className') + ' ???');
			S.add2Response({error:' cannot find model.' + cast param.get('className')}, true);
			//return false;
		}
		var fl:Dynamic = Reflect.field(cl, 'create');
		//trace(fl);
		if (fl == null)
		{
			trace(cl + 'create is null');
			S.add2Response({error:cast cl + ' create is null'}, true);
		}
		var iFields:Array<String> = Type.getInstanceFields(cl);
		//trace(iFields);
		if (iFields.has(param.get('action')))
		{
			trace('calling create ' + cl);
			Reflect.callMethod(cl, fl, [param]);
		}
		else 
		{
			trace('not calling create ');
			false;
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

		sqlBf.add(' FROM ' + S.my.quote(qTable));		
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
			filterTables = q.get('filter_tables').split(',').map(function(f:String) return 'fly_crm.' + S.my.quote(f)).join(',');			
			sqlBf.add(' FROM $filterTables,' + S.my.quote(qTable));
		}
		else
			sqlBf.add(' FROM ' + S.my.quote(qTable));		
		
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
			buildCond(q.get('filter').split(',').map( function(f:String) return 'fly_crm.' + S.my.quote(f) 
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
		sqlBf.add('SELECT ' + (fields != null ? fieldFormat( fields.split(',').map(function(f:String) return S.my.quote(f)).join(',') ): '*' ));
		var qTable:String = (q.get('table').any2bool() ? q.get('table') : table);
		var joinCond:String = (q.get('joincond').any2bool() ? q.get('joincond') : null);
		var joinTable:String = (q.get('jointable').any2bool() ? q.get('jointable') : null);
		var filterTables:String = '';
		if (q.get('filter').any2bool() )
		{
			filterTables = q.get('filter_tables').split(',').map(function(f:String) return 'fly_crm.' + S.my.quote(f)).join(',');			
			sqlBf.add(' FROM $filterTables,' + S.my.quote(qTable));
		}
		else
			sqlBf.add(' FROM ' + S.my.quote(qTable));		
		//sqlBf.add(' FROM ' + S.my.quote(qTable));		
		if (joinTable != null)
			sqlBf.add(' INNER JOIN $joinTable');
		if (joinCond != null)
			sqlBf.add(' ON $joinCond');
		var where:String = q.get('where');
		if (where != null)
			buildCond(where, sqlBf, phValues);
			
		if (q.get('filter').any2bool())
		{			
			buildCond(q.get('filter').split(',').map( function(f:String) return 'fly_crm.' + S.my.quote(f) 
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
		//sqlBf.add('SELECT ' + (fields != null ? fieldFormat( fields.split(',').map(function(f:String) return S.my.quote(f)).join(',') ): '*' ));
		sqlBf.add('SELECT ' + (fields != null ? fieldFormat(fields): '*' ));
		var qTable:String = (q.get('table').any2bool() ? q.get('table') : table);
		//TODO: JOINS
		sqlBf.add(' FROM ' + S.my.quote(qTable));		
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
				fieldsWithFormat.push(S.my.quote( f ) + ' AS ' + format[1]);	
				else
				fieldsWithFormat.push(format[0] + '(' + S.my.quote(f) + ', "' + format[1] + '") AS `' + f + '`');
			}
			else
				fieldsWithFormat.push(S.my.quote( f ));				
		}
		//trace(fieldsWithFormat);
		return fieldsWithFormat.join(',');
	}
	
	public function find(param:StringMap<String>):Void
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
		 json_encode();
	}
	
	//public function execute(sql:String, param:StringMap<Dynamic>, ?phValues:Array<Array<Dynamic>>):NativeArray
	public function execute(sql:String, ?phValues:Array<Array<Dynamic>>):NativeArray
	{
		trace(sql);	
		var stmt:PDOStatement =  S.my.prepare(sql, null);
		//var success:Bool = stmt.prepare(sql);
		//var success:EitherType<MySQLi_STMT ,Bool> = stmt.prepare(sql);
		var error:String = S.my.errorCode();
		trace (error);
		if (error=='')
		{
			trace(stmt.errorInfo());
			return null;
		}		
		var bindTypes:String = '';
		var values2bind:NativeArray = null;
		//var dbFieldTypes:StringMap<String> =  Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject(S.conf.get('dbFieldTypes')));
		
		var qObj:Dynamic = { };
		//var qVars:String = 'qVar_';
		var i:Int = 0;
		for (ph in phValues)
		{
			var type:Int = PDO.PARAM_STR; //dbFieldTypes.get(ph[0]);
			//bindTypes += (type.any2bool()  ?  type : 's');
			values2bind[i++] = ph[1];
			if (!stmt.bindParam(i, ph[1], type))
			{
				trace('ooops:' + stmt.errorInfo());
				Sys.exit(0);
			}
		}
		
		var data:NativeArray = null;
		var success: Bool;
		if (phValues.length > 0)
		{			
			//var fieldNames:Array<String> =  param.get('fields').split(',');
			success = stmt.execute(values2bind);
			if (!success)
			{
				trace(stmt.errorInfo());
				return null;
			}
			num_rows = stmt.rowCount();
			if (num_rows>0)
			{
				data = stmt.fetchAll(PDO.FETCH_ASSOC);
			}			
			return(data);		
		}
		else {
			success = stmt.execute(new NativeArray());
			if (!success)
			{
				trace(stmt.errorInfo());
				return untyped Syntax.code("array({0}, {1})", 'ERROR', stmt.error);
			}
			//var result:EitherType<MySQLi_Result,Bool> = stmt.get_result();
			num_rows = stmt.rowCount();
			if (num_rows>0)
			{
				data = stmt.fetchAll(PDO.FETCH_ASSOC);				
			}			
			return(data);	
		}
		return Syntax.assocDecl({'ERROR': stmt.errorInfo()});
		//return untyped __call__("array", 'ERROR', stmt.error);
	}
	
	public  function query(sql:String, ?resultType):NativeArray
	{
		trace(sql.split('password')[0]);
		if (resultType == null)
			resultType = PDO.FETCH_ASSOC;
		//var res:EitherType <MySQLi_Result , Bool > = S.my.real_query(sql, MySQLi.MYSQLI_USE_RESULT);
		//new NativeArray();
		var stm:PDOStatement = S.my.query(sql);
		if (! untyped stm)
		{
			trace(S.my.errorInfo());
			Sys.exit(0);
		}
		stm.execute(new NativeArray());
		trace(stm);
		var res:NativeArray = stm.fetchAll(resultType);
		Syntax.foreach(res, function(key:String, value:Dynamic){
			trace('$key => $value'); 
			res[key] = value;
		});
		return res;
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
						S.exit( {error:'BETWEEN needs 2 values - got only:' + values.join(',')});
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
	
	function quoteField(f : String):String {
		return f;
		//return KEYWORDS.exists(f.toLowerCase()) ? "`"+f+"`" : f;
	}	
	
	public function new(?param:StringMap<String>) {
		this.param = param;
		data = {};
		data.rows = new NativeArray();
		if (param != null && param.get('firstLoad') == 'true')
		{
			trace('firstLoad');
			globals = { };
			globals.users = query("SELECT full_name, user, active, user_group FROM vicidial_users");
		}
	}
	
	public function json_encode():Void
	{	
		data.userName = S.userName;
		data.globals = globals;
		S.add2Response({data:data});
	}
	
	public function json_response(res:String):String
	{
		return Syntax.code("json_encode({0},{1})", {content:res}, 64);//JSON_UNESCAPED_SLASHES
	}
	
	function getEditorFields(?table_name:String):StringMap<Array<StringMap<String>>>
	{
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		var param:StringMap<String> = new StringMap();
		param.set('table', 'fly_crm.editor_fields');
		
		param.set('where', 'field_cost|>-2' + (table_name != null ? 
		',table_name|' + S.my.quote(table_name): ''));
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