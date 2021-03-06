tree grammar SociaLiteRule;
options {
    tokenVocab=SociaLite;
    ASTLabelType=CommonTree;
    output = AST;
}

@header {
    package socialite.parser.antlr;    
    import socialite.parser.Query;
    import socialite.parser.Variable;
    import socialite.parser.Const;
    import socialite.parser.Predicate;
    import socialite.parser.Function;
    import socialite.parser.AggrFunction;
    import socialite.parser.Expr;
    import socialite.parser.Op;    
    import socialite.parser.CmpOp;
    import socialite.parser.BinOp;
    import socialite.parser.AssignOp;
    import socialite.parser.AssignDotVar;
    import socialite.parser.UnaryOp;    
    import socialite.parser.UnaryMinus;    
    import socialite.parser.TypeCast;
    import socialite.parser.hash;
    import socialite.parser.Parser;   
    import socialite.util.ParseException;
    import socialite.util.InternalException;
    import socialite.util.Assert;
    import java.util.List;
    import java.util.ArrayList;
    import java.util.HashMap;
    import java.util.Map;
    import java.util.Set;
    import java.util.LinkedHashSet;
    import socialite.type.Utf8;    
    import java.lang.reflect.Array;
}

@members {
    public Parser parser;
    public Map<String, TableDecl> tableDeclMap = new HashMap<String, TableDecl>();
    Set<Variable> dotVars = new LinkedHashSet<Variable>();
    List<AssignOp> tmpVarAssigns = new ArrayList<AssignOp>();
    int kind=0;
    public Parser getParser() { return parser; }
    public String maybeGetDuplicateColumnName(ColumnDecl d1, List<ColumnDecl> decls) {
        LinkedHashSet<String> names = new LinkedHashSet<String>(decls.size()+1);
        if (d1!=null) names.add(d1.name);
        if (decls==null) return null;
        for (ColumnDecl d:decls) {
            if (names.contains(d.name))
                return d.name;
            names.add(d.name);
        }
        return null;
    }
    public void displayRecognitionError(String[] tokenNames, RecognitionException e) {
//        String hdr = getErrorHeader(e);
        String msg = getErrorMessage(e, tokenNames);
        throw new ParseException(parser, e, msg);
    }

    public void checkParamsInBodyP(Predicate bodyp, int line, int pos) {
        for (Object p:bodyp.getAllParams()) {
        }
    }
    public void checkParamsInHeadP(Predicate head, int line, int pos) {
        for (Object p:head.getAllParams()) {
        }
    }
    public boolean isSimpleIntValue(Object o) {
        return getSimpleIntValue(o) != null;
    }
    public Integer getSimpleIntValue(Object o) {
        if (o instanceof Const) {
            Const c=(Const)o;
            if (c.type.equals(Integer.class)||c.type.equals(int.class))
                return (Integer)c.val;
        }

        if (o instanceof BinOp) {
            BinOp b = (BinOp)o;
            if (b.arg1 instanceof Const && b.arg2 instanceof Const) {
                Integer arg1=(Integer)((Const)b.arg1).val;
                Integer arg2=(Integer)((Const)b.arg2).val;
                if (b.op.equals("+")) {
                    return arg1+arg2;
                } else if (b.op.equals("-")) {
                    return arg1-arg2;
                } else if (b.op.equals("mod")) {
                    return arg1\%arg2;
                } else if (b.op.equals("*")) {
                    return arg1*arg2;
                } else if (b.op.equals("/")) {
                    return arg1/arg2;
                }
            }
        }
        return null;
    }

    public Variable addTmpVarAssign(Object rhs) {
        Variable tmpVar = Variable.getTmpVar();
        try { tmpVarAssigns.add(new AssignOp(tmpVar, rhs));}
        catch (InternalException e) {}
        return tmpVar;
    }
    public boolean tmpVarAssignHasFunc() {
        for (AssignOp o:tmpVarAssigns) {
            if (o.arg2 instanceof Function) {
                return true;
            }
        }
        return false;
    }
}
prog returns [List result]
	: {$result = new ArrayList();}
	(stat {
	    if ($stat.result instanceof List)
	        $result.addAll((List)($stat.result));
	    else
    	        $result.add($stat.result);}
    	)+ EOF
	;
