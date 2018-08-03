package view;
import haxe.ds.StringMap;
import haxe.xml.Check.Attrib;
import js.Browser;
import js.html.Node;
import js.jquery.*;
import js.jquery.Helper.*;

/**
 * ...
 * @author axel@cunity.me
 */

using Lambda;
using StringTools;
using Util;
 
typedef FData = 
{
	var name:String;
	var value:Dynamic;
}

@:expose("FD")
class FormData
{
	/*
	 * Merge Data|Settings with Form 
	 */
	
	public static function query(jForm:JQuery, ?eData:Dynamic) :String
	{
		var fD:Array<FData> = cast jForm.serializeArray();
		var ret:String = '';
		var d:FData = null;
		for (f in Reflect.fields(eData))
		{
			d = Reflect.field(eData, f);
			if ( d != null && Std.string(d) != '')
			{
				if (ret != '')
					ret += '&';		
				ret += f + '=' + d;
			}

		}
		for (item in fD)
		{
			if (item.value != null && item.value != '')
			{
				if(ret != '')
					ret += '&';
				ret +=  item.name + '=' + item.value;
			}
		}
		return ret;
	}
	/*
	 * Regex replace parameter order switched
	 */
	
	/*public static function replace(e:String, by:String, source:String):String
	{		
		var eR:EReg =  new EReg(e, '');
		trace(eR + ' replace:' + source + ' by:' + by);
		return eR.replace(source, by);
	}*/
	
	/*
	 * Build WHERE data string based on match type options 4 LIKE: exact|start|end|any
	 * and BETWEEN
	 * Change array values to IN(...)
	 */
	
	public static function save(jForm:JQuery):Array<FData>
	{
		//PREPARE EDITOR DATA FOR POSTING
		var ret: Array<FData> = cast jForm.serializeArray();
		var checkBoxes = jForm.find('input[type="checkbox"]');
		var missing:StringMap<Bool> = new StringMap();
		trace(jForm.length);
		//trace(ret);
		App.ist.logTrace(jForm.length + ':' + Std.string(ret));
		checkBoxes.each(function(i:Int, n:Node) {
			var checkBox:JQuery = J(n);
			//trace(checkBox.attr('name') + ':' + checkBox.prop('checked'));
			//if (!checkBoxes.prop('checked'))
			if (! ret.forone(function(fd:FData):Bool return fd.name == checkBox.attr('name')))
			{
				ret.push( { name:checkBox.attr('name'), value:(checkBox.prop('checked')?1:0) } );
			}
			else ret = ret.map(function(fd:FData):FData {
				if(fd.name==checkBox.attr('name'))
					fd.value = (checkBox.prop('checked')?1:0);
				return fd;
			});
			if (checkBox.data('required') == 'true' && !checkBox.prop('checked'))
			{
				missing.set(checkBox.attr('name'), true);
			}
			//else
				//missing.set(checkBox.attr('name'), false);
			//trace(ret);
		});
		//trace(ret);
		//TODO: RADIO!!!

		for (fd in ret)
		{
			var itemName:String = fd.name.split('[')[0];
			if (Reflect.hasField(App.storeFormats, itemName))
			{
				var sForm:Array<Dynamic> = Reflect.field(App.storeFormats, itemName);
				var callParam:Array<Dynamic> = sForm.length>1 ? sForm.slice(1) : [];
				var method:String = sForm[0];
				//trace('call FormData' + method);
				callParam.push(fd.value);
				if (itemName.indexOf('_') == 0)
				{
					//trace(J('input[name="' + fd.name + '"]').data('value'));
					callParam.push(J('input[name="' + fd.name + '"]').data('value'));
					fd.name = fd.name.substr(1);
					//trace(fd.name);
				}
				fd.value = Reflect.callMethod(Browser.window, Reflect.field(Browser.window, method), callParam);
			}
			if (!missing.exists(fd.name) && J('input[name="' + fd.name + '"]').data('required') == 'true' && J('input[name="' + fd.name + '"]').val() == '')
			{
				missing.set(fd.name, true);
			}
		}
		trace(ret);
		ret.push({name:'missing', value:missing});
		return ret;
	}
	
