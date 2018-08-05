package phprbac;
import haxe.extern.EitherType;

/**
 * ...
 * @author axel@bi4.me
 */
@:native('\\PhpRbac\\Rbac\\Users')
extern class Users 
{

	public function allRoles(UserID:Int = null):Array<Roles>;
	
	public function assign(Role:EitherType<Int,String>, UserID:Int = null):Bool;
	
	public function hasRole(Role:EitherType<Int,String>, UserID:Int = null):Bool;
	
	public function resetAssignments(Ensure:Bool = false):Int;
	
	public function roleCount(UserID:Int = null):Int;
	
	public function unassign(Role:EitherType<Int,String>, UserID:Int = null):Bool;
	
}