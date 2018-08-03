<?php
	require("config/config.inc.php");
	require("functions.php");
	header('Content-Type: application/json');
	echo json_encode($_SERVER);
	echo json_encode($_POST);
	session_start();
	echo "OK";
?>