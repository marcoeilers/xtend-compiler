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
import org.eclipse.xtext.common.types.JvmGenericType
import org.eclipse.xtext.common.types.JvmIdentifiableElement
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.common.types.JvmPrimitiveType
import org.eclipse.xtext.common.types.JvmType
import org.eclipse.xtext.common.types.JvmTypeParameter
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.common.types.JvmVisibility
import org.eclipse.xtext.common.types.JvmVoid
import org.eclipse.xtext.common.types.util.TypeReferences
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
	private ReturnAnalysisResult returnInfo

	@Inject
	private extension IXtendJvmAssociations jvmTypes

	@Inject 
	private XbaseInterpreter interpreter
	
	@Inject
	private IBatchTypeResolver typeResolver;
	
	@Inject
	private TypeReferences typeProvider

	@Inject
	private ReturnValueAnalyzer returnAnalyzer
	
	def generateClass(XtendClass clazz) {
		bytes = new ArrayList
		addMagicNumber
		addVersion

		// constant pool will be added later
		clazz.addAccessFlags

		bytes += getU2(constantPool.addClassEntry(clazz.qualifiedName))

		bytes += getU2(constantPool.addClassEntry(clazz.extends?.qualifiedErasureName ?: "java.lang.Object"))

		bytes += getU2(clazz.implements.size)

		for (interf : clazz.implements) {
			bytes += getU2(constantPool.addClassEntry(interf.qualifiedErasureName))
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
			
		returnInfo = returnAnalyzer.analyze(func)
		
		freeLocal.put(func, 1 + func.parameters.size)
		
		val flags = 0x0001
		result += getU2(flags)

		result += getU2(constantPool.addUtf8Entry(method.simpleName))

		result +=
			getU2(
				constantPool.addUtf8Entry(
					convertToMethodDescriptior(method.returnType.qualifiedErasureName,
						method.parameters.map[parameterType.qualifiedErasureName])))

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
			result += e.compileExpressionAndHandleReturnValue(func)
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
			result += store(type.type.qualifiedErasureName, newVarIndex)
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

	def List<byte[]> compileExpressionAndHandleReturnValue(XExpression expr, XtendFunction func){
		if (returnInfo.implicitlyReturned.contains(expr)){
			println("implicit return for " + expr)
			val result = new ArrayList
			result += compileExpressionToExpectedType(expr, func)
			result += returnType(func.directlyInferredOperation.returnType.qualifiedErasureName)
			result
		}else if (returnInfo.throwAwayReturnValue.contains(expr)){
			println("throwing away return value for " + expr)
			compileExpressionDiscardingResult(expr, func)
		}else{
			compileExpressionToExpectedType(expr, func)
		}
	}
	
	def List<byte[]> compileExpressionDiscardingResult(XExpression expr, XtendFunction func){
		val result = new ArrayList
		result += compileExpressionToExpectedType(expr, func)
		if (!(expr.actualType.type instanceof JvmVoid))
			result += pop
		result
	}
	
	def dispatch List<byte[]> compileExpression(XBasicForLoopExpression expr, XtendFunction func){
		val result = new ArrayList
		for (ie : expr.initExpressions)
			result += ie.compileExpressionDiscardingResult(func)

		val check =  expr.expression.compileExpressionToExpectedType(func)
		result += check
		val startJump = newByteArrayOfSize(3)
		changeStack("ifeq", -1)
		startJump.setU1(0, 0x99)
		result += startJump
		
		val each = expr.eachExpression.compileExpressionAndHandleReturnValue(func)
		result += each
		
		val update = new ArrayList
		for (ue : expr.updateExpressions)
			update += ue.compileExpressionDiscardingResult(func)
		result += update
			
		val endJump = newByteArrayOfSize(3)
		changeStack("goto", 0)
		endJump.setU1(0, 0xa7)
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
		
		
		startJump.setU2(1, startOffset)
		
		
		endJump.setU2(1, endOffset)
		result
	}
	
	def dispatch List<byte[]> compileExpression(XInstanceOfExpression expr, XtendFunction func) {
		#[instanceofOp(expr.type.qualifiedErasureName)]
	}
	
	def dispatch List<byte[]> compileExpression(XTypeLiteral expr, XtendFunction func){
		#[ldc(constantPool.addClassEntry(expr.type.qualifiedErasureName))]
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
			result += dup
			result += store(expr.actualArguments.head.actualType.type.qualifiedErasureName, index)
			result
		}else if (expr.feature instanceof JvmField){
			if (expr.actualArguments.size != 1)
				throw new IllegalStateException
			val field = expr.feature as JvmField
			val result = new ArrayList
			if (!field.static){
				if (expr.actualReceiver != null){
					result += expr.actualReceiver.compileExpressionToExpectedType(func)
				}else{
					result += aload(0)
				}
			}
			result += expr.actualArguments.head.compileExpressionToExpectedType(func)
			result += putField(field)
			result
		}else{
			compileExpression(expr as XAbstractFeatureCall, func)
		}
	}

	def dispatch List<byte[]> compileExpression(XReturnExpression expr, XtendFunction func) {
		val result = new ArrayList
		if (expr.expression != null) {
			result += compileExpression(expr.expression, func)
			result += returnType(func.directlyInferredOperation.returnType.qualifiedErasureName)
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
		changeStack("ifeq", -1)
		ifJump.setU1(0, 0x99)
		
		result += ifJump
		
		val thenBranch = expr.then.compileExpressionAndHandleReturnValue(func)
		
		var byte[] elseJump = null
		if (expr.^else != null){
			elseJump = newByteArrayOfSize(3)
			changeStack("goto", 0)
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
		
		result += newObject(expr.constructor.declaringType.qualifiedErasureName)
		result += dup
		for (arg : expr.arguments)
			result += arg.compileExpressionToExpectedType(func)
		result += invokeSpecial(constantPool.addMethodEntry(expr.constructor.declaringType.qualifiedErasureName, "<init>", "void", expr.constructor.parameters.map[parameterType.qualifiedErasureName]))
		
		result
	}

	def dispatch List<byte[]> compileExpression(XAbstractFeatureCall expr, XtendFunction func) {
		val result = new ArrayList
		if (expr.feature instanceof JvmOperation) {
			val op = expr.feature as JvmOperation
			if (!op.static){
				if (expr.actualReceiver != null){
					result += expr.actualReceiver.compileExpressionToExpectedType(func)
				}else{
					// assume the receiver is this
					result += aload(0)
				}
			}
				
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
			result += load(expr.actualType.type.qualifiedErasureName, index)
		}else if (expr.feature instanceof JvmFormalParameter){
			val param = expr.feature as JvmFormalParameter
			val index = func.directlyInferredOperation.parameters.indexOf(param)
			if (index == -1)
				throw new IllegalStateException
			result += load(param.parameterType.qualifiedErasureName, index + 1)
		}else if (expr.feature instanceof JvmField){
			val field = expr.feature as JvmField
			if (!field.static){
				if (expr.actualReceiver != null){
					result += expr.actualReceiver.compileExpressionToExpectedType(func)
				}else{
					// assume the receiver is this
					result += aload(0)
				}
			}
			result += getField(field)
		}else if (expr.feature instanceof JvmGenericType) {
			val type = expr.feature as JvmGenericType
			if (func.declaringType.qualifiedName == type.qualifiedName){
				result += aload(0)
			}else{
				throw new IllegalStateException
			}
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
//		
//		println("---")
//		println("Expression: " +expr)
//		println("Expected: " + expected)
//		println("Actual: " + actual)
		if (expected != null && expected.type instanceof JvmVoid){
			compileExpression(expr, func)
		}else if (expected != null && actual.type instanceof JvmPrimitiveType && !(expected.type instanceof JvmPrimitiveType)){
			println("Boxing")
			val result = new ArrayList
			result += newObject(actual.type.qualifiedErasureName.boxedVersion)
			result += dup
			result += compileExpression(expr, func)
			result += invokeSpecial(constantPool.addMethodEntry(actual.type.qualifiedErasureName.boxedVersion, "<init>", "void", #[actual.type.qualifiedErasureName]))
			result
		}else if (expected != null && expected.type instanceof JvmPrimitiveType && !(actual.type instanceof JvmPrimitiveType)){
			println("Unboxing")
			//TODO
			val result = new ArrayList
			result += compileExpression(expr, func)
			result += invokeVirtual(constantPool.addMethodEntry(actual.type.qualifiedErasureName, expected.type.qualifiedErasureName + "Value", expected.type.qualifiedErasureName, #[]))
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
				constantPool.addMethodEntry(clazz.extends?.qualifiedErasureName ?: "java.lang.Object", "<init>", "void", #[]))
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
		changeStack("invokeSpecial", (if (op.returnType.type instanceof JvmVoid) 0 else 1) - op.parameters.size)
		invokeSpecial(
			constantPool.addMethodEntry(op.declaringType.qualifiedErasureName, op.simpleName, op.returnType.qualifiedErasureName,
				op.parameters.map[parameterType.qualifiedErasureName]))
	}
	
	def byte[] invokeStatic(JvmOperation op) {
		changeStack("invokeStatic", (if (op.returnType.type instanceof JvmVoid) 0 else 1) - op.parameters.size)
		invokeStatic(
			constantPool.addMethodEntry(op.declaringType.qualifiedErasureName, op.simpleName, op.returnType.qualifiedErasureName,
				op.parameters.map[parameterType.qualifiedErasureName]))
	}

	def byte[] invokeVirtual(JvmOperation op) {
		changeStack("invokeVirtual", (if (op.returnType.type instanceof JvmVoid) 0 else 1) - op.parameters.size)
		invokeVirtual(
			constantPool.addMethodEntry(op.declaringType.qualifiedErasureName, op.simpleName, op.returnType.qualifiedErasureName,
				op.parameters.map[parameterType.qualifiedErasureName]))
	}
	
	def byte[] getField(JvmField field){
		if (field.static)
			getStatic(constantPool.addFieldEntry(field.declaringType.qualifiedErasureName, field.simpleName, field.type.qualifiedErasureName))
		else
			getField(constantPool.addFieldEntry(field.declaringType.qualifiedErasureName, field.simpleName, field.type.qualifiedErasureName))
	}
	
	def byte[] putField(JvmField field){
		if (field.static)
			putStatic(constantPool.addFieldEntry(field.declaringType.qualifiedErasureName, field.simpleName, field.type.qualifiedErasureName))
		else
			putField(constantPool.addFieldEntry(field.declaringType.qualifiedErasureName, field.simpleName, field.type.qualifiedErasureName))
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
			case "void" : returnVoid
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
		result.setU2(4, constantPool.addUtf8Entry(field.type.qualifiedErasureName.convertToFieldDescriptor))
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
	
	def String getQualifiedErasureName(JvmTypeReference type){
		type.type.qualifiedErasureName
	}
	
	def String getQualifiedErasureName(JvmType type){
		if (type instanceof JvmTypeParameter){
			var actualType = typeProvider.findDeclaredType("java.lang.Object", type)
			for (c : type.constraints.filter[identifier.startsWith("extends")]){
				actualType = c.typeReference.type
			}
			actualType.qualifiedName
		}else{
			type.qualifiedName
		}
	}
}
