package model;
import haxe.ds.StringMap;
import haxe.extern.EitherType;

import php.Lib;
import php.NativeArray;
import php.Web;

using Lambda;
using Util;

/**
 * ...
 * @author ...
 */
@:keep
class ClientHistory extends Clients
{
	private static var vicdial_list_fields = 'lead_id,entry_date,modify_date,status,user,vendor_lead_code,source_id,list_id,gmt_offset_now,called_since_last_reset,phone_code,phone_number,title,first_name,middle_initial,last_name,address1,address2,address3,city,state,province,postal_code,country_code,gender,date_of_birth,alt_phone,email,security_phrase,comments,called_count,last_local_call_time,rank,owner,entry_list_id'.split(',');		
	private static var clients_fields = 'client_id,lead_id,creation_date,state,use_email,register_on,register_off,register_off_to,teilnahme_beginn,title,namenszusatz,co_field,storno_grund,birth_date'.split(',');	
	private static var pay_source_fields = 'pay_source_id,client_id,lead_id,debtor,bank_name,account,blz,iban,sign_date,pay_source_state,creation_date'.split(',');
	private static var pay_plan_fields = 'pay_plan_id,client_id,creation_date,pay_source_id,target_id,start_day,start_date,buchungs_tag,cycle,amount,product,agent,pay_plan_state,pay_method,end_date,end_reason'.split(',');
	//private static var pay_source_fields = '';
	
	private static var custom_fields_map:StringMap<String> = [
		'title'=>'anrede',
		//'co_field'=>'addresszusatz',
		'geburts_datum'=>'birth_date',
	];
	
	public function addCond(where:Array<Dynamic>, phValues:Array<Array<Dynamic>>):String
	{
		if (where.length == 0)
			return '';
		var sqlBf:StringBuf = new StringBuf();
		
		//trace(where);

		var first:Bool = true;
		for (w in where)
		{
			
			var wData:Array<String> = w.split('|');
			var values:Array<String> = wData.slice(2);
			
			var filter_tables:Array<String> = null;
			if (param.any2bool() && param.exists('filter_tables') && param.get('filter_tables').any2bool())
			{
				var jt:String = param.get('filter_tables');
				filter_tables = jt.split(',');
			}
			
			trace(wData + ':' + joinTable + ':' +  filter_tables);
			if (~/^pay_[a-zA-Z_]+\./.match(wData[0]) && wData[0].split('.')[0] != joinTable )
			{
				continue;
			}
			
			if (first)
			{
				sqlBf.add(' WHERE ');
				first = false;
			}
			else
				sqlBf.add(' AND ');		
			
			switch(wData[1].toUpperCase())
			{
				case 'BETWEEN':
					if (!(values.length == 2) && values.foreach(function(s:String) return s.any2bool()))
						S.exit( 'BETWEEN needs 2 values - got only:' + values.join(','));
					sqlBf.add(quoteField(wData[0]));
					sqlBf.add(' BETWEEN ? AND ?');
					phValues.push([wData[0], values[0]]);
					phValues.push([wData[0], values[1]]);
				case 'IN':					
					sqlBf.add(quoteField(wData[0]));					
					sqlBf.add(' IN(');
					sqlBf.add( values.map(function(s:String) { 
						phValues.push([wData[0], values.shift()]);
						return '?'; 
						} ).join(','));							
					sqlBf.add(')');
				case 'LIKE':					
					sqlBf.add(quoteField(wData[0]));
					sqlBf.add(' LIKE ?');
					phValues.push([wData[0], wData[2]]);
				case _:
					sqlBf.add(quoteField(wData[0]));
					if (~/^(<|>)/.match(wData[1]))
					{
						var eR:EReg = ~/^(<|>)/;
						eR.match(wData[1]);
						var val = Std.parseFloat(eR.matchedRight());
						sqlBf.add(eR.matched(0) + '?');
						phValues.push([wData[0],val]);
						continue;
					}
					//PLAIN VALUE
					if( wData[1] == 'NULL' )
						sqlBf.add(" IS NULL");
					else {
						sqlBf.add(" = ?");
						phValues.push([wData[0],wData[1]]);	
					}			
			}			
		}
		return sqlBf.toString();
	}
	
	public static function create(param:StringMap<String>):EitherType<String,Bool>
	{
		var self:Clients = new ClientHistory(param);	
		self.table = 'vicidial_list';
		//trace(param);
		return Reflect.callMethod(self, Reflect.field(self,param.get('action')), [param]);
	}
	
