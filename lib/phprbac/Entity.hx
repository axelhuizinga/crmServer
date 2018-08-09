package phprbac;
import haxe.extern.EitherType;

/**
 * ...
 * @author axel@bi4.me
 */

typedef EntityObj =
{
	Title:String,
	ID:Int,
	Depth:Int,
	Description:String
}

typedef NodeObj = 
{
	Title:String,
	Description:String,
	ID: Int
}

@:native('PhpRbac\\Rbac\\Entity')
extern class Entity 
{

	public function add(title:String, description:String, parentID:Int = null):Int;
	
	public function addPath(Path:String, Descriptions:Array<String> = null):Int;
	
	public function assign(Role:EitherType<Int,String>, Permission:EitherType<Int,String>):Bool;
	
	public function children(ID:Int):Array<Entity>;
	
	public function count():Int;
	
	public function depth(ID:Int):Int;
	
	public function descendants(ID:Int):Map<String, EntityObj>;
	
	public function edit(ID:Int, NewTitle:String = null, NewDescription:String = null):Bool;
	
	public function getDescription(ID:Int):String;
	
	public function getPath(ID:Int):String;
	
	public function getTitle(ID:Int):String;
	
	public function parentNode(ID:Int):Array<NodeObj>;
	
	public function pathId(Path:String):Int;
	
	public function returnId(EntityPathOrTitle:String):Int;
	
	public function titleId(Title:String):Int;
	
	public function unassign(Role:EitherType<Int,String>, Permission:EitherType<Int,String>):Bool;
	
	public function reset(Ensure:Bool = false):Int;
	
	public function resetAssignments(Ensure:Bool = false):Int;
		
}