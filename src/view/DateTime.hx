package view;
import haxe.Timer;
import js.jquery.*;
import js.jquery.Helper.*;
import me.cunity.js.JHelper.vsprintf;

/**
 * ...
 * @author axel@cunity.me
 */
@:keep class DateTime extends View
{
	static var wochentage =  ["Sonntag","Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag"];
	static var monate =  ["Januar","Februar","März","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"];
	var format:String;
	
	var interval:Int;
	
	public function new(?data:Dynamic) 
	{
		super(data);
		interval = data.interval;
		format = data.format;
		var t:Timer = new Timer(interval);
		var d:Date = Date.now();
		template = J('#t-' + id).tmpl( { datetime:vsprintf(format, [wochentage[d.getDay()] , d.getDate(), d.getMonth()+1, d.getFullYear(), d.getHours(), d.getMinutes()]) } );
		draw();
		var start:Int = d.getSeconds();
		if (start == 0)
		{
			t.run = draw;
		}
		else
			Timer.delay(function() { 
				t.run = draw; 
				draw();
			}, (60 - start) * 1000);
		
	}
	
	public function draw():Void
	{
		var d:Date = Date.now();
		template.html(vsprintf(format, [wochentage[d.getDay()] , d.getDate(), d.getMonth() + 1, d.getFullYear(), d.getHours(), d.getMinutes()]));
	}
	
}