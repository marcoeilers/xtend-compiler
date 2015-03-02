package org.nanosite.xtend.compiler

import com.google.inject.Inject
import java.util.ArrayList
import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.xtend.core.jvmmodel.IXtendJvmAssociations
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtend.core.xtend.XtendVariableDeclaration
import org.eclipse.xtext.common.types.JvmField
import org.eclipse.xtext.common.types.JvmFormalParameter
import org.eclipse.xtext.common.types.JvmIdentifiableElement
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.common.types.JvmPrimitiveType
import org.eclipse.xtext.common.types.JvmVisibility
import org.eclipse.xtext.common.types.JvmVoid
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtext.xbase.XAssignment
import org.eclipse.xtext.xbase.XBasicForLoopExpression
import org.eclipse.xtext.xbase.XBlockExpression
import org.eclipse.xtext.xbase.XConstructorCall
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XIfExpression
import org.eclipse.xtext.xbase.XInstanceOfExpression
import org.eclipse.xtext.xbase.XNumberLiteral
import org.eclipse.xtext.xbase.XReturnExpression
import org.eclipse.xtext.xbase.XStringLiteral
import org.eclipse.xtext.xbase.XTypeLiteral
import org.eclipse.xtext.xbase.XVariableDeclaration
import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import org.eclipse.xtext.xbase.typesystem.IBatchTypeResolver

import static org.nanosite.xtend.compiler.OpcodeFactory.*

import static extension org.nanosite.xtend.compiler.CompilerUtil.*

class XtendCompiler {
	protected static final int ACC_PUBLIC = 0x0001
	protected static final int ACC_FINAL = 0x0010
	protected static final int ACC_SUPER = 0x0020
	protected static final int ACC_INTERFACE = 0x0200
	protected static final int ACC_ABSTRACT = 0x0400
	protected static final int ACC_SYNTHETIC = 0x1000
	protected static final int ACC_ANNOTATION = 0x2000
	protected static final int ACC_ENUM = 0x4000

	private ConstantPoolManager constantPool = new ConstantPoolManager
	private List<byte[]> bytes
	private Map<XtendFunction, Integer> freeLocal
	private Map<XtendFunction, Map<JvmIdentifiableElement, Integer>> usedLocals

	@Inject
	private extension IXtendJvmAssociations jvmTypes

	@Inject private XbaseInterpreter interpreter
	@Inject
	private IBatchTypeResolver typeResolver;

	def generateClass(XtendClass clazz) {
		bytes = new ArrayList
		addMagicNumber
		addVersion

		// constant pool will be added later
		clazz.addAccessFlags

		bytes += getU2(constantPool.addClassEntry(clazz.qualifiedName))

		bytes += getU2(constantPool.addClassEntry(clazz.extends?.qualifiedName ?: "java.lang.Object"))

		bytes += getU2(clazz.implements.size)

		for (interf : clazz.implements) {
			bytes += getU2(constantPool.addClassEntry(interf.qualifiedName))
		}

		bytes += getU2(clazz.inferredType.declaredFields.size)

		for (field : clazz.inferredType.declaredFields) {
			field.addField
		}

		// methods
		bytes += getU2(1 + clazz.members.filter(XtendFunction).size)
		clazz.addDefaultConstructor

		for (func : clazz.members.filter(XtendFunction))
			func.addMethod

		// attributes
		bytes += getU2(0)

		bytes.add(2, getU2(constantPool.poolSize))
		bytes.add(3, constantPool.poolBytes)

		var resultSize = 0
		for (b : bytes)
			resultSize += b.length

		val result = newByteArrayOfSize(resultSize)
		var offset = 0
		for (b : bytes) {
			System.arraycopy(b, 0, result, offset, b.length)
			offset += b.length
		}
		result
	}

