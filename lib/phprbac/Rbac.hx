package phprbac;

/**
 * ...
 * @author axel@bi4.me
 */
//namespace PhpRbac;

//use \Jf;

extern class Role
{
	
}

extern class Permission
{
	
}

/**
 * @file
 * Provides NIST Level 2 Standard Role Based Access Control functionality
 *
 * @defgroup phprbac Rbac Functionality
 * @{
 * Documentation for all PhpRbac related functionality.
 */

@:native('PhpRbac\\Rbac')
extern class Rbac
{
	public var Roles:Roles;
	public var Permissions:Permissions;
	public var Users:Users;
	
    public function new(unit_test:String='') : Void;

    public function assign(role:Role, permission:Permission) : Void;

    public function check(permission:Permission, user_id:Int) : Void;

    public function enforce(permission:Permission, user_id:Int) : Void;

    public function reset(ensure:Bool=false) : Void;

    public function tablePrefix() : Void;
}

/** @} */ // End group phprbac */