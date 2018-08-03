#!/usr/bin/perl -w

use strict 'vars';
BEGIN{
        use File::Basename;
        use Data::Dumper;
        use CGI qw(:standard :cgi-lib);
        use JSON;
        use IO::Handle;
        unshift @INC, "${ENV{'DOCUMENT_ROOT'}}/../crm";
        my $subject = "$0 Error";
        my $sendto = "info\@flyingpenguin.de";
        $sendto = "axel\@cunity.me";
        my $SENDMAIL='/usr/sbin/sendmail';
        sub errmail{
		  my $msg = shift;
		  open (SENDMAIL,"|$SENDMAIL -t") || &logerror("$0 $msg - sendmail failed");
		  print SENDMAIL <<EOF;
To: $sendto
Subject: $subject
From: $0\@${ENV{'HTTP_HOST'}}
Content-Type: text/plain; charset="utf-8"

$msg

EOF

        };
        use Carp qw( cluck );

        $SIG{__DIE__} = \&errmail;
		#close STDERR;
}

our(
		  $affected_rows, $admin, $bccFirst,$args,
                  $campCond,
		  $DB,
		  $VARDB_database, $VARDB_server ,$VARDB_port, $VARDB_user, $VARDB_pass,
		  $checkRequired,$notification,
		  $bcc, $customData,$date, $dbh, $file, $from,
		  $lastClientID,$lang,$numRows,
		  $htmlHead,$output,$outDir,$outLink,$outLinkPath,$json,$log,
			$old,
		  $product,$prodCond,$printStatus,$res, $rDate,$row,$rows,
		  $sdate, $sday,
		  $session,$sql, $sth, $sthA, $sthB, $sthC, $subject,$tmpDir,
		  $templateDir,$templateDoc,$templateName, $tfMasters, $userFields, $userFieldsClassPath,
		  $templateOnceDoc,$tfMastersOnce,$userFieldsOnce,$onceTemplateLoaded,
		  $catalog, $schema, $table, $field,
		  $desktop,$rc,$rsm,$uno,$xas,$xis,$xiv
);

$args = Vars;
use CGI::Cookie;

$DB = 1;
#our ($year,$month,$day) = Today();
our ($year,$month,$day,$hour,$min,$sec) = Today_and_Now();

open($log,'>>',$ENV{'DOCUMENT_ROOT'}.'/../crm/mailing.log') or die $!;
$VARDB_database = 'fly_crm';

$templateDir = $ENV{'DOCUMENT_ROOT'}.'/../documents/templates';

#if (!$VARDB_port) {$VARDB_port='3306';}
printf  $log "$0: %02d.%02d.%s %02d:%02d:%02d\n",$day,$month,$year,$hour,$min,$sec;

use DBI;
use DBIx::Simple;
use Data::Dumper;
use DateTime;
use Date::Calc qw(Decode_Date_EU Today Add_Delta_YM Now Today_and_Now);
use Date::Language;
use MIME::Lite;
use POSIX qw(setlocale LC_ALL LC_CTYPE);
use Switch;
use PHP::Session;
use File::Basename;

use OpenOffice::UNO;
use lib dirname($ENV{'SCRIPT_FILENAME'}).'../crm';
#use lib dirname($ENV{'SCRIPT_FILENAME'}).'/lib';
require "config.pl";
#printf "Env:%s %s\n", $ENV{HOME},param('processLeads');
#exit;

$output = {};

$lang = Date::Language->new('German');
$date = $lang->time2str("%d.%m.%y", time);

($year,$month,$day) = Decode_Date_EU($date);

my $ddate = sprintf("%02d.%02d.%s",$day,$month,$year);
#printf "%s($year,$month,$day)=>$ddate",header();exit;
my $duration = DateTime->now(time_zone=>"Europe/Berlin")->subtract_datetime(DateTime->today(time_zone=>"Europe/Berlin"));
my $secondsToday = $duration->{seconds} + $duration->{minutes}*60;
#printf "%s($year,$month,$day)=>$ddate secondsToday:$secondsToday\n",header();exit;
$dbh = DBI->connect("DBI:mysql:$VARDB_database:$VARDB_server:$VARDB_port", "$VARDB_user", "$VARDB_pass",
                     {dbi_connect_method=>'connect_cached'})
 or die "Couldn't connect to database: " . DBI->errstr;

#$dbh->do("set names 'utf8'");
$dbh->{'mysql_enable_utf8'} = 1;

my $action = param('action');
if ( !$ENV{HOME} eq '/root' && $action)
{
		  my $sid = param('sid');
		  $session = PHP::Session->new($sid, {save_path=>'/var/lib/php5'});
		  $admin = $session->{_data}->{'PHP_AUTH_USER'};
		  if (!&checkAuth) {
                        $output->{error} .= "Passwort oder Benutzerfehler :(\n";
                        &printOut;
		  }
}

