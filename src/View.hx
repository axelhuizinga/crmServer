package;
import haxe.ds.ObjectMap;
import haxe.ds.StringMap;
import view.Pager;

import haxe.Timer;
import js.Browser;
import js.html.Element;
import js.jquery.*;
import js.html.Node;
import js.html.Rect;
import js.html.XMLHttpRequest;
import me.cunity.util.Data;
import view.ContextMenu;
import view.Input;
import view.TabBox;
import js.jquery.Helper.*;
import me.cunity.debug.Out;


using Lambda;
using Util;
using me.cunity.util.Data;

/**
 * ...
 * @author axel@cunity.me
 */

typedef  InteractionState =
{
	var disables:Array<String>;
	var enables:Array<String>;
}

typedef   ViewData = 
{
	var action:String;
	var attach2:String;
	var id:String;
	var dbLoaderIndex:Int;
	@:optional var fields:Array<String>;
	@:optional var hidden:String;
	@:optional var parent: String;
	@:optional var primary_id: String;
	@:optional var parentTab: Int;
	@:optional var parentView: View;
	@:optional var views:Array<ViewData>;
}

typedef DataLoader = 
{
	var callBack:Dynamic->Void;
	var prepare:Void->Dynamic;
	var valid:Bool;
}

class View
{
	var attach2:String; // parentSelector
	var fields:Array<String>;
	var primary_id:String;
	var repaint:Bool;
	var name:String;
	var root:JQuery;
	var vData:Dynamic;
	var template:JQuery;
	var spinner:Dynamic;
	var waiting:Timer;
	var parentView:View;	
	var parentTab:Int;
	var params:Dynamic;	
	var loading:Int;
	var listening:ObjectMap<JQuery,String>;
	var suspended:StringMap<JQuery>;
	var interactionStates:StringMap<InteractionState>;
	var dbLoader:Array<StringMap<DataLoader>>;// DATALOADER MAP
	var templ:JQuery;
	
	public var dbLoaderIndex:Int;
	public var contextMenu:ContextMenu;	
	public var id:String;	
	public var instancePath:String;	
	public var interactionState(default, set):String;
	public var inputs:StringMap<Input>;	
	public var selectedID:String;
	public var lastFindParam:StringMap<String>;
	public var reloadID:String;
	public var views(default, null):StringMap<View>;
	
			
	public function new(?data:Dynamic ) 
	{
		views = new StringMap();		
		//views = App.getViews();
		inputs = new StringMap();
		vData = data;
		var data:ViewData = cast data;
		id = data.id;
		//parentTab = data.parentTab;
		parentView = data.parentView;
		primary_id = data.primary_id;
		if (parentView == null)
		{
			instancePath = App.appName + '.' + id;
		}
		else
		{
			instancePath = parentView.instancePath + '.' + id;
		}
		dbLoader = new Array();
		dbLoaderIndex = (data.dbLoaderIndex == null ? 0:data.dbLoaderIndex);
		if (Std.instance(this, TabBox) == null)
			dbLoader.push(new StringMap());
		attach2 = data.attach2 == null ? '#' + id : data.attach2;
		name = Type.getClassName(Type.getClass(this)).split('.').pop();
		root = J('#' + id).css({opacity:0});
		trace(name + ':'  + id + ':' + root.length + ':' + J(attach2).attr('id') + ':' + dbLoaderIndex); 		
		interactionStates = new StringMap();
		listening = new ObjectMap();
		suspended = new StringMap();
	}
	
	function init()
	{
		loading = 0;
		if (loadingComplete())
			initState();
		else
			Timer.delay(initState, 1000);
	}
	