	public static function filter(jForm:JQuery, tableData:StringMap<Array<String>>, tableNames:Array<String>):String
	{
		var fResult:String = '';
		var table2remove:Array<String> = new Array();
		trace(tableNames.join(','));
		for (tN in tableNames)
		{
			var tD:Array<String> = tableData.get(tN);
			var ret:Array<String> = new Array();
			for (tDn in tD)
			{		
				if (!jForm.find('[name="' + tDn +'"]').val().any2bool())
				{		
					trace('$tDn not set:' + jForm.find('[name="' + tDn +'"]').val());
					continue;
				}
				var matchTypeOption:JQuery =  jForm.find('[name="' + tDn + '_match_option"]');
				trace (tDn + ':' + matchTypeOption.length );
				if (matchTypeOption.length == 1)
				{
					ret.push(switch(matchTypeOption.val())
					{
						case 'exact':
							tDn + '|' + jForm.find('[name="' + tDn +'"]').val();
						case 'start':
							tDn + '|LIKE|' + jForm.find('[name="' + tDn +'"]').val() + '%';
						case 'end':
							tDn + '|LIKE|%' + jForm.find('[name="' + tDn +'"]').val();
						case 'any':
							tDn + '|LIKE|%' + jForm.find('[name="' + tDn +'"]').val() + '%';		
						case _:
							trace('ERROR: unknown matchTypeOption value:' + matchTypeOption.val());
							'ERROR|unknown matchTypeOption value:' + matchTypeOption.val();							
					});
					//trace('done $tDn');
					continue;
				}
				if (tDn.indexOf('range_from_') == 0 )
				{
					var from:String = jForm.find('[name="' + tDn +'"]').val();
					if (from.length > 0)
						from = gDateTime2mysql(from + ' 00:00:00');
					var name:String = tDn.substr(11);
					trace(name + ':' +  jForm.find('[name="range_from_' + name + '"]').val() );
					var to:String = jForm.find('[name="range_to_' + name + '"]').val();
					if (to.length > 0)
						to = gDateTime2mysql(to + ' 23:59:59');
					if (from.length > 0 && to.length > 0)
						ret.push(name + '|BETWEEN|' + from + '|' + to);
					else if (from.length > 0)
						ret.push(name + '|BETWEEN|' + from + '|' + DateTools.format(Date.now(), '%Y-%m-%d'));
					else if (to.length > 0)//	TODO: CONFIG SYSTEM START DATE
						ret.push(name + '|BETWEEN|2015-01-01 00:00:00|' + to);
				}
				else if (tDn.indexOf('range_to_') == 0)
					continue;
				else if (tDn.indexOf('_match_option') == -1)
				{
					if (tDn == 'pay_source.pay_source_state')
					{
						if (jForm.find('[name="' + tDn +'"]').prop('checked'))
							ret.push (tDn + '|IN|active|new');
					}
					else
					ret.push (tDn + '|' + jForm.find('[name="' + tDn +'"]').val() );
					//trace('name:$tDn' + jForm.find('[name="' + tDn +'"]').prop('checked'));
				}
				
			}
			if (ret.length > 0)
			{
				if (fResult != '')
					fResult += ',';
				fResult += ret.join('|');
			}
			else
				table2remove.push(tN);
		}
		table2remove.map(function(s:String) tableNames.remove(s));
		//trace(table2remove);
		//trace(tableNames);
		//trace(fResult);
		//fResult = ret.join(',');tableNames.remove(tN);
		return fResult;
	}
	