$outDir = $ENV{'DOCUMENT_ROOT'}."/../documents/files/$args->{product}/pdf";

my $kProduct = ($args->{product} eq 'KINDERHILFE' ? "kinder" : "tiere");

$outLinkPath = $ENV{'DOCUMENT_ROOT'}."/flyCRM/$args->{product}/pdf";
trace("$outLinkPath ... $outDir");
my @leadsFields = qw(title first_name last_name address1 address2 postal_code city email);
my @monat = ("Januar","Februar","M�rz","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember");

my @customFields = qw( co_feld anrede briefAnrede);
my @clientsFields = qw( co_feld title);

#setlocale(LC_ALL,'de_DE');
if(!$ENV{SERVER_NAME} =~ /xpress/){$ENV{'URE_BOOTSTRAP'} ='vnd.sun.star.pathname:/opt/libreoffice6.0/program/fundamentalrc';}
#trace(Dumper(\%ENV));
$uno = OpenOffice::UNO->new;
my $ctx  = $uno->createInitialComponentContext;
trace(Dumper($ctx));
my $sm  = $ctx->getServiceManager;
my $resolver = $sm->createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", $ctx);
trace(Dumper($resolver));
$rsm = $resolver->resolve("uno:socket,host=localhost,port=8100;urp;StarOffice.ServiceManager");
trace(Dumper($rsm));
	# get an instance of the Desktop service
$rc = $rsm->getPropertyValue("DefaultContext");
trace(Dumper($rc));
$desktop = $rsm->createInstanceWithContext("com.sun.star.frame.Desktop", $rc);
trace(Dumper($desktop));
#die('oops');
my $periodMap = {
		  'once'=>'Einmalspende',
		  'annual' => 'jährlich',
		  'monthly' => 'monatlich',
		  'semiannual' => 'halbjährlich',
		  'quarterly' => 'vierteljährlich'
};

#551920 - my testlead
#46285 jacob kalus testlead
#printf "%s\n", Dumper($args);
#exit;
my $linkList = [];

printf STDERR "%s\n",Dumper($args);
trace(Dumper($args));
#exit;
processLeads($args);


