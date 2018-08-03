package view;

/**
 * ...
 * @author axel@cunity.me
 */
import haxe.Timer;
import js.jquery.*;
import js.html.Element;
import js.jquery.Helper.*;
import view.Campaigns;

import View;

using view.FormData;


@:keep class QC extends View
{
	
	var listattach2:String;
	var edit:Editor;
	
	public function new(?data:CampaignsData) 
	{
		super(data);
		addInteractionState('init', { disables:['call','close','save','qcok','qcbad'], enables:['find'] } );
		//addInteractionState('edit', { disables:['add', 'delete'], enables:['save'] } );
		addInteractionState('selected', { disables:[], enables:['call','close','save','qcok','qcbad'] } );
		addInteractionState('call', { disables:['close' ], enables:['call','save','qcok','qcbad'] } );		
		//trace(data);
		listattach2 = data.listattach2;
		if (!(data.limit > 0))
			data.limit = 15;
		trace('#t-' + id + ' attach2:' + data.attach2 + ':' + dbLoaderIndex);
		
		//trace(J('#t-' + id));
		//trace(J('#t-' + id).tmpl(data));	
		J('#t-' + id).tmpl(data).appendTo(data.attach2);	
		if (data.table != null)
		{
			parentView.addDataLoader(listattach2, {
				callBack:update,
				prepare:function() {
					resetParams();
					if(vData.order != null)
						params.order = vData.order;							
					return params;
				},
				valid:false
			},dbLoaderIndex);
		}
		if(data.views != null)
			addViews(data.views);
		try{			
			edit = cast views.get(instancePath + '.' + id + '-editor');		
		}
		catch (ex:Dynamic)
		{
			trace(ex);
		}
		trace('found editor:' + instancePath + '.' +  id + '-editor :' + edit.vData.id);			
		init();
	}
	
	override public function select(evt:Event):Void
	{
		evt.preventDefault();
		trace(J(cast evt.target).get()[0].nodeName);
		if (App.ist.ctrlPressed)
			trace('ctrlPressed');
		var jTarget = J(cast evt.target).parent();
		if (jTarget.hasClass('selected'))
		{
			wait(false);
			jTarget.removeClass('selected');
		}
		else
		{
			jTarget.siblings().removeClass('selected');	
			jTarget.addClass('selected');
			wait();
			edit.edit(jTarget);
		}
		
		if (jTarget.hasClass('selected'))
			interactionState = 'selected';
		else
			interactionState = 'init';
	}
	
	/*override public function update(data:Dynamic):Void
	{
		super.update(data);
		trace(data.count);
		if (App.limit < data.count)
		{
			//CREATE PAGER
			var pager:Pager = new Pager({
				count:data.count,
				id:vData.id,
				page:data.page,
				parentView:this
			});
		}
	}*/
}