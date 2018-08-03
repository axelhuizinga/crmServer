package model;
import comments.CommentString.*;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Json;
import me.cunity.php.db.MySQLi;
import me.cunity.php.db.MySQLi_Result;
import me.cunity.php.db.MySQLi_STMT;
import php.Lib;
import php.NativeArray;
import php.Web;

using Lambda;
using Util;

typedef CustomField = 
{
	var field_label:String;
	var field_name:String;
	var field_type:String;
	//var rank:String;
	//var order:String;
	@:optional var field_options:String;
} 
/**
 * ...
 * @author axel@cunity.me
 */
@:keep
 class Clients extends Model
{
	private static var vicdial_list_fields = 'lead_id,entry_date,modify_date,status,user,vendor_lead_code,source_id,list_id,gmt_offset_now,called_since_last_reset,phone_code,phone_number,title,first_name,middle_initial,last_name,address1,address2,address3,city,state,province,postal_code,country_code,gender,date_of_birth,alt_phone,email,security_phrase,comments,called_count,last_local_call_time,rank,owner,entry_list_id'.split(',');		
	private static var clients_fields = 'client_id,lead_id,creation_date,state,use_email,register_on,register_off,register_off_to,teilnahme_beginn,title,anrede,namenszusatz,co_field,storno_grund,birth_date,old_active'.split(',');	
	private static var pay_history_fields = 'buchungsanforderungID,Mandat-ID,Betrag,Termin,tracking_status,Textschlüssel bzw. Zahlart'.split(',');
	private static var pay_source_fields = 'pay_source_id,client_id,lead_id,debtor,bank_name,account,blz,iban,sign_date,pay_source_state,creation_date'.split(',');
	private static var pay_plan_fields = 'pay_plan_id,client_id,creation_date,pay_source_id,target_id,start_day,start_date,buchungs_tag,cycle,amount,product,agent,pay_plan_state,pay_method,end_date,end_reason'.split(',');
	private static var booking_fields = ''.split(',');	
	
	
	private static var custom_fields_map:StringMap<String> = [
		'title'=>'anrede',
		//'co_field'=>'addresszusatz',
		'geburts_datum'=>'birth_date',
	];
	
	override public function doJoin(q:StringMap<String>, sqlBf:StringBuf, phValues:Array<Array<Dynamic>>):NativeArray
	{
		var fields:String = q.get('fields');	
		//trace(fields);
		//sqlBf.add('SELECT ' + fieldFormat((fields != null ? fields.split(',').map(function(f:String) return quoteField(f)).join(',') : '*' )));
		sqlBf.add('SELECT ' + (fields != null ? fieldFormat( fields.split(',').map(function(f:String) return S.my.real_escape_string(f)).join(',') ): '*' ));
		var qTable:String = (q.get('table').any2bool() ? q.get('table') : table);
		var joinCond:String = (q.get('joincond').any2bool() ? q.get('joincond') : null);
		var joinTable:String = (q.get('jointable').any2bool() ? q.get('jointable') : null);
		//trace ('table:' + q.get('table') + ':' + (q.get('table').any2bool() ? q.get('table') : table) + '' + joinCond );
		//trace (sqlBf.toString());oh
		var filterTables:String = '';
		if (q.get('filter').any2bool() )
		{
			filterTables = q.get('filter_tables').split(',').map(function(f:String) return 'fly_crm.' + S.my.real_escape_string(f)).join(',');			
			sqlBf.add(' FROM $filterTables,' + S.my.real_escape_string(qTable));
		}
		else
			sqlBf.add(' FROM ' + S.my.real_escape_string(qTable));		
		//sqlBf.add(' FROM ' + S.my.real_escape_string(qTable));		
		if (joinTable != null)
			sqlBf.add(' INNER JOIN $joinTable');
		if (joinCond != null)
			sqlBf.add(' ON $joinCond');
		var where:String = q.get('where');
		if (where != null)
			buildCond(where, sqlBf, phValues);

		if (q.get('filter').any2bool())
		{			
			buildCond(q.get('filter').split(',').map( function(f:String) return 'fly_crm.' + S.my.real_escape_string(f) 
			).join(','), sqlBf, phValues, false);
			
			if (joinTable == 'vicidial_users')
				sqlBf.add(' ' + filterTables.split(',').map(function(f:String) return 'AND $f.client_id=vicidial_list.vendor_lead_code').join(' '));
			else
				sqlBf.add(' ' + filterTables.split(',').map(function(f:String) return 'AND $f.client_id=clients.client_id').join(' '));
			//sqlBf.add(' ' + filterTables.split(',').map(function(f:String) return 'AND $f.client_id=clients.client_id').join(' '));
		}
		
		var groupParam:String = q.get('group');
		if (groupParam != null)
			buildGroup(groupParam, sqlBf);
		//TODO:HAVING
		var order:String = q.get('order');
		if (order != null)
			buildOrder(order, sqlBf);
		var limit:String = q.get('limit');
		buildLimit((limit == null?'15':limit), sqlBf);	//	TODO: CONFIG LIMIT DEFAULT
		return execute(sqlBf.toString(), phValues);
		//return execute(sqlBf.toString(), q, phValues);
	}
	
