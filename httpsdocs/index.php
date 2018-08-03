<?php
# 
# index.php
#
# this file is part of sec_login
#
# Copyright © 2018 by Jörg Frings-Fürst <j.fringsfuerst@flyingpenguin.de>,
#                     Frank Gorgas-Waller <fg.waller@flyingpenguin.de>,
#                     flyingpenguin.de <info@flyingpenguin.de>
# License AGPL 3.0+
#
# 20180128 First Release
#

$release = "0.1.5";

$DB=0;

session_start();
error_reporting(E_ALL);


if (version_compare(phpversion(), '5.5.14', '<')) {
    echo "php Version >= 5.5.14 requested. Found " . phpversion() . PHP_EOL;
    exit;
}

$relation = "/etc/flyingpenguin/";
include_once($relation."config.inc.php");
	
#############################################
##### START SYSTEM_SETTINGS LOOKUP #####
$stmt = "SELECT agent_script FROM system_settings;";
if ($DB) { echo "$stmt\n"; }
$rslt=mysqli_query($link, $stmt);
if (mysqli_num_rows($rslt) > 0)	{
    $row=mysqli_fetch_row($rslt);
	$agent_script = $row[0];
} else {
    echo "Not found ";
}
mysqli_free_result($rslt);
##### END SETTINGS LOOKUP #####
###########################################

$error = $user = $pass = '';
	
	
if (isset($_GET["user"]))
    $user = $_GET['user'];
elseif(isset($_POST['user']))
    $user = $_POST['user'];

if (isset($_GET["pass"]))
	$pass = $_GET['pass'];
elseif(isset($_POST['pass']))
    $pass = $_POST['pass'];
	
$test = 0;
if((isset($_POST['Adminlogin'])) || (isset($_POST['Agentlogin']))) {
    $test = 1;	    
}

if($test == 1) {

$_POST['pass'] = mysqli_real_escape_string($link, $_POST['pass']);
$_POST['pass'] = preg_replace("/[^a-zA-Z0-9_]/","",$_POST['pass']);
$_POST['user'] = mysqli_real_escape_string($link, $_POST['user']);
$_POST['user'] = preg_replace("/[^a-zA-Z0-9_]/","",$_POST['user']);

if(isset($_GET['clear']))
{
    session_destroy();
}
	
	
if(!isset($_POST['user']) || ! isset($_POST['pass']) AND
    isset($_SESSION['PHP_AUTH_USER']) && ($_SESSION['PHP_AUTH_USER'] != "") AND 
	(isset( $_SESSION['PHP_AUTH_PW']) && $_SESSION['PHP_AUTH_PW'] != "")) {
	    $_POST['user']=preg_replace("/[^a-zA-Z0-9_]/","",$_SESSION['PHP_AUTH_USER']);
        $_POST['pass']=preg_replace("/[^a-zA-Z0-9_]/","",$_SESSION['PHP_AUTH_PW']);
}

openlog('sec_login', LOG_PID, LOG_SYSLOG);

    if(isset($_POST['user']) && $_POST['user'] != "" AND 
      (isset($_POST['pass']) && $_POST['pass'] != "")) {
        $stmtA = "SELECT active,pass  FROM `vicidial_users` WHERE ((user = '".$_POST['user']."') AND pass = '{$_POST['pass']}') AND active = 'Y' LIMIT 1";
        $resultA = mysqli_query($link, $stmtA);
        $rowA=mysqli_fetch_array($resultA);
		if($rowA['active'] = "Y") {
            $_SESSION['PHP_AUTH_USER'] = $_POST['user'];
            $_SESSION['PHP_AUTH_PW'] = $_POST['pass'];
            if((!isset($_SESSION['adminLogin']) || $_SESSION['adminLogin']==0) && isset($_POST['adminLogin'])) {
                $_SESSION['adminLogin'] =  $_POST['adminLogin'];
            }
		
            session_write_close();
	        
            ### OK - AUTH SUCCESS - ADD MY IP TO FIREWALL
            
            syslog(LOG_INFO, "Login user: " . $_POST['user']);
            $added = `/usr/local/sbin/sec_login.sh {$_SERVER['REMOTE_ADDR']}`;
            if( !$added ) {
                sleep(1);
				if(isset($_POST['Agentlogin'])) {
					header("Location: https://$host/agc/{$agent_script}?relogin=YES&VD_login={$_SESSION['PHP_AUTH_USER']}&VD_pass={$_SESSION['PHP_AUTH_PW']}");
				}
				if(isset($_POST['Adminlogin'])) {
					header("Location: https://{$_SESSION['PHP_AUTH_USER']}:{$_SESSION['PHP_AUTH_PW']}@$host/vicidial/admin.php");
				}
				exit();
            } else {
        	echo "Failed";
    	    }
            
		}
    }
} // if($test == 1)
	
echo '<!DOCTYPE html>' . PHP_EOL;
echo '<html><head>' . PHP_EOL;
echo '<html lang = "de-DE">' . PHP_EOL;
echo '<meta charset="UTF-8">' . PHP_EOL;
echo '<TITLE>secLogin - ' . $host .' </TITLE></HEAD>' . PHP_EOL;
echo '<link rel="stylesheet" type="text/css" href="sec_login.css">' .PHP_EOL;
echo '</head>' .PHP_EOL;
echo '<body topmargin=0 leftmargin=0 >' . PHP_EOL;

echo '<TABLE>' . PHP_EOL;
echo '<TR><TD colspan="2" align="center"> <h1>Login</h1></TD></TR>' . PHP_EOL;
echo '<form action="index.php" method="post">' . PHP_EOL;
echo '<TR><TD align="right">Nutzer:</TD> <TD><input type="text" name="user" /></TD></TR>' . PHP_EOL;
echo '<TR><TD align="right">Kennwort:</TD> <TD><input type="password" name="pass" /></TD></TR>' . PHP_EOL;
echo '<TR><TD>&nbsp;</TD> <TD><button type="submit" name="Agentlogin">Agent Login</button></TD></TR>' . PHP_EOL;
echo '<TR><TD>&nbsp;</TD> <TD><button type="submit" name="Adminlogin">Admin Login</button></TD></TR>' . PHP_EOL;
echo '</form>' . PHP_EOL;
echo '</TABLE>' . PHP_EOL;

echo '</body></html>' . PHP_EOL;