stat returns [Object result]
	:table_decl {$result = $table_decl.result;}
	|rule {$result = $rule.result;}
	|query{$result = $query.result;}
	|table_stmt {$result = $table_stmt.result;}
	;
table_stmt returns [TableStmt result]
	: ^(CLEAR ID) { $result = new ClearTable($ID.text);}	
	|^(DROP ID?) { $result = new DropTable($ID.text);}
	;
query returns [Query result]
	:^(QUERY predicate) { 
	$result = new Query($predicate.result);
	Variable.nextRule();
	Const.nextRule();
	tmpVarAssigns.clear();
	}
	;
table_decl returns [TableDecl result]
	:^(DECL (KIND1{kind=1;} | KIND2 {kind=2;})  ID ^(INDEX col_decl?) decls  ^(OPTION table_opts?) )
	  {
	    if (kind==2 && $col_decl.result==null) 
	        throw new ParseException(getParser(), $ID.line-1, $ID.pos+$ID.text.length()+1, "Cannot have nested table without any other columns"); 
	    String dupCol=maybeGetDuplicateColumnName($col_decl.result, $decls.result.getAllColDecls());
	    if (dupCol!=null) 
	        throw new ParseException(getParser(), $ID.line-1, $ID.pos,  "Duplicate column name "+dupCol+" in "+$ID);
	    if (kind==1) $result = new TableDecl($ID.text, $col_decl.result, $decls.result.colDecls, $decls.result.nestedTable);    
	    else $result = new TableDecl($ID.text, $col_decl.result, null, $decls.result);    
	    if ($result.nestedTable!=null) {
	        for (ColumnDecl d:$result.nestedTable.getAllColDecls()) {
	            if (d.option() instanceof ColIter) {
	                throw new ParseException(getParser(), $ID.line-1, $ID.pos+$ID.text.length()+1, "Iterator column cannot be nested."); 
	            }
	        }
	    }
	    try { $result.setOptions($table_opts.result); }
	    catch (ParseException e) {
	        e.setLine($ID.line-1); e.setPos(0);e.setParser(getParser());
	        throw e;
	    }
	    if (tableDeclMap.containsKey($ID.text)) {
	        if (!$result.equals(tableDeclMap.get($ID.text))) {
	            throw new ParseException(getParser(), $ID.line-1, $ID.pos, 
	                        $ID.text+" was previously declared with different signature.");	 
	        }
	        $result=null;
	    } else { tableDeclMap.put($ID.text, $result); }
	}
	;	

table_opts returns [List<TableOpt> result]
	:opt1=t_opt {$result = new ArrayList<TableOpt>(); $result.add($opt1.result);}
	(opt2=t_opt {$result.add($opt2.result);})* 
	;
t_opt returns [TableOpt result]
	:^(SORT_BY col=ID (order=SORT_ORDER)?) {
	    if ($order.text == null)  $result = new SortBy($col.text);
	    else if ($order.text.equals("asc"))  $result = new SortBy($col.text);
	    else  $result = new SortBy($col.text, false);
	}
	|^(ORDER_BY ID) {$result = new OrderBy($ID.text);}
	|^(INDEX_BY ID) {$result = new IndexBy($ID.text);}
	|^(GROUP_BY INT) { $result = new GroupBy(Integer.parseInt($INT.text));}
	| PREDEFINED {$result = new Predefined(); }
	| MULTISET {$result = new MultiSet();}	
	;
decls returns [NestedTableDecl result]
	:^(COL_DECLS col_decls ^(DECL nested=decls?))
	{ $result = new NestedTableDecl($col_decls.result, $nested.result);
	};	
