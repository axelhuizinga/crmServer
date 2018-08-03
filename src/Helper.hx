package;

/**
 * ...
 * @author ...
 */
class Helper 
{

	public static inline function vsprintf(format:String, args:Array<Dynamic>):String
	{
		//trace(format);
		//trace(args);
		return (untyped __js__("vsprintf"))(format, args);
	}
	
}