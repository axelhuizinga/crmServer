package view;
import haxe.Timer;
import js.jquery.*;
import js.html.XMLHttpRequest;

/**
 * ...
 * @author axel@cunity.me
 */

using Lambda;

class Input
{
	var vData:Dynamic;
	var params:Dynamic;
	public var name:String;
	public var id:String;
	public var loading:Int;
	public var parentView:View;
	public var hasData:Bool;
	
	public function new(data:Dynamic) 
	{
		if (!(data.limit > 0))
			data.limit = 15;
		vData = data;
		hasData = data.db;
		parentView = data.parentView;
		name = Type.getClassName(Type.getClass(this)).split('.').pop();
		id = parentView.id + '_' + data.name ;
		loading = 0;	
	}	
	
	public function init()
	{
		if (hasData)
		{
			loadData( resetParams(), function(data:Dynamic) { 
				//data.parentSelector = listattach2; 
			update(data); } );		
		}
	}
	
	function loadData(data:Dynamic, callBack:Dynamic->Void)
	{
		var dependsOn:Array<String> = vData.dependsOn;
		if (dependsOn != null && dependsOn.length > 0)
		{
			if (! dependsOn.foreach(function(s:String) return parentView.inputs.exists(s) && parentView.inputs.get(s).loading == 0))
			{
				trace(id + ' still waiting on:' + dependsOn.toString());
				var iK:Iterator<String> = parentView.inputs.keys();
				var ki:String = '';
				while (iK.hasNext())
					ki += iK.next() + ',';
				//trace('inputs:' + ki);
				//Timer.delay(function() loadData(data, callBack), 1000);
				return;
			}
		}
		trace(id);
		//trace(data);
		//return;
		loading++;
		js.jquery.JQuery.post('server.php', data , function(data:Dynamic, textStatus:String, xhr:XMLHttpRequest)
		{
			//trace(data);
			callBack(data);
			loading--;
		});	
	}

	private function resetParams(?where:Dynamic):Dynamic
	{
		params = {
			action:vData.action,
			className:name,
			dataType:'json',
			fields:[vData.value, vData.label].join(','),
			limit:vData.limit,
			table:vData.name
		};
		if (where != null)
			params.where = where;
		return params;
	}
	
	public function update(data:Dynamic)
	{
		trace('method has to be implemented by subclass');
	}	
}