	public function set_interactionState(iState:String):String
	{
		interactionState = iState;
		var iS:InteractionState = interactionStates.get(iState);
		trace(id + ':' + iState + ':' + iS);
		if (iS == null)
			return null;
		var lIt:Iterator<JQuery> = listening.keys();
		while (lIt.hasNext())
		{
			var aListener:JQuery = lIt.next();
			var aAction:String = listening.get(aListener);
			//trace(aAction + ':' + aListener.data());
			if (iS.disables.has(aAction))
			{				
				aListener.prop('disabled', true);
				//trace(aListener.data());
			}
			if (iS.enables.has(aAction))
				aListener.prop('disabled', false);
			//trace(aListener.closest('.tabContent').attr('id') + ':' + aAction + ' disabled:' + (aListener.prop('disabled') ? 'Y':'N'));
		}
		trace(iState);
		return iState;
	}
	
	function addInteractionState(name:String, iS:InteractionState):Void
	{
		trace(id + ':' + name + ':' + iS);
		interactionStates.set(name, iS);
	}
	
	function addInputs(v:Array<Dynamic>, className:String):Void
	{
		//trace(v.length);
		for (aI in v)
		{
			aI.parentView = this;
			aI.id = id + '_' + aI.name;
			addInput(aI, className);
		}
	}
	
	function addInput(v:Dynamic, className:String):Input
	{
		var aI:Input = null;
		
		var iParam:Dynamic = v;
		trace(className + ':' + iParam.id);
		var cl:Class<Dynamic> = Type.resolveClass('view.' + className);
		if (cl != null)
		{
			//trace(cl);
			if (Reflect.hasField(v, 'attach2'))
				iParam.attach2 = v.attach2;
			iParam.parentView = this;
			//trace(Std.string(iParam));
			aI = Type.createInstance(cl, [iParam]);
			inputs.set(iParam.id, aI);				
			//trace("inputs.set(" +iParam.id +")");
			if (iParam.db == 1)
				aI.init();
		}		
		return aI;
	}
	
	public function addListener(jListener:JQuery)
	{
		jListener.each(function(i, n)
		{
			//trace(id + ':' + n + ':' + J(n).data('contextaction'));
			listening.set(J(n), J(n).data('contextaction'));
		});
	}
	
	@:expose
	public function addView(v:ViewData):View
	{
		var av:View = null;
		var className:String = Reflect.fields(v)[0];
		var iParam:Dynamic = Reflect.field(v, className);
		trace(name + ':' + className + ':' + dbLoader.length);
		//trace(className + ':' + iParam);
		var cl:Class<Dynamic> = Type.resolveClass('view.' + className);
		if (cl != null)
		{
			trace(cl);
			if (Reflect.hasField(v, 'attach2'))
				iParam.attach2 = v.attach2;
			if (Reflect.hasField(v, 'dbLoaderIndex'))
				iParam.dbLoaderIndex = v.dbLoaderIndex;				
			iParam.parentView = this;
			//trace(Std.string(iParam));
			av = Type.createInstance(cl, [iParam]);
			views.set(av.instancePath, av);				
			trace("views.set(" +av.instancePath +")");
			//views.set(iParam.id, av);				
			//trace("views.set(" +iParam.id +")");
		}		
		return av;
	}
	
	public function addViews(v2add:Array<ViewData>):Void
	{
		for (vD in v2add)
		{
			vD.parentView = this;
			addView(vD);
		}
		
	}
	
	function initState():Void
	{
		trace (id +':' + (loadingComplete() ? 'Y':'N') + ' :' + J('button[data-contextaction]').length);	
		if (!loadingComplete())
		{			
			Timer.delay(initState, 1000);
			return;
		}
		addListener(J('#$id button[data-contextaction]'));
		interactionState = 'init';
		J('td').attr('tabindex', -1);
		var el:Element = cast J('#' + id).get()[0];
		trace(id + ' initState complete - we can show up :)' + ':' + el);
		//trace(J('#' + id).find('.datepicker').length);
		J('#' + id).animate( { opacity:1 }, 300, 'linear', 
			function() { 
			//trace(untyped __js__("this"));
			//trace(J(untyped __js__("this")).attr('id')); 			
			});
	}
	
	function loadingComplete():Bool
	{
		//trace (loading);return true;
		if (loading > 0)
			return false;
		if (!inputs.empty() && !inputs.foreach(function(i:Input) return i.loading == 0))
			return false;
		else
			return views.foreach(function(v:View) return v.loading == 0);
		return true;
	}
	
