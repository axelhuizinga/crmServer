package ;

import haxe.ds.StringMap;
import haxe.Http;
import haxe.Json;
import haxe.Log;
import haxe.Timer;
import js.Browser;
import js.html.Node;
import js.Lib;
import js.jquery.*;
import me.cunity.debug.Out;
import view.Campaigns;
import view.Clients;
import view.ClientHistory;
import view.ContextMenu;
import view.DateTime;
import view.ClientEditor;
import view.Editor;
import view.History;
import view.QC;
import view.TabBox;
import me.cunity.debug.Out;
import js.jquery.Helper.*;
using Lambda;

/**
 * ...
 * @author axel@cunity.me
 */
typedef Rectangle =
{
	@:optional var width:Float;
	@:optional var height:Float;
	@:optional var left:Float;
	@:optional var top:Float;
}



class App
{
	public static var ist:App;
	public static var basePath:String;
	public static var appName:String;
	public static var user:String;
	public static var company:String;
	public static var appLabel:Dynamic;
	//public static var cssStyles:Dynamic;
	public static var storeFormats:Dynamic;
	public static var uiMessage:Dynamic;
	public static var waitTime:Int;
	public static var limit:Int;
	
	public  var hasTabs:Bool;
	public  var rootViewPath:String;
	public var globals:Dynamic;
	public var altPressed:Bool;
	public var ctrlPressed:Bool;
	public var shiftPressed:Bool;
	
	var views:StringMap<View>; 
	
	
	static function main() 
	{
		Log.trace = Out._trace;		
	}
	
	public function new()
	{		
		views = new StringMap();
		//dbLoader = new Array();
	}
	
	public static function inputError(form:JQuery, inputs:Array<String>)
	{
		trace(form.attr('id') + ':' + inputs);
		form.find('input').each(function(i:Int, n:Node)
		{
			//trace (J(n).attr('name') + ': ' + (inputs.has(J(n).attr('name')) ? 'Y' : 'N') );
			if (inputs.has(J(n).attr('name')))
			{
				J(n).addClass('error');
				//J(n).append(J('<span class="error">*</span>'));
			}
		});
	}
	
	@:expose('choice')
	public static function choice(data:Dynamic)
	{
		if (data != null && data.id != null)
		{
			J('#t-choice' ).tmpl(data).appendTo('#' +data.id).css( { width:J(Browser.window).width(), height:J(Browser.window).height() } ).animate( { opacity:1 } );
			trace(data.id + ':' + J('#' +data.id + ' .overlay .scrollbox').length + ':' + J('#' +data.id + ' .overlay').height());
			J('#' +data.id + ' .overlay .scrollbox').height(J('#' +data.id + ' .overlay').height());
		}
		else
			J('#choice').hide(300, null, function() J('#choice').remove());
	}	
	
	@:expose('modal')
	public static function modal(mID:String, ?data:Dynamic)
	{
		trace(data);
		if (data != null && data.mID != null)
		{
			J('#t-' + mID ).tmpl(data).appendTo('#' +data.id).css( { width:J(Browser.window).width(), height:J(Browser.window).height() } ).animate( { opacity:1 } );
			trace(data.id + ':' + J('#' +data.id + ' .overlay .scrollbox').length + ':' + J('#' +data.id + ' .overlay').height());
			J('#' +data.id + ' .overlay .scrollbox').height(J('#' +data.id + ' .overlay').height());
		}
		else
			J('#' + mID).hide(300, null, function() J('#' + mID).remove());
	}	
	
	@:expose('info')
	public static function info(data:Dynamic)
	{
		trace(data);
		if (data.target == null && data.id != null)
		{
			J('#t-info' ).tmpl(data).appendTo('#' +data.id).css( { width:(J(Browser.window).width() - 440) +'px', height:'100px', 
				margin: (J(Browser.window).height() - 200) + 'px 0 0 100px' } ).animate( { opacity:1 } );
			trace(data.id + ':' + J('#' +data.id + ' .overlay .scrollbox').length + ':' + J('#' +data.id + ' .overlay').height());
		}
		else
			J('#$data #info').hide(300, null, function() J('#$data #info').remove());
	}		
	
