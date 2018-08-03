<?php
	 
	$appLog = "/var/log/flyCRM.log";
	#error_log("syncLog:$appLog");
	
	function array2json($arr)
	{
		$json = '[';
		if($arr)
			foreach($arr as $a)
				$json .= sprintf ('"%s"', $a);
		$json .= ']';
		return $json;
	}
	
	function myBindParam($stmt, $params, $types)
	{
		$bindArray = refValues($params);
		array_unshift($bindArray, $types);
		#edump($bindArray);		
		$res =  call_user_func_array(array($stmt, 'bind_param'), $bindArray);
		return $res;
	}
	
	function refValues(&$arr){
		if (strnatcmp(phpversion(),'5.3') >= 0) //Reference is required for PHP 5.3+
		{
			$refs = array();
			foreach($arr as $key => $value)
				$refs[$key] = &$arr[$key];
			return $refs;
		}
		return $arr;
	}
	
	function edump($m, $stackPos=0)
	{
		#return;
		#global $appLog;
		global $appLog;
		error_log("syncLog:$appLog");
		if(!is_string($m))
			$m = print_r($m,1);
		$m = preg_replace("/\r\n|\n/", '', $m);
		$dump = debug_backtrace();
		$file = basename($dump[$stackPos]['file']);
		$dumpBuf = "$file::{$dump[$stackPos]['line']}: $m";
		if($appLog)
			file_put_contents($appLog,"$dumpBuf\n",FILE_APPEND);
			#echo "$dumpBuf\n";
		else
			error_log($dumpBuf);
	}
	

?>