	def void addMethod(XtendFunction func) {
		val method = func.directlyInferredOperation

		var result = new ArrayList
		if (freeLocal == null)
			freeLocal = new HashMap
		if (usedLocals == null)
			usedLocals = new HashMap
		usedLocals.put(func, new HashMap)
		
		for (var i = 0; i < func.parameters.size; i++)
			usedLocals.get(func).put(func.directlyInferredOperation.parameters.get(i), i + 1)
		
		freeLocal.put(func, 1 + func.parameters.size)
		val flags = 0x0001
		result += getU2(flags)

		result += getU2(constantPool.addUtf8Entry(method.simpleName))

		result +=
			getU2(
				constantPool.addUtf8Entry(
					convertToMethodDescriptior(method.returnType.qualifiedName,
						method.parameters.map[parameterType.qualifiedName])))

		result += getU2(1)

		// code attribute
		val attribute = new ArrayList
		attribute += getU2(constantPool.addUtf8Entry("Code"))

		// set length at the end
		// max stack, whatever
		attribute += getU2(8)

		// max locals, whatever
		attribute += getU2(8)

		// set code length at the end
		// do code here
		val code = func.expression.compileExpression(func)

		var codeLength = 0
		for (c : code)
			codeLength += c.length
		attribute += getU4(codeLength)

		// set code length now
		attribute += code

		// exception table length
		attribute += getU2(0)

		// attributes
		attribute += getU2(0)

		// set length now
		var length = 0
		for (b : attribute.tail)
			length += b.length

		attribute.add(1, getU4(length))

		result += attribute

		bytes += result
	}

	def dispatch List<byte[]> compileExpression(XBlockExpression expr, XtendFunction func) {
		val result = new ArrayList
		for (e : expr.expressions)
			result += e.compileExpression(func)
		result
	}
	
	def dispatch List<byte[]> compileExpression(XVariableDeclaration expr, XtendFunction func){
		if (!(expr instanceof XtendVariableDeclaration))
			throw new IllegalArgumentException
		val result = new ArrayList
		val newVarIndex = func.nextFreeLocal
		usedLocals.get(func).put(expr, newVarIndex)
		if (expr.right != null){
			result += compileExpressionToExpectedType(expr.right, func)
			val resolved = typeResolver.resolveTypes(expr)
			val type = resolved.getActualType(expr.right)
			result += store(type.type.qualifiedName, newVarIndex)
		}
		result
	}
	
//	def dispatch List<byte[]> compileExpression(XNullLiteral expr, XtendFunction func){
//		#[aconst_null]
//	}
//	
//	def dispatch List<byte[]> compileExpression(XForLoopExpression expr, XtendFunction func){
//		
//	}
//	
	def dispatch List<byte[]> compileExpression(XBasicForLoopExpression expr, XtendFunction func){
		val result = new ArrayList
		for (ie : expr.initExpressions)
			result += ie.compileExpressionToExpectedType(func)

		val check =  expr.expression.compileExpressionToExpectedType(func)
		result += check
		val startJump = newByteArrayOfSize(3)
		result += startJump
		
		val each = expr.eachExpression.compileExpressionToExpectedType(func)
		result += each
		
		val update = new ArrayList
		for (ue : expr.updateExpressions)
			update += ue.compileExpressionToExpectedType(func)
		result += update
			
		val endJump = newByteArrayOfSize(3)
		result += endJump
		
		var endOffset = -3
		var startOffset = 3
		for (b : check)
			endOffset -= b.length
		for (b : each){
			startOffset += b.length
			endOffset -= b.length
		}
		for (b : update){
			startOffset += b.length
			endOffset -= b.length
		}
		startOffset += 3
		
		startJump.setU1(0, 0x99)
		startJump.setU2(1, startOffset)
		
		endJump.setU1(0, 0xa7)
		endJump.setU2(1, endOffset)
		result
	}
	
	def dispatch List<byte[]> compileExpression(XInstanceOfExpression expr, XtendFunction func) {
		#[instanceofOp(expr.type.qualifiedName)]
	}
	
	def dispatch List<byte[]> compileExpression(XTypeLiteral expr, XtendFunction func){
		#[ldc(constantPool.addClassEntry(expr.type.qualifiedName))]
	}
	