	public function findClient(param:StringMap<Dynamic>,?dataOnly:Bool):EitherType<EitherType<NativeArray,String>,Bool>
	//public function findClient(param:StringMap<Dynamic>,?dataOnly:Bool):NativeArray
	{
		var sql:StringBuf = new StringBuf();
		var phValues:Array<Array<Dynamic>> = new Array();
		
		var cond:String = '';
		var limit:Int = param.get('limit');
		if (!limit.any2bool())
		{
			limit = untyped S.conf.get('sql')['LIMIT'];
			if (!limit.any2bool())
				limit = 15;
		}
		//
		var globalCond:String = '';
		var reasons:String = '';
		var where:String = param.get('where');
		if (where.length > 0)
		{
			var where:Array<Dynamic> = where.split(',');
			var whereElements:Array<Dynamic> = where.filter(function(el:Dynamic) return el.indexOf('reason') != 0);
			//trace(where);
			//var first:Bool = true;
			for (w in where)
			{
				var wData:Array<String> = w.split('|');
				switch(wData[0])
				{
					case 'reason':
					reasons = wData.slice(1).join(' ');
					//TODO: PROTECT
				}					
			}	
			if (whereElements.length>0)
				globalCond = addCond(whereElements, phValues);
		}
		
		
		
		sql.add('SELECT SQL_CALC_FOUND_ROWS * FROM(');
		var first:Bool = true;
		//### AC04 KONTO AUFGELOEST
		if (reasons.indexOf('AC04') > -1)
		{
			if (first)
				first = false;			
			sql.add('(SELECT d, e AS amount, SUBSTR(j,17,8) AS m_ID, z AS IBAN, "AC04" AS reason FROM `konto_auszug` WHERE i LIKE "%AC04 KONTO AUFGELOEST%" $cond  LIMIT 0,10000)');
			sql.add('UNION ');
			sql.add('(SELECT d, e AS amount, SUBSTR(k, 17, 8) AS m_ID, z AS IBAN, "AC04" AS reason FROM `konto_auszug` WHERE j LIKE "%AC04 KONTO AUFGELOEST%" $cond  LIMIT 0, 10000)');			
		}

		if (reasons.indexOf('AC01') > -1)
		{
			if (first)
				first = false;
			else
				sql.add('UNION ');
			//### AC01 IBAN FEHLERHAFT

			sql.add('(SELECT d, e AS amount, SUBSTR(j,17,8) AS m_ID, z AS IBAN, "AC01" AS reason FROM `konto_auszug` WHERE i LIKE "%AC01 IBAN FEHLERHAFT%" $cond  LIMIT 0,10000)');
			sql.add('UNION ');
			sql.add('(SELECT d, e AS amount, SUBSTR(k, 17, 8) AS m_ID, z AS IBAN, "AC01" AS reason FROM `konto_auszug` WHERE j LIKE "%AC01 IBAN FEHLERHAFT%" $cond  LIMIT 0, 10000)');		
		}

		if (reasons.indexOf('MD06') > -1)
		{	
			if (first)
				first = false;
			else			
				sql.add('UNION ');
			//### MD06 WIDERSPRUCH DURCH ZAHLER
			
			sql.add('(SELECT d, e AS amount, SUBSTR(j,17,8) AS m_ID, z AS IBAN, "MD06" AS reason FROM `konto_auszug` 
			WHERE (i LIKE "%MD06%" OR i LIKE "%AC06%"
			$cond  LIMIT 0,10000)');
			sql.add('UNION ');
			sql.add('(SELECT d, e AS amount, SUBSTR(k, 17, 8) AS m_ID, z AS IBAN, "MD06" AS reason FROM `konto_auszug` WHERE j LIKE "%MD06%" $cond  LIMIT 0, 10000)');		
		}

		if (reasons.indexOf('MS03') > -1)
		{			
			if (first)
				first = false;
			else			
				sql.add('UNION ');		
			//### MS03 SONSTIGE GRUENDE
			
			sql.add('(SELECT d, e AS amount, SUBSTR(j,17,8) AS m_ID, z AS IBAN, "MS03" AS reason FROM `konto_auszug` WHERE i LIKE "%MS03 SONSTIGE GRUENDE%" $cond  LIMIT 0,10000)');
			sql.add('UNION ');
			sql.add('(SELECT d, e AS amount, SUBSTR(k, 17, 8) AS m_ID, z AS IBAN, "MS03" AS reason FROM `konto_auszug` WHERE j LIKE "%MS03 SONSTIGE GRUENDE%" $cond  LIMIT 0, 10000)');		
		}
		sql.add(' )_lim $globalCond LIMIT $limit');
		
		S.my.select_db('fly_crm');
		var rows:NativeArray = execute(sql.toString(), phValues);
		if (dataOnly)
			return rows;
		data =  {
			count: untyped query('SELECT FOUND_ROWS()')[0]['FOUND_ROWS()'],
			page:(param.exists('page') ? Std.parseInt( param.get('page') ) : 1),
			rows: rows
		};
		
		return json_encode();
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
	
}