package;
import haxe.Unserializer;
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
//import StringTools;

 /* ...
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

@:enum
abstract JoinType(String)
{
	var INNER = 'INNER';	
	var LEFT = 'LEFT';	
	var RIGHT = 'RIGHT';	
}

typedef DataRelation =
{
	var joinType:JoinType;
	var joinCondition:String;	
}

typedef DataSource =
{
	@:optional var alias:String;
	@:optional var fields:Array<String>;
//	@:optional var alias:String;
	@:optional var filter:Array<StringMap<String>>;
}

class Model
{
	public var data:MData;
	public var db:String;
	public var joinSql:String;
	public var queryFields:String;
	public var filterSql:String;
	var filterValues:Array<Array<Dynamic>>;
	public var globals:Dynamic;
	public var tables:Array<String>;
	public var primary:String;
	public var num_rows(default, null):Int;
	var dataSource:StringMap<StringMap<String>>;// EACH KEY IS A TABLE NAME
	var dataSourceSql:String;
	var param:StringMap<String>;
	
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
	
	public function count():Int
	{
		var sqlBf:StringBuf = new StringBuf();
		sqlBf.add('SELECT COUNT(*) AS count FROM ');

		if (tables.length>1)
		{
			sqlBf.add(buildJoin());
		}		
		else
		{
			sqlBf.add(quoteIdent(tables[0]) + ' ');
		}
	
		return Lib.hashOfAssociativeArray(execute(sqlBf.toString())[0]).get('count');
	}
	
	public function buildJoin():String
	{
		if (joinSql != null)
			return joinSql;
		var sqlBf:StringBuf = new StringBuf();				
		for (table in tables)
		{
			var tRel:StringMap<String> = dataSource.get(table);
			var alias:String = tRel.get('alias');
			var jCond:String = tRel.get('jCond');
			if (jCond != null)
			{
				var jType:String = switch(tRel.get('jType'))
				{
					case JoinType.LEFT:
						'LEFT';
					case JoinType.RIGHT:
						'RIGHT';
					default:
						'INNER';
				}
				sqlBf.add('$jType JOIN ${quoteIdent(table)} $alias ON $jCond ');		
			}
			else
			{// FIRST TABLE
				sqlBf.add('${quoteIdent(table)} $alias ');
			}
		}
		joinSql = sqlBf.toString();
		return joinSql;
	}
	
	public function doSelect():NativeArray
	{	
		var sqlBf:StringBuf = new StringBuf();

		sqlBf.add('SELECT $queryFields FROM ');
		if (tables.length>1)
		{
			sqlBf.add(buildJoin());
		}		
		else
		{
			sqlBf.add(quoteIdent(tables[0]) + ' ');
		}
		var groupParam:String = param.get('group');
		if (groupParam != null)
			buildGroup(groupParam, sqlBf);
		//TODO:HAVING
		var order:String = param.get('order');
		if (order != null)
			buildOrder(order, sqlBf);
		var limit:String = param.get('limit');
		buildLimit((limit == null?'25':limit), sqlBf);	//	TODO: CONFIG LIMIT DEFAULT
		return execute(sqlBf.toString());
		//return execute(sqlBf.toString(), q,filterValuess);
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
	
	public function find():Void
	{	
		data =  {
			count:count(),
			page: param.exists('page') ? Std.parseInt( param.get('page') ) : 1,
			rows: doSelect()
		};
		json_encode();
	}
	
	//public function execute(sql:String, param:StringMap<Dynamic>, filterValuess:Array<Array<Dynamic>>):NativeArray
	public function execute(sql:String):NativeArray
	{
		trace(sql);	
		var stmt:PDOStatement =  S.my.prepare(sql);
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

		
		var data:NativeArray = null;
		var success: Bool;
		if(filterValues.length > 0)
		{
			var i:Int = 0;
			for (fV in filterValues)
			{
				var type:Int = PDO.PARAM_STR; //dbFieldTypes.get(fV[0]);
				//bindTypes += (type.any2bool()  ?  type : 's');
				values2bind[i++] = fV[1];
				//if (!stmt.bindParam(i, fV[1], type))//TODO: CHECK POSTGRES DRIVER OPTIONS
				if (!stmt.bindValue(i, fV[1], type))//TODO: CHECK POSTGRES DRIVER OPTIONS
				{
					trace('ooops:' + stmt.errorInfo());
					Sys.exit(0);
				}
			}			
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
		//trace(sql.split('password')[0]);
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
		if (stm.errorCode() != '00000')
		{
			trace(stm.errorCode());
			trace(stm.errorInfo());
			Sys.exit(0);
		}
		trace(stm);
		var res:NativeArray = stm.fetchAll(resultType);
		Syntax.foreach(res, function(key:String, value:Dynamic){
			trace('$key => $value'); 
			res[key] = value;
		});
		return res;
	}
	
	public function buildCond():String
	{
		if (filterSql != null)
			return filterSql;
		var filter:String = param.get('filter');
		if (filter == null)		
		{
			filterSql = '';
			return filterSql;			
		}
		var filters:Array<Dynamic> = filter.split(',');
		var	fBuf:StringBuf = new StringBuf();
		var first:Bool = true;
		filterValues = new Array();
		for (w in filters)
		{			
			var wData:Array<String> = w.split('|');
			var values:Array<String> = wData.slice(2);			
			trace(wData + ':' + ':');			
			if (first)
				fBuf.add(' WHERE ' );
			else
				fBuf.add(' AND ');
			first = false;			
			
			switch(wData[1].toUpperCase())
			{
				case 'BETWEEN':
					if (!(values.length == 2) && values.foreach(function(s:String) return s.any2bool()))
						S.exit( {error:'BETWEEN needs 2 values - got only:' + values.join(',')});
					fBuf.add(quoteIdent(wData[0]));
					fBuf.add(' BETWEEN ? AND ?');
					filterValues.push([wData[0], values[0]]);
					filterValues.push([wData[0], values[1]]);
				case 'IN':					
					fBuf.add(quoteIdent(wData[0]));					
					fBuf.add(' IN(');
					fBuf.add( values.map(function(s:String) { 
						filterValues.push([wData[0], values.shift()]);
						return '?'; 
						} ).join(','));							
					fBuf.add(')');
				case 'LIKE':					
					fBuf.add(quoteIdent(wData[0]));
					fBuf.add(' LIKE ?');
					filterValues.push([wData[0], wData[2]]);
				case _:
					fBuf.add(quoteIdent(wData[0]));
					if (~/^(<|>)/.match(wData[1]))
					{
						var eR:EReg = ~/^(<|>)/;
						eR.match(wData[1]);
						var val = Std.parseFloat(eR.matchedRight());
						fBuf.add(eR.matched(0) + '?');
						filterValues.push([wData[0],val]);
						continue;
					}
					//PLAIN VALUES
					if( wData[1] == 'NULL' )
						fBuf.add(" IS NULL");
					else {
						fBuf.add(" = ?");
						filterValues.push([wData[0],wData[1]]);	
					}			
			}			
		}
		filterSql = fBuf.toString();
		return filterSql;
	}

	public function buildGroup(groupParam:String, sqlBf:StringBuf):Bool
	{
		//TODO: HANDLE expr|position
		var fields:Array<String> = groupParam.split(',');
		if (fields.length == 0)
			return false;
		sqlBf.add(' GROUP BY ');
		sqlBf.add(fields.map(function(g:String) return  quoteIdent(g)).join(','));
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
			return  quoteIdent(g[0]) + ( g.length == 2 && g[1] == 'DESC'  ?  ' DESC' : '');
		}).join(','));
		return true;
	}
	
	public function buildLimit(limitParam:String, sqlBf:StringBuf):Void
	{
		sqlBf.add(' LIMIT ' + (limitParam.indexOf(',') > -1 ? limitParam.split(',').map(function(s:String):Int return Std.parseInt(s)).join(',') 
			: Std.string(Std.parseInt(limitParam))));
	}
	
	function quoteIdent(f : String):String 
	{
		if ( ~/^(a-zA-Z_)a-zA-Z0-9_+$/.match(f))
		{
			return f;
		}
		
		return '"$f"';
		//return S.my.quote(f);
	}	
	
	function row2jsonb(row:Dynamic):String
	{
		var _jsonb_array_text:StringBuf = new StringBuf();
		for (f in Reflect.fields(row))
		{
			trace('$f: ${Reflect.field(row, f)}');
			var val:Dynamic = Reflect.field(row, f);
			if (val == null)
			{
				trace(null);
				val = '""';
			}
			else if (val == '')
			{
				trace("''");
				val = '""';
			}
			var _comma:String = _jsonb_array_text.length > 2?',':'';
			_jsonb_array_text.add('$_comma$f,$val');
		}
		return _jsonb_array_text.toString();
	}
	
	public function new(?param:StringMap<String>) 
	{
		this.param = param;
		data = {};
		data.rows = new NativeArray();
		if (param.exists('filter'))
		{			
			filterValues = new Array();
		}

		if (param != null && param.get('fullReload') == 'true')
		{
			trace('fullReload');
			globals = { };
			globals.users = query("SELECT first_name, last_name, user_name, active, user_group FROM vicidial_users");
		}
		tables = [];
		var fields:Array<String> = [];
		if(param.get('dataSource') != null)
		{
			dataSource = new StringMap();
			dataSource = Unserializer.run(param.get('dataSource'));
			trace(dataSource.toString());
			for (tableName in dataSource.keys())
			{
				tables.push(tableName);
				var table:StringMap<String> = dataSource.get(tableName);
				if(table.exists('fields'))
					fields.concat(buildFields(tableName, table));
			}
		}
		queryFields = fields.length>0?fields.join(','):'*';		
		joinSql = buildJoin();
		filterSql = buildCond();
	}
	
	function buildFields(name:String, table:StringMap<String>):Array<String>
	{
		var prefix = (table.exists('alias')?table.get('alias'):name);
		if (table.exists('fields'))
		{
			return table.get('fields').split(',').map(function(field) return '$prefix.$field');
		}
		return [];
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
		var filterValues:Array<Array<Dynamic>> = new Array();
		var param:StringMap<String> = new StringMap();
		param.set('table', 'fly_crm.editor_fields');
		
		param.set('filter', 'field_cost|>-2' + (table_name != null ? 
		',table_name|' + quoteIdent(table_name): ''));
		param.set('fields', 'field_name,field_label,field_type,field_options,table_name');
		param.set('order', 'table_name,field_rank,field_order');
		param.set('limit', '100');
		//trace(param);
		var eFields:Array<Dynamic> = Lib.toHaxeArray( doSelect());
		//var eFields:NativeArray = doSelect(param, sqlBffilterValueses);
		//var eFields:Dynamic = doSelect(param, sqlBffilterValueses);
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