	def instanceofOp(String fqn){
		instanceofOp(constantPool.addClassEntry(fqn))
	}
	
	def dispatch List<byte[]> compileExpression(XAssignment expr, XtendFunction func){
		if (expr.feature instanceof XtendVariableDeclaration){
			if (expr.actualArguments.size != 1)
				throw new IllegalStateException
			val result = new ArrayList
			val variable = expr.feature as XtendVariableDeclaration
			val index = usedLocals.get(func).get(variable)
			result += compileExpressionToExpectedType(expr.actualArguments.head, func)
			result += store(expr.actualArguments.head.actualType.type.qualifiedName, index)
			result
		}else{
			compileExpression(expr as XAbstractFeatureCall, func)
		}
	}

	def dispatch List<byte[]> compileExpression(XReturnExpression expr, XtendFunction func) {
		val result = new ArrayList
		if (expr.expression != null) {
			result += compileExpression(expr.expression, func)
			result += returnType(func.directlyInferredOperation.returnType.qualifiedName)
		} else {
			result += returnVoid
		}
		result
	}

	def dispatch List<byte[]> compileExpression(XStringLiteral expr, XtendFunction func) {
		val result = new ArrayList
		val constIndex = constantPool.addStringEntry(expr.value.toUpperCase)
		result += ldc(constIndex)
		result
	}

