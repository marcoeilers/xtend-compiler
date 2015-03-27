package org.nanosite.xtend.compiler.test.input

import org.junit.Test
import static org.junit.Assert.*

class CompiledClassTest {
	
	@Test
	def void testSomething(){
		val instance = new MarcosTestClass
		instance.someString = "asdasdasd"
		instance.private = "PRIVATE"
		assertEquals("asdasdasd", instance.someString)
		assertEquals("SOMETHINGBLAUAUAUA48PRIVATEPRIVATE", instance.doSomething(7))
	}
}