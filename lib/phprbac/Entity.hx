package phprbac;

/**
 * ...
 * @author axel@bi4.me
 */
@:native('\\PhpRbac\\Rbac\\Entity')
extern class Entity 
{

	public function add(title:String, description:String, parentID:Int = null):Int;
	
	public function addPath():Int;
	
}