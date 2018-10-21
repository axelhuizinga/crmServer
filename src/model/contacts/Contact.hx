package model.contacts;
import comments.CommentString.*;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Json;
//import me.cunity.php.db.MySQLi;
//import me.cunity.php.db.MySQLi_Result;
//import me.cunity.php.db.MySQLi_STMT;
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
 class Contact extends Model
{
	private static var vicdial_list_fields = 'lead_id,entry_date,modify_date,status,user,vendor_lead_code,source_id,list_id,gmt_offset_now,called_since_last_reset,phone_code,phone_number,title,first_name,middle_initial,last_name,address1,address2,address3,city,state,province,postal_code,country_code,gender,date_of_birth,alt_phone,email,security_phrase,comments,called_count,last_local_call_time,rank,owner,entry_list_id'.split(',');		
	private static var contact_fields = 'client_id,lead_id,creation_date,state,use_email,register_on,register_off,register_off_to,teilnahme_beginn,title,anrede,namenszusatz,co_field,storno_grund,birth_date,old_active'.split(',');	
	
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
		sqlBf.add('SELECT ' + (fields != null ? fieldFormat( fields.split(',').map(function(f:String) return S.my.quote(f)).join(',') ): '*' ));
		var qTable:String = (q.get('table').any2bool() ? q.get('table') : table);
		var joinCond:String = (q.get('joincond').any2bool() ? q.get('joincond') : null);
		var joinTable:String = (q.get('jointable').any2bool() ? q.get('jointable') : null);
		//trace ('table:' + q.get('table') + ':' + (q.get('table').any2bool() ? q.get('table') : table) + '' + joinCond );
		//trace (sqlBf.toString());oh
		var filterTables:String = '';
		if (q.get('filter').any2bool() )
		{
			filterTables = q.get('filter_tables').split(',').map(function(f:String) return 'fly_crm.' + S.my.quote(f)).join(',');			
			sqlBf.add(' FROM $filterTables,' + S.my.quote(qTable));
		}
		else
			sqlBf.add(' FROM ' + S.my.quote(qTable));		
		//sqlBf.add(' FROM ' + S.my.quote(qTable));		
		if (joinTable != null)
			sqlBf.add(' INNER JOIN $joinTable');
		if (joinCond != null)
			sqlBf.add(' ON $joinCond');
		var where:String = q.get('where');
		if (where != null)
			buildCond(where);

		if (q.get('filter').any2bool())
		{			
			buildCond(q.get('filter').split(',').map( function(f:String) return 'fly_crm.' + S.my.quote(f) 
			).join(','), false);
			
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
		return execute(sqlBf.toString());
		//return execute(sqlBf.toString(), q, phValues);
	}
	
	public static function create(param:StringMap<String>):Void
	{
		var self:Contact = new Contact(param);	
		self.table = 'vicidial_list';
		//self.param = param;
		//trace(param);
		Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}
	
	override public function find(param:StringMap<String>):Void
	{	
		var sqlBf:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		trace(param);
		var count:Int = count(param);
		
		sqlBf = new StringBuf();
		phValues = new Array();
		trace( param.get('joincond')  +  ' count:' + count + ':' + param.get('page')  + ': ' + (param.exists('page') ? 'Y':'N'));
		data =  {
			count:count,
			page:(param.exists('page') ? Std.parseInt( param.get('page') ) : 1),
			rows: doJoin(param, sqlBf, phValues)
		};
		json_encode();
	}	
	
	public function edit(param:StringMap<Dynamic>):Void
	{
		
		 json_encode();		
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
	
	function save(q:StringMap<Dynamic>):Bool
	{
		var clientID = q.get('client_id');
		
		return false;
	}
	
	
	
}