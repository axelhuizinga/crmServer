package phprbac;
import haxe.extern.EitherType;

/**
 * ...
 * @author axel@bi4.me
 */
@:native('PhpRbac\\Rbac\\Roles')
extern class Roles extends Entity
{

	public function hasPermission(role:Int, permission:Int):Bool;
	
	public function permissions(role:Int, onlyIDs:Bool = true):EitherType <Array<Int>, Array<Array<Dynamic>>>;
	
	public function remove(id:Int, recursive:Bool = false):Int;
	
	public function unassignPermission(id:Int):Int;
	
	public function unassignUsers(id:Int):Int;
	
}