sub processLeads
{
        my ($cond) = @_;
        trace(sprintf "%s\n", Dumper($cond));
        $printStatus = $cond->{action};
        #endDebug();
        my $fileNames = [];

        switch($cond->{action})
        {
                case 'PRINTLIST' {
                        #WELCOME MEMBER LETTER
                        $tmpDir = $ENV{'DOCUMENT_ROOT'}."/../documents/mails/$args->{product}/tmp";
                        $templateName = ($args->{product} eq 'KINDERHILFE' ? "Kinder_Neu" : "2017_Anschreiben_TIERE_NEUKUNDEN");
                        my @old = <$tmpDir/*.pdf>;
                        if(@old){ unlink(@old);}
                        if ($cond) {
                                #printf "param:%s\n", Dumper($cond);
                                my $IDs =  $cond->{list};
                                chomp($IDs);
                                $IDs =~ s/^\s+|\s+$//g;
                                my @c =$IDs =~ s/\s+/,/g;

                                $output->{header} = sprintf 'Liste mit %d Anschreiben', 0+@c;

                                $sql = <<EOS;
                SELECT lead_id,entry_list_id,vendor_lead_code FROM vicidial_list WHERE  list_id = 10000 AND vendor_lead_code IN($IDs)

EOS

                        }
                }
                case 'PRINTNEW' {
                        #PRINTNEW WELCOME MEMBER LETTER

                        $tmpDir = $ENV{'DOCUMENT_ROOT'}."/../documents/mails/$args->{product}/new";
                        if($args->{product} eq 'KINDERHILFE' )
                        {
                                $templateName = "Kinder_Neu";
                                $prodCond = "AND entry_list_id NOT LIKE '2%'";
                        }
                        else
                        {
                                $templateName = "2017_Anschreiben_TIERE_NEUKUNDEN";
                                $prodCond = "AND entry_list_id LIKE '2%'";
                        }

                        my @old = <$tmpDir/*.pdf>;
                        if(@old){ $old = unlink(@old);}
												if(!$old){trace($!);}

                        $sql = <<EOS;
                SELECT lead_id,entry_list_id,vendor_lead_code FROM vicidial_list WHERE  list_id = 10000 AND status = 'QCOKM' $prodCond

EOS
                }
                case 'EPRINT' {
                       # WELCOME MEMBER EMAIL
                }
                case 'S_POST' {
                       # INFO LETTER
                       $tmpDir = $ENV{'DOCUMENT_ROOT'}."/../documents/mails/$args->{product}/info";
                        if($args->{product} eq 'KINDERHILFE' )
                        {
                                $templateName = "InfoMail";
                                $prodCond = "AND entry_list_id NOT LIKE '2%'";
                                $campCond = "KIND%";
                        }
                        else
                        {
                                $templateName = "2017_Anschreiben_TIERE_INFOPOST";
                                $prodCond = "AND entry_list_id LIKE '2%'";
                                $campCond = "TIER%";
                        }
                       my @old = <$tmpDir/*.pdf>;
                       if(scalar @old){ unlink(@old);}
                       #$templateName = "InfoMail";

                       $sql = <<EOS;
                       SELECT lead_id,entry_list_id,vendor_lead_code FROM asterisk.vicidial_list WHERE (list_id < 3000 OR list_id IN(8000,10000))
                       AND status = 'S_POST' $prodCond
                       UNION
                       SELECT lead_id,entry_list_id,vendor_lead_code FROM vicidial_list WHERE lead_id IN(
                               SELECT DISTINCT(lead_id)  FROM `vicidial_agent_log` WHERE `status` IN( 'P_POST', 'P_POS2')
                               AND campaign_id LIKE '$campCond'
                               #AND DATEDIFF(`event_time`, CURDATE())<10
                       )
                       AND status = 'CBHOLD'
                       AND lead_id NOT IN(
                           SELECT DISTINCT(lead_id) FROM fly_crm.print_log WHERE reason = 'info_brief_${kProduct}' AND print_again=0
                       )
EOS
                        #$sql = "SELECT lead_id,entry_list_id,vendor_lead_code FROM asterisk.vicidial_list WHERE lead_id=542869";
                        #trace($sql);
                        trace("$templateName");
                        #&printOut;
                }
                case 'S_MAIL' {
                       # INFO EMAIL - shouldn't happen here
                       $output->{error}= 'Status S_MAIL handled by cron';
                       &printOut;
                }
        }

        trace("file://$templateDir/$templateName.ott");
        #print header({content-type=>'text/plain'});
        loadTemplate("file://$templateDir/$templateName.ott");

        my $leads = $dbh->selectall_arrayref($sql) or die "$sql $!";

        foreach my $lead(@$leads)
        {
                #        TODO: wantInfo Flag gesetzt hier pr�fen
                if(0 && $printStatus =~ /_POS/ && !checkWantInfo(@$lead))
                {
                        next;
                }
                #printf "%s\n", join(',', @$lead);

                my $mergedID = mailMerge(@$lead);
                #exit;
                push(@$fileNames, $mergedID) if $mergedID;
        }

        my $c;
        switch($cond->{action})
        {
                case 'PRINTLIST' {
                        $c = sprintf("%s output $outDir/Liste-$ddate-$secondsToday.pdf", join(' ',@$fileNames));
                        chdir($tmpDir);
                        $output->{command} .= `pwd`;
                        $output->{command} .= "pdftk $c\n";
                        $output->{command} .= sprintf "%s\n", `pdftk $c`|| 'OK';
                        $output->{command} .= sprintf "%s\n", `cp -p $outDir/Liste-$ddate-$secondsToday.pdf $outLinkPath`|| 'OK';
                        #$linkList = map({{url=>"$outLink/Liste.pdf", fileName=>"Liste.pdf"}} @$fileNames);
                        #$output->{link} = [{url=>"$outLink/Liste.pdf", fileName=>"Liste.pdf"}];
                        #printf STDERR "%s\n", Dumper($output);
                        $output->{fileName} = "Liste-$ddate-$secondsToday.pdf";
                        $output->{filePath} = $outDir;
                        &printOut;
                }

                case 'PRINTNEW' {
                        $c = sprintf("%s output $outDir/NeuListe-$ddate-$secondsToday.pdf", join(' ',@$fileNames));
                        chdir($tmpDir);
                        $output->{command} .= `pwd`;
                        $output->{command} .= "pdftk $c\n";
                        $output->{command} .= sprintf "%s\n", `pdftk $c` || 'OK';
                        $output->{command} .= sprintf "%s\n", `cp -p $outDir/NeuListe-$ddate-$secondsToday.pdf $outLinkPath`|| 'OK';
                        $output->{fileName} = "NeuListe-$ddate-$secondsToday.pdf";
                        $output->{filePath} = $outDir;
                        if(&printList)
                        {
                                $dbh->do("UPDATE vicidial_list SET status='MPRINT' WHERE status='PRINTN'");
                                &printOut;
                        }
                        else
                        {
                                ### NOTIFIY QUERY IS EMPTY
                                $output->{error} = "Keine Neuen Anschreiben!";
                                &printOut;
                        }

                }

                case ('S_POST') {
                        $c = sprintf("%s output $outDir/InfoListe-$ddate-$secondsToday.pdf", join(' ',@$fileNames));
                        chdir($tmpDir);
                        $output->{command} .= `pwd`;
                        $output->{command} .= "pdftk $c\n";
                        $output->{command} .= sprintf "%s\n", `pdftk $c` || 'OK';
                        $output->{command} .= sprintf "%s\n", `cp -p $outDir/InfoListe-$ddate-$secondsToday.pdf $outLinkPath`|| 'OK';
                        $output->{fileName} = "InfoListe-$ddate-$secondsToday.pdf";
                        $output->{filePath} = $outDir;
                        &printOut;
                }
        }
}

sub checkWantInfo
{
        my($lead_id, $customList, $vendor_lead_code) = @_;
        $sql = <<EOS;
        SELECT * FROM `custom_${customList}` WHERE lead_id=$lead_id AND mailing='info_brief'
EOS
        $rows = $dbh->do($sql) or die "$sql $!";
        trace( "$lead_id - $customList::$rows:%s\n",($rows == 1 ? 'Y':'N'));
        return $rows == 1;
}

sub mailMerge
{
		  my ($lead_id, $customList, $vendor_lead_code) = @_;
		  #printf "%d::$lead_id, $customList, $vendor_lead_code, $printStatus\n",__LINE__;

		  #if ($printStatus eq 'S_MAIL' || $printStatus eq 'S_POST' || $printStatus eq 'P_MAIL' || $printStatus eq 'P_POST')
		  if ($printStatus eq 'S_POST' || $printStatus eq 'P_POST')
		  {#INFO TEMPLATE
					 $sql = <<EOS;
		  SELECT title, IF(anrede='Herr','Herrn',anrede) AS anrede, first_name, last_name, IF(title!='',CONCAT(title,' '),''), address1, address2, email, co_field AS co_feld, postal_code, city,
		  vl.lead_id, vl.status,
		  CASE WHEN anrede = 'Frau' THEN 'Sehr geehrte Frau'
		  WHEN anrede = 'Herr' THEN 'Sehr geehrter Herr'
		  WHEN anrede = 'Familie' THEN 'Sehr geehrte Familie'
		  ELSE 'Sehr geehrte Damen & Herren' END AS `briefAnrede`
		  FROM `custom_${customList}`  AS cus, vicidial_list AS vl
		  WHERE cus.lead_id = vl.lead_id
		  AND vl.lead_id=$lead_id
EOS

		  }
		  else
		  {
                        switch($printStatus)
                        {
				case 'PRINTLIST' {
		  #WIEDERHOLUNG ANSCHREIBEN NEUBEITRAG - neue version mehr aus fly_crm
					 $sql = <<EOS;
		  SELECT IF(anrede='Herr','Herrn',anrede) AS anrede, IF(title!='',CONCAT(title,' '),''),first_name, last_name, address1, address2, '' AS email, co_field AS co_feld, postal_code, city,
		  start_monat,
		  (CASE WHEN buchungs_zeitpunkt = '15' THEN 'Mitte' ELSE 'Anfang' END)AS buchungs_zeitpunkt,
		  format(amount,2,'de_DE') AS spenden_hoehe, cycle AS turnus, vendor_lead_code,
		  (CASE WHEN anrede = 'Frau' THEN 'Sehr geehrte Frau'
		  WHEN anrede = 'Herr' THEN 'Sehr geehrter Herr'
		  WHEN anrede = 'Familie' THEN 'Sehr geehrte Familie'
		  ELSE 'Sehr geehrte Damen & Herren' END) AS briefAnrede
		  FROM asterisk.custom_${customList} AS cus, asterisk.vicidial_list AS vl
		  INNER JOIN fly_crm.pay_plan pl
		  ON pl.client_id='$vendor_lead_code'
		  WHERE cus.lead_id = vl.lead_id AND vl.list_id = 10000 AND vl.vendor_lead_code='$vendor_lead_code'
EOS
					 trace($sql);
                                }

                                case 'PRINTNEW' {
		  #ANSCHREIBEN NEUBEITRAG (BEDINGUNG IF START WITHIN NEXT 45 DAYS ENTFERNT)
					 $sql = <<EOS;
		  SELECT IF(anrede='Herr','Herrn',anrede) AS anrede, IF(title!='',CONCAT(title,' '),''), first_name, last_name, address1, address2, '' AS email, co_field AS co_feld, postal_code, city,
		  start_monat,
		  (CASE WHEN buchungs_zeitpunkt = '15' THEN 'Mitte' ELSE 'Anfang' END)AS buchungs_zeitpunkt,
		  format(amount,2,'de_DE') AS spenden_hoehe, cycle AS turnus, vendor_lead_code,
		  (CASE WHEN anrede = 'Frau' THEN 'Sehr geehrte Frau'
		  WHEN anrede = 'Herr' THEN 'Sehr geehrter Herr'
		  WHEN anrede = 'Familie' THEN 'Sehr geehrte Familie'
		  ELSE 'Sehr geehrte Damen & Herren' END) AS briefAnrede
		  FROM asterisk.custom_${customList} AS cus, asterisk.vicidial_list AS vl
		  INNER JOIN fly_crm.pay_plan pl
		  ON pl.client_id='$vendor_lead_code'
		  WHERE cus.lead_id = vl.lead_id AND vl.list_id = 10000 AND vl.vendor_lead_code='$vendor_lead_code'

EOS

### DATEDIFF BEDINGUNG 46 D VOR START ENTFERNT
				}
			}
		  }

		  my $mailData = $dbh->selectrow_hashref($sql);
		  if(!$mailData && $dbh->errstr)
		  #if(!$mailData)
		  {
                        printf STDERR "%s == $!\n", $dbh->errstr;
                        $output->{error} = "$sql\n$!";
                        &printOut;
		  };

		  if ($printStatus eq 'PRINTNEW' )
		  {
                        #printf STDERR "%s\n", $mailData ? 'Y' :'N';
                        trace($sql);
                        trace($mailData);
                        return undef unless $mailData;
                        #$output->{mailData} = $sql.sprintf "\n%s", Dumper($mailData);
                        #&printOut;
		  }

		  #printf "%d::mailData:%s\n", __LINE__, Dumper($mailData);
		  if(($printStatus eq 'S_MAIL' || $printStatus eq 'P_MAIL' || $printStatus eq  'EPRINT') && !($mailData->{email} && $mailData->{email}=~ m/.+\@.+\..+/))
		  {
                        $output->{error} .= sprintf "%d::invalid email: %s\n", __LINE__, $mailData->{email};
                        return;
		  }

		  #printf "%d::%s\n", __LINE__, Dumper($tfNames);
		  #trace($sql);
		  my ($k,$tF);
		  $mailData->{title} .= ' ' if($mailData->{title});
		  if($printStatus =~ /^PRINT/) {
                        $mailData->{turnus} = $periodMap->{$mailData->{turnus}};
                        #trace($mailData->{turnus});

                        if ($mailData->{turnus} eq 'Einmalspende') {
                                if (!$onceTemplateLoaded) {
                                        loadOnceTemplate("file://$templateDir/".($args->{product} eq 'KINDERHILFE' ? "Kinder_Neu_Einmal.ott" : "2017_Anschreiben_TIERE_EINMAL.ott"));
                                        #loadOnceTemplate("file://$templateDir/Kinder_Neu_Einmal.ott");
                                }
                                for $k (@$userFieldsOnce)
                                {
                                        #next unless has($userFields, "com.sun.star.text.fieldmaster.User.$k");
                                        #trace("$k $mailData->{$k}");
                                        $tF = $tfMastersOnce->getByName("com.sun.star.text.fieldmaster.User.$k");
                                        $tF->setPropertyValue("Content",$mailData->{$k});
                                }
                        }
                        else
                        {
                                for $k (@$userFields)
                                {
																				next unless $mailData->{$k};
                                        trace("$k $mailData->{$k}");
                                        #next unless has($userFields, "com.sun.star.text.fieldmaster.User.$k");
                                        $tF = $tfMasters->getByName("com.sun.star.text.fieldmaster.User.$k");
                                        $tF->setPropertyValue("Content",$mailData->{$k});
                                        trace("set $k to:". $tF->getPropertyValue("Content"));
                                }
                        }
		}
                else
                {
                        for $k (@$userFields)
                        {
                                trace("$k:$mailData->{$k}");
                                #next unless has($userFields, "com.sun.star.text.fieldmaster.User.$k");
                                $tF = $tfMasters->getByName("com.sun.star.text.fieldmaster.User.$k");
                                $tF->setPropertyValue("Content",$mailData->{$k});
                        }
                }

                switch($printStatus)
                {
                case 'PRINTLIST' {
                        # PRINT AGAIN WELCOME MEMBER LETTER
                        #trace(sprintf "$mailData->{turnus} %s\n", $mailData->{turnus} eq 'Einmalspende'?'Y':'N');
                        savePdf("file://$tmpDir/$vendor_lead_code.pdf", ($mailData->{turnus} eq 'Einmalspende'));
                        $dbh->do("INSERT INTO fly_crm.print_log SET lead_id=$lead_id, client_id=$vendor_lead_code,reason='print_${kProduct}_manuell'");
                        return "$vendor_lead_code.pdf";
                }
                case 'PRINTNEW' {
                        # WELCOME MEMBER LETTER
                        savePdf("file://$tmpDir/$vendor_lead_code.pdf",$mailData->{turnus} eq 'Einmalspende');
                        #$output->{fileName} = "$vendor_lead_code.pdf";
                        #$output->{filePath} = $tmpDir;
                        #&printOut;
                        $dbh->do("INSERT INTO fly_crm.print_log SET lead_id=$lead_id, client_id=$vendor_lead_code,reason='print_${kProduct}_neu'");
                        $dbh->do("UPDATE vicidial_list SET status='PRINTN' WHERE vendor_lead_code=$vendor_lead_code");
                        return "$vendor_lead_code.pdf";
                }

                case ('S_POST'){
                       # INFO LETTER => MOVE2LIST 1700
                       #$templateName = "InfoMail";
                       savePdf("file://$tmpDir/$lead_id.pdf");
                       #my $pStatus = ($printStatus eq 'S_POST' ? 'PRINTS':'PRINTP');
                       my $pStatus = ($mailData->{status} ne 'CBHOLD' ? 'PRINTS':'CBHOLD');

                       $dbh->do("INSERT INTO fly_crm.print_log SET lead_id=$lead_id,reason='info_brief_${kProduct}'") or
                                         die ("INSERT INTO fly_crm.print_log SET lead_id=$lead_id,reason='info_brief_${kProduct}'");
                       $dbh->do("UPDATE asterisk.vicidial_list SET list_id=1700, status='$pStatus',`comments`=CONCAT('Info Brief gesendet ',`comments`) WHERE lead_id=$lead_id") or
                                die("UPDATE asterisk.vicidial_list SET list_id=1700, status='$pStatus',`comments`=CONCAT('Info Brief gesendet ',`comments`) WHERE lead_id=$lead_id");
                       # SO FAR SUCCESSFUL => CLEAR CUSTOM_FIELDS TABLE FIELD mailing
                       $dbh->do("UPDATE asterisk.custom_${customList} SET mailing='no_info' WHERE lead_id=$lead_id") or
                                die("UPDATE asterisk.custom_${customList} SET mailing='no_info' WHERE lead_id=$lead_id");
                       return "$lead_id.pdf";
                }

                case ('S_MAIL')
                {
                       # INFO EMAIL
                       $output->{error}= 'Status S_MAIL handled by cron';
                       &printOut;
                }
        }

}


sub loadTemplate
{
        my $url = shift;
        trace($url);
        # create a name/value pair to be used in opening the document
        my $pv = $uno->createIdlStruct("com.sun.star.beans.PropertyValue");
        $pv->Name("Hidden");
        $pv->Value(OpenOffice::UNO::Boolean->new(1));
        my $pv2 = $uno->createIdlStruct("com.sun.star.beans.PropertyValue");
        $pv2->Name("AsTemplate");
        $pv2->Value(OpenOffice::UNO::Boolean->new(1));
        # open a document
        trace($desktop);
        $templateDoc = $desktop->loadComponentFromURL($url,"_blank",0, [$pv,$pv2]);
        $tfMasters = $templateDoc->getTextFieldMasters();
        my $tfNames = $tfMasters->getElementNames();
        #$userFields = [grep({ /(.?User)\.([a-bA-B_0-9]+)$/; } @$tfNames)];
        #printf header()."userFields:%s\n", Dumper($tfNames);#exit;
        trace(Dumper($tfNames));
        foreach (@$tfNames)
        {
                /User\.([a-zA-Z_0-9]+)$/;
                next unless $1;
                push @$userFields, $1;
                if (!$userFieldsClassPath) {
                        my @parts = split /User/;
                        $userFieldsClassPath = $parts[0].'User';
                }
        }
        #printf "$userFieldsClassPath =>\n%s\n", Dumper($userFields);
        trace(Dumper($userFields));
        #exit;

}

sub loadOnceTemplate
{
        my $url = shift;
        $onceTemplateLoaded = 1;
        # create a name/value pair to be used in opening the document
        #trace($url);
        my $pv = $uno->createIdlStruct("com.sun.star.beans.PropertyValue");
        $pv->Name("Hidden");
        $pv->Value(OpenOffice::UNO::Boolean->new(1));
        my $pv2 = $uno->createIdlStruct("com.sun.star.beans.PropertyValue");
        $pv2->Name("AsTemplate");
        $pv2->Value(OpenOffice::UNO::Boolean->new(1));
        # open a document
        $templateOnceDoc = $desktop->loadComponentFromURL($url,"_blank",0, [$pv,$pv2]);
        $tfMastersOnce = $templateOnceDoc->getTextFieldMasters();
        my $tfNames = $tfMasters->getElementNames();
        #trace($tfNames);
        #$userFields = [grep({ /(.?User)\.([a-bA-B_0-9]+)$/; } @$tfNames)];
        #printf "userFields:%s\n", Dumper($tfNames);exit;
        foreach (@$tfNames)
        {
                /User\.([a-zA-Z_0-9]+)$/;
                next unless $1;
                push @$userFieldsOnce, $1;
        }
}

sub savePdf
{
        my ($url,$once) = @_;
        #printf "savePdf:$url\n";
        my $pv = $uno->createIdlStruct("com.sun.star.beans.PropertyValue");
        $pv->Name("FilterName");
        $pv->Value("writer_pdf_Export");
        #trace ($once?'Y':'N');
        if ($once)
        {
                $templateOnceDoc->storeToURL($url,[$pv]);
                #trace($url);
        }
        else
        {
                $templateDoc->storeToURL($url,[$pv]);
                $pv->Value("writer8");
                $templateDoc->storeAsURL( 'file:///var/www/vhosts/cunity.me/crm.cunity.me/test.odt',[$pv]);
                #trace($url);
        }

}

sub sendMail
{
        my ($data, $pdfs, $paths) = @_;
        my $html = <<EOC;
        $htmlHead
        <body text="#000000" bgcolor="#eeeeee">
        <div class="screen">
        <h3>$data->{briefAnrede} $data->{last_name}, </h3>
        <p>wir bedanken uns f�r Ihr Interesse und senden Ihnen im Anhang die gew�nschten Informationen zu unserem
        Engagement in der Berliner Kinderhilfe Schutzengel. </p>
        <p>Herzliche Gr��e,<br>
        Jacob Kalus
        </p>
        <div class=""><span style="font-size: 11px;" class=""><strong class="">BERLINER KINDERHILFE&nbsp;</strong></span></div>
        <div class=""><span style="font-size: 11px;" class=""><strong class="">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Schutzengel</strong>		  </span></div>
        <div class=""><b style="font-size: 11px; text-align: -webkit-auto;" class="">-Au�enstelle F�rderung-</b></div>

        <div class=""><br class=""></div>
        <pre style="margin:0px;padding:0px;">
Johannisberger Str. 4 / 14197 Berlin
Tel. (030) 897 32 755
Fax: (030) 897 32 753

Website: <a href="http://www.berliner-schutzengel.de" class="">www.berliner-schutzengel.de</a>
E-Mail: <a href="mailto:kontakt\@berliner-schutzengel.de" >kontakt\@berliner-schutzengel.de</a>

<b style="font-size: 11px;" class="">Die Berliner Kinderhilfe Schutzengel ist ein Projekt der
Johannes Kinder- und Jugendf�rderung Deutschland
gemeinn�tzige Gesellschaft mbH</b>
<div style="font-size: 11px;" face="Helvetica-Light">
Gesch�ftsf�hrer: J�rgen Schnelle
Amtsgericht Berlin HRB 154526 B
StNr. zur Feststellung der Gemeinn�tzigkeit: 27/613/02936
</div>
</pre>
</div>
</body>
</html>
EOC

        my $msg;
        if($bccFirst)
        {
                $msg = MIME::Lite->new(
                        To => $data->{email},
                        From => $from,
                        Subject => $subject,
                        Bcc => $bcc,
                        Type => 'multipart/mixed'
                );
                $bccFirst = 0;
        }
        else
        {
                $msg = MIME::Lite->new(
                        To => $data->{email},
                        From => $from,
                        Subject => $subject,
                        Type => 'multipart/mixed'
                );
        }
        $msg->attr('content-type.charset' => 'iso-8859-15');

        $msg->attach(
                Type => 'text/html',
                Data => $html,
        );
        my $i=0;

        foreach(@$pdfs)
        {

                $msg->attach(
                        Type => 'application/pdf',
                        Filename   => "$_.pdf",
                        Encoding => 'base64',
                        Path => "$paths->[$i++]/$_.pdf",
                );
        }
        $msg->send() || die " $data->{email} :$!";
        printf "Info sent to %s\n", $msg->get('To');

}

sub printList
{
        my $aktDatum= `date +'%d.%m.%Y_%H_%M_%S'`;
        $aktDatum =~ s/^\s+|\s+$//g;
        my $stmtA = <<EOS;

       SELECT first_name, last_name, phone_number FROM `vicidial_list` WHERE `status` LIKE 'PRINTN' into outfile
       '/srv/www/htdocs/flyCRM/dokumente/anschreiben/liste-$aktDatum.csv'

EOS

        trace( "printList:$stmtA\n");
	my $affected_rows = $dbh->do($stmtA);
        trace("listrows:$affected_rows ".($dbh->errstr?$dbh->errstr:''));
        return $affected_rows;
}



sub printOut
{
        #trace(exists($output->{error})? $output->{error}: 'OK:'."$output->{filePath}/$output->{fileName}");
        if(!exists($output->{error}))
        {
                my $cookie = CGI::Cookie->new(-name=>'fileDownload',-value=>'true',-path=>'/');
                print header(-cookie=>[$cookie],-type=>'application/pdf',-attachment=>$output->{fileName});
                open(my $down, "$output->{filePath}/$output->{fileName}") or die "$output->{filePath}/$output->{fileName}:$!";
                my @file_array = <$down>;
                trace( sprintf "$output->{filePath}/$output->{fileName} pdf:%s::%d\n", $file_array[0], length(join('',@file_array)));
                close($down);
                print @file_array;
                exit;
        }
        $json = JSON->new->utf8;
        print header('application/json; charset="utf-8');
        my $jlog = sprintf  "%s\n",Dumper($json->encode($output));
        $jlog =~ s/\r\n|\n|\t/ /g;
        trace($jlog);
        print $json->encode($output);
        exit;
}

sub endDebug
{
        print header('text/plain'),"endDebug\n";
        exit;
}

__END__

##########################
DATEDIFF BEDINGUNG:
##########################

		  AND DATEDIFF(STR_TO_DATE(
					 CONCAT(IF( buchungs_zeitpunkt+0 =1,1,15),'.',start_monat+0,',',
					 IF( MONTH(NOW()) <= MONTH(
    STR_TO_DATE(
	 CONCAT(IF( buchungs_zeitpunkt+0 =1,1,15),'.',start_monat+0,',', YEAR(now())), '%d.%m,%Y')),  YEAR(now()),  YEAR(now())+1)
					 ), '%d.%m,%Y') ,NOW())<46
#########################
FEHLER BEIM WIEDERAUSDRUCK VON LEADS DIE SCHON EIN ANSCHREIBEN ERHALTEN HABEN (ES WURDE JEDENFALLS GEDRUCKT)
#########################
                       UNION
                       SELECT lead_id,entry_list_id,vendor_lead_code FROM asterisk.vicidial_list WHERE list_id = 1700
                       AND (status = 'S_POST' || status = 'P_POST' || status = 'CBHOLD')

sub trace
{
   my ($package, $filename, $line) = caller;
	my $m = shift;
   #printf( "%s:%s:%s\n", $filename, $line, $m);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
   printf($log "%02d:%02d:%02d %s:%s:%s\n", $hour, $min, $sec, $filename, $line, $m);
	$log->flush();
}


					  $stmtA = "UPDATE vicidial_list AS vl INNER JOIN custom_$entry_list_id AS cus
					  ON vl.lead_id=cus.lead_id
		  SET province=`status`,`status`='PRINTNEW'
		  WHERE vl.lead_id=$lead_id AND
			DATEDIFF(STR_TO_DATE(CONCAT(IF( cus.buchungs_zeitpunkt+0 =1,1,15),'.',cus.start_monat+0,',', YEAR(now())), '%d.%m,%Y') ,NOW())<45";


sub preparePrintable
{
		  $sql = "SELECT lead_id FROM asterisk.vicidial_list WHERE list_id = 10000 AND status = 'QCOKM'";

		  my $dbs  = DBIx::Simple->connect($dbh);
		  my @sales2qc = $dbs->query($sql)->flat or die $dbs->error;
		  ### IF $CLEAR MOVE MPRINT TO MITGL

		  if( param('clear') )
		  {
					 $sql = "UPDATE vicidial_list SET status = 'MITGL' WHERE status = 'MPRINT' ";
					 $affected_rows = $dbh->do($sql);
					 if($DB){print STDERR "\n$affected_rows MPRINT SET TO MITGL\n";}
			  }
		  }

		  ##### Mark as PRINTable
		  while (my $lead_id = shift(@sales2qc))
		  {
					 $sql = "UPDATE asterisk.vicidial_list AS vl INNER JOIN fly_crm.pay_plan AS pl
					  ON vl.vendor_lead_code=pl.client_id
		  SET  `status`='PRINTNEW'
		  WHERE  vl.status = 'QCOKM' AND  DATEDIFF(pl.start_date ,NOW())<45";

					 $affected_rows = $dbh->do($sql);

		  }

}

sub printList
{
        my $stmtA = <<'EOS';
SET @sql_text =
   CONCAT (
       "SELECT first_name, last_name, phone_number FROM `vicidial_list` WHERE `status` LIKE 'PRINTN' into outfile '/srv/www/htdocs/flyCRM/dokumente/anschreiben/liste-"
       , DATE_FORMAT( NOW(), '%d.%m.%Y.%H.%i.%s')
       , ".csv'"
    );
PREPARE s1 FROM @sql_text;
EXECUTE s1;
DROP PREPARE s1;
EOS

        trace( "$stmtA\n");
	my $affected_rows = $dbh->do($stmtA);
        trace("listrows:$affected_rows ".$dbh->errstr);
}
