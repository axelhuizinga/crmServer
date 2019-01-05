package model;
import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.Http;
import php.Lib;
import php.Web;
import sys.io.File;
using Util;
/**
 * ...
 * @author axel@cunity.me
 */
class AgcApi extends Model
{
	var vicidialUser:String;
	var vicidialPass:String;
	var statuses:StringMap<String>;
	
	public static function create(param:StringMap<String>):EitherType<String,Bool>
	{
		var self:AgcApi = new AgcApi(param);	
		self.vicidialUser = param.get('user_name');
		self.vicidialPass = S.vicidialPass;
		return Reflect.callMethod(self, Reflect.field(self, param.get('action')), [param]);
	}
	
	public function check4Update(param:StringMap<String>):EitherType<String,Bool>
	{
		var lead_id:Dynamic = Std.parseInt(param.get('lead_id'));
		trace(S.host + ':' + lead_id);
		//TODO: CATCH FAILURE
		return json_response(query('SELECT state FROM vicidial_list WHERE lead_id=$lead_id')[0]);
	}
	
	public function external_dial(param:StringMap<String>):EitherType<String,Bool>
	{
		//TODO: GET HOST FROM CONFIG OR SYSTEM
		var url:String = '${S.request_scheme}://${S.host}/agc/api.php?source=flyCRM&user=$vicidialUser&pass=$vicidialPass&function=external_dial&search=NO&preview=NO&focus=NO&lead_id='
		+ param.get('lead_id') + '&agent_user=' + param.get('agent_user');
		trace(url);
		var agcResponse:String = Http.requestUrl(url);
		trace(agcResponse);
		return json_response(agcResponse.indexOf('SUCCESS') == 0 ? 'OK' : agcResponse);
	}
	
	public function external_hangup(param:StringMap<String>):EitherType<String,Bool>
	{
		if(param.get('pause')=='Y')
			Http.requestUrl('${S.request_scheme}://${S.host}/agc/api.php?source=flyCRM&user=$vicidialUser&pass=$vicidialPass&function=external_pause&value=PAUSE&agent_user=' + param.get('agent_user'));
		var url:String = '${S.request_scheme}://${S.host}/agc/api.php?source=flyCRM&user=$vicidialUser&pass=$vicidialPass&function=external_hangup&value=1&agent_user=' + param.get('agent_user');
		trace(url);
		var agcResponse:String = Http.requestUrl(url);
		trace(agcResponse);
		if (agcResponse.indexOf('SUCCESS') == 0)
		{
			if (param.get('dispo').any2bool())
			{
				return external_status(param);
			}
			else
			{//	QUERY VALID STATI CHOICES
				var campaign_id:String = S.dbh.real_escape_string(param.get('campaign_id'));
				var sql = '(SELECT `status`,`status_name` FROM `vicidial_statuses` WHERE `selectable`="Y") UNION (SELECT `status`,`status_name` FROM `vicidial_campaign_statuses` WHERE `selectable`="Y" AND campaign_id="$campaign_id") ORDER BY `status`' ;				
				data =  {
					response:'OK',
					choice: query(sql)
				};
				 json_encode();
			}			
		}

		return json_response(agcResponse);		
	}
	
	public function external_status(param:StringMap<String>):EitherType<String,Bool>
	{
		var status:String = param.get('dispo');
		var url = '${S.request_scheme}://${S.host}/agc/api.php?source=flyCRM&user=$vicidialUser&pass=$vicidialPass&function=external_status&value=$status&agent_user=' + param.get('agent_user');
		trace(url);
		var agcResponse:String = Http.requestUrl(url);
		return json_response(agcResponse.indexOf('SUCCESS') == 0 ? 'OK' : agcResponse);
	}
	
	public function update_fields_x(param:StringMap<String>):EitherType<String,Bool>
	{
		var state:String = param.get('state');
		/*var user = param.get('agent_user');
		var url = '/agc/api.php?source=flyCRM&user=$vicidialUser&pass=$vicidialPass&function=update_fields&agent_user=$user&state=$state' ;
		trace(url);
		var agcResponse:String = Http.requestUrl(url);*/
		var lead_id:Dynamic = Std.parseInt(param.get('lead_id'));
		var agcResponse = S.dbh.query('UPDATE vicidial_list SET state="$state" WHERE lead_id=$lead_id');
		
		return json_response(agcResponse ? 'OK' : S.dbh.error);
		//return json_response(agcResponse.indexOf('SUCCESS') == 0 ? 'OK' : agcResponse);
	}
	
	
	
}