package model;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type.ClassField;
import haxe.macro.Context;
#end


import haxe.PosInfos;

/**
 * ...
 * @author axel@cunity.me
 */
class Helper
{

	macro static public function createCond( cond:Expr):Expr
	{
		var p = cond.pos;
		trace(cond);
		switch (cond.expr)
		{
			case EConst(e):
				switch(e)
				{
					case CIdent(s): trace(s);
					case _:
						trace('ooops');
				}
			case _:
				trace('ooops');
		}
		return  cond;
		//return  Context.follow(cond, p);
		//return { expr : EConst(CIdent('$' + 'last_name')), pos:Context.currentPos() };
	}
	
}