	public static function create(param:StringMap<String>):EitherType<String,Bool>
	{
		var self:Clients = new Clients(param);	
		self.table = 'vicidial_list';
		//self.param = param;
		//trace(param);
		return Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}
	
	override public function find(param:StringMap<String>):EitherType<String,Bool>
	{	
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		trace(param);
		var count:Int = countJoin(param, sqlBf, phValues);
		
		sqlBf = new StringBuf();
		phValues = new Array();
		trace( param.get('joincond')  +  ' count:' + count + ':' + param.get('page')  + ': ' + (param.exists('page') ? 'Y':'N'));
		data =  {
			count:count,
			page:(param.exists('page') ? Std.parseInt( param.get('page') ) : 1),
			rows: doJoin(param, sqlBf, phValues)
		};
		return json_encode();
	}	
	
	public function edit(param:StringMap<Dynamic>):EitherType<String,Bool>
	{
		var entry_list_id:String = S.my.real_escape_string(param.get('entry_list_id'));
		var fieldNames:StringMap<String> = new StringMap();
		//var typeMap:StringMap<String> = new StringMap();
		var typeMap:StringMap<String> = ['buchungsanforderungID'=>'HIDDEN','Mandat-ID'=>'TEXT','Betrag'=>'TEXT','Termin'=>'TEXT'];
		var optionsMap:StringMap<String> = ['anrede' => 'Frau,Frau\r\nHerr,Herr\r\nFamilie,Familie\r\nFirma,Firma'];//new StringMap();		
		var eF:StringMap<Array<StringMap<String>>> = getEditorFields();
		//trace(eF);
		var keys:Iterator<String> = eF.keys();		
		var tableNames:Array<String> = new Array();
		var tableFields:StringMap<Array<String>> = new StringMap();
		
		trace(param);
		while (keys.hasNext())
		{
			var k:String = keys.next();
			//trace(k);
			tableNames.push(k);
			var aFields:Array<StringMap<String>> = eF.get(k);
			//trace(aFields);
			var cFields:Array<String> = aFields.map(function(field:StringMap<String>):String return field.get('field_label'));
			//trace(cFields);
			tableFields.set(k, cFields);
			for (f in 0...cFields.length)
			{
				fieldNames.set(cFields[f], aFields[f].get('field_name'));					
				if (aFields[f].get('field_options') != null)
					optionsMap.set(cFields[f], aFields[f].get('field_options'));
				typeMap.set(cFields[f], aFields[f].get('field_type'));
			}			
		}
		trace(tableNames);
		//trace(tableFields);
		var editTables:StringMap<StringMap<String>> = new StringMap();
		var ti:Int = 0;
		tableNames.remove('vicidial_list');
		tableNames.push('buchungs_anforderungen');
		for (table in tableNames)
		{
			var p:StringMap<String> = new StringMap();
			var sqlBf:StringBuf = new StringBuf();
			var phValues:Array<Array<Dynamic>> = new Array();
			p.set('primary_id', param.get('primary_id'));
			//FETCH VICIDIAL DATA ALONG WITH MEMBER DATA
			switch(table) {
			case 'clients':			
				p.set('table', 'vicidial_list');
				p.set('jointable', 'fly_crm.' + table);
				//p.set('joincond', 'vicidial_list.lead_id=fly_crm.clients.lead_id');
				p.set('joincond', param.get('joincond'));
				p.set('fields', param.get('fields').split(',').map(function(f:String) return (f.indexOf('vicidial_list.') !=0 ? 'vicidial_list.' + f:f)).join(',')
					+ ',' + tableFields.get(table).map(function(f:String) return table + '.' + f).join(','));
				p.set('where', 'vicidial_list.lead_id|' + Std.parseInt(param.get('lead_id')));
				editTables.set(table, Lib.hashOfAssociativeArray(doJoin(p, sqlBf, phValues)));
				trace(editTables);
			case 'buchungs_anforderungen':
				p.set('table', 'fly_crm.'+ table);
				p.set('fields', pay_history_fields.map(function(el:String) return '`$el`').join(','));
				p.set('where', '`Mandat-ID`|LIKE|' +  Std.parseInt(param.get('client_id')) + '_1');
				//var limit = p.get('limit');
				p.set('limit', '2400');// WE NEED ALL ENTRIES IN THE PAY HISTORY HERE
				editTables.set('pay_history', Lib.hashOfAssociativeArray(doSelect(p, sqlBf, phValues)));
				//if(limit != null)
					//p.set('limit', limit);
			default:
				p.set('table', (table == 'vicidial_list'?table:'fly_crm.'+ table));
				p.set('fields', tableFields.get(table).join(','));
				if (table == 'vicidial_list')
				p.set('where', 'vendor_lead_code|' +  Std.parseInt(param.get('client_id')));
				else
				p.set('where', 'client_id|' +  Std.parseInt(param.get('client_id')));
				editTables.set(table, Lib.hashOfAssociativeArray(doSelect(p, sqlBf, phValues)));
			
			//trace(p);			
			if(table == 'pay_source')
				trace(tableFields.get(table));
			}
		}
		var recordings:NativeArray = getRecordings(Std.parseInt(param.get('lead_id')));
		editTables.set('konto_auszug', Lib.hashOfAssociativeArray(cast( new ClientHistory().findClient(
			["where" => 'reason|AC01 AC04 AC06 MD06 MS03,m_ID|' +  Std.parseInt(param.get('client_id')),"limit"=>150], true),NativeArray)));
		//me.cunity.php.NArray.push(, cData);
		data =  {
			fieldNames:Lib.associativeArrayOfHash(fieldNames),
			editData:Lib.associativeArrayOfHash(editTables),
			typeMap:Lib.associativeArrayOfHash(typeMap),
			optionsMap:Lib.associativeArrayOfHash(optionsMap),
			recordings:recordings
		};
		var userMap:StringMap<String> = new StringMap();
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();		
		var p:StringMap<String> = new StringMap();
		p.set('table', 'asterisk.vicidial_users');
		p.set('fields', 'user,full_name');
		p.set('where', 'user_group|AGENTS_A');
		var owner:Int = Std.parseInt(Lib.hashOfAssociativeArray(untyped editTables.get('clients').get('0')).get('owner'));
		trace(owner);
		//TODO: CHECK WE SHOULDNT NEED TO PULL THE USERMAP HERE
		data.userMap = new Users().get_info();
		//data.userMap = new Users().get_info(owner<1000?Std.string(owner):null);
		return json_encode();		
	}
	
