package model;

import haxe.extern.EitherType;
import haxe.ds.StringMap;
//import model.Users;
import php.Lib;

/**
 * ...
 * @author ...
 */
class App extends Model
{

	public static function create(param:StringMap<String>):Void
	{
		return untyped __call__("json_encode", new App(param).getGlobals(), 64|256);//JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE
	}
	
	public function getGlobals():Dynamic
	{
		var fieldNames:StringMap<String> = new StringMap();
		var typeMap:StringMap<String> = new StringMap();
		var optionsMap:StringMap<String> = new StringMap();		
		
		var eF:StringMap<Array<StringMap<String>>> = getEditorFields();
		//trace(eF);
		var keys:Iterator<String> = eF.keys();		
		var tableNames:Array<String> = new Array();
		var tableFields:StringMap<Array<String>> = new StringMap();
		
		trace(param);
		while (keys.hasNext())
		{
			var k:String = keys.next();
			//trace(k);
			tableNames.push(k);
			var aFields:Array<StringMap<String>> = eF.get(k);
			//trace(aFields);
			var cFields:Array<String> = aFields.map(function(field:StringMap<String>):String return field.get('field_label'));
			//trace(cFields);
			tableFields.set(k, cFields);
			for (f in 0...cFields.length)
			{
				fieldNames.set(cFields[f], aFields[f].get('field_name'));					
				if (aFields[f].get('field_options') != null)
					optionsMap.set(cFields[f], aFields[f].get('field_options'));
				typeMap.set(cFields[f], aFields[f].get('field_type'));
			}			
		}
		var me:VicidialUsers = new VicidialUsers(param);
		me.get_info();
		var data:Dynamic = 
		{ 
			fieldNames:Lib.associativeArrayOfHash(fieldNames),
			userMap: me.globals,
			optionsMap: optionsMap,
			typeMap: typeMap,
			limit:untyped S.conf.get('sql')['LIMIT']
		}
		return data;
	}
	
}