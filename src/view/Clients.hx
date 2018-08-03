package view;

/**
 * ...
 * @author axel@cunity.me
 */
import haxe.Timer;
import js.jquery.*;
import js.html.Element;
import js.html.Node;
import js.jquery.Helper.*;
import View;

using view.FormData;


typedef ClientsData =
{>ViewData,
	
	@:optional var limit:Int;
	@:optional var listattach2:String;
	@:optional var order:String;
	@:optional var table:String;
	@:optional var where:String;
};

@:keep class Clients extends View
{
	
	var listattach2:String;
	var edit:Editor;
	
	public function new(?data:ClientsData) 
	{
		super(data);
		//trace(data);
		listattach2 = data.listattach2;
		if (!(data.limit > 0))
			data.limit = 15;
		trace('#t-' + id + ' attach2:' + data.attach2 + ':' + dbLoaderIndex);

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
			
		addInteractionState('selected', { disables:['reload'], enables:['call','pay_plan', 'pay_source','pay_history','client_history','close','save'] } );
		addInteractionState('subScreenSaved', { enables:['reload'],disables:[] } );
		addInteractionState('init', { disables:['call','pay_plan', 'pay_source','pay_history','client_history','close','save','reload'], enables:[] } );
		edit = cast views.get(instancePath + '.' + id + '-editor');		
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
			jTarget.removeClass('selected');
		else
		{
			jTarget.siblings().removeClass('selected');	
			jTarget.addClass('selected');
			selectedID = jTarget.attr('id');
			trace(selectedID);
			edit.edit(jTarget);
		}
		
		if (jTarget.hasClass('selected'))
			interactionState = 'selected';
		else
			interactionState = 'init';
	}
	
	override public function update(data:Dynamic)
	{
		super.update(data);
		//trace(data);
		trace('#' + id + '-list tr[data-status]' + J('#' + id + '-list data-status').length);
		J('#' + id + '-list tr[data-status]').each(function(i:Int, n:Node)
		{
			//trace(i + ':' + J(n).data('status'));
			if (J(n).data('state') == 'passive')
				J(n).addClass('MPASS') ;
			else
				J(n).addClass(J(n).data('status')) ;
		});
		//	PREFIX T | K PRODUKT ID @ CLIENT_ID
		J('#' + id + '-list tr[data-entry_list_id]').each(function(i:Int, n:Node)
		{
			var entry_list_id:Int = J(n).data('entry_list_id');
			var prefix:String = (entry_list_id > 1900 && entry_list_id < 3000 ? 'T' : 'K');
			//trace(J(n).data('$entry_list_id => $prefix'));
			J(n).find('td[data-name="client_id"]').text(prefix + J(n).attr('id'));
		});
	}
}