package;

/**
 * ...
 * @author axel@cunity.me
 */

import js.jquery.*;
import jQuery.JHelper.J;
//import js.JqueryUI;
import pushstate.PushState;
import me.cunity.debug.Out;

//using js.JqueryUI;

extern class Template
{

	/*public static function compile(template:String, data:Dynamic):String
	{
		trace(template + ':' + data);
		return ~/{([a-x]*)}/g.map(template, function(r:EReg)
		{
			var m:String = r.matched(1);
			var d:String = Std.string(Reflect.field(data, m));
			return Reflect.field(data, m);
		});
	}
	
	public static function include(template,ids:Array<String>):String
	{
		for (id in ids)
		{
			id = ~/[{}]/g.replace(id, '');
			trace(id);	
			var r:EReg = new EReg("{" + id + "}", "g");
			template = r.replace(template, J('#' + id).wrap('div').html());
		}

		return template;
	}*/
	
	public static function tmpl2(j:JQuery, data:Dynamic):JQuery;
	
}