	public static function where(jForm:JQuery, fields:Array<String>):String
	{
		var ret:Array<String> = new Array();
		var fD:Array<FData> = cast jForm.serializeArray();
		trace(fields);
		var aFields:StringMap<Array<String>> = new StringMap();
		fD.iter(function(aFD:FData) {
			if(fields.has(aFD.name))
			 aFields.set(aFD.name, (aFields.exists(aFD.name) ? aFields.get(aFD.name).concat(aFD.value): [aFD.value]));
		});
		var it:Iterator<String> = aFields.keys();
		var ret:Array<String> = new Array();
		while (it.hasNext())
		{
			var k:String = it.next();
			if (aFields.get(k).length > 1)
			{
				//FOUND ARRAY FIELD - REPLACE AT ORIGINAL
				fD = fD.filter(function(aFD:FData):Bool return aFD.name != k );
				ret.push( k + '|IN|' + aFields.get(k).join('|'));
			}
		}		
		//trace(fD);
		for (item in fD)
		{
			
			//if (!(fields.has(item.name) || item.name.indexOf('range_from_') == 0))
			if ( item.name.indexOf('_match_option')>-1 || !(fields.has(item.name) || fields.forone(function(f:String) { 
				//trace(f + ':' + item.name + ' ' + (item.name.indexOf('.')>-1 && item.name.startsWith(f.split('.')[0])?'TRUE':'FALSE'));
				return item.name.indexOf('.')>-1 && item.name.startsWith(f.split('.')[0]); } ) || item.name.indexOf('range_from_') == 0) )
				continue;
			trace( item.name);
			if (item.value != null && item.value != '' || item.name.indexOf('range_from_') == 0)
			{
				if (Reflect.hasField(App.storeFormats, item.name))
				{
					var sForm:Array<Dynamic> = Reflect.field(App.storeFormats, item.name);
					var callParam:Array<Dynamic> = sForm.length>1 ? sForm.slice(1) : [];
					var method:String = sForm[0];
					trace('call FormData' + method);
					callParam.push(item.value);
					//item.value = Reflect.callMethod(FormData, Reflect.field(FormData, method), callParam);
					item.value = Reflect.callMethod(Browser.window, Reflect.field(Browser.window, method), callParam);
					trace(item.value);
				}
				var matchTypeOption:JQuery =  jForm.find('[name="' + item.name + '_match_option"]');
				trace (item.name + ':' + matchTypeOption.length );
				if (matchTypeOption.length == 1)
				{
					ret.push(switch(matchTypeOption.val())
					{
						case 'exact':
							item.name + '|' + item.value;
						case 'start':
							item.name + '|LIKE|' + item.value + '%';
						case 'end':
							item.name + '|LIKE|%' + item.value;
						case 'any':
							item.name + '|LIKE|%' + item.value + '%';		
						case _:
							trace('ERROR: unknown matchTypeOption value:' + matchTypeOption.val());
							'ERROR|unknown matchTypeOption value:' + matchTypeOption.val();							
					});
					//trace('skipping $item');
					continue;
				}
				if (item.name.indexOf('range_from_') == 0 )
				{
					var from:String = item.value;
					if (from.length > 0)
						from = gDateTime2mysql(from + ' 00:00:00');
					var name:String = item.name.substr(11);
					trace(name + ':' +  jForm.find('[name="range_from_' + name + '"]').val() );
					var to:String = jForm.find('[name="range_to_' + name + '"]').val();
					if (to.length > 0)
						to = gDateTime2mysql(to + ' 23:59:59');
					if (from.length > 0 && to.length > 0)
						ret.push(name + '|BETWEEN|' + from + '|' + to);
					else if (from.length > 0)
						ret.push(name + '|BETWEEN|' + from + '|' + DateTools.format(Date.now(), '%Y-%m-%d'));
					else if (to.length > 0)//	TODO: CONFIG SYSTEM START DATE
						ret.push(name + '|BETWEEN|2015-01-01 00:00:00|' + to);
				}
				else if (item.name.indexOf('range_to_') == 0)
					continue;
				else
					ret.push (item.name + '|' + item.value );
			}
		}
		trace(ret.join(','));		
		return ret.join(',');		
	}
	
	@:expose('gDate2mysql')
	public static function gDate2mysql(gDate:String):String
	{
		if (gDate == null || gDate == '')
			return null;
		var d:Array<String> = gDate.split('.').map(function(s:String) return StringTools.trim(s));
		if (d.length != 3)
		{			
			if (d.length == 1 && d[0].length == 4)
			{
				return d[0] + '-01-01';
			}
			trace('Falsches Datumsformat:$gDate :' + d.toString());
			return 'Falsches Datumsformat:' + gDate;
		}
		return d[2] + '-' + d[1] + '-' + d[0];
	}
	
	@:expose('gDateTime2mysql')
	public static function gDateTime2mysql(gDateTime:String):String
	{
		var d:Array<String> = ~/[\. :]/g.split(gDateTime).map(function(s:String) return StringTools.trim(s));
		trace(d);
		if (d.length != 6)
		{			
			trace('Falsches Datumsformat:$gDateTime');
			return 'Falsches Datumsformat:' + gDateTime;
		}
		return d[2] + '-' + d[1] + '-' + d[0] + ' ' + d[3] + ':' + d[4] + ':' + d[5];
	}	
	
	@:expose('_gDateTime2mysql')
	public static function _gDateTime2mysql(gDate:String, gDateTime:String):String
	{
		var d:Array<String> = ~/[\- :]/g.split(gDateTime).map(function(s:String) return StringTools.trim(s));
		trace(d);
		if (d.length != 6)
		{			
			trace('Falsches Datumsformat:$gDateTime');
			return 'Falsches Datumsformat:' + gDateTime;
		}
		var n:Array<String> = gDate.split('.').map(function(s:String) return StringTools.trim(s));
		if (n.length != 3)
		{			
			/*if (n.length == 1 && n[0].length == 4)
			{
				return d[0] + '-01-01';
			}*/
			trace('Falsches Datumsformat:$gDate :' + d.toString());
			return 'Falsches Datumsformat:' + gDate;
		}
		//return d[2] + '-' + d[1] + '-' + d[0];
		return n[2] + '-' + n[1] + '-' + n[0] + ' ' + d[3] + ':' + d[4] + ':' + d[5];
	}	
}