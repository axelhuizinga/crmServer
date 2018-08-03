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

/**
 * ...
 * @author axel@cunity.me
 */
@:keep
class QC extends Clients
{
	private static var vicdial_list_fields = 'lead_id,entry_date,modify_date,status,user,vendor_lead_code,source_id,list_id,gmt_offset_now,called_since_last_reset,phone_code,phone_number,title,first_name,middle_initial,last_name,address1,address2,address3,city,state,province,postal_code,country_code,gender,date_of_birth,alt_phone,email,security_phrase,comments,called_count,last_local_call_time,rank,owner,entry_list_id'.split(',');
	 
	 
	public static function create(param:StringMap<String>):EitherType<String,Bool>
	{
		var self:QC = new QC(param);	
		self.table = 'vicidial_list';
		//trace(param);
		return Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}
		
	override public function edit(param:StringMap<Dynamic>):EitherType<String,Bool>
	{
		var entry_list_id:String = param.get('entry_list_id');
		var cF:Array<StringMap<String>> = getCustomFields(entry_list_id);
		var cFields:Array<String> = cF.map(function(field:StringMap<String>):String return field.get('field_label'));
		trace(cFields.join(','));
		//trace(cFields);
		//trace(param);
		var fieldDefault:StringMap<String> = new StringMap();
		var fieldNames:StringMap<String> = new StringMap();
		var fieldRequired:StringMap<Bool> = new StringMap();
		var typeMap:StringMap<String> = new StringMap();
		var optionsMap:StringMap<String> = new StringMap();
		//--->
		//var eF:StringMap<Array<StringMap<String>>> = getEditorFields().get('vicidial_list');
		var eF:Array<StringMap<String>> = getEditorFields().get('vicidial_list');

		for (f in eF)
		{
			/*var field:String = f.get('field_label');
			if (! cFields.has(field))
			{
				
				cFields.push(field);
				cF.push(f);
			}*/
			fieldNames.set(f.get('field_label'), f.get('field_name'));					
			if (f.get('field_options') != null)
				optionsMap.set(f.get('field_label'), f.get('field_options'));
			typeMap.set(f.get('field_label'), f.get('field_type'));
		}
		//
		//trace(cFields);
		//trace(fieldNames);
		//<---
		for (f in 0...cFields.length)
		{
			fieldNames.set(cFields[f], cF[f].get('field_name'));
			if (cF[f].get('field_options') != null)
				optionsMap.set(cFields[f], cF[f].get('field_options'));
			var def:Dynamic = cF[f].get('field_default');
			switch (def)
			{
				case null, 'NULL', '':
					//DO NOTHING
				default:
				fieldDefault.set(cFields[f], cF[f].get('field_default'));				
			}
			if(cF[f].get('field_required')=='Y')
				fieldRequired.set(cFields[f], true);					
			typeMap.set(cFields[f], cF[f].get('field_type'));
		}
		cFields.push('entry_date');
		param.set('fields', cFields);		
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		//trace(param);
		//trace(fieldNames);
		data =  {
			fieldDefault:Lib.associativeArrayOfHash(fieldDefault),
			fieldNames:Lib.associativeArrayOfHash(fieldNames),
			fieldRequired:Lib.associativeArrayOfHash(fieldRequired),
			rows: doSelectCustom(param, sqlBf, phValues),
			typeMap:Lib.associativeArrayOfHash(typeMap),
			optionsMap:Lib.associativeArrayOfHash(optionsMap),
			recordings:getRecordings(Std.parseInt(param.get('lead_id')))
		};
		var userMap:StringMap<String> = new StringMap();
		sqlBf = new StringBuf();
		phValues = new Array();		
		var p:StringMap<String> = new StringMap();
		p.set('table', 'vicidial_users');
		p.set('fields', 'user,full_name');
		p.set('where', 'user_group|AGENTS_A');
		//data.userMap = doSelect(p, sqlBf, phValues);
		trace(num_rows + ':' + param.get('owner'));
		data.userMap = new Users().get_info();
		//trace(new Users().get_info(param.get('owner')));
		//return false;
		return json_encode();		
	}
	
	override public function find(param:StringMap<String>):EitherType<String,Bool>
	{	
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		var count:Int = countJoin(param, sqlBf, phValues);
		trace(param);
		sqlBf = new StringBuf();
		phValues = new Array();
		trace( 'count:' + count + ':' + param.get('page')  + ': ' + (param.exists('page') ? 'Y':'N'));
		data =  {
			count:count,
			page:(param.exists('page') ? Std.parseInt( param.get('page') ) : 1),
			rows: doJoin(param, sqlBf, phValues)
		};
		return json_encode();
	}	
	
