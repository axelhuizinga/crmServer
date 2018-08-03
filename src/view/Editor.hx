package view;

/**
 * ...
 * @author axel@cunity.me
 */

import haxe.ds.StringMap;
import haxe.Json;
import haxe.Timer;
import js.jquery.*;
import view.FormData.FData;
import js.Browser;
import App.Rectangle;
import js.html.Audio;
import js.html.Node;
import js.jquery.Helper.*;
import me.cunity.debug.Out;
import me.cunity.js.data.IBAN;

using Lambda;

class Editor extends View
{
	var cMenu:ContextMenu;
	var fieldNames:Dynamic;
	var overlay:JQuery;
	var optionsMap:Dynamic;
	var typeMap:Dynamic;
	public var eData(default, null):JQuery;
	public var action:String;
	public var agent:String;
	public var leadID:String;
	var savingFlagSet:Bool;
	var accountSelector:String;
	var blzSelector:String;
	var ibanSelector:String;
	var maxSaveLoop:Int;
	
	public function new(?data:Dynamic)  
	{
		super(data);
		
		cMenu =  cast (parentView.views.get(parentView.instancePath + '.' + parentView.id + '-menu'), ContextMenu);
		name = parentView.name;	//ACCESS PARENT VIEW CLASS ON SERVER
		//Out.dumpObject(data);
		templ = J('#t-' + id);
		trace(id);
		init();
		accountSelector = parentView.id + '-edit-form ' + 'input[name="account"]';
		blzSelector = parentView.id + '-edit-form ' + 'input[name="blz"]';
		ibanSelector = parentView.id + '-edit-form ' + 'input[name="iban"]';
	}
	
	public function checkIban():Bool
	{
		var iban:String = J('#' + ibanSelector).val();
		//trace('#' + ibanSelector);
		//trace(iban);
		return IBAN.checkIBAN(iban);
	}
	
	public function checkAccountAndBLZ(ok2submit:Bool->Void):Void
	{
		var account:String = J('#' + accountSelector).val();
		var blz:String = J('#' +  blzSelector).val();
		trace('accountSelector: #' + accountSelector);
		trace(account + ':' + blz);
		if (!(account.length > 0 && blz.length > 0))
		{
			ok2submit(false);
			return;
		}
		IBAN.buildIBAN(account, blz, function(success:IbanSuccess) {
			if (IBAN.checkIBAN(success.iban))
			{
				J('#' + ibanSelector ).val(success.iban);
				ok2submit(true);
			}
		},
		function(error:IbanError)
		{
			trace(error.message);
			ok2submit(false);
		});
	}
	
	public function  editCheck(dataRow:JQuery)
	{
		var p:Dynamic = resetParams();
		p.primary_id = (vData.primary_id == null ? parentView.primary_id : vData.primary_id);
		Reflect.setField(p, p.primary_id, eData.attr('id'));	
		if (parentView.vData.hidden != null)
		{			
			//copy all data fields from this dataRow to the load parameter
			var hKeys:Array<String> = parentView.vData.hidden.split(',');
			for (k in hKeys)
			{
				Reflect.setField(p, k, eData.data(k));
			}
		}
		trace(p);	
		trace(leadID);
		p.action = 'edit';
		p.fields = (vData.fields != null ? vData.fields : parentView.vData.fields);
		loadData('server.php', p, compareEdit);		
	}
	
