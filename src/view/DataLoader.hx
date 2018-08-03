package view;

/**
 * ...
 * @author axel@cunity.me
 */
class DataLoader
{
	var callBack:Dynamic->Void;
	var prepare:Void->Void;
	var loaded:Bool;

	public function new(cB:Dynamic->Void, pre:Void->Dynaic) 
	{
		callBack = cB;
		prepare = pre;
		loaded = false;
	}
	
	public function load()
	{
		prepare();
	}
	
}