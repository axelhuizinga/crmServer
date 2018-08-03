package;
import js.html.EventTarget;
import js.html.UIEvent;

/**
 * ...
 * @author axel@cunity.me
 */
class DataEvent extends UIEvent
{
	
	var data(default, null) : Dynamic;
	
	function new( type : String, canBubble : Bool = true, cancelable : Bool = true ) : Void
	{
		super(type, canBubble, cancelable);
	}
	
}