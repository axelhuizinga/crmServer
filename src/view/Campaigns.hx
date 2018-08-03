package view;

/**
 * ...
 * @author axel@cunity.me
 */

import js.jquery.*;
import js.html.Element;
import View;
import view.Select;
import js.jquery.Helper.*;

using Util;

typedef CampaignsData =
{>ViewData,	
	@:optional var limit:Int;
	@:optional var listattach2:String;
	@:optional var order:String;
	@:optional var select:Array<Dynamic>;
	@:optional var table:String;
	@:optional var where:String;
};
 
@:keep class Campaigns extends View
{
	var listattach2:String;
	
	public function new(?data:Dynamic) 
	{
		//trace(data);
		super(data);
		var campaignData:CampaignsData = cast data;
		listattach2 = campaignData.listattach2;
		if (!(data.limit > 0))
			data.limit = 15;
		trace('#t-' + id + ' attach2:' + data.attach2);
		J('#t-' + id).tmpl(data).appendTo(data.attach2);
		if(data.views != null)
			addViews(data.views);
		/*addInteractionState('init', { disables:['edit', 'delete'], enables:['add'] } );
		addInteractionState('edit', { disables:['add', 'delete'], enables:['save'] } );
		addInteractionState('selected', { disables:[], enables:['add', 'delete','edit'] } );
		addInteractionState('init', { disables:['edit', 'delete'], enables:['add'] } );*/
		init();
	}
	
	public function findLeads(where:String):Void
	{
		trace('|'+where+'|' + (where.any2bool() ? 'Y':'N'));
		trace(vData.where);
		var fData:Dynamic = { };
		var pkeys:Array<String> = 'className,fields,limit,order,where'.split(',');
		for (f in pkeys)
		{
			if (Reflect.field(vData, f) != null)		
			{
				if (f == 'where' && (where.any2bool() || 	vData.where.any2bool()))			
				{
					fData.where = (vData.where.any2bool() ? vData.where + (where.any2bool() ? ',' + where  : '') : where);
				}
				else
					Reflect.setField(fData, f, Reflect.field(vData, f));
			}
		}
		fData.action = 'findLeads';
		//trace(vData);
		resetParams(fData);
		//loadData('server.php', params, update);
		loadData('server.php', params, 		function(data:Dynamic)
				{ 
					data.loaderId = vData.listattach2; 
					update(data); 
					//loader.valid = true;
				});
	}
	
/*	public function load():Void
	{		
		trace('#t-' + id + ' attach2:' + data.attach2);
		J('#t-' + id).tmpl(data).appendTo(data.attach2);		
		if(vData.views != null)
			addViews(vData.views);		
			

	}	*/
	
}