	function compareEdit(data:Dynamic):Void
	{
		var displayFormats:Dynamic = untyped window.displayFormats;
		//trace(data.rows[0]);
		var cData:Dynamic = data.rows[0];
		var cOK:Bool = true;
		var errors:StringBuf = new StringBuf();
		
		for (f in Reflect.fields(cData))
		{
			if (f == 'vendor_lead_code' && overlay.find('[name="vendor_lead_code"]').val()=='')
				continue;
			var val:Dynamic = '';
			var dbData:Dynamic = Reflect.field(cData, f);
			//trace(f +':' + (Reflect.hasField(displayFormats, f) ? 'Y':'N') + ' :' + (['date','datetime'].has(Reflect.field(displayFormats, f))) +':' + untyped __typeof__(window[Reflect.field(displayFormats, f)]) + ':>' +  Reflect.field(displayFormats, f));
			var displayFormat:String = Reflect.field(displayFormats, f);
			if (displayFormat != null)
			{
				if (displayFormat.indexOf('%') > -1)
					val = untyped window.sprintf(displayFormat, Reflect.field(cData, f));
				else
				/*if (['date','datetime','_datetime','gFloat'].has(displayFormat))*/
				{
					//val = Reflect.field(Browser.window, Reflect.field(displayFormats, f))(f, Reflect.field(cData, f));
					if (displayFormat.indexOf('_') == 0)
					{
						trace('input[name="_$f"]');
						val = Reflect.callMethod(Browser.window, Reflect.field(Browser.window,'display'), [displayFormat,dbData,J('input[name="_$f"]').data('value')]);
					}
					else
						val = Reflect.callMethod(Browser.window, Reflect.field(Browser.window,'display'), [displayFormat,dbData]);
					trace(dbData + ':' + displayFormat + ':' + val);
				}
				/*else
					val = untyped window.sprintf(displayFormat, Reflect.field(cData, f));	
					*/
			}
			else
				val = Reflect.field(cData, f);
			var shouldDVal = val;
			cOK = switch(Reflect.field(data.typeMap, f))
			{
				case 'RADIO', 'CHECKBOX':
					var fData = overlay.find('[name="$f"]:checked').val();
					if (fData==null) 
					{
						fData = '';
					}
					val == fData;
				default:
					//val == dbData;
					if (displayFormat != null && displayFormat.indexOf('_') == 0)
						val == overlay.find('[name="_$f"]').val();
					else
						val == overlay.find('[name="$f"]').val();
			}
			
			if (!cOK)
			{
				trace('$dbData< oops - $f: >$shouldDVal< not = >' + overlay.find('[name="$f"]').val() + '<');
				errors.add('oops - $f: $shouldDVal not = ' + overlay.find('[name="$f"]').val() + '<-\r\n');
				//break;
			}			
		}
		if (errors.length > 0)
		{
			trace('edit check failed :(' +errors.toString()  + '\r\n');
			var fD:Array<FData> = FormData.save(J('#' + parentView.id + '-edit-form'));
			var fDs:String = '';
			fD.iter(function(d:FData) fDs += "\n" + d.name + '=>' + d.value);
			var content:Dynamic = {
				header:'edit check failed :(\r\n',
				form: fDs  + '\r\n',
				data:Std.string(data) + '\r\n',
				errors:errors.toString()  + '\r\n'
			};
			js.jquery.JQuery.post('/flyCRM/editorLog.php', content,function(d:Dynamic, s:String, _) { trace(d); trace(s); } ).fail(function() {
				trace( "error" );
			});
			
			//Browser.window.alert(errors.toString());
		}
		//else
		//{//DATA SAVED IS VALIDATED AGAINST FORM CONTENT - OK TO CLOSE FORM
			close();
			if(lastFindParam != null)
				parentView.find(parentView.lastFindParam);
			else
			{
				trace({
					var p:Dynamic = parentView.resetParams();
					if(parentView.vData.order != null)
						p.order = parentView.vData.order;							
					p;
				});
				parentView.find( (parentView.lastFindParam == null ? new StringMap<String>(): parentView.lastFindParam));
			}
		//}
	}
	
	public function  edit(dataRow:JQuery)
	{
		trace(dataRow);
		
		savingFlagSet = false;
		var p:Dynamic = resetParams();
		p.primary_id = (vData.primary_id == null ? parentView.primary_id : vData.primary_id);
		eData = dataRow;
		Reflect.setField(p, p.primary_id, eData.attr('id'));
	
		if (parentView.vData.hidden != null)
		{			
			//copy all data fields from this dataRow to the load parameter
			var hKeys:Array<String> = parentView.vData.hidden.split(',');
			for (k in hKeys)
			{
				Reflect.setField(p, k, eData.data(k));
			}
		}
		leadID = p.lead_id;
		trace(leadID);
		p.action = 'edit';
		//var eFields:Array<String> = vData.fields;
		//p.fields = parentView.vData.fields.split(',').filter(function(f:String) return (eFields.has(f) ? ;
		p.fields = (vData.fields != null ? vData.fields : parentView.vData.fields);
		trace(p);	
		//cMenu.active    cMenu.getIndexOf(vData.action));
		cMenu.active = cMenu.getIndexOf(p.action);
		trace(p.action + ':' + cMenu.active);
		cMenu.root.data('disabled', 1);
		loadData('server.php', p, update);		
	}
	
