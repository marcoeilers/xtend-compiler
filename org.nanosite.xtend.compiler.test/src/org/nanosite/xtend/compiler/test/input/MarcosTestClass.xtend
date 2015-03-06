		package org.nanosite.xtend.compiler.test.input
		
		class MarcosTestClass {
			public String someString
			private String privateString
			public Integer compiler
			
			def String doSomething(int aNumber){
				return "the code compiled by the compiler should be run instead"
			} 
		}