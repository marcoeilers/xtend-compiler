package org.nanosite.xtend.compiler

import static extension org.nanosite.xtend.compiler.CompilerUtil.*

class OpcodeFactory {
	
	static int stackSize = 0
	
	def static void changeStack(String function, int diff){
		println(function)
		stackSize += diff
		println("New Stack size " + stackSize)
	}
	
	def static byte[] getField(int index){
		changeStack("getField", 0)
		val result = newByteArrayOfSize(3)
		result.setU1(0, 0xb4)
		result.setU2(1, index)
		result
	}
	
	def static byte[] getStatic(int index){
		changeStack("getStatic", 1)
		val result = newByteArrayOfSize(3)
		result.setU1(0, 0xb2)
		result.setU2(1, index)
		result
	}
	
	def static byte[] putField(int index){
		changeStack("putField", -2)
		val result = newByteArrayOfSize(3)
		result.setU1(0, 0xb5)
		result.setU2(1, index)
		result
	}
	
	def static byte[] putStatic(int index){
		changeStack("putStatic", -1)
		val result = newByteArrayOfSize(3)
		result.setU1(0, 0xb3)
		result.setU2(1, index)
		result
	}
	
	def static byte[] instanceofOp(int index){
		val result = newByteArrayOfSize(3)
		result.setU1(0, 0xc1)
		result.setU2(1, index)
		changeStack("instanceof", 0)
		result
	}

	def static byte[] ireturn() {
		changeStack("ireturn", -1)
		getU1(0xac)
	}
	
	def static byte[] aconst_null(){
		changeStack("aconst_null", 1)
		getU1(0x01)
	}

	def static byte[] dreturn() {
		changeStack("dreturn", -2)
		getU1(0xaf)
	}

	def static byte[] lreturn() {
		changeStack("lreturn", -2)
		getU1(0xad)
	}

	def static byte[] freturn() {
		changeStack("freturn", -1)
		getU1(0xae)
	}

	def static byte[] areturn() {
		changeStack("areturn", -1)
		getU1(0xb0)
	}

	def static byte[] istore(int index) {
		changeStack("istore", -1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x36)
		result.setU1(1, index)
		result
	}

	def static byte[] dstore(int index) {
		changeStack("dstore", -1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x39)
		result.setU1(1, index)
		result
	}

	def static byte[] fstore(int index) {
		changeStack("fstore", -1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x38)
		result.setU1(1, index)
		result
	}

	def static byte[] lstore(int index) {
		changeStack("lstore", -2)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x37)
		result.setU1(1, index)
		result
	}

	def static byte[] astore(int index) {
		changeStack("astore", -1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x3a)
		result.setU1(1, index)
		result
	}

	def static byte[] iload(int index) {
		changeStack("iload", 1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x15)
		result.setU1(1, index)
		result
	}

	def static byte[] dload(int index) {
		changeStack("dload", 2)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x18)
		result.setU1(1, index)
		result
	}

	def static byte[] fload(int index) {
		changeStack("fload", 1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x17)
		result.setU1(1, index)
		result
	}

	def static byte[] lload(int index) {
		changeStack("lload", 2)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x16)
		result.setU1(1, index)
		result
	}

	def static byte[] aload(int index) {
		changeStack("aload", 1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x19)
		result.setU1(1, index)
		result
	}
		
	def static byte[] pop(){
		changeStack("pop", -1)
		getU1(0x57)
	}

	def static byte[] invokeSpecial(int methodIndex) {
		invoke(0xb7, methodIndex)
	}

	def static byte[] invokeStatic(int methodIndex) {
		invoke(0xb8, methodIndex)
	}

	def static byte[] invokeVirtual(int methodIndex) {
		invoke(0xb6, methodIndex)
	}

	def static byte[] invoke(int op, int methodIndex) {
		val result = newByteArrayOfSize(3)
		result.setU1(0, op)
		result.setU2(1, methodIndex)

		result
	}

	def static byte[] loadLocalReference(int index) {
		changeStack("load", 1)
		getU1(0x2a + index)
	}

	def static byte[] returnVoid() {
		changeStack("return", -1)
		getU1(0xb1)
	}

	def static byte[] ret(int index) {
		changeStack("ret", -1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0xa9)
		result.setU1(1, index)
		result
	}

	def static byte[] ldc(int index) {
		changeStack("ldc", 1)
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x12)
		result.setU1(1, index)
		result
	}

	def static byte[] dup() {
		changeStack("dup", 1)
		getU1(0x59)
	}
	
	def static byte[] newOp(int index){
		changeStack("new", 1)
		val result = newByteArrayOfSize(3)
		result.setU1(0, 0xbb)
		result.setU2(1, index)
		result
	}
}