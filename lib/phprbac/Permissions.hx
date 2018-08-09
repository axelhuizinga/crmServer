package phprbac;
import haxe.extern.EitherType;

/**
 * ...
 * @author axel@bi4.me
 */
@:native('PhpRbac\\Rbac\\Permissions')
extern class Permissions extends Entity 
{

	public function remove(ID:Int, Recursive:Bool = false):Bool;
	
	public function roles(Permission:EitherType<Int,String>, OnlyIDs:Bool = true):EitherType < Array<Int>, Array<Array<Dynamic>> > ;

	public function unassignRoles(ID:Int):Int;
	
}