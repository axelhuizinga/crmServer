package view;
import js.jquery.*;
import js.jquery.Helper.*;
import js.Browser;
import me.cunity.js.jqPlugin.JMore;

using StringTools;
/**
 * ...
 * @author axel@cunity.me
 */
class Mailing extends View
{
	var cMenu:ContextMenu;
	var host:String;
	var proto:String;
	
	public var mailingID:String;
	
	public function new(?data:Dynamic) 
	{
		super(data);
		host = Browser.window.location.host;
		proto = Browser.window.location.protocol;
		init();
	}
	
	public function printNewMembers(mID:String):Void
	{
		var product:String = J('#$mID input[name="product"]:checked').val();
		var url:String = '$proto//$host/cgi-bin/mailing.pl?action=PRINTNEW&product=$product';		
		trace(url);
		J('#$mID #preparing-file-download').show();
		J("#error-download").hide();
		J('#$mID #success-download').hide();
		JQuery.fileDownload(url, {
			successCallback: function(url)
			{										
				trace('OK:) $url');
				J('#$mID #preparing-file-download').hide();				
				J('#$mID #success-download').show();
			},
			failCallback: function(responseHtml, url)
			{										
				trace('oops $url $responseHtml');
				J('#$mID #preparing-file-download').hide();
				J("#error-download").show();
			}
		} );
		return;		
		var res:String = js.jquery.JQuery.ajax({
			async: false,
			url:url,
			dataType:'json'
		}).responseText;			
		var json:Dynamic = js.jquery.JQuery.parseJSON(res);
		json.id = 'clients';
		trace(Reflect.fields(json));	
		trace(json);	
		App.info(json);
	}
	
	public function printList(mID:String):Void
	{
		var list:String = J('#$mID #printListe').val();
		var product:String = J('#$mID input[name="product"]:checked').val();
		var url:String = '$proto//$host/cgi-bin/mailing.pl?action=PRINTLIST&list=${list.urlEncode()}&product=$product';// + list.urlEncode();		
		trace(url);
		J('#$mID #preparing-file-download').show();
		J("#error-download").hide();
		J('#$mID #success-download').hide();
		JQuery.fileDownload(url, {
			successCallback: function(url)
			{										
				trace('OK: $url');
				J('#$mID #preparing-file-download').hide();
				J('#$mID #success-download').show();
			},
			failCallback: function(responseHtml, url)
			{										
				trace('oops $url $responseHtml');
				J('#$mID #preparing-file-download').hide();
				J("#error-download").show();
			}
		} );
		return;
		var res:String = js.jquery.JQuery.ajax({
			async: false,
			url:url,
			dataType:'json'
		}).responseText;			
		var json:Dynamic = js.jquery.JQuery.parseJSON(res);
		json.id = 'clients';
		trace(Reflect.fields(json));	
		trace(json);	
		App.info(json);
	}

	public function printNewInfos(mID:String):Void
	{
		var product:String = J('#$mID input[name="product"]:checked').val();
		var url:String = '$proto//$host/cgi-bin/mailing.pl?action=S_POST&product=$product';		
		trace(url);
		J('#$mID #preparing-file-download').show();
		J("#error-download").hide();
		J('#$mID #success-download').hide();
		//wait(1);
		JQuery.fileDownload(url, {
			successCallback: function(url)
			{										
				trace('OK: $url');
				J('#$mID #preparing-file-download').hide();
				J('#$mID #success-download').show();
				//wait();
			},
			failCallback: function(responseHtml, url)
			{										
				trace('oops $url $responseHtml');
				J('#$mID #preparing-file-download').hide();
				J("#error-download").show();
			}
		} );
	}
	
	public function previewOne(mID:String):Void
	{
		
	}
}