	function getCustomFields(list_id:String):Array<StringMap<String>>
	{
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		var param:StringMap<String> = new StringMap();
		param.set('table', 'vicidial_lists_fields');
		param.set('where', 'list_id|' + S.my.real_escape_string(list_id));
		param.set('fields', 'field_name,field_label,field_type,field_options,field_required,field_default');
		param.set('order', 'field_rank,field_order');
		param.set('limit', '100');
		//trace(param);
		var cFields:Array<Dynamic> = Lib.toHaxeArray( doSelect(param, sqlBf, phValues));
		trace(cFields.length);
		var ret:Array<StringMap<String>> = new Array();
		for (cf in cFields)
		{
			//trace(cf);
			var field:StringMap<String> = Lib.hashOfAssociativeArray(cf);
			//trace(field.get('field_label')+ ':' + field);
			ret.push(field);
		}
		//trace(ret);
		return ret;
	}
	
	function getRecordings(lead_id:Int):NativeArray
	{
		var records:Array<Dynamic> = Lib.toHaxeArray(query("SELECT location ,  start_time, length_in_sec FROM recording_log WHERE lead_id = " 
		+ Std.string(lead_id) + ' ORDER BY start_time DESC'));
		var rc:Int = num_rows;
		trace ('$rc == ' + records.length);
		//TODO: CONFIG FOR MIN LENGTH_IN_SEC, NUM_DISPLAY FOR RECORDINGS	
		return Lib.toPhpArray(records.filter(function(r:Dynamic) return untyped Lib.objectOfAssociativeArray(r).length_in_sec > 60));		
	}
	
