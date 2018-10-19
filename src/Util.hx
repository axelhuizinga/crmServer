package;
import haxe.ds.StringMap;
import hx.strings.RandomStrings;

/**
 * ...
 * @author axel@cunity.me
 */
class Util
{

	public static inline function any2bool(v:Dynamic) :Bool
	{
		return (v != null && v != 0 && v !='');
	}
	
	public static function copyStringMap<T>(source:StringMap<T>):StringMap<T>
	{
		var copy:StringMap<T> = new StringMap();
		var keys = source.keys();
		while (keys.hasNext())
		{
			var k:String = keys.next();
			copy.set(k, source.get(k));
		}
		return copy;
	}
	
	public static inline function randomString(length:Int, ?charactersToUse = "abcdefghijklmnopqrstuvwxyz$_§!%ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"):String
	{
		return RandomStrings.random(length,charactersToUse);
	}
}