col_decls returns [List<ColumnDecl> result]
	:d1=col_decl {$result = new ArrayList<ColumnDecl>(); $result.add($d1.result);}
	 (d2=col_decl {$result.add($d2.result);})*
	;  
col_decl returns [ColumnDecl result]
	: ^(COL_DECL type ID col_opt?) {
	$result = new ColumnDecl($type.result, $ID.text, $col_opt.result);
	}
	;
col_opt returns [ColOpt result]
	:^(RANGE i1=INT i2=INT) {
	    $result = new ColRange(Integer.parseInt($i1.text), Integer.parseInt($i2.text));
	}
	|^(SIZE i1=INT) {
	  $result = new ColSize(Integer.parseInt($i1.text));
	}
	| ITER {
	 $result = new ColIter();
	}
	;
type returns [Class result]
	:'int' {$result = int.class;} ('[' ']' {$result = int[].class;} )?  
	|'long'{$result=long.class;} ('[' ']' {$result = long[].class;})? 
	|'float' {$result = float.class;} ('[' ']' {$result = float[].class;})?  
	|'double' {$result = double.class;} ('[' ']' {$result = double[].class;})?  
	|'String' {$result = String.class;} ('[' ']' {$result = String[].class;})?  
	|'Object'{$result = Object.class;} ('[' ']' {$result = Object[].class;})?  
	| ID { 
	    String fullname = "socialite.type."+$ID.text;
	    try {  $result = Class.forName(fullname);
	    } catch (ClassNotFoundException e) {
	        throw new ParseException(getParser(), $ID.line-1, $ID.pos, "Class "+fullname+" cannot be resolved");	        
	    }
	} ('[' ']' {$result = Array.newInstance((Class)$result,0).getClass();})? 
	;
rule returns [Object result]
	:^(RULE ^(HEAD predicate) ^(BODY body1=litlist) ^(BODY body2=litlist?))
	{   
	    ArrayList body = new ArrayList($body1.result);
	    RuleDecl rd = new RuleDecl($predicate.result, body);
	    if ($body2.result==null) {
	        $result = rd;
	    } else {
	        ArrayList<RuleDecl> list = new ArrayList<RuleDecl>();
	        list.add((RuleDecl)rd);
	        rd = new RuleDecl($predicate.result, $body2.result);
	        list.add((RuleDecl)rd);
	        $result = list;
	    }
	    Variable.nextRule(); 
	    Const.nextRule();
	}
	;
litlist returns [List result]
	: { $result = new ArrayList(); }
	l1=literal  {
	    for (Variable v: dotVars) {
	        String root=v.name.substring(0, v.name.indexOf('.'));
	        Variable rootVar=Variable.getVariable(root);
	        AssignDotVar a;
	        try { a=new AssignDotVar(v, rootVar); } 
	        catch (InternalException e) { throw new RuntimeException(e);}
	        $result.add(new Expr(a));
	    }
	    dotVars.clear();

	    if ($l1.result instanceof List) {
	        for(Object o:(List)$l1.result) 
	            $result.add(o);
	    } else { $result.add($l1.result); }
	}
	(l2=literal {
	    for (Variable v: dotVars) {
	        String root=v.name.substring(0, v.name.indexOf('.'));
	        Variable rootVar=Variable.getVariable(root);
	        AssignDotVar a;
	        try { a=new AssignDotVar(v, rootVar); } 
	        catch (InternalException e) { throw new RuntimeException(e);}
	        $result.add(new Expr(a));
	    }
	    dotVars.clear();

	    if ($l2.result instanceof List) {
	        for(Object o:(List)$l2.result) 
	            $result.add(o);
	    } else { $result.add($l2.result); }
	})*
	;