	def dispatch List<byte[]> compileExpression(XNumberLiteral expr, XtendFunction func) {
		val result = new ArrayList

		val actualNumber = interpreter.evaluate(expr).result

		val resolvedTypes = typeResolver.resolveTypes(expr);
		val expectedType = resolvedTypes.getExpectedType(expr);

		if (actualNumber instanceof Integer) {
			if (expectedType == null || expectedType.type instanceof JvmPrimitiveType) {
				result += ldc(constantPool.addIntegerEntry(actualNumber))
			} else {
				result += newObject("java.lang.Integer")
				result += dup
				result += ldc(constantPool.addIntegerEntry(actualNumber))
				result += invokeSpecial(constantPool.addMethodEntry("java.lang.Integer", "<init>", "void", #["int"]))
			}

		} else {
			throw new UnsupportedOperationException
		}

		//TODO
		result
	}
	
	def dispatch List<byte[]> compileExpression(XIfExpression expr, XtendFunction func){
		val result = new ArrayList
		
		result += expr.^if.compileExpressionToExpectedType(func)
		
		val ifJump = newByteArrayOfSize(3)
		ifJump.setU1(0, 0x99)
		
		result += ifJump
		
		val thenBranch = expr.then.compileExpressionToExpectedType(func)
		
		var byte[] elseJump = null
		if (expr.^else != null){
			elseJump = newByteArrayOfSize(3)
			elseJump.setU1(0, 0xa7)
			thenBranch += elseJump
		}
		
		var thenBranchSize = 0
		for (b : thenBranch)
			thenBranchSize += b.length
		ifJump.setU2(1, thenBranchSize + 1 + 2)
		
		result += thenBranch
		
		if (expr.^else != null){
			val elseBranch = expr.^else.compileExpressionToExpectedType(func)
			
			var elseBranchSize = 0
			for (b : elseBranch)
				elseBranchSize += b.length
			elseJump.setU2(1, elseBranchSize + 1 + 2)
			result += elseBranch
		}
		
		result
	}
		
	def dispatch List<byte[]> compileExpression(XConstructorCall expr, XtendFunction func){
		val result = new ArrayList
		
		result += newObject(expr.constructor.declaringType.qualifiedName)
		result += dup
		for (arg : expr.arguments)
			result += arg.compileExpressionToExpectedType(func)
		result += invokeSpecial(constantPool.addMethodEntry(expr.constructor.declaringType.qualifiedName, "<init>", "void", expr.constructor.parameters.map[parameterType.qualifiedName]))
		
		result
	}

	def dispatch List<byte[]> compileExpression(XAbstractFeatureCall expr, XtendFunction func) {
		val result = new ArrayList
		if (expr.feature instanceof JvmOperation) {
			val op = expr.feature as JvmOperation
			if (!op.static)
				result += aload(0)
			for (a : expr.actualArguments)
				result += a.compileExpressionToExpectedType(func)
			if (op.static) {
				result += invokeStatic(op)
			} else if (op.visibility == JvmVisibility.PRIVATE) {
				result += invokeSpecial(op)
			} else {
				result += invokeVirtual(op)
			}
		}else if (expr.feature instanceof XtendVariableDeclaration){
			val decl = expr.feature as XtendVariableDeclaration
			val index = usedLocals.get(func).get(decl)
			result += load(expr.actualType.type.qualifiedName, index)
		}else if (expr.feature instanceof JvmFormalParameter){
			val param = expr.feature as JvmFormalParameter
			val index = func.directlyInferredOperation.parameters.indexOf(param)
			if (index == -1)
				throw new IllegalStateException
			result += load(param.parameterType.qualifiedName, index + 1)
		}else{
			throw new UnsupportedOperationException
		}
		result
	}
	
	def getActualType(XExpression expr){
		val resolved = typeResolver.resolveTypes(expr)
		resolved.getActualType(expr)
	}
	
	def List<byte[]> compileExpressionToExpectedType(XExpression expr, XtendFunction func){
		val resolved = typeResolver.resolveTypes(expr)
		val expected = resolved.getExpectedType(expr)
		val actual = resolved.getActualType(expr)
		
		println("---")
		println("Expression: " +expr)
		println("Expected: " + expected)
		println("Actual: " + actual)
		if (expected != null && expected.type instanceof JvmVoid){
			compileExpression(expr, func)
		}else if (expected != null && actual.type instanceof JvmPrimitiveType && !(expected.type instanceof JvmPrimitiveType)){
			println("Boxing")
			val result = new ArrayList
			result += newObject(actual.type.qualifiedName.boxedVersion)
			result += dup
			result += compileExpression(expr, func)
			result += invokeSpecial(constantPool.addMethodEntry(actual.type.qualifiedName.boxedVersion, "<init>", "void", #[actual.type.qualifiedName]))
			result
		}else if (expected != null && expected.type instanceof JvmPrimitiveType && !(actual.type instanceof JvmPrimitiveType)){
			println("Unboxing")
			//TODO
			val result = new ArrayList
			result += compileExpression(expr, func)
			result += invokeVirtual(constantPool.addMethodEntry(actual.type.qualifiedName, expected.type.qualifiedName + "Value", expected.type.qualifiedName, #[]))
			result
		}else{
			compileExpression(expr, func)
		}
	}
	
	def getBoxedVersion(String primitive){
		switch (primitive){
			case "int" : "java.lang.Integer"
			default: throw new UnsupportedOperationException
		}
	}

	def void addDefaultConstructor(XtendClass clazz) {
		var result = new ArrayList
		val flags = 0x0001
		result += getU2(flags)

		result += getU2(constantPool.addUtf8Entry("<init>"))

		result += getU2(constantPool.addUtf8Entry(convertToMethodDescriptior("void", #[])))

		result += getU2(1)

		// code attribute
		val attribute = new ArrayList
		attribute += getU2(constantPool.addUtf8Entry("Code"))

		// set length at the end
		// max stack, whatever
		attribute += getU2(5)

		// max locals, whatever
		attribute += getU2(5)

		// set code length at the end
		// do code here
		val code = new ArrayList
		code += loadLocalReference(0)
		code +=
			invokeSpecial(
				constantPool.addMethodEntry(clazz.extends?.qualifiedName ?: "java.lang.Object", "<init>", "void", #[]))
		code += returnVoid

		var codeLength = 0
		for (c : code)
			codeLength += c.length
		attribute += getU4(codeLength)

		// set code length now
		attribute += code

		// exception table length
		attribute += getU2(0)

		// attributes
		attribute += getU2(0)

		// set length now
		var length = 0
		for (b : attribute.tail)
			length += b.length

		attribute.add(1, getU4(length))

		result += attribute

		bytes += result
	}

	def byte[] invokeSpecial(JvmOperation op) {
		invokeSpecial(
			constantPool.addMethodEntry(op.declaringType.qualifiedName, op.simpleName, op.returnType.qualifiedName,
				op.parameters.map[parameterType.qualifiedName]))
	}
	
	def byte[] invokeStatic(JvmOperation op) {
		invokeStatic(
			constantPool.addMethodEntry(op.declaringType.qualifiedName, op.simpleName, op.returnType.qualifiedName,
				op.parameters.map[parameterType.qualifiedName]))
	}

	def byte[] invokeVirtual(JvmOperation op) {
		invokeVirtual(
			constantPool.addMethodEntry(op.declaringType.qualifiedName, op.simpleName, op.returnType.qualifiedName,
				op.parameters.map[parameterType.qualifiedName]))
	}

	def byte[] store(String typeFqn, int index) {
		switch (typeFqn) {
			case "byte": istore(index)
			case "char": istore(index)
			case "double": dstore(index)
			case "float": fstore(index)
			case "int": istore(index)
			case "long": lstore(index)
			case "short": istore(index)
			case "boolean": istore(index)
			default: astore(index)
		}
	}

	def byte[] load(String typeFqn, int index) {
		switch (typeFqn) {
			case "byte": iload(index)
			case "char": iload(index)
			case "double": dload(index)
			case "float": fload(index)
			case "int": iload(index)
			case "long": lload(index)
			case "short": iload(index)
			case "boolean": iload(index)
			default: aload(index)
		}
	}

	def byte[] returnType(String typeFqn) {
		switch (typeFqn) {
			case "byte": ireturn
			case "char": ireturn
			case "double": dreturn
			case "float": freturn
			case "int": ireturn
			case "long": lreturn
			case "short": ireturn
			case "boolean": ireturn
			default: areturn
		}
	}

	def void addField(JvmField field) {
		val size = 2 + 2 + 2 + 2
		val result = newByteArrayOfSize(size)

		var flags = 0
		if (field.isFinal)
			flags = flags.bitwiseOr(0x0010)
		if (field.isStatic)
			flags = flags.bitwiseOr(0x0008)
		if (field.volatile)
			flags = flags.bitwiseOr(0x0040)
		switch (field.visibility) {
			case JvmVisibility.PUBLIC:
				flags = flags.bitwiseOr(0x0001)
			case JvmVisibility.PROTECTED:
				flags = flags.bitwiseOr(0x0004)
			case JvmVisibility.PRIVATE:
				flags = flags.bitwiseOr(0x0002)
			default: {
			}
		}

		result.setU2(0, flags)
		result.setU2(2, constantPool.addUtf8Entry(field.simpleName))
		result.setU2(4, constantPool.addUtf8Entry(field.type.qualifiedName.convertToFieldDescriptor))
		result.setU2(6, 0)

		bytes += result
	}
	
	def byte[] newObject(String fqn) {
		newOp(constantPool.addClassEntry(fqn))
	}

	def void addAccessFlags(XtendClass clazz) {
		var result = ACC_SUPER
		if (clazz.visibility == JvmVisibility.PUBLIC)
			result = result.bitwiseOr(ACC_PUBLIC)
		if (clazz.isFinal)
			result = result.bitwiseOr(ACC_FINAL)
		if (clazz.isAbstract)
			result = result.bitwiseOr(ACC_ABSTRACT)
		bytes.add(result.u2)
	}

	def void addMagicNumber() {
		val magicPart = newByteArrayOfSize(4)
		magicPart.setU2(0, 0xcafe)
		magicPart.setU2(2, 0xbabe)
		bytes.add(magicPart)
	}

	def void addVersion() {
		val versionPart = newByteArrayOfSize(4)
		versionPart.setU2(0, 0)
		versionPart.setU2(2, 49)
		bytes.add(versionPart)
	}

	def int nextFreeLocal(XtendFunction func) {
		val result = freeLocal.get(func)
		freeLocal.put(func, result + 1)
		result
	}
}
