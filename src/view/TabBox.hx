package view;

import haxe.CallStack;
import haxe.ds.StringMap;
import haxe.Timer;
import js.Browser;
import js.html.Element;
import js.html.Node;
import js.html.XMLHttpRequest;
import View;
import js.jquery.*;
import pushstate.PushState;
import js.jquery.Helper.*;
import me.cunity.debug.Out;

using Util;

/**
 * ...
 * @author axel@cunity.me
 */

typedef Tabs = Dynamic;

typedef TabData = 
{>ViewData,
	var id:String;
	var label:String;
	//@:optional var action:String;
	
}

typedef TabBoxData = 
{>ViewData,
	var tabs:Array<TabData>;
	//@:optional var action:String;
	@:optional var includes:Array<String>;
	@:optional var isNav:Bool;
	@:optional var onLoad:String;
	@:optional var append2header:String;
	@:optional var heightStyle:String;
}

@:keep class TabBox extends View
{
	var active:Int;
	var tabBoxData:TabBoxData;
	var tabsInstance:Tabs;
	var tabObj:Dynamic;
	var tabLinks:Array<String>;
	var tabLabel:Array<String>;
		
	public function new(?data:TabBoxData) 
	{
		super(data);

		tabLabel = new Array();
		tabLinks = new Array();

		if (data != null )
		{
			tabBoxData = cast data;
			//trace(tabBoxData);
			if (tabBoxData.isNav)
			{
				PushState.init();
				PushState.addEventListener(go);
			}						
			active = 0;
			for (tab in tabBoxData.tabs)
			{
				if (tab.id == tabBoxData.action)
					active = tabLinks.length;
				tabLabel.push(tab.label);
				tabLinks.push(tab.id);
				dbLoader.push(new StringMap<DataLoader>());
			}
			
			trace(id + ':' + dbLoader.length);
			
			J('#t-' + id).tmpl(tabBoxData.tabs).appendTo(root.find('ul:first'));	
			
			tabObj = root.tabs( 
			{
				active:0,
				activate: function( event:Event, ui:Dynamic ) 
				{
					trace(J(ui.newPanel));	
					var selector = ui.newPanel.selector;
					var template = '';
					try
					{
						trace('$selector a:' + J('$selector').attr('aria-labelledby'));
						selector = J('$selector').attr('aria-labelledby');
						trace(App.ist.globals.templates);
						trace('selector:$selector');
						template = Reflect.field(App.ist.globals.templates, J('#$selector').attr('href'));
						if (!template.any2bool())
						{
							//LOAD TEMPLATE
							trace('loading templates/' +  J('#$selector').attr('href') + '.html...');
							js.jquery.JQuery.get('templates/' +  J('#$selector').attr('href') + '.html',function(data:Dynamic, textStatus:String, xhr:XMLHttpRequest){
								trace('$textStatus:${xhr.responseURL}' +  xhr.getAllResponseHeaders());
								if(data.length>0)
								trace(data.substr(0,100));
								if (textStatus == 'success')
								{					
									if (data == 'NOTFOUND')
										return;
									J('body').append(data);
									Reflect.setField(App.ist.globals.templates, J('#$selector').attr('href'), true);
									trace(untyped Browser.window.lastView);
									if(untyped Browser.window.lastView == null)
										return;
									//addView(untyped Browser.window.lastView);
									tabBoxData.tabs[tabsInstance.options.active].views.push(untyped Browser.window.lastView);
									trace(tabsInstance.options.active+':' + tabBoxData.tabs[tabsInstance.options.active].views.length);
									var v:ViewData = tabBoxData.tabs[tabsInstance.options.active].views[tabBoxData.tabs[tabsInstance.options.active].views.length - 1];
									v.attach2 =  tabsInstance.panels[tabsInstance.options.active];
									v.dbLoaderIndex = tabsInstance.options.active;
									
									var jP:JQuery = J(tabsInstance.panels[tabsInstance.options.active]);
									//Out.dumpObjectTree(tabsInstance.panels[tabIndex]);
									//if (tabsInstance.options.active != active)
										//jP.css('visibility','hidden').show();
									trace('adding:' + tabBoxData.tabs[tabsInstance.options.active].id + ' to:' + id + ' @:'  + tabsInstance.options.active );
									addView(v);
									/*if (tabIndex != active)
										jP.hide(0).css('visibility','visible');								
											
										}*/
									loadAllData(v.dbLoaderIndex);
								}
								
							});
						}
					}
					catch (ex:Dynamic) { trace(ex); }
					trace('activate:' + ui.newPanel.selector + ':' + ui.newTab.context + ':' + tabsInstance.options.active + ':' + active + ' template:' + template);
					dbLoaderIndex = active = tabsInstance.options.active;
					PushState.replace(Std.string(ui.newTab.context).split(Browser.window.location.hostname).pop());
					//trace(tabObj.tabs);
					runLoaders();
				},				
				create: function( event:Event, ui ) 
				{
					trace('ready2load content4tabs:' + tabBoxData.tabs.length);
					tabsInstance =  J('#' + id).tabs("instance");		
					//trace(tabObj.tabs);
					//Out.dumpObject(tabsInstance.panels);
					if (tabBoxData.append2header != null)
					{
						var views:StringMap<View> = App.getViews();
						//trace(views.toString());
						//trace(views.get(tabBoxData.append2header));
						views.get(App.appName + '.' + tabBoxData.append2header).template.appendTo(J('#' + id + ' ul'));
					}
					var tabIndex:Int = 0;
					for (t in tabBoxData.tabs)
					{
						//trace(t);
						for (v in t.views)
						{
							//trace(v);
							v.dbLoaderIndex = tabIndex;
							v.attach2 =  tabsInstance.panels[tabIndex];
							var jP:JQuery = J(tabsInstance.panels[tabIndex]);
							//Out.dumpObjectTree(tabsInstance.panels[tabIndex]);
							if (tabIndex != active)
								jP.css('visibility','hidden').show();
							trace('adding:' +t.id + ' to:' + id + ' @:'  + tabIndex );
							addView(v);
							if (tabIndex != active)
								jP.hide(0).css('visibility','visible');								
						}
						tabIndex++;
					}
					//APP UI CREATION DONE - LOAD DATA 4 ACTIVE TAB
				},
				beforeLoad: function( event:Event, ui ) 
				{
					trace('beforeLoad ' + ui.ajaxSettings.url);
					//JQuery._static.post(ui.ajaxSettings.url,{},load, 'json');
					return false;
				},
				heightStyle: tabBoxData.heightStyle == null ? 'auto':tabBoxData.heightStyle				
			});	
			//trace(tabObj);
			trace(tabsInstance.option('active'));
			trace(dbLoader.length + ':'  + active );
		}
		
		trace (Browser.window.location.pathname + ' != ' + App.basePath);
		if (Browser.window.location.pathname != App.basePath)
		{			
			Timer.delay(function() { go(Browser.window.location.href);init();} , 500);
		}
		else
			init();
	}
	
	//public function load(res:Dynamic, data:String, xhr:JqXHR):Void
	
	//public function go(url:String, p:Dynamic):Void
	public function go(url:String):Void
	{
		trace(url + ':' + tabLinks.join(','));
		trace(tabsInstance.options.active + ' : ' + tabLinks.indexOf(url));
		//Out.dumpObject(p);
		/*if (tabsInstance.options.active == tabLinks.indexOf(url))
		{
			//trace('full reload');
			//Browser.window.location.reload();
		}*/
		
		if (url.indexOf('?') >-1)
		{
			if (tabLinks[tabsInstance.options.active] != 'clients')
			{
				//tabLinks[tabsInstance.options.active] = 1;
				if(tabObj!=null)
				tabObj.tabs( "option", "active", 1 );
				Browser.document.title = App.company + " " + App.appName + '  ' + tabLabel[tabsInstance.options.active];
				return;
			}
		}
		
		if (!Std.is(url, String))
		{
			Out.dumpStack(CallStack.callStack());
			return;
		}
		var p:Array<String> = url.split(App.basePath);
		//trace(p.toString() + ':' + p.length + ' basePath:' + Application.basePath);
		if (p.length == 2 && p[1] == '')
			p[1] = tabLinks[0];
		else if (p.length == 1)
			p[1] = url;
		if (tabsInstance.options.active == tabLinks.indexOf(p[1]))
		{			
			trace(tabsInstance.options.active + ' == ' + tabLinks.indexOf(p[1]));
			return;
		}
		if (tabLinks[tabsInstance.options.active] != p[1])
		{
			trace(id + ' root:' +  root.attr('id'));
			if(tabObj!=null)
				tabObj.tabs( "option", "active", tabLinks.indexOf(p[1]) );
		}
		//trace(p.toString() + ':' + tabsInstance.options.active + ':' + tabLinks.indexOf(p[1]));
		Browser.document.title = App.company + " " + App.appName + '  ' + tabLabel[tabsInstance.options.active];
	}
	
}