literal returns [Object result]
	:^(PREDICATE NOT? predicate) {
	    $result = $predicate.result;
	    if ($NOT.text != null) {
	        ((Predicate)$predicate.result).setNegated(); 
	    }
	    if (!tmpVarAssigns.isEmpty()) {
	        $result = new ArrayList();
	        for (AssignOp op:tmpVarAssigns)
	            ((List)$result).add(new Expr(op));
	        ((List)$result).add($predicate.result);
	        tmpVarAssigns.clear();
	    }
	} |^(EXPR expr)  {
	    Expr e = new Expr((Op)$expr.result);
	    $result = e;
	    if (!tmpVarAssigns.isEmpty()) {
	        $result = new ArrayList();
	        for (AssignOp op:tmpVarAssigns)
	            ((List)$result).add(new Expr(op));
	        ((List)$result).add(e);
	        tmpVarAssigns.clear();
	    }
	}
	;
predicate returns [Predicate result]
	: ID ^(INDEX param?) paramlist
	{   TableDecl decl=tableDeclMap.get($ID.text);
	    if (decl==null) {
 	        throw new ParseException(getParser(), $ID.line-1, $ID.pos, "Table "+$ID.text+" is not declared");	 
	    } else {
	       try {
	           decl.checkTypes($param.result, $paramlist.result);
	       } catch(InternalException e) {
	           throw new ParseException(getParser(), $ID.line-1, $ID.pos, e.getMessage());
	       }
	    }
	    $result = new Predicate($ID.text, $param.result, $paramlist.result);
	}
	;	
function returns [Function result]
	: ^(FUNC dotname fparamlist?) {
	    $result = new Function($dotname.result, $fparamlist.result);
	}
	;
param returns [Object result]
	: simpleExpr {
	    if (tmpVarAssignHasFunc()) {
	        throw new ParseException(getParser(), 
	                        $simpleExpr.tree.getLine()-1,
	                        $simpleExpr.tree.getCharPositionInLine()+1, 
	                        "Cannot use functions with operators in a param list");
	    }
	    $result = $simpleExpr.result;
	    /*if ($simpleExpr.result instanceof TypeCast) {
	        TypeCast cast=(TypeCast)$result;
	        if (cast.arg instanceof Function) {
	           throw new ParseException(getParser(), 
	                        $simpleExpr.tree.getLine()-1,
	                        $simpleExpr.tree.getCharPositionInLine()+1, 
	                        "Cannot use type cast to aggregate functions");
	        }
	    }*/
	    if ($simpleExpr.result instanceof Function) {
	        $result = new AggrFunction((Function)$simpleExpr.result); 
	    }
	};
fparam returns [Object result]
	: simpleExpr { $result = $simpleExpr.result; };

paramlist returns [List result]
	:{ $result = new ArrayList(); }
	p1=param { 
	    if (isSimpleIntValue($p1.result)) {
	        $result.add(new Const(getSimpleIntValue($p1.result)));
	    } else if (($p1.result instanceof BinOp)||($p1.result instanceof UnaryOp)) {
	        Variable tmpVar = addTmpVarAssign($p1.result);
	        $result.add(tmpVar);
	    } else if ($p1.result instanceof Op) {
	        throw new ParseException(getParser(), 
	                        $p1.tree.getLine()-1, $p1.tree.getCharPositionInLine()+1, 
	                        "Cannot use "+$p1.result+" in parameter list"); 
	    } else { $result.add($p1.result); }
	}
	(p2=param { 
	    if (isSimpleIntValue($p2.result)) {
	        $result.add(new Const(getSimpleIntValue($p2.result)));
	    } else if (($p2.result instanceof BinOp)||($p2.result instanceof UnaryOp)) {
	        Variable tmpVar = addTmpVarAssign($p2.result);
	        $result.add(tmpVar);
	    } else if ($p2.result instanceof Op) {
	        throw new ParseException(getParser(),
	                        $p2.tree.getLine()-1, $p2.tree.getCharPositionInLine()+1, 
	                        "Cannot use "+$p2.result+" in parameter list"); 
	    } else { $result.add($p2.result); }
	})*
	;

