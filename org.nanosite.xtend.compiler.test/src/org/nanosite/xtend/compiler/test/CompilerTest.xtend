package org.nanosite.xtend.compiler.test

import com.google.inject.Inject
import java.io.FileOutputStream
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtext.junit4.InjectWith
import org.eclipse.xtext.junit4.XtextRunner
import org.eclipse.xtext.junit4.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith
import org.nanosite.xtend.compiler.XtendCompiler

@InjectWith(XtendencyInjectorProvider)
@RunWith(XtextRunner)
class CompilerTest {
	public static final String PACKAGE = "org.nanosite.xtend.interpreter.tests.input"
	
	@Inject
	private XtendCompiler compiler
	
	@Inject
	protected ParseHelper<XtendFile> parser 
	
	def void compileToFile(XtendFile file, String className, String fileName){
		val clazz = file.xtendTypes.findFirst[name == className]
		
		val output = compiler.generateClass(clazz as XtendClass)
		
		val outputStream = new FileOutputStream(fileName)
		outputStream.write(output)
		outputStream.close
		
	}
	
	@Test
	def void testSomething(){
		val source = '''
		package org.nanosite.xtend.compiler.test.input
		
		class MarcosTestClass {
			public String someString
			private String privateString
			public Integer compiler
			
			def String doSomething(int aNumber){
				var aVar = aNumber
				aVar = aVar + 17
				var blaVar = "bl"
				//println("Test123")
				for (var i = 0; i < aNumber; i = i + 1)
					blaVar = blaVar + if (i % 2 == 0) "a" else "u"
				"something" + blaVar + (aVar * 2) + privateString + private
			}
			
			def void setPrivate(String someString){
				privateString = someString
			}
			
			def String getPrivate(){
				privateString
			}
		}
		'''
		
		val file = parser.parse(source)
		
		compileToFile(file, "MarcosTestClass", "bin/org/nanosite/xtend/compiler/test/input/MarcosTestClass.class")

	}
}