	public function saveLog(q:StringMap<Dynamic>, ref_id:Int = 0):EitherType < Int, Bool >
	{
		var lead_id = Std.parseInt(q.get('lead_id'));
		var user:String = S.user;
		//COPY LEAD TO VICIDIAL_LEAD_LOG + CUSTOM_LOG
		if( S.my.query(
			'INSERT INTO vicidial_lead_log SELECT * FROM (SELECT NULL AS log_id,$lead_id AS lead_id,NOW() AS entry_date) AS ll JOIN (SELECT modify_date,status,user,vendor_lead_code,source_id,list_id,gmt_offset_now,called_since_last_reset,phone_code,phone_number,title,first_name,middle_initial,last_name,address1,address2,address3,city,state,province,postal_code,country_code,gender,date_of_birth,alt_phone,email,security_phrase,comments,called_count,last_local_call_time,rank,owner,entry_list_id,$user AS log_user,$ref_id as ref_id FROM `vicidial_list` WHERE `lead_id`=$lead_id)AS vl'
		))
		{
			var cTable:String = 'custom_' + q.get('entry_list_id');
			var log_id:Int = S.my.insert_id;
			//trace(cTable + ' log_id:' + log_id);
			if (checkOrCreateCustomTable(cTable))
			{
				var cLogTable =  cTable + '_log';
				S.my.query(
					'INSERT INTO $cLogTable SELECT * FROM (SELECT $log_id AS log_id) AS ll JOIN (SELECT * FROM `$cTable` WHERE `lead_id`=$lead_id)AS cl'
				);
				trace ('INSERT INTO $cLogTable ...' + S.my.error + '<');
				if (S.my.error == '')
					return log_id;
			}
		}
		return false;
	}
	
	public function savePayBack(q:StringMap<Dynamic>):EitherType<String, Bool>
	{
		trace(q);
		var client_id:String =  S.my.real_escape_string(q.get('client_id'));
		var amount:Int = Std.parseInt(q.get('Betrag'));
		var buchungs_datum = S.my.real_escape_string(q.get('buchungs_datum'));
		var verwendungszweck:String = S.my.real_escape_string(q.get('verwendungszweck'));
		var crm_db:String = (q.exists('crm_db') ? S.my.real_escape_string(q.get('crm_db')) : 'fly_crm');
		var sql:String = comment(unindent, format)
		/*
		INSERT IGNORE $crm_db.buchungs_anforderungen
		SELECT pt.name, pt.iban, pt.bic, ps.debtor, '', '', '',  ps.iban, '', $amount, '', 'SEPA',
			'$buchungs_datum',
		CONCAT('MITGLIEDS-NR. ',ps.client_id),'$verwendungszweck',
		'','','','','','','',NULL,'neu',
		CURDATE(),'0000-00-00', 
		'once','', 
		CONCAT(pp.client_id,pp.product,'1'), ps.sign_date,'DE28ZZZ00001362509','', '' 
		FROM $crm_db.pay_source AS ps, $crm_db.pay_target AS pt, $crm_db.pay_plan AS pp 
		INNER JOIN $crm_db.clients cl ON cl.client_id=pp.client_id  
		WHERE pp.client_id=ps.client_id
		AND pp.pay_source_id=ps.pay_source_id
		AND pt.id=1 AND cl.client_id = $client_id 
		*/;
		query(sql);
		if (S.my.error == '')
		{
			return json_response('OK');
		}
		return false;
	}
	
