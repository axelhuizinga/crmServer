package view;

import js.jquery.*;
import js.jquery.Helper.*;
using Lambda;
/**
 * ...
 * @author axel@cunity.me
 */

class Select extends Input
{

		
	public function new(data:Dynamic) 
	{
		super(data);
		//trace(data);
	}
	
	function addDataLoader():Void
	{
		if (vData.db)
		{
			parentView.addDataLoader(id, {
				callBack:update,
				prepare:function() {
					resetParams();
					if(vData.order != null)
						params.order = vData.order;	
					return params;
				},
				valid:false
			},parentView.dbLoaderIndex);
		}		
	}
	
	override private function resetParams(?where:Dynamic):Dynamic
	{
		params = {
			action:vData.action,
			className:name,
			dataType:'json',
			fields:[vData.value, vData.label].join(','),
			limit:vData.limit,
			table:vData.table
		};
		if (vData.where != null)
		{
			var whereCheck:Array<String> = vData.where.check;
			var whereParam:Array<String> = [];
			if (vData.check)
			{
				var checks:Array<{name:String, checked:Bool}> = vData.check;
				for (c in checks)
				{
					if( whereCheck.has(c.name))
						whereParam.push(c.name + "|" + (c.checked? "Y":"N" ));
				}
				if (whereParam.length > 0)
				params.where = whereParam.join(',');
			}			
		}
		//trace(params);	
		return params;
	}
	
	override public function update(data:Dynamic)
	{
		//trace(data);
		trace('#t-'+vData.name + ' appending2:' +  id);
		J('#t-'+vData.name).tmpl(data).appendTo(J('#'+id));
	}
	
}