	function close()
	{
		trace('going to close:' + J('#overlay').length);
		cMenu.root.find('.recordings').remove();
		cMenu.root.data('disabled', 0);
		J(cMenu.attach2).find('tr').removeClass('selected');
		if (parentView.interactionState == 'call')
			cMenu.activePanel.find('button[data-contextaction="call"]').html('Anrufen');
		parentView.interactionState = 'init';
		//J('#overlay').animate( { opacity:0.0 }, 300, null, function() { J('#overlay').detach(); } );
		overlay.animate( { opacity:0.0 }, 300, null, function() { overlay.detach(); } );		
	}
	
	public function contextAction(action:String)
	{
		this.action = action;
		switch(action)
		{
			case 'close':
				close();
			case 'save', 'qcok':
				if (!checkIban())
				{
					checkAccountAndBLZ(function(ok:Bool)
					{
						trace (ok);
						if (ok)
						{
							//TODO: TEST THE CHANGE FROM ACTION TO ENDACTION
							if (parentView.interactionState == 'call')
								cMenu.hangup(this, function() save(action));
							else
								save(action);
						}
						else
						{
							App.inputError( J('#' + parentView.id + '-edit-form'), ['account','blz','iban'] );
						}
					});
				}
				else {
					if (parentView.interactionState == 'call')
						cMenu.hangup(this, function() save(action));
					else
						save(action);
				}
			case 'qcbad':
				if (parentView.interactionState == 'call')
					cMenu.hangup(this, function() save(action));
				else				
					save(action);
			case 'errsal':
				if (parentView.interactionState == 'call')
					cMenu.hangup(this, function() save(action));
				else				
					save(action);
			case 'call':
				if (parentView.interactionState == 'call')					
					cMenu.call(this, function() save(action));
				else
					cMenu.call(this);
			default:
				trace(action);
		}//DONE END ACTION CASE EDIT
	}
	
	function ready4save():Bool
	{
		var p:Array<FData> = new Array();
		p.push( { name:'className', value:'AgcApi' } );
		p.push( { name:'action', value:'check4Update' });
		p.push( { name:'lead_id', value:leadID } );
		var amReady:Bool = false;
		js.jquery.JQuery.ajax({
			type: 'POST',
			url: 'server.php',
			data: p,
			success: function(result) 
			{
				trace(result);
				try
				{
					if (result.response.state == 'XX')
					{
						trace('OK - XX HAS BEEN RESTORED');
						amReady = true;
					}				
				}
				catch (ex:Dynamic)
				{
					trace(ex);
				}

			},
			dataType: 'json',
			async:false
		});
		trace('returning $amReady');
		return amReady;
	}
	
	public function save(?status:String):Void
	{
		trace(parentView.interactionState);
		if (parentView.interactionState == 'call')
		{
			maxSaveLoop = 3;
			if (!ready4save())
			{//	SET WAIT TIMEOUT
				trace ("have to wait...");
				Timer.delay(function() save(status), 1500);
				maxSaveLoop--;
				return;				
			}
		}
		var p:Array<FData> = FormData.save(J('#' + parentView.id + '-edit-form'));
		trace(p);
		p.push( { name:'className', value:parentView.name });
		p.push( { name:'action', value:'save' } );
		p.push( { name:'user', value:App.user});
		p.push( { name:'primary_id', value: parentView.vData.primary_id} );
		p.push( { name:parentView.vData.primary_id, value: eData.attr('id') } );
		trace (status);
		switch (status)
		{
			case 'errsal':
			p.push( { name:'status', value: 'ERRSALE'});
			case 'qcok','qcbad','call':
			p.push( { name:'status', value: (status=='call' ? 'QCOPEN': status.toUpperCase()) });
		}
		if (parentView.vData.hidden != null)
		{							
			var hKeys:Array<String> = parentView.vData.hidden.split(',');
			for (k in hKeys)
			{
				if(eData.data(k) != null && p.foreach(function(jD:FData) return jD.name!=k))
					p.push( { name:k, value:eData.data(k) } );
			}													
		}
		//trace(p);
		parentView.loadData('server.php', p, function(data:Dynamic) { 
			trace(data +': ' + (data ? 'Y':'N'));
			if (data) {
				editCheck(eData);
			}
		});
	}
	
