package org.nanosite.xtend.compiler.test.input;

import org.nanosite.xtend.compiler.test.input.MarcosTestClass;

public class OtherClassTestClass {
	public static void main(String[] args){
		MarcosTestClass something = new MarcosTestClass();
		
		something.someString = "asdasd";
		
		System.out.println(something.someString);
		System.out.println(something.doSomething(240));

		
	}
}
