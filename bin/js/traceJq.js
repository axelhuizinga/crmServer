var initArg, debugWin, debugOut, isOpera, dumpedObjects;
function openDebugWin(arg){
	//if(frames.debugWin)debugWin.close();
	if (/msie/i.test(navigator.userAgent) && !/opera/i.test(navigator.userAgent) && typeof(console)=='undefined'){
		//alert(navigator.userAgent +':'+/opera/i.test(navigator.userAgent));
		//reinit = function(){init(arg)}
		initArg = arg;
		debugWin = window.open('debugWin.php', 'debugWindow', 'left=0,top=0,width=400,height=400,scrollbars=yes');
		return;
	}
	 (/opera/i.test(navigator.userAgent)) ? isOpera = 1: isOpera = 0;
	init(arg)
}

function debug(m){
	var lastError;
	try{
		Throw('');
	}
	catch(e){lastError = e;}
	debugE(m, getEline(lastError) );
}

function debugE(m, eLine){
	//return;
	if(eLine)
		m = eLine + ':' + m;

	if(typeof(console)!='undefined'){
		console.log(m);
		return;
	}
	
	if(typeof(dump)!='undefined'){
		dump(m+'\n')
		return
	}
		
	if(isOpera)
		opera.postError(m);
	if(!debugWin || !debugWin.dOut)return;
	//debugWin.document.write(m+'<br>');
	debugWin.dOut.value +=(m+'\n');
	//debugWin.scrollTo(0, debugWin.document.body.scrollHeight)
	debugWin.focus();
}

function getEline(e)
{
	if(typeof(e.stack)!='undefined')
	{
		console.log(e.stack);
	}
	var trace = printStackTrace({e: e});
	trace = trace[1].split("/");
	trace = trace.pop();
	return(trace.replace(/\)/,''));
}

function dumpObject(o, deep){
	var lastError;
	try{
		throw('');
	}
	catch(e){lastError = e;}
	dumpObjectE(o, deep, getEline(lastError));
}

function dumpObjectE(o, deep, eLine){ 
	deep ? deep=true : deep = false
	debugE('dump:'+o+' recursive:'+deep, eLine); 
	for(e in o){
		try{
			debugE(e+'->'+o[e] + ':'+typeof(o[e]), eLine);
			if(deep && typeof(o[e]) == 'object') dumpObjectE(o[e], 1, eLine);
		}
		catch(ex){
			debugE(e+ ' exception:'+ex, eLine)
		}
	}
}

function dumpObjectKeys(o, deep){
	var lastError;
	try{
		Throw('');
	}
	catch(e){lastError = e;}
	dumpObjectKeysE(o, deep, getEline(lastError));
}

function dumpObjectKeysE(o, deep, eLine){ 
	deep ? deep=true : deep = false
	//debugE('objectKeys:'+o+' recursive:'+deep, eLine);
	var k = '';
	for(e in o){
		try{
			//debugE(e+'->'+typeof(o[e]), eLine);
			k += e+'->'+typeof(o[e]) + '\n';
			if(deep && typeof(o[e]) == 'object') dumpObjectKeysE(o[e], 1, eLine);
		}
		catch(ex){
			debugE(e+ ' exception:'+ex, eLine)
		}
	}
	debugE('objectKeys:\n'+k, eLine);
}


function dumpArray(a){
	var lastError;
	try{
		Throw('');
	}
	catch(e){lastError = e;}
	dumpArrayE(a, getEline(lastError));	
}

function dumpArrayE(a, eLine){
	debugE(a+' len:'+a.length+' typeof:'+typeof(a), eLine);
	for(var i=0;i<a.length;i++)debugE(i+'->'+a[i]);
}

function dumpLayout(el, recursive){
	var lastError;
	try{
		Throw('');
	}
	catch(e){lastError = e;}
	dumpLayoutE(el, recursive, getEline(lastError));
}
	
function dumpLayoutE(el, recursive, eLine){

	var m = 'el:' + el.id +':'+el.nodeName;
	var jQ = $(el);
	m  +=  ' left:' + jQ.position().left + ' top:' + jQ.position().top +' width:' + jQ.width() + 
	' height:' + jQ.height() + ' visibility:' + jQ.css('visibility') + ' display:' + jQ.css('display') + ' position:' + jQ.css('position') 
	+ ' class:' + el.className +' overflow:' + jQ.css('overflow') + ' opacity:' + jQ.css('opacity');
	debugE(m, eLine);
	if(recursive && el.parentNode.nodeName != 'body')
		dumpLayoutE(el.parentNode, recursive, eLine);

}
function dumpXml(node)
{
	var xs = new XMLSerializer();
	debugE(xs.serializeToString(node));
}

function adumpStack(sTrace) {
	var lastError;
	try{
		Throw('');
	}
	catch(e){lastError = e;}
	dumpStackE(printStackTrace(), getEline(lastError));
}

//function dumpStack(sTrace, eLine) {
function dumpStack() {
	var dump = 'callStack:\n';//eLine;
	var sTrace = printStackTrace();
	for (i=4;i<sTrace.length;i++) {
		dump += sTrace[i].split("/").pop() + '\n';
	}
	console.log(dump);
}