	public  function logTrace(logMsg:String, file:String = '/var/log/flyCRM/dev.log'):Void
	{
		trace(logMsg);
		var p:Dynamic = {
			logFile:'/var/log/flyCRM/app.log',
			user:App.user,
			log:logMsg
		};
		JQuery.post('/flyCRM/formLog2.php', p).done(function() {
			trace( "log success" );
		  })
		  .fail(function() {
			trace( "error" );
		  });
	}
	
	@:expose("initApp") 
	public static function init(config:Dynamic):App
	{
		ist = new App();
		appName = config.appName;
		appLabel = config.appLabel;
		user = config.user;
		storeFormats = config.storeFormats;
		//cssStyles = config.cssStyles;
		uiMessage = config.uiMessage;
		waitTime = config.waitTime;
		company = config.company;
		limit = config.limit;
		ist.hasTabs = config.hasTabs;
		ist.rootViewPath = appName + '.' + config.rootViewPath;
		var fields:Array<String> = Type.getClassFields(App);
		for (f in fields)
		{
			if(Reflect.field(config, f)!=null)
			Reflect.setField(App, f, Reflect.field(config, f));
			//trace(Reflect.field(App, f));
		}
		basePath = Browser.location.pathname.split(config.appName)[0] + config.appName + '/';
		//trace(cssStyles);
		ist.globals = { firstLoad:true};
		ist.globals = { };
		//ist.initUI(config.views);		

		return ist;
	}
	
	function initUI(viewConfigs:Array<Dynamic>):Void
	{//trace(viewConfigs);
		for (v in viewConfigs)
		{
			var className:String = Reflect.fields(v)[0];
			var iParam:Dynamic = Reflect.field(v, className);
			//trace(className + ':' + iParam);
			var cl:Class<Dynamic> = Type.resolveClass('view.' + className);
			if (cl != null)
			{
				//trace(cl);
				var av:View = Type.createInstance(cl, [iParam]);
				views.set(av.instancePath, av);				
				trace("views.set(" +av.instancePath +")");				
				//views.set(iParam.id, av);				
				//trace("views.set(" +iParam.id +")");
			}
		}
		J(Browser.window).keydown(function(evt) {
			switch (evt.which) { 
				case 16:
					shiftPressed = true;
				case 17:
					ctrlPressed = true;
				case 18:
					altPressed = true;			
			}
		}).keyup(function(evt) {
			switch (evt.which) { 
				case 16:
					shiftPressed = false;
				case 17:
					ctrlPressed = false;
				case 18:
					altPressed = false;
			 }
		});	
		Timer.delay(function() {
			//views.get(rootViewPath).runLoaders();
			views.get(rootViewPath).runLoaders();
		},500);
		
	}
	
	public function prepareAgentMap():Array<Array<String>>
	{
	var agents:Array<Array<String>> = [['','']];
		var users:Array<Dynamic> = App.ist.globals.userMap.users;
		for (u in users) 
		{
			if (u.user_group.indexOf('AGENT')==0 && u.active == 'Y')
			{
				agents.push([u.user ,u.full_name]);		
			}
		}
		return agents;
	}
	
	public static function getMainSpace():Rectangle
	{
		var navH:Float = J('.ui-tabs-nav').outerHeight();
		return 
		{
			top:navH + 5,
			left:0,
			height:J(Browser.window).height() -  Std.parseFloat(J('#mtabs').css('padding-top')) -  Std.parseFloat(J('#mtabs').css('padding-bottom') ) - navH,
			width:J(Browser.window).width() * .7
		};
	}
	
	public static function getViews(): StringMap<View>
	{
		return ist.views;
	}
	
	public static function dateSort(a:String, b:Array<Dynamic>):Void
	{
		untyped Browser.window.dateSort(a, b);
	}
	
	function test()
	{
		var template = "{a} Hello {c} World!";
		var data = { a:123, b:333, c:"{nested}" };
		var t:String = "hello";
		trace(t + ':' + t.indexOf('lo'));
		var ctempl:String = ~/{([a-x]*)}/g.map(template, function(r:EReg)
		{
			//Out.dumpObject(r);
			var m:String = r.matched(1);
			var d:String = Std.string(Reflect.field(data, m));
			if (d.indexOf('{')==0)
			trace("nested template :) " + d.indexOf('{'));
			return d;
		});
		trace(ctempl);
	}
	
}