	public function save(q:StringMap<Dynamic>):Bool
	{
		var lead_id = Std.parseInt(q.get('lead_id'));
		//var res:EitherType < MySQLi_Result, Bool > = saveLog(q);
		//var log_id:Int = S.my.insert_id;
		//if (res.any2bool() && log_id > 0)
		var ref_id:EitherType < Int, Bool > = false;
		if (ref_id = saveLog(q))
		{
			var cTable:String = 'custom_' + q.get('entry_list_id');
			//trace(cTable + ' log_id:' + log_id);
			//SAVE CLIENT DATA
			var primary_id:String =  S.my.real_escape_string(q.get('primary_id'));
			var sql:StringBuf  = new StringBuf();
			sql.add('UPDATE $cTable SET ');
			var cFields = S.tableFields('$cTable');
			trace('$cTable fields:' + cFields.toString());
			cFields.remove('lead_id');
			cFields.remove(primary_id);
			var bindTypes:String = '';
			var values2bind:NativeArray = null;
			var i:Int = 0;
			var dbFieldTypes:StringMap<String> = Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject(S.conf.get('dbFieldTypes')));
			var sets:Array<String> = new Array();
			for (c in cFields)
			{
				var val:Dynamic = q.get(c);
				trace(c + ':' + custom_fields_map.get(c) + ':$val ' + custom_fields_map.get(c).any2bool());
				//if (val != null)
				if (val != null)
				{
					//TODO: MULTIVAL SELECT OR CHECKBOX custom_fields_map
					values2bind[i++] = (Std.is(val,String) ? val: val[0] );
					var type:String = dbFieldTypes.get(c);
					bindTypes += (type.any2bool() ?  type : 's');	
					sets.push( (custom_fields_map.get(c).any2bool() ? custom_fields_map.get(c) : c ) + '=?');
				}
			}
			var customFields2Save:Bool = false;
			var success:Bool = false;
			var stmt =  S.my.stmt_init();
			if (sets.length > 0)
			{
				customFields2Save = true;
				sql.add(sets.join(','));
				sql.add(' WHERE lead_id=$lead_id');						
				trace(sql.toString());
				success = stmt.prepare(sql.toString());					
			}
			else success = true;
			if (!success)
			{
				trace(stmt.error);
				return false;
			}
			if (customFields2Save)
			{
				success = untyped __call__('myBindParam', stmt, values2bind, bindTypes);						
			}
			else
				success = true;
			//trace ('success:' + success);
			if (success)
			{
				if (customFields2Save)
				{						
					success = stmt.execute();
					if (!success)
					{
						trace(stmt.error);
						return false;
					}			
					//CUSTOM SAVED 
				}
				sql = new StringBuf();
				var uFields = vicdial_list_fields;
				uFields.remove(primary_id);
				bindTypes = '';
				values2bind = null;
				i = 0;						
				sql.add('UPDATE vicidial_list SET ');
				sets  = new Array();
				for (c in uFields)
				{
					var val:Dynamic = q.get(c);
					if (val != null)
					{
						//TODO: MULTIVAL
						values2bind[i++] = (Std.is(val,String) ? val: val[0] );
						var type:String = dbFieldTypes.get(c);
						bindTypes += (type.any2bool() ?  type : 's');	
						sets.push(c + '=?');
					}
				}
				values2bind[i++] = 'XX';
				bindTypes += 's';						
				sets.push('state=?');//RESTORE SAVING FLAG
				if (q.get('status') == 'QCOK' || q.get('status') == 'QCBAD')
				{//	MOVE INTO MITGLIEDER LISTE (10000) OR QCBAD (1800)
					var list_id:Int = 10000;
					if (q.get('status') == 'QCOK') 
					{
						var mID:Int = Std.parseInt(q.get('vendor_lead_code'));
						if (mID == null)//	NEW MEMBER - CREATE ID
						{								
							mID = S.newMemberID();
							values2bind[i++] = mID;
							bindTypes += 's';
							sets.push('vendor_lead_code=?');								
						}								
					}
					else
						list_id = 1800;

					var entry_list_id:String = q.get('entry_list_id');
					values2bind[i++] = q.get('status');
					bindTypes += 's';
					sets.push('`status`=?');
					values2bind[i++] = list_id;
					bindTypes += 's';
					sets.push('list_id=?');	
					values2bind[i++] = entry_list_id;
					bindTypes += 's';
					sets.push('entry_list_id=?');	
					values2bind[i++] = q.get('owner');
					bindTypes += 's';
					sets.push('owner=?');							
				}
				sql.add(sets.join(','));
				sql.add(' WHERE lead_id=$lead_id');
				var stmt =  S.my.stmt_init();
				trace(sql.toString());
				var success:Bool = stmt.prepare(sql.toString());
				if (!success)
				{
					trace(stmt.error);
					return false;
				}
				//trace(' values:' );
				//trace(values2bind);
				success = untyped __call__('myBindParam', stmt, values2bind, bindTypes);
				trace ('success:' + success);
				if (success)
				{
					success = stmt.execute();
					if (!success)
					{
						trace(stmt.error);
						return false;
					}		
					if ( !saveClientData(q))
					{
						trace('oops:' + S.my.error);
					}
					else
					{
						return saveLog(q, ref_id) != false;
					}
				}
				else
					trace('oops:' + S.my.error);
			}
			
		}
		return false;
	}
	
	function saveClientDataLog(q:StringMap<Dynamic>, ref_id:Int = 0):EitherType < Int, Bool >
	{
		var clientID = q.get('client_id');
		var user:String = S.user;
		var res:EitherType < MySQLi_Result, Bool > = S.my.query('INSERT INTO fly_crm.client_log SELECT client_id,lead_id,creation_date,state,pay_obligation,use_email,register_on,register_off,register_off_to,teilnahme_beginn,title,anrede,namenszusatz,co_field,storno_grund,birth_date,old_active,$user AS log_user,NULL AS log_date,$ref_id AS ref_id, NULL as log_id FROM fly_crm.clients WHERE client_id=$clientID');
		if (!res.any2bool())
		{
			trace('failed to: INSERT INTO fly_crm.client_log SELECT client_id,lead_id,creation_date,state,pay_obligation,use_email,register_on,register_off,register_off_to,teilnahme_beginn,title,namenszusatz,co_field,storno_grund,birth_date,old_active,$user AS log_user,NULL AS log_date,$ref_id AS ref_id, NULL as log_id FROM fly_crm.clients WHERE client_id=$clientID');
			return false;
		}
		return cast S.my.insert_id;
	}
	
	function saveClientData(q:StringMap<Dynamic>):Bool
	{
		var clientID = q.get('client_id');
		var log_id:EitherType < Int, Bool > = saveClientDataLog(q);
		if (clientID == null || !log_id)
			return false;
		//var res:EitherType < MySQLi_Result, Bool > = S.my.query('INSERT INTO fly_crm.client_log SELECT client_id,lead_id, creation_date,`state`,pay_obligation,comments,use_email,register_on,register_off,register_off_to,teilnahme_beginn,title,namenszusatz,co_field,storno_grund, NULL AS log_date FROM fly_crm.clients WHERE client_id=$clientID');

		var sql:StringBuf = new StringBuf();
		var uFields:Array<String> = clients_fields;
		uFields.remove('client_id');
		var bindTypes:String = '';
		var values2bind:NativeArray = null;
		var i:Int = 0;
		var dbFieldTypes:StringMap<String> = Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject(S.conf.get('dbFieldTypes')));
		var sets:Array<String> = new Array();				
		sql.add('UPDATE fly_crm.clients SET ');
		for (c in uFields)
		{
			var val:Dynamic = q.get(c);
			if (val != null)
			{
				//TODO: MULTIVAL
				values2bind[i++] = (Std.is(val,String) ? val: val[0] );
				var type:String = dbFieldTypes.get(c);
				bindTypes += (type.any2bool() ?  type : 's');	
				sets.push(c + '=?');
			}
		}
		if (sets.length == 0)
		{
			return true;
		}
		sql.add(sets.join(','));
		sql.add(' WHERE client_id=$clientID');
		var stmt =  S.my.stmt_init();
		trace(sql.toString());
		var success:Bool = stmt.prepare(sql.toString());
		if (!success)
		{
			trace(stmt.error);
			return false;
		}
		//trace(' values:' );
		trace(values2bind);
		success = untyped __call__('myBindParam', stmt, values2bind, bindTypes);
		trace ('success:' + success);
		if (success)
		{
			success = stmt.execute();
			if (!success)
			{
				trace(stmt.error);
				return false;
			}		
			return saveClientDataLog(q,log_id) !=false;
		}			
		return false;
	}
	
	public function save_pay_plan_log(pay_plan_id:Int, ref_id:Int=0):EitherType < Int, Bool >
	{
		var user = S.user;
		var res:EitherType < MySQLi_Result, Bool > = S.my.query('INSERT INTO fly_crm.pay_plan_log SELECT pay_plan_id,client_id,creation_date,pay_source_id,target_id,start_day,start_date,buchungs_tag,cycle,amount,product,agent,agency_project,pay_plan_state,pay_method,end_date,end_reason,repeat_date,$user AS log_user,NOW() AS log_date,$ref_id AS ref_id, NULL as log_id FROM fly_crm.pay_plan WHERE pay_plan_id=$pay_plan_id');
		if (!res.any2bool())
		{
			trace ('Failed to:  INSERT INTO fly_crm.pay_plan_log SELECT pay_plan_id,client_id,creation_date,pay_source_id,target_id,start_day,start_date,buchungs_tag,cycle,amount,product,agent,pay_plan_state,pay_method,end_date,end_reason,repeat_date,$user AS log_user,NOW() AS log_date,$ref_id AS ref_id, NULL as log_id FROM fly_crm.pay_plan WHERE pay_plan_id=$pay_plan_id');
			return false;
		}
		return cast S.my.insert_id;
	}
	
	public function save_pay_plan(q:StringMap<Dynamic>):Bool
	{
		//var product:Array<Dynamic> = Lib.hashOfAssociativeArray(q.get('product'));
		var product:StringMap<Dynamic> = Lib.hashOfAssociativeArray(q.get('product'));
		var user:String = S.user;
		//trace(product + ':' + product.length);
		trace(product + ':' + product.count() + ':' + product.keys().hasNext());
		//return true;
		//for (i in 0...product.length)
		var pIt:Iterator<Dynamic> = product.keys();
		while(pIt.hasNext())
		{
			var pay_plan_id = pIt.next();
			var log_id:EitherType < Int, Bool > = save_pay_plan_log(pay_plan_id);
			trace(log_id);
			// SAVE TO LOG
			if (!log_id)
				return false;
			var sql:StringBuf = new StringBuf();
			var uFields:Array<String> = pay_plan_fields;
			uFields.remove('pay_plan_id');
			var bindTypes:String = '';
			var values2bind:NativeArray = null;
			var i:Int = 0;
			var dbFieldTypes:StringMap<String> = Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject(S.conf.get('dbFieldTypes')));
			var sets:Array<String> = new Array();				
			sql.add('UPDATE fly_crm.pay_plan SET ');
			for (c in uFields)
			{
				trace(c + ':' + Type.typeof(q.get(c)));
				var p = q.get(c);
				var val:Dynamic = null;
				if (p != null)
				{
					if (!Std.is(p, String))
					{
						var valMap:StringMap<Dynamic> = Lib.hashOfAssociativeArray(q.get(c));
						val  = valMap.get(Std.string(pay_plan_id));
					}
					else
					{
						val = p;
					}					
					//TODO: MULTIVAL
					values2bind[i++] = val;
					var type:String = dbFieldTypes.get(c);
					bindTypes += (type.any2bool() ?  type : 's');	
					sets.push(c + '=?');
				}
			}
			if (sets.length == 0)
			{
				continue;
			}
			sql.add(sets.join(','));
			sql.add(' WHERE pay_plan_id=$pay_plan_id');
			var stmt =  S.my.stmt_init();
			trace(sql.toString());
			var success:Bool = stmt.prepare(sql.toString());
			if (!success)
			{
				trace(stmt.error);
				return false;
			}
			//trace(' values:' );
			trace(values2bind);
			success = untyped __call__('myBindParam', stmt, values2bind, bindTypes);
			trace ('success:' + success);
			if (success)
			{
				success = stmt.execute();
				if (!success)
				{
					trace(stmt.error);
					return false;
				}		
				save_pay_plan_log(pay_plan_id, log_id);
				if(!pIt.hasNext())
					return true;
			}			
		}
		return false;
	}

	public function save_pay_source_log(pay_source_id:Int, ref_id:Int=0):EitherType < Int, Bool >
	{
		var user = S.user;
		var res:EitherType < MySQLi_Result, Bool > = S.my.query('INSERT INTO fly_crm.pay_source_log SELECT  pay_source_id,client_id,lead_id,debtor,bank_name,account,blz,iban,sign_date,pay_source_state,creation_date,$user AS log_user,NOW() AS log_date,$ref_id AS ref_id, NULL as log_id FROM fly_crm.pay_source WHERE pay_source_id=$pay_source_id');
		if (!res.any2bool())
		{
			trace('Failed to:  INSERT INTO fly_crm.pay_source_log SELECT pay_source_id,client_id,lead_id,debtor,bank_name,account,blz,iban,sign_date,pay_source_state,creation_date,$user AS log_user,NOW() AS log_date,$ref_id AS ref_id, NULL as log_id FROM fly_crm.pay_source WHERE pay_source_id=$pay_source_id');
			return false;
		}		
		return cast S.my.insert_id;
	}
	
	public function save_pay_source(q:StringMap<Dynamic>):Bool
	{
		var account:StringMap<Dynamic> = Lib.hashOfAssociativeArray(q.get('account'));
		//trace(account + ':' + account.length);
		trace(account + ':' + account.count);
		//return true;
		//for (i in 0...account.length)
		var pIt:Iterator<Dynamic> = account.keys();
		var user:String = S.user;
		while(pIt.hasNext())
		{
			var pay_source_id = pIt.next();
			// SAVE TO LOG
			var log_id:EitherType < Int, Bool > = save_pay_source_log(pay_source_id);
			if (!log_id)
				return false;
			var sql:StringBuf = new StringBuf();
			var uFields:Array<String> = pay_source_fields;
			uFields.remove('pay_source_id');
			var bindTypes:String = '';
			var values2bind:NativeArray = null;
			var i:Int = 0;
			var dbFieldTypes:StringMap<String> = Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject(S.conf.get('dbFieldTypes')));
			var sets:Array<String> = new Array();				
			sql.add('UPDATE fly_crm.pay_source SET ');
			for (c in uFields)
			{
				trace(c + ':' + Type.typeof(q.get(c)));
				var p = q.get(c);
				var val:Dynamic = null;
				if (p != null)
				{
					if (!Std.is(p, String))
					{
						var valMap:StringMap<Dynamic> = Lib.hashOfAssociativeArray(q.get(c));
						val  = valMap.get(Std.string(pay_source_id));
					}
					else
					{
						val = p;
					}					
					//TODO: MULTIVAL
					values2bind[i++] = val;
					var type:String = dbFieldTypes.get(c);
					bindTypes += (type.any2bool() ?  type : 's');	
					sets.push(c + '=?');
				}
			}
			if (sets.length == 0)
			{
				continue;
			}
			sql.add(sets.join(','));
			sql.add(' WHERE pay_source_id=$pay_source_id');
			var stmt =  S.my.stmt_init();
			trace(sql.toString());
			var success:Bool = stmt.prepare(sql.toString());
			if (!success)
			{
				trace(stmt.error);
				return false;
			}
			//trace(' values:' );
			trace(values2bind);
			success = untyped __call__('myBindParam', stmt, values2bind, bindTypes);
			trace ('success:' + success);
			if (success)
			{
				success = stmt.execute();
				if (!success)
				{
					trace(stmt.error);
					return false;
				}		
				save_pay_source_log(pay_source_id, log_id);
				if(!pIt.hasNext())
					return true;
			}			
		}
		return false;
	}
	
	function checkOrCreateCustomTable(srcTable:String, ?suffix:String='log'):Bool
	{
		var newTable:String = S.my.real_escape_string(srcTable + '_' + suffix);
		//trace('SHOW TABLES LIKE  "$newTable"');
		var res:MySQLi_Result = S.my.query('SHOW TABLES LIKE  "$newTable"');
		if (res.any2bool() && res.num_rows == 0)
		{
			trace('CREATE TABLE `$newTable` like `$srcTable`');
			var res:EitherType < MySQLi_Result, Bool > = S.my.query('CREATE TABLE `$newTable` like `$srcTable`');
			if (S.my.error == '')
			{
				res = S.my.query('ALTER TABLE $newTable DROP PRIMARY KEY, ADD `log_id` INT(9) NOT NULL  FIRST,  ADD  PRIMARY KEY (`log_id`)');
				if (S.my.error != '')
					S.exit(S.my.error);
				return true;
			}
			else S.exit(S.my.error);
		}
		else trace('num_rows:' + res.num_rows);
		return true;
	}
	
}