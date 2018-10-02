package;
import haxe.ds.StringMap;
import php.Lib;
import php.Syntax;
import php.Web;
import sys.FileSystem;
import sys.io.File;
import tjson.TJSON;
//import me.cunity.php.Services_JSON;
import StringTools;
using StringTools;
/**
 * ...
 * @author axel@cunity.me
 */
class Config
{
	public static function load(cjs:String) :StringMap<Dynamic>
	{
		var js:String = File.getContent(cjs);
		//Syntax.("file_get_contents", cjs);
		//trace(js);
		var vars:Array<String> = js.split('var');
		vars.shift();
		var result:StringMap<Dynamic> = new StringMap();
		//trace(vars.length);
		for (v in vars)
		{
			var data:Array<String> = v.split('=');
			var json:Dynamic = TJSON.parse(data[1]);
			result.set(data[0].trim(), json);
		}		
		return result;
	}
	
}