package view;
import haxe.ds.StringMap;
import php.net.Socket;
import haxe.Timer;
//import FormData.FData;
import js.jquery.*;
import js.html.Element;
import js.html.HtmlElement;
import js.html.Node;
//import js.jquery.Helper.*;
import me.cunity.debug.Out;
import View;

using Lambda;

//typedef Accordion = Dynamic;

typedef MenuItem =
{
	var link:String;
	var action:Event->Void;
}

typedef ContextMenuData = 
{>ViewData,
	var context:String;
	var items:Array<Dynamic>;
	var tableData:StringMap<Array<String>>;
	@:optional var heightStyle:String;
}

/**
 * ...
 * @author axel@cunity.me
 */

@:keep class AppTest
{
	var accordion:JQuery;
	var contextData:ContextMenuData;
	var action:String;
	public var active(get,set):Int;
	public var activePanel:JQuery;
	
	public static function main()
	{
		trace(new());
	}
	
	public function new(?data:Dynamic) 
	{
		super(data);
		parentView.contextMenu = this;
		contextData = cast data;
		contextData.tableData = new StringMap();
		trace(id+ ' heightStyle:' + contextData.heightStyle + ' attach2:' + data.attach2);
		if (contextData.heightStyle == null)
			contextData.heightStyle = 'auto';
		//Out.dumpObjectTree(data);
		//trace(data);
		data.optionsMap = App.ist.globals.optionsMap.h;
		data.typeMap = App.ist.globals.typeMap.h;
		if (id == 'qc-menu')
		{
			data.optionsMap.owner = App.ist.prepareAgentMap();
			data.typeMap.owner = 'SELECT';
		}
		else
		data.optionsMap.agent = App.ist.prepareAgentMap();
		//{ agent:App.ist.prepareAgentMap() };
		//trace(data.optionsMap);
		var tmp = JQuery('#t-' + id).tmpl(data);// .appendTo(JQuery(data.attach2)) ;
		//trace('OK:' + tmp.html());
		tmp.appendTo(JQuery(data.attach2)) ;
		//JQuery('#t-' + id).tmpl(data).appendTo(JQuery(data.attach2)) ;
		createInputs();
		active = 0;
		trace(active);
		root = JQuery('#' + id).accordion( 
		{ 
			active:0,
			activate:activate,	
			"autoHeight": false,
			beforeActivate:function(event:Event, ui) {
				if(root.data('disabled'))
				{
					event.preventDefault();
				}
				else
				{					
					activePanel = JQuery(ui.newPanel[0]);
				}
			},
			create:create,
			fillSpace: true,
			heightStyle:contextData.heightStyle
		});
		accordion = root.accordion('instance');
		//trace(accordion);
		//active = 0;
		trace(JQuery('#' + id).find('.datepicker').length );
		JQuery('#' + id).find('.datepicker').datepicker( { 
			beforeShow: function(el, ui) {
				var jq:JQuery = JQuery(el);  
				if(jq.val()=='')
					jq.val(jq.attr('placeholder'));
			}
		});		
		JQuery('#' + id + ' button[data-contextaction]').click(run);
		init();
	}
	
	public function get_active():Int
	{
		trace(root.accordion('option', 'active'));
		return cast(root.accordion('option', 'active'),Int);
	}
	
	public function set_active(act:Int):Int
	{
		trace(active + ' => ' + act);
		root.accordion('option','active', act);
		//root.data('disabled', 1);
		return act;
	}
	
	function activate( event:Event, ui ) 
	{
		//trace(ui);
		action = JQuery(ui.newPanel[0]).find('input[name="action"]').first().val();
		active = getIndexOf(action);
		//activePanel = parentView.root.find('.ui-accordion-content [style^="display: block"]');// JQuery(ui.newPanel[0]);
		//activePanel = JQuery(ui.newPanel[0]);
		trace(action + ':' + activePanel.attr('id') + ' == ' + JQuery(ui.newPanel[0]).attr('id'));
	}
	

	public function call(editor:Editor, ?onComplete:Void->Void)
	{
		trace('parentView.interactionState:' + parentView.interactionState + ' agent:' + editor.agent + ' editor.leadID:' + editor.leadID);
		if (parentView.interactionState == 'call')
		{// HANG UP
			hangup(editor, onComplete);
			return;
		}//DO CALL
		var p:Dynamic = 
		{
			className:'AgcApi',
			action:'external_dial',
			lead_id:editor.leadID,
			agent_user:editor.agent
		};
		//parentView.interactionState = 'call'; activePanel.find('button[data-contextaction="call"]').html('Auflegen');return;
		parentView.loadData('server.php', p, function(data:Dynamic) { 
			trace(data);
			if (data.response == 'OK') {
				trace('OK');// ACTIVE CALL
				//parentView.vData.call = 1;
				parentView.interactionState = 'call';
				trace(activePanel.find('button[data-contextaction="call"]').length);
				activePanel.find('button[data-contextaction="call"]').html('Auflegen');
			}
		});										
	}	
	
	function createInputs():Void
	{
		var cData:ContextMenuData = cast vData;
		//var i:Int = 0;
		for (aI in cData.items)
		{
			//trace(aI.Select);
			//TODO: USE REFLECTION TO ITERATE ALL FIELDS AND CREATE MATCHING INPUT CLASS
			if (aI.Select != null)
			{
				/*var aiS:Array<Dynamic> = aI.Select;
				aiS.iter(function(sel:Dynamic) sel.action = aI.action);*/
				//trace(aI.Select);
				addInputs(aI.Select, 'Select');
			}
		}
		//trace(cData);
	}	
	
	function create( event:Event, ui ) 
	{ 	
		action = JQuery(ui.panel[0]).find('input[name="action"]').first().val();
		if(ui.panel.length>0)
		activePanel = JQuery(ui.panel[0]);
		trace(action);
	}
	
	public function getIndexOf(act:String):Int
	{
		var index:Int = null;
		contextData.items.mapi(function(i:Int,  item:Dynamic):Dynamic
		{
			if (item.action == act)
			{
				trace(i + ':' + act);
				index = i;		
			}
			return item;
		});
		trace(index);
		return index;
	}
	
	public function hangup(editor:Editor, ?onCompletion:Void->Void )
	{	
		trace('OK');
		var p:Dynamic = 
		{
			className:'AgcApi',
			action:'update_fields_x',
			lead_id:editor.leadID,
			//agent_user:editor.agent,
			state:''
		};
		
		parentView.loadData('server.php', p, function(data:Dynamic) { 
			//trace(data);
			if (data.response == 'OK') 
			{//state CLEARED
				trace('OK state CLEARED');		
				p = {
					className:'AgcApi',
					action:'external_hangup',
					lead_id:editor.leadID,
					agent_user:editor.agent
				};		
				
				parentView.loadData('server.php', p, function(data:Dynamic) { 
					//trace(data);
					if (data.response == 'OK') 
					{//HUNG UP - SET DISPO STATUS
						trace('OK');		
						//trace(data.choice);	
						setCallStatus(editor, onCompletion);
						//SHOW DISPO CHOICE DIALOG
						//parentView.interactionState = 'init';
					}
					else
					{
						App.choice( { header:data.response, id:parentView.id } );
					}
				});
			}
			else
			{
				App.choice( { header:data.response, id:parentView.id } );
			}	
		});
	}
	
	public function layout()
	{
		var maxWidth:Float = 0;
		var maxHeight:Float = 0;
		var jP:Array<HtmlElement> = accordion.panels;
		var p:Int = 0;
		for (p in 0...jP.length)
		{
			var jEl:JQuery = JQuery(jP[p]);
			if (p != active)
				jEl.css('visibility', 'hidden').show();
			maxWidth =   Math.max(jEl.width(), maxWidth);
			maxHeight = Math.max(jEl.height(), maxHeight);
			if (p != active)
				jEl.hide(0).css('visibility','visible');
		}
		root.find('table').width(maxWidth);
		root.accordion("option", "active", active);
	}
	
	public function findPage(page:String, limit:String)
	{
		action = 'find';
		var items:Array<Dynamic> = vData.items;
		//trace(items);
		items.mapi(function(i:Int, item:Dynamic) {if (item.action == action){ active = i; } return item;});
		trace(action + ':' + active);
		var findFields:Array<String> = vData.items[active].fields;		
		trace(findFields);
		if (findFields != null && findFields.length > 0)/*READ FIND FORM*/
		{
			var tables:Iterator<String> = contextData.tableData.keys();
			var tableNames:Array<String> = new Array();
			while (tables.hasNext())
			{
				var table:String = tables.next();
				tableNames.push(table);
				trace(table);
				//fields = fields.concat(contextData.tableData.get(table));// .map(function(f:String) return table + '.' + f));
			}					
			var form:JQuery = JQuery('#' + parentView.id + '-menu .ui-accordion-content-active form');
			var where:String = FormData.where(form, findFields);
			trace(where);
			var wM:StringMap<String> = new StringMap();
			//for (tn in tableNames)
				//wM.set(tn, contextData.tableData.get(tn).toString());
			wM.set('filter', FormData.filter(form, contextData.tableData, tableNames));
			wM.set('filter_tables', tableNames.join(','));
			wM.set('where', where);
			wM.set('limit', limit);
			wM.set('page', page);
			trace(wM);
			parentView.find(wM);
			//Reflect.callMethod(parentView, Reflect.field(parentView, action), [wM]);			
		}
	}
	
	public function run(evt:Event)
	{
		evt.preventDefault();
		
		//var options =  cast root.accordion( "option");
		//var active:Int = get_active();
		var jNode:JQuery = JQuery(cast( evt.target, Node));
		action = vData.items[active].action;
		trace( action + ':' + active); 		
		var contextAction = jNode.data('contextaction');
		//action = JQuery( evt.target).data('action');
		trace(action + ':' + contextAction);
		switch(action)
		{
			case 'find':
				var fields:Array<String> = vData.items[active].fields;
				
				if (fields != null && fields.length > 0)/*READ FIND FORM*/
				{
					var tables:Iterator<String> = contextData.tableData.keys();
					var tableNames:Array<String> = new Array();
					while (tables.hasNext())
					{
						var table:String = tables.next();
						tableNames.push(table);
						trace(table);
						//fields = fields.concat(contextData.tableData.get(table));// .map(function(f:String) return table + '.' + f));
					}					
					//var where:String = FormData.where(JQuery(cast( evt.target, Element)).parent(), fields);
					var where:String = FormData.where(jNode.closest('form'), fields);
					trace(where);
					var wM:StringMap<String> = new StringMap();
					//for (tn in tableNames)
						//wM.set(tn, contextData.tableData.get(tn).toString());
					wM.set('filter', FormData.filter(jNode.closest('form'), contextData.tableData, tableNames));
					wM.set('filter_tables', tableNames.join(','));
					wM.set('where', where);
					parentView.find(wM);
					//Reflect.callMethod(parentView, Reflect.field(parentView, action), [wM]);			
				}	
			case 'edit':
				var editor:Editor = cast(parentView.views.get(parentView.instancePath + '.' + parentView.id + '-editor'), Editor);
				editor.contextAction(contextAction);				
			case 'mailings':
				var mailing:Mailing = cast(parentView.views.get(parentView.instancePath + '.' + parentView.id + '-mailing'), Mailing);
				trace(contextAction);
				switch(contextAction)
				{
					case 'printNewInfos':
						mailing.printNewInfos(jNode.closest('div').attr('id'));
					case 'printList':
						mailing.printList(jNode.closest('div').attr('id'));
					case 'printNewMembers':
						mailing.printNewMembers(jNode.closest('div').attr('id'));
					default:
						trace(contextAction);
				}
			default:
				trace(action + ':' + contextAction);
		}
	}
	
	public function setCallStatus(editor:Editor, ?onCompletion:Void->Void )
	{
		trace(editor.action + ':' + onCompletion);
		var p:Dynamic = {
			className:'AgcApi',
			action:'external_status',
			dispo:switch(editor.action)
			{
				case 'call', 'save'://HANGUP OR SAVE => QCOPEN
				'QCOPEN';
				default:
				editor.action.toUpperCase();
			},
			agent_user:editor.agent
		};
		parentView.loadData('server.php', p, function(data:Dynamic) { 
			trace(data);
			if (data.response == 'OK')		
			{
				
				if (onCompletion != null)
					onCompletion();
				else
					parentView.interactionState = 'init';
			}
			else
				App.choice( { header:data.response, id:parentView.id } );
		});
				
	}
	
	override function initState():Void
	{
		super.initState();
		trace(id + ':' + root.find('tr[data-table]').length);
		layout();
		root.find('tr[data-table]').each(function(i:Int, n:Node)
		{
			var table:String = JQuery(n).data('table');
			if (!contextData.tableData.exists(table))
			{
				contextData.tableData.set(table, new Array());
			}
			//vData.fields.push();
		});
		
		var tables:Iterator<String> = contextData.tableData.keys();
		while (tables.hasNext())
		{
			var table:String = tables.next();
			trace(table);
			JQuery('tr[data-table^=' + table+'] input').each(function(_, inp) {
				if(JQuery(inp).attr('name').indexOf('_match_option')==-1)
					contextData.tableData.get(table).push(JQuery(inp).attr('name'));
			});
			JQuery('tr[data-table^=' + table+'] select').each(function(_, inp) {
				contextData.tableData.get(table).push(JQuery(inp).attr('name'));
			});
		}		
		trace(contextData.tableData.toString());		
	}
}