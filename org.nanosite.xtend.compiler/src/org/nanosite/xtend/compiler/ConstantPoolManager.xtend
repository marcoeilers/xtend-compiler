package org.nanosite.xtend.compiler

import java.util.List
import java.util.ArrayList
import static extension org.nanosite.xtend.compiler.CompilerUtil.*

class ConstantPoolManager {
	private ArrayList<byte[]> pool
	private int nextActualIndex = 0
	private int nextDeclaredIndex = 1
	
	new(){
		pool = new ArrayList
	}
	
	def create index : nextDeclaredIndex++ addUtf8Entry(String string){
		val actualIndex = nextActualIndex++
		pool.expandTo(actualIndex + 1)
		val entrySize = 1 + 2 + string.length
		val entry = newByteArrayOfSize(entrySize)
		entry.setU1(0, 1)
		entry.setU2(1, string.length)
		System.arraycopy(string.getBytes("UTF-8"), 0, entry, 3, string.length)
		pool.set(actualIndex, entry)
	}
	
	def create index : nextDeclaredIndex++ addStringEntry(String string){
		val actualIndex = nextActualIndex++
		pool.expandTo(actualIndex + 1)
		val entrySize = 1 + 2
		val entry = newByteArrayOfSize(entrySize)
		entry.setU1(0, 8)
		val utf8Index = addUtf8Entry(string)
		entry.setU2(1, utf8Index)
		pool.set(actualIndex, entry)
	}
	
	def create index : nextDeclaredIndex++ addClassEntry(String fqn){
		val actualIndex = nextActualIndex++
		pool.expandTo(actualIndex + 1)
		val entrySize = 1 + 2
		val entry = newByteArrayOfSize(entrySize)
		entry.setU1(0, 7)
		val internalFqn = fqn.convertToInternalClassName
		val utf8Entry = addUtf8Entry(internalFqn)
		entry.setU2(1, utf8Entry)
		pool.set(actualIndex, entry)
	}
	
	def create index : nextDeclaredIndex++ addNameAndTypeEntry(String name, String descriptor){
		val actualIndex = nextActualIndex++
		pool.expandTo(actualIndex + 1)
		val entrySize = 1 + 2 + 2
		val entry = newByteArrayOfSize(entrySize)
		entry.setU1(0, 12)
		val nameEntry = addUtf8Entry(name)
		val descriptorEntry = addUtf8Entry(descriptor)
		entry.setU2(1, nameEntry)
		entry.setU2(3, descriptorEntry)
		pool.set(actualIndex, entry)
	}
	
	def create index : nextDeclaredIndex++ addFieldEntry(String className, String fieldName, String type){
		val actualIndex = nextActualIndex++
		pool.expandTo(actualIndex + 1)
		val entrySize = 1 + 2 + 2
		val entry = newByteArrayOfSize(entrySize)
		entry.setU1(0, 9)
		val classIndex = addClassEntry(className)
		val nameTypeIndex = addNameAndTypeEntry(fieldName, type.convertToFieldDescriptor)
		entry.setU2(1, classIndex)
		entry.setU2(3, nameTypeIndex)
		pool.set(actualIndex, entry)
	}
	
	def addMethodEntry(String className, String methodName, String returnType, List<String> argTypes){
		addMethodEntry(className, methodName, returnType, argTypes, 10)
	}
	
	def create index : nextDeclaredIndex++ addMethodEntry(String className, String methodName, String returnType, List<String> argTypes, int tag){
		val actualIndex = nextActualIndex++
		pool.expandTo(actualIndex + 1)
		val entrySize = 1 + 2 + 2
		val entry = newByteArrayOfSize(entrySize)
		entry.setU1(0, tag)
		val classIndex = addClassEntry(className)
		val nameTypeIndex = addNameAndTypeEntry(methodName, convertToMethodDescriptior(returnType, argTypes))
		entry.setU2(1, classIndex)
		entry.setU2(3, nameTypeIndex)
		pool.set(actualIndex, entry)
	}
	
	def addInterfaceMethodEntry(String className, String methodName, String returnType, List<String> argTypes){
		addMethodEntry(className, methodName, returnType, argTypes, 11)
	}
	
	def addIntegerEntry(int value){
		addIntegerFloatEntry(value, 3)
	}
	
	def create index : nextDeclaredIndex++ addIntegerFloatEntry(int value, int tag){
		val actualIndex = nextActualIndex++
		pool.expandTo(actualIndex + 1)
		val entrySize = 1 + 4
		val entry = newByteArrayOfSize(entrySize)
		entry.setU1(0, tag)
		entry.setU1(1, value >> 24)
		entry.setU1(2, (value >> 16) % 256)
		entry.setU1(3, (value >> 8) % 256)
		entry.setU1(4, value % 256)
		pool.set(actualIndex, entry)
	}
	
	def addFloatEntry(float value){
		addIntegerFloatEntry(Float.floatToIntBits(value), 4)
	}
	
	def create index : nextDeclaredIndex++ addLongDoubleEntry(long value, int tag){
		nextDeclaredIndex++
		val actualIndex = nextActualIndex++
		pool.expandTo(actualIndex + 1)
		val entrySize = 1 + 4 + 4
		val entry = newByteArrayOfSize(entrySize)
		entry.setU1(0, tag)
		entry.setU1(1, (value >> 56) % 256)
		entry.setU1(2, (value >> 48) % 256)
		entry.setU1(3, (value >> 40) % 256)
		entry.setU1(4, (value >> 32) % 256)
		entry.setU1(5, (value >> 24) % 256)
		entry.setU1(6, (value >> 16) % 256)
		entry.setU1(7, (value >> 8) % 256)
		entry.setU1(8, value % 256)
		pool.set(actualIndex, entry)
	}
	
	def addLongEntry(long value){
		addLongDoubleEntry(value, 5)
	}
	
	def addDoubleEntry(double value){
		addLongDoubleEntry(Double.doubleToLongBits(value), 5)
	}
	
	def getPoolSize(){
		nextDeclaredIndex
	}
	
	def getPoolBytes(){
		var actualSize = 0
		for (b : pool)
			actualSize += b.length
		
		val result = newByteArrayOfSize(actualSize)
		var offset = 0
		for (b : pool){
			System.arraycopy(b, 0, result, offset, b.length)
			offset += b.length
		}
		result
	}
	
	def void expandTo(List<?> bytes, int size){
		if (bytes.size >= size)
			throw new IllegalStateException
		while (bytes.size < size)
			bytes.add(null)
	}
	
}