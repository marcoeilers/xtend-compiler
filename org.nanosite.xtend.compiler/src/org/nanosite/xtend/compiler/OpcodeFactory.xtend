package org.nanosite.xtend.compiler

import static extension org.nanosite.xtend.compiler.CompilerUtil.*

class OpcodeFactory {
	
	def static byte[] instanceofOp(int index){
		val result = newByteArrayOfSize(3)
		result.setU1(0, 0xc1)
		result.setU2(1, index)
		result
	}

	def static byte[] ireturn() {
		getU1(0xac)
	}
	
	def static byte[] aconst_null(){
		getU1(0x01)
	}

	def static byte[] dreturn() {
		getU1(0xaf)
	}

	def static byte[] lreturn() {
		getU1(0xad)
	}

	def static byte[] freturn() {
		getU1(0xae)
	}

	def static byte[] areturn() {
		getU1(0xb0)
	}

	def static byte[] istore(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x36)
		result.setU1(1, index)
		result
	}

	def static byte[] dstore(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x39)
		result.setU1(1, index)
		result
	}

	def static byte[] fstore(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x38)
		result.setU1(1, index)
		result
	}

	def static byte[] lstore(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x37)
		result.setU1(1, index)
		result
	}

	def static byte[] astore(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x3a)
		result.setU1(1, index)
		result
	}

	def static byte[] iload(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x15)
		result.setU1(1, index)
		result
	}

	def static byte[] dload(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x18)
		result.setU1(1, index)
		result
	}

	def static byte[] fload(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x17)
		result.setU1(1, index)
		result
	}

	def static byte[] lload(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x16)
		result.setU1(1, index)
		result
	}

	def static byte[] aload(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x19)
		result.setU1(1, index)
		result
	}
		
	def static byte[] pop(){
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
		getU1(0x2a + index)
	}

	def static byte[] returnVoid() {
		getU1(0xb1)
	}

	def static byte[] ret(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0xa9)
		result.setU1(1, index)
		result
	}

	def static byte[] ldc(int index) {
		val result = newByteArrayOfSize(2)
		result.setU1(0, 0x12)
		result.setU1(1, index)
		result
	}

	def static byte[] dup() {
		getU1(0x59)
	}
	
	def static byte[] newOp(int index){
		val result = newByteArrayOfSize(3)
		result.setU1(0, 0xbb)
		result.setU2(1, index)
		result
	}
}