	function suspendAll()
	{
		
	}
	
	public function addDataLoader(loaderId:String, dL:DataLoader, loaderIndex:Int=0)
	{
		dbLoader[loaderIndex].set(loaderId, dL);
		trace(id + ':' + loaderIndex + ':' + loaderId);
	}
	
	public function loadAllData(?loaderIndex:Int = 0):Void
	{// 	INITIAL LOAD DB DATA

		var dLoader:StringMap<DataLoader> = dbLoader[loaderIndex];
		var keys:Iterator<String> = dLoader.keys();
		trace(dLoader.count() + ':' + loaderIndex);
		for (k in keys)
		{
			trace(k);
			load(k, loaderIndex);
		}
	}
	
	public function load(loaderId:String, loaderIndex:Int = 0):Void
	{
		//INITIAL LOAD DB DATA
		var loader:DataLoader = dbLoader[loaderIndex].get(loaderId);
		if(!loader.valid)
			loadData('server.php', loader.prepare(), 
				function(data:Dynamic)
				{ 
					data.loaderId = loaderId; 
					trace(id + ':' + data.fields + ':' + data.loaderId);
					loader.callBack(data); 
					loader.valid = true;
				});		
	}
	
	public function loadData(url:String, p:Dynamic, callBack:Dynamic->Void):Void
	{
		//trace(Std.string(p));
		loading++;
		js.jquery.JQuery.post(url, p , function(data:Dynamic, textStatus:String, xhr:XMLHttpRequest)
		{
			//trace(data);
			callBack(data);
			loading--;
		}, 'json');
	}
	
	public function find(p:StringMap<String>):Void
	{
		lastFindParam = p.copy();
		//trace(p);
		//trace(lastFindParam);
		var where:String = p.get('where');
		//trace(id + '|'+where+'|' + (where.any2bool() ? 'Y':'N'));
		//trace(vData.where);
		var fData:Dynamic = { };
		var pkeys:Array<String> = 'action,className,fields,primary_id,hidden,limit,order,page,pay_source,filter_tables,table,where,filter'.split(',');
		for (f in pkeys)
		{
			if (Reflect.field(vData, f) != null)		
			{
				if (f == 'where' && (where.any2bool() || vData.where.any2bool()))			
				{
					fData.where = (vData.where.any2bool() ? vData.where + (where.any2bool() ? ',' + where  : '') : where);
				}
				else
					Reflect.setField(fData, f, p.exists(f) ? p.get(f) : Reflect.field(vData, f));
			}
			if (f != 'where' && p.exists(f))
				Reflect.setField(fData, f, p.get(f));
		}
		
		//trace(vData);
		resetParams(fData);
		loadData('server.php', params, update);
	}
	
	public function order(j:JQuery):Void
	{
		if (params.order.indexOf(j.data('order')) == 0)//	CHANGE DIRECTION OF CURRENT ORDER BY FIELD
			params.order = j.data('order') + (params.order.indexOf( 'ASC') >0  ?  '|DESC' : '|ASC');
		else
			params.order = j.data('order') + '|ASC';		
		//trace( params.order);
		wait();
		loadData('server.php', params, update);
	}	
	
	private function resetParams(?pData:Dynamic):Dynamic
	{		
		var pkeys:Array<String> = 'action,className,fields,limit,order,page,table,jointable,filter_tables,pay_source,joincond,joinfields,where,filter'.split(',');
		//var aData:Dynamic = pData.any2bool() ? pData : vData;
		//MERGE pData into vData
		//trace(pData);
		var aData:Dynamic = vData.copy();
		if (pData != null)
		{
			var pFields:Array<String> = Reflect.fields(pData);
			for (f in pFields)
				Reflect.setField(aData, f, Reflect.field(pData, f));
		}
		fields = aData.fields.any2bool()?aData.fields.split(','):null;
		//trace(fields);
		//trace(aData.hidden);
		//trace(aData.joincond);
		var order:String = (params == null ? null : params.order);
		params = {
			action:'find',
			firstLoad:App.ist.globals.firstLoad,
			className:name,
			instancePath:instancePath
		};
		App.ist.globals.firstLoad = false;
		

		for (f in pkeys)
		{
			if (Reflect.field(aData, f) != null)
			{//trace(Reflect.field(aData, f));
				Reflect.setField(params, f, Reflect.field(aData, f));				
			}
		}
		if (order != null)
			params.order = order;		
		return params;
	}
	