	public function doSelectCustom(q:StringMap<Dynamic>, sqlBf:StringBuf, phValues:Array<Array<Dynamic>>):NativeArray
	{
		var fields:Array<String> = q.get('fields');	
		//trace(fields);
		sqlBf.add('SELECT ' + (fields != null ? fieldFormat( fields.map(function(f:String) return S.my.real_escape_string(f)).join(',') ): '*' ));
		var entry_list_id:String = q.get('entry_list_id');
		var primary_id:String = S.my.real_escape_string(q.get('primary_id'));
		sqlBf.add(' FROM ' + S.my.real_escape_string(table) + ' AS vl INNER JOIN ' + S.my.real_escape_string('custom_' + entry_list_id) + ' AS cu ON vl.' + primary_id + '=cu.' +  primary_id);		
		buildCond('vl.' + primary_id + '|' + S.my.real_escape_string(q.get(q.get('primary_id'))) , sqlBf, phValues);
		//trace(phValues);		
		//trace(sqlBf.toString());		
		return execute(sqlBf.toString(), phValues);
		//return execute(sqlBf.toString(), q, phValues);
		return null;
	}	
	
	function errSale(q:StringMap<Dynamic>):Bool
	{
		var lead_id = Std.parseInt(q.get('lead_id'));
		var user:String = S.user;	
		
		var sql:String = comment(unindent, format) /**
            UPDATE vicidial_list SET status='NI', list_id=`entry_list_id` WHERE lead_id=$lead_id
        **/;
		query(sql);
		return S.my.affected_rows == 1;		
	}
		
	
	override public function save(q:StringMap<Dynamic>):Bool
	{
		var lead_id = Std.parseInt(q.get('lead_id'));
		var user:String = S.user;
		//RESET ERRSALES
		if (q.exists('status') && q.get('status') == 'ERRSALE')
			return errSale(q);
		var log_id:EitherType < Int, Bool > = false;
		if (log_id  = saveLog(q))
		{
			//SAVE QC DATA ONLY AFTER SUCCESSFUL LOG ENTRY
			var cTable:String = 'custom_' + q.get('entry_list_id');
			trace(cTable + ' log_id:' + log_id);
			var primary_id:String =  S.my.real_escape_string(q.get('primary_id'));
			var sql:StringBuf  = new StringBuf();
			sql.add('UPDATE $cTable SET ');
			var cFields = S.tableFields('$cTable');
			trace('$cTable fields:' + cFields.toString());
			cFields.remove(primary_id);
			var bindTypes:String = '';
			var values2bind:NativeArray = null;
			var i:Int = 0;
			var dbFieldTypes:StringMap<String> = Lib.hashOfAssociativeArray(Lib.associativeArrayOfObject(S.conf.get('dbFieldTypes')));
			var sets:Array<String> = new Array();
			for (c in cFields)
			{
				var val:Dynamic = q.get(c);
				if (val != null)
				{
					//TODO: MULTIVAL SELECT OR CHECKBOX
					if (c == 'period' && val == '') val = "''";
					values2bind[i++] = (Std.is(val,String) ? val: val[0] );
					var type:String = dbFieldTypes.get(c);
					bindTypes += (type.any2bool() ?  type : 's');	
					sets.push(c + '=?');
				}
			}
			sql.add(sets.join(','));
			sql.add(' WHERE lead_id=$lead_id');
			var stmt =  S.my.stmt_init();
			trace(sql.toString());
			trace(values2bind);
			var success:Bool = stmt.prepare(sql.toString());
			if (i>0 && !success)
			{
				trace(stmt.error);
				return false;
			}
			//success = untyped __call__('myBindParam', stmt, values2bind, bindTypes);
			success = (i>0 ? untyped __call__('myBindParam', stmt, values2bind, bindTypes):true);
			trace ('success:' + success);
			if (success)
			{
				success = (i==0 || stmt.execute());
				if (!success)
				{
					trace(stmt.error);
					return false;
				}			
				//CUSTOM SAVED || nothing custom to save?
				if (i == 0) trace('i:$i custom fields saved???');
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
				values2bind[i++] = S.user;
				bindTypes += 's';
				sets.push('security_phrase=?');//STORE QC AGENT
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
					trace('list_id:$list_id');
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
				trace('$i values:' );
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
					else
					{
						return saveLog(q, log_id) != false;
					}
				}			
				return false;
			}
		
		}
		else
			trace('oops');
			/*}
			
		}*/
		return false;
	}
	
	
}