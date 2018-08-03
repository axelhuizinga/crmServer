package model;
import haxe.ds.StringMap;


import me.cunity.php.db.MySQLi;
import me.cunity.php.db.MySQLi_Result;
import me.cunity.php.db.MySQLi_STMT;
import php.Lib;
import php.NativeArray;
import php.Web;

using Lambda;
/**
 * ...
 * @author axel@cunity.me
 */
class Input extends Model
{

/*override	public function execute(sql:String, param:StringMap<Dynamic>, ?placeholders:StringMap<Dynamic>):NativeArray
	{
		//trace(sql);
		//sql = S.my.real_escape_string(sql);
		trace(sql);	
		var stmt =  S.my.stmt_init();
		trace(stmt);
		var success:Bool = stmt.prepare(sql);
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
		var qVars:String = 'qVar_';
		var i:Int = 0;
		for (name in placeholders.keys())
		{
			bindTypes += dbFieldTypes.get(name);
			values2bind[i++] = placeholders.get(name);
		}
		
		trace(Std.string(values2bind));
		success = untyped __call__('myBindParam', stmt, values2bind, bindTypes);
		trace ('success:' + success);
		if (success)
		{
			var fieldNames:Array<String> =  param.get('fields').split(',');
			var data:NativeArray = null;
			success = stmt.execute();
			if (!success)
			{
				trace(stmt.error);
				return null;
			}
			var result:EitherType<MySQLi_Result,Bool> = stmt.get_result();
			if (result != false)
			{
				data = cast(result, MySQLi_Result).fetch_all(MySQLi.MYSQLI_ASSOC);
			}			
			return(data);		
		}
		else
			trace(stmt.error);
		return null;
	}
	
override	public function query(sql:String, ?placeholders:StringMap<Dynamic>):NativeArray
	{
		//trace(sql);
		trace(sql);
		var res:EitherType < MySQLi_Result, Bool > = S.my.query(sql, MySQLi.MYSQLI_ASSOC);
		if (res)
		{
			var data:NativeArray = cast(res, MySQLi_Result).fetch_all(MySQLi.MYSQLI_ASSOC);
			return(data);		
		}
		else
			trace(res + ':' + S.my.error);
		return null;
	}
	*/
	public function new() 
	{
		super();
	}
	
}