	override public function update(data:Dynamic):Void
	{
		parentView.wait(false);
		//primary_id,hidden,
		agent = data.agent;
		//trace(data.agent);
		//trace(data);
		var dataOptions:Dynamic = {};
		var keys:Array<String> = Reflect.fields(data.optionsMap);
		for (k in keys)
		{
			var opts:Array<Array<String>> = new Array();
			var optRows: Array<String> = Reflect.field(data.optionsMap, k).split('\r\n');
			for (r in optRows)
				opts.push(r.split(','));
			Reflect.setField(dataOptions, k, opts);
		}
		data.user = eData.data('owner');
		optionsMap = data.optionsMap = dataOptions;
		data.typeMap.buchungs_tag = 'TEXT';
		typeMap = data.typeMap;
		var dRows:Array<Dynamic> = data.rows;
		var fieldDefault:Dynamic = data.fieldDefault;
		for (row in dRows)
		{
			for (f in Reflect.fields(row))
			{
				if (Reflect.field(row,f)=='' && f != 'period'  && Reflect.hasField(fieldDefault, f))
					Reflect.setField(row, f, Reflect.field(fieldDefault, f));
			}
			
		}
		trace(data);
		//trace(data.typeMap);
		var r:EReg = ~/([a-z0-9_-]+.mp3)$/;
		var rData = { recordings:data.recordings.map(function(rec) {
				rec.filename = ( r.match(rec.location) ?  r.matched(1) : rec.location);
				return rec;
			})
		};
		var recordings:JQuery = J('#t-' + parentView.id + '-recordings').tmpl(rData);
		cMenu.activePanel.find('form').append(recordings);		

		var oMargin:Int = 8;
		var mSpace:Rectangle = App.getMainSpace();
		//FILL TEMPLATE AND SHOW EDITOR FORM OVERLAY
		overlay = templ.tmpl(data).appendTo('#' + parentView.id).css( {
			marginTop:Std.string(mSpace.top + oMargin ) + 'px',
			marginLeft:Std.string(oMargin ) + 'px',
			height:Std.string(mSpace.height - 2 * oMargin - Std.parseFloat(J('#overlay').css('padding-top')) -  Std.parseFloat(J('#overlay').css('padding-bottom'))) + 'px',
			width:Std.string( J('#'+parentView.vData.id+'-menu').offset().left - 35 ) + 'px'
		}).animate( { opacity:1 }, {
			done:function (el)
			{
				trace(J('#' + parentView.id).find('input[name="period"]').length);
				var unchecked = true;
				J('#' + parentView.id).find('input[name="period"]').each(function(i, n){
					trace(J(n).prop('checked'));
					if (J(n).prop('checked'))
					{						
						unchecked = false;
					}
				});
				if (unchecked)
				{
					J('#' + parentView.id).find('button:contains("Einmalspende")').css('color', 'rgb(114,150,100)');
				}
			}
		});
		trace(mSpace.height + ':' +  2 * oMargin + ':' + Std.parseFloat(J('#overlay').css('padding-top')) + ':' + Std.parseFloat(J('#overlay').css('padding-bottom')));
		J('#' + parentView.id +' .scrollbox').height(J('#' + parentView.id +' #overlay').height());
		trace(id + ':' + parentView.id + ':' + J('#' + parentView.id +' .scrollbox').length + ':' +   J('#' + parentView.id +' .scrollbox').height());
		//trace(overlay.html());
		//trace(data.recordings);

		//cMenu.root.accordion("refresh");
	}
	
}