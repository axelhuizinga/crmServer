package model;

import haxe.ds.StringMap.StringMap<String>;

/**
 * ...
 * @author ...
 */

@:enum 
abstract BookingType(String)
{
	var akonto = 'akonto';
	var rlast = 'rlast';
	var gutschrift = 'gutschrift';
}

class AgencyBooking extends Model 
{
	private static var booking_fields = 'id,entry_date,agency_project,start_datum,betrag,typ,user';
	
	public function new(?param:StringMap<String>) 
	{
		super(param);		
	}
	
	public function book()
	{
		var agency_project = Std.parseInt(param.get('agency_project'));
		var betrag = Std.parseFloat(param.get('betrag'));
		var start_datum =  S.dbh.real_escape_string(param.get('start_datum'));
		var user:String = S.user;
		var sB:StringBuf = new StringBuf();
		var bFields:Array<String> = booking_fields.split(',').slice(2);
		sB.add('INSERT INTO fly_crm.agentur_buchungen ');
		sB.add( bFields.join(',') );
		sB.add(' VALUES(' + bFields.map(function(s:String) return '?').join(',') + ') ' );
		var res:EitherType < MySQLi_Result, Bool > = S.dbh.query(sB.toString());
		if (!res.any2bool())
		{
			trace('failed to:' + sB.toString());
			return false;
		}
		return cast S.dbh.insert_id;		
	}
	
}