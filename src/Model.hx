package;
import haxe.Unserializer;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Json;
import haxe.io.Bytes;
import hxbit.Serializer;
import php.Lib;
import php.NativeArray;
import model.VicidialUsers;
import model.*;
import me.cunity.php.db.*;
import php.Syntax;
import php.Web;
import php.db.PDO;
import php.db.PDOStatement;
import shared.DbData;
import sys.db.*;
import sys.io.File;

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
	@:optional var fieldNames:Map<String,String>;
	@:optional var fieldRequired:NativeArray;
	@:optional var jwt:String;
	@:optional var optionsMap:NativeArray;
	@:optional var recordings:NativeArray;
	@:optional var tableNames:Array<String>;
	@:optional var typeMap:NativeArray;
	@:optional var userMap:Array<UserInfo>;
	@:optional var user_name:String;
};

typedef RData =
{
	?rows:NativeArray,
	?error:StringMap<Dynamic>,
	?info:StringMap<Dynamic>
}

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
	public var fieldNames:Array<String>;
	public var tableNames:Array<String>;
	public var table:String;
	public var num_rows(default, null):Int;
	var dbData:DbData;
	var qParam:DbData;
	var dataSource:StringMap<StringMap<String>>;// EACH KEY IS A TABLE NAME
	var dataSourceSql:String;
	var param:Map<String, Dynamic>;
	
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
	
	public static function paramExecute(stmt:PDOStatement, ?values:NativeArray):Bool
	{
		S.saveLog(values);
		if (!stmt.execute(values))
		{
			trace(stmt.errorInfo());
			return false;
		}
		return true;
	}
	
	public function count():Int
	{
		var sqlBf:StringBuf = new StringBuf();
		sqlBf.add('SELECT COUNT(*) AS count FROM ');

		if (tableNames.length>1)
		{
			sqlBf.add(buildJoin());
		}		
		else
		{
			sqlBf.add('$tableNames[0] ');
		}
		if (filterSql != null)
		{
			sqlBf.add(filterSql);
		}
	
		return Lib.hashOfAssociativeArray(execute(sqlBf.toString())[0]).get('count');
	}
	
	public function buildJoin():String
	{
		if (joinSql != null)
			return joinSql;
		var sqlBf:StringBuf = new StringBuf();				
		for (table in tableNames)
		{
			var tRel:StringMap<String> = dataSource.get(table);
			var alias:String = (tRel.exists('alias')? quoteIdent(tRel.get('alias')):'');
			var jCond:String = tRel.exists('jCond') ? quoteIdent(tRel.get('jCond')):null;
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
				sqlBf.add('$jType JOIN $table $alias ON $jCond ');		
			}
			else
			{// FIRST TABLE
				sqlBf.add('$table $alias ');
			}
		}
		joinSql = sqlBf.toString();
		return joinSql;
	}
	
	public function doSelect():NativeArray
	{	
		var sqlBf:StringBuf = new StringBuf();

		sqlBf.add('SELECT $queryFields FROM ');
		if (tableNames.length>1)
		{
			sqlBf.add(joinSql);
		}		
		else
		{
			sqlBf.add('$tableNames[0] ');
		}
		if (filterSql != null)
		{
			sqlBf.add(filterSql);
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
				fieldsWithFormat.push(S.dbh.quote( f ) + ' AS ' + format[1]);	
				else
				fieldsWithFormat.push(format[0] + '(' + S.dbh.quote(f) + ', "' + format[1] + '") AS `' + f + '`');
			}
			else
				fieldsWithFormat.push(S.dbh.quote( f ));				
		}
		//trace(fieldsWithFormat);
		return fieldsWithFormat.join(',');
	}
	
	public function find():Void
	{	
		var rData:RData =  {
			info:['count'=>count(),'page'=>(param.exists('page') ? Std.parseInt( param.get('page') ) : 1)],
			rows: doSelect()
		};
		S.sendData(dbData,rData);
	}
	
	public function execute(sql:String):NativeArray
	{
		trace(sql);	
		var stmt:PDOStatement =  S.dbh.prepare(sql);
		if (S.dbh.errorCode()!='00000')
		{
			trace(stmt.errorInfo());
			S.sendErrors(dbData, ['DB' => stmt.errorInfo]);
			return null;
		}		
		var bindTypes:String = '';
		var values2bind:NativeArray = null;
		//var dbFieldTypes:StringMap<String> =  Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject(S.conf.get('dbFieldTypes')));
		//trace(filterValues);
		var data:NativeArray = null;
		var success: Bool;
		if(filterValues.length > 0)
		{
			var i:Int = 0;
			for (fV in filterValues)
			{
				var type:Int = PDO.PARAM_STR; //dbFieldTypes.get(fV[0]);
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
			dbData.dataInfo['count'] = stmt.rowCount();
			if (dbData.dataInfo['count']>0)
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
				return Syntax.assocDecl({'error': stmt.errorInfo()});
			}
			//var result:EitherType<MySQLi_Result,Bool> = stmt.get_result();
			num_rows = stmt.rowCount();
			if (num_rows>0)
			{
				data = stmt.fetchAll(PDO.FETCH_ASSOC);				
			}			
			return(data);	
		}
		return Syntax.assocDecl({'error': stmt.errorInfo()});
	}
	
	public  function query(sql:String, ?resultType):NativeArray
	{
		if (resultType == null)
			resultType = PDO.FETCH_ASSOC;
		var stm:PDOStatement = S.dbh.query(sql);
		if (! untyped stm)
		{
			trace(S.dbh.errorInfo());
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
	
	public function update():NativeArray
	{	
		var sqlBf:StringBuf = new StringBuf();
		trace(queryFields);
		sqlBf.add('UPDATE ');
		if (tableNames.length>1)
		{
			sqlBf.add(joinSql);
		}		
		else
		{
			sqlBf.add('$tableNames[0] ');
		}
		if (filterSql != null)
		{
			sqlBf.add(filterSql);
		}		

		var limit:String = param.get('limit');
		buildLimit((limit == null?'25':limit), sqlBf);	//	TODO: CONFIG LIMIT DEFAULT
		trace(sqlBf.toString());
		//return null;
		return execute(sqlBf.toString());
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
		if ( ~/^([a-zA-Z_])[a-zA-Z0-9_\.=\/]+$/.match(f))
		{
			return f;
		}
		
		return '"$f"';
		//return S.dbh.quote(f);
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
		trace(param);
		data = {};
		data.rows = new NativeArray();
		dbData = new DbData();
		if (param.exists('qParam'))
		{
			var s:Serializer = new Serializer();
			qParam = s.unserialize(Bytes.ofString(param.get('qParam')),DbData);
			trace(qParam);
		}
		if (param.exists('filter'))
		{			
			filterValues = new Array();
		}

		if (param != null && param.get('fullReload') == 'true')
		{
			trace('fullReload');
			globals = {users: query("SELECT first_name, last_name, user_name, active, user_group FROM vicidial_users") };
		}
		
		if(table != null)
		fieldNames = S.tableFields(table);
		tableNames = [];
		var fields:Array<String> = [];
		//trace('>'+param.get('dataSource')+'<');
		if(param.get('dataSource') != null)
		{
			dataSource = Unserializer.run(param.get('dataSource'));
			trace(dataSource);
			var tnI:Iterator<String> = dataSource.keys();
			while(tnI.hasNext()) 
			{
				var tableName:String = quoteIdent(tnI.next());
				tableNames.push(tableName);
				var table:StringMap<String> = dataSource.get(tableName);
				trace('$table $tableName');
				if(table.exists('fields'))
					fields = fields.concat(buildFields(tableName, table));
			}
		}
		queryFields = fields.length > 0?fields.join(','):'*';		
		trace(queryFields);
		//trace(param.get('values'));
		joinSql = buildJoin();
		//trace(joinSql);
		filterSql = buildCond();
	}
	
	function buildFields(name:String, table:StringMap<String>):Array<String>
	{
		var prefix = (table.exists('alias')?quoteIdent(table.get('alias')):name);
		if (table.exists('fields'))
		{
			return table.get('fields').split(',').map(function(field) return '$prefix.${quoteIdent(field)}');
		}
		return [];
	}
	
	public function json_encode():Void
	{	
		data.user_name = S.user_name;
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
	
	function serializeRows(rows:NativeArray):Bytes
	{
		var s:Serializer = new Serializer();
		Syntax.foreach(rows, function(k:Int, v:Dynamic)
		{
			dbData.dataRows.push(Lib.hashOfAssociativeArray(v));
		});
		trace(dbData);
		return s.serialize(dbData);
	}
	
	function sendRows(rows:NativeArray):Bool
	{
		var s:Serializer = new Serializer();
		
		Syntax.foreach(rows, function(k:Int, v:Dynamic)
		{
			dbData.dataRows.push(Lib.hashOfAssociativeArray(v));			
		});
		Web.setHeader('Content-Type', 'text/html charset=utf-8');
		Web.setHeader("Access-Control-Allow-Headers", "access-control-allow-headers, access-control-allow-methods, access-control-allow-origin");
		Web.setHeader("Access-Control-Allow-Credentials", "true");
		Web.setHeader("Access-Control-Allow-Origin", "https://192.168.178.56:9000");
		var out = File.write("php://output", true);
		out.bigEndian = true;
		out.write(s.serialize(dbData));
		Sys.exit(0);
		return true;
	}
}