fparamlist returns [List result]
	:{ $result = new ArrayList(); }
	p1=fparam { 
	    if (($p1.result instanceof BinOp)||($p1.result instanceof UnaryOp)||($p1.result instanceof Function)) {
	        Variable tmpVar = addTmpVarAssign($p1.result);
	        $result.add(tmpVar);
	    } else if ($p1.result instanceof Op) {
	        throw new ParseException(getParser(), 
	                        $p1.tree.getLine()-1, $p1.tree.getCharPositionInLine()+1, 
	                        "Cannot use "+$p1.result+" in parameter list"); 
	    } else { $result.add($p1.result); }
	}
	(p2=fparam { 
	    if (($p2.result instanceof BinOp)||($p2.result instanceof UnaryOp)||($p2.result instanceof Function)) {
	        Variable tmpVar = addTmpVarAssign($p2.result);
	        $result.add(tmpVar);
	    } else if ($p2.result instanceof Op) {
	        throw new ParseException(getParser(),
	                        $p2.tree.getLine()-1, $p2.tree.getCharPositionInLine()+1, 
	                        "Cannot use "+$p2.result+" in parameter list"); 
	    } else { $result.add($p2.result); }
	})*
	;


term returns [Object result]
	:^(T_INT INT)  {
	    if ($INT.text.endsWith("l") || $INT.text.endsWith("L")) {
	        Long v = new Long(Long.parseLong($INT.text.substring(0, $INT.text.length()-1)));
	        $result = new Const(v);
	    } else {
	        Integer v = new Integer(Integer.parseInt($INT.text));
	        $result = new Const(v);
	    }
	 } |^(T_FLOAT FLOAT)  {
 	    if ($FLOAT.text.endsWith("f") || $FLOAT.text.endsWith("F")) {
 	        Float v = new Float(Float.parseFloat($FLOAT.text.substring(0, $FLOAT.text.length()-1)));
 	        $result = new Const(v);
 	    } else if ($FLOAT.text.endsWith("d") || $FLOAT.text.endsWith("D")) {
 	        Double v = new Double(Double.parseDouble($FLOAT.text.substring(0, $FLOAT.text.length()-1)));
 	        $result = new Const(v);
 	    } else {
     	        Double v = new Double(Double.parseDouble($FLOAT.text));
     	        $result = new Const(v);
 	    }
	}
	|^(T_STR STRING)  {String v = new String($STRING.text.substring(1, $STRING.text.length()-1)); $result = new Const(v); }
	|^(T_UTF8 UTF8)  { Utf8 v =  new Utf8($UTF8.text.substring(2, $UTF8.text.length()-1)); $result = new Const(v); }
	|^(T_VAR dotname) {
	    $result = Variable.getVariable($dotname.result);
	    if ($dotname.result.indexOf('.')>=0) {
	        dotVars.add((Variable)$result);
	    }
	};
expr returns [Object result]
	:^(cmpStr=('<'|'<='|'>'|'>='|'=='|'!=') e1=simpleExpr e2=simpleExpr) {
	    try { $result = new CmpOp($cmpStr.text, $e1.result, $e2.result); }
	    catch (InternalException e) {
	        throw new ParseException(getParser(), $cmpStr.line-1, $cmpStr.pos+1, e.getMessage()); 
	    }
	} |^(eq='=' e1=simpleExpr e2=simpleExpr) {
	    if (!($e1.result instanceof Variable)) {
	        throw new ParseException(getParser(), $eq.line-1, $eq.pos+1, "Invalid assignment to "+$e1.result); 
	    }
	    TypeCast cast = null;
	    Object a1=$e1.result, a2=$e2.result;
	    if ($e2.result instanceof TypeCast) {
	        cast = (TypeCast)$e2.result;
	        a2 = cast.arg;
	        if (a2 instanceof TypeCast) throw new ParseException(getParser(), $eq.line-1, $eq.pos+1, "Invalid type cast"); 
	    }
	    try { $result = new AssignOp(a1, cast, a2); }
	    catch (InternalException e) {
	        throw new ParseException(getParser(), $eq.line-1, $eq.pos+1, e.getMessage()); 
	    }
	}  |^(MULTI_ASSIGN varlist function c=cast?) {
	    try { 
	        TypeCast typecast=null;
	        if ($c.result!=null) {
	            int line=$c.tree.getLine()-1, pos=$c.tree.getCharPositionInLine()+1;
	            throw new ParseException(getParser(), line, pos, "Invalid type cast"); 
	        }
	        $result = new AssignOp($varlist.result, typecast, $function.result); 
	    } catch (InternalException e) {
	        int line=$varlist.tree.getLine()-1, pos=$varlist.tree.getCharPositionInLine()+1;
	        throw new ParseException(getParser(), line, pos, e.getMessage()); 
	    }
	};
simpleExpr returns [Object result]
	:multExpr {$result = $multExpr.result;}
	|^(op=('+'|'-') e1=simpleExpr e2=simpleExpr) {
	    Object arg1=$e1.result, arg2=$e2.result;
	    if (arg1 instanceof Function) arg1=addTmpVarAssign(arg1);
	    if (arg2 instanceof Function) arg2=addTmpVarAssign(arg2); 

	    try { $result = new BinOp($op.text, arg1, arg2); }
	    catch (InternalException e) {
	        throw new ParseException(getParser(), $op.line-1, $op.pos+1, e.getMessage()); 
	    }
	};
multExpr returns [Object result]
	: exprValue { $result = $exprValue.result; }
	|^(op=('*'|'/'|'mod') v1=multExpr v2=multExpr) {
	    Object arg1=$v1.result, arg2=$v2.result;
	    if (arg1 instanceof Function) arg1=addTmpVarAssign(arg1);
	    if (arg2 instanceof Function) arg2=addTmpVarAssign(arg2); 

	    try { $result = new BinOp($op.text, arg1, arg2); }
	    catch (InternalException e) {
	        throw new ParseException(getParser(), $op.line-1, $op.pos+1, e.getMessage()); 
	    }
	};
compExpr returns [Object result]
	: e1=simpleExpr {$result=$e1.result;}
	   ;
varlist returns [Object result]
	:id1=dotname{ 
	    List<Variable> vars = new ArrayList<Variable>();
	    vars.add(Variable.getVariable($id1.result)); $result = vars; }
	(id2=dotname{ 
	    vars.add(Variable.getVariable($id2.result));})+
	;
exprValue returns [Object result]
	:^(TERM term (neg='-')? c=cast?) {
	    $result = $term.result;
	    if ($c.result != null) {
	        TypeCast cast = new TypeCast($c.result, $result);
	        $result = cast;
	    }
	    if ($neg.text != null) {
	        if ($term.result instanceof Const) {
	            ((Const)$term.result).negate();
	        } else {
	            try { $result = new UnaryMinus($result); }
	            catch (InternalException e) {
	                throw new ParseException(getParser(), $neg.line-1, $neg.pos+1, e.getMessage()); 
	            }
	        }
	    }
	}
	|^(FUNCTION function c=cast?) { 
	    $result = $function.result; 
	    if ($c.result != null) {
	        Object tmpvar = addTmpVarAssign($function.result);
	        TypeCast cast = new TypeCast($c.result, tmpvar);
	        $result = cast;
	    }
	}
	|^(COMPOUND_EXPR compExpr c=cast?) { 
	    $result = $compExpr.result;
	    if ($c.result != null) {
	        TypeCast cast=new TypeCast($c.result, $result);
	        $result = cast;
	    }
	}
	;
cast returns [Class result]
	:type {$result = $type.result; };

dotname returns [String result]
	:ID { $result = new String($ID.text); }
	 (DOT_ID { $result += new String($DOT_ID.text); })*
	;

