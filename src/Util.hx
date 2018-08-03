package;
import haxe.ds.StringMap;

/**
 * ...
 * @author axel@cunity.me
 */
class Util
{

	public static inline function any2bool(v:Dynamic) :Bool
	{
		#if js
		//trace(untyped __js__("v?true:false"));
		//return (untyped __js__(true,v));
		//return (untyped __strict_neq__(v, true));
		return (v != null && v != 0 && v !='');
		#elseif php
		return (v != null && v != 0 && v !='');
		#end
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
}