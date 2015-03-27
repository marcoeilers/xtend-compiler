package org.nanosite.xtend.compiler

import java.util.List
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration

class CompilerUtil {
	def static setU1(byte[] bytes, int position, int value){
		bytes.set(position, value as byte)
	}
	
	def static setU1(byte[] bytes, int position, long value){
		bytes.set(position, value as byte)
	}
	
	def static setU2(byte[] bytes, int position, int value){
		val short svalue = value as short
		bytes.set(position, (svalue >> 8) as byte)
		bytes.set(position + 1, (svalue % 256) as byte)
		bytes
	}
	
	def static setU4(byte[] bytes, int position, int value){
		bytes.set(position, (value >> 24) as byte)
		bytes.set(position + 1, ((value >> 16) % 256) as byte)
		bytes.set(position + 2, ((value >>  8) % 256) as byte)
		bytes.set(position + 3, (value % 256) as byte)
	}
	
	def static byte[] getU1(int value){
		val result = newByteArrayOfSize(1)
		result.setU1(0, value)
		result
	}
	
	def static byte[] getU2(int value){
		val result = newByteArrayOfSize(2)
		result.setU2(0, value)
		result
	}
	
	def static byte[] getU4(int value){
		val result = newByteArrayOfSize(4)
		result.setU4(0, value)
		result
	}
	
	def static String getQualifiedName(XtendTypeDeclaration clazz){
		(clazz.eContainer as XtendFile).package + "." + clazz.name
	}
	
	def static String convertToMethodDescriptior(String returnType, List<String> params){
		'''(«FOR p : params»«p.convertToFieldDescriptor»«ENDFOR»)«returnType.convertToFieldDescriptor»'''
	}
	
	def static convertToInternalClassName(String fqn){
		fqn.replaceAll("\\.", "/")
	}
	
	def static convertToFieldDescriptor(String fqn){
		var withoutArray = fqn
		var arrayDims = 0
		while (withoutArray.endsWith("[]")){
			withoutArray = withoutArray.substring(0, withoutArray.length - 2)
			arrayDims++
		}
		
		val internalClassName = switch(withoutArray){
			case "byte" : "B"
			case "char" : "C"
			case "double" : "D"
			case "float" : "F"
			case "int" : "I"
			case "long" : "J"
			case "short" : "S"
			case "boolean" : "Z"
			case "void" : "V"
			default: {
				// assume class name
				"L" +  withoutArray.convertToInternalClassName + ";"
			}
		}
		var result = new StringBuilder
		for (i : 0..<arrayDims)
			result.append("[")
		result.append(internalClassName)
		result.toString
	}
}