	public function update(data:Dynamic):Void
	{
		// UPDATE MAIN DATA TABLE
		if (data.globals != null)
		{
			//App.ist.globals.users = data.globals.users;
			//trace(App.ist.globals.users);
		}
		//trace(params);
		data.fields = fields;
		data.hidden = vData.hidden;
		data.primary_id = primary_id;
		trace(id + ':' + data.fields + ':' + data.hidden + ':' + data.primary_id + ':' +  root.length);
		//trace(data);
		if ( J('#' + id + '-list').length > 0)
			J('#' + id + '-list').replaceWith(J('#t-' + id + '-list').tmpl(data));
		else
			J('#t-' + id + '-list').tmpl(data).appendTo(J(data.loaderId).first());	
			
		J('#' + id + '-list th').each(function(i, el) { J(el).click(function(_) { order(J(el)); } ); } );	
		//remove click handler from all main data list rows td cells  - why???
		J('#' + id + '-list tr').first().siblings().click(select).find('td').off('click');
		//J('td').attr('tabindex', -1);
		var limit:Int = (vData.limit > 0? vData.limit : App.limit);
		trace('data.count:'+ data.count + ' - limit $limit:' + vData.limit +' _ ' + App.limit);
		if (limit < data.count)
		{
			//CREATE PAGER
			var pager:Pager = new Pager({
				count:data.count,
				id:vData.id,
				limit:limit,
				page:data.page,
				parentView:this
			});
		}
		//if(J('#clients-menu').length>0 && 
		trace(Std.string( J('#'+id+'-menu').offset().left - 35 ) +' reloadID:' + reloadID);
		J('.main-left').width(Std.string( J('#'+id+'-menu').offset().left - 35 ) );
		trace(Std.string( J('#'+id+'-menu').offset().left - 35 ) +' reloadID:' + reloadID);
		wait(false);
		if (reloadID != null)
		{
			trace('#' + reloadID + ' : ' + J('#' + reloadID ).length);
			J('#' + reloadID ).children().first().trigger('click');
			trace(id +':' + J('#' + id + '-list tr[class~="selected"]').length);
			reloadID =  null;
		}		
	}
	

	public function runLoaders():Void
	{
		trace(dbLoaderIndex);
		loadAllData(dbLoaderIndex);
	}
	
	public function select(evt:Event):Void
	{
		trace('has to be implemented in subclass!');
	}
	
	public function wait(start:Bool = true, ?message:String , ?timeout:Int=15000)
	{
		if (!start && waiting != null)
		{
			waiting.stop();
			trace(J('#wait').length); 			
			J('#wait').animate( { opacity:0.0 }, 300, null, function() { J('#wait').detach();  trace(J('#wait' ).length); } );
			spinner.stop();
		}
		if (!start)
		{
			return;
		}
		if (message == null)
			message = App.uiMessage.wait;
		if (timeout == null)
			timeout = App.waitTime;
			
		J('#t-wait' ).tmpl( { wait: message} ).appendTo('#' +id).css({width:J(Browser.window).width(), height:J(Browser.window).height(), zIndex:8000}).animate({opacity:0.8});

		spinner = untyped  Browser.window.spin('wait');
		if (message == App.uiMessage.retry || message == App.uiMessage.timeout) 
		{		
			waiting = Timer.delay(function() { wait(false);} , timeout);
		}
		else
		{
			trace('set timeout:' + timeout + ':' + message);
			waiting = Timer.delay(function() { wait(true, App.uiMessage.timeout, 3500); } , timeout);	
		}
	}
	

	
}