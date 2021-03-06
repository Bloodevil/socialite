package socialite.parser;

import java.io.Serializable;
import java.util.HashMap;

import socialite.util.InternalException;
import socialite.util.SociaLiteException;

public class Variable implements Serializable {
	private static final long serialVersionUID = 1L;


	static HashMap<String, Variable> varMapInARule=new HashMap<String, Variable>();
	public static Variable getVariable(String name) {
		if (name.equals("_")) return new Variable(name);
		if (varMapInARule.containsKey(name)) return varMapInARule.get(name);
		Variable v = new Variable(name);
		varMapInARule.put(name, v);
		return v;
	}
	public static Variable getTmpVar() {
		String name = "_tmp$"+(varCountInARule++);
		return new Variable(name);
	}
	public static void nextRule() { 
		varMapInARule.clear();
		varCountInARule=0;
	}
	private static int varCountInARule=0;
	
	
	public String name;
	public Class type;	
	public boolean dontCare=false;

	public Variable(String _name) {
		if (_name.equals("_")) { // don't care variable
			_name = "_$"+(varCountInARule++);
			dontCare=true;
		}
		name = _name;
		type = NoType.class;
	}

	public Variable(String _name, Class _type) {
		name = _name;
		type = _type;
	}

	public String toString() { return name; }

	//public void rename(String _name) { name = _name; }
	public void setType(Class _type) throws InternalException {
		_type = MyType.javaType(_type);		
		if (hasType()) {
			if (type.equals(_type)) return;
			if (_type.equals(Object.class)) return;
			if (type.equals(Object.class)) {
				type = _type;
				return;
			}			
						
			String msg="Variable "+name+" is "+type.getSimpleName()+ " type"+
						", incompatible with type "+ _type.getSimpleName();
			throw new InternalException(msg);
		}		
		type = MyType.javaType(_type);
	}

	public boolean isRealVar() {
		if (name.indexOf('.')>=0)
			return false;
		return true;
	}
	public boolean hasType() {
		if (type.equals(NoType.class)) return false;
		else return true;
	}

	@Override
	public int hashCode() {
		return name.hashCode() << 2 + type.hashCode();
	}

	@Override
	public boolean equals(Object o) {
		if (!(o instanceof Variable)) return false;

		Variable v = (Variable) o;
		if (name.equals(v.name) && type.equals(v.type))
			return true;
		return false;
	}

	public String description() {
		int id=System.identityHashCode(this);
		return name + "@"+id+":" + type.getSimpleName();
	}
}