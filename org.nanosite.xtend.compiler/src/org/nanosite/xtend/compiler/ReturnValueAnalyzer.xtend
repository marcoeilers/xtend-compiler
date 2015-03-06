package org.nanosite.xtend.compiler

import java.util.Set
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.core.xtend.XtendFunction
import java.util.HashSet
import org.eclipse.xtext.xbase.XBlockExpression
import java.util.Map
import org.eclipse.xtext.xbase.XIfExpression
import org.eclipse.xtext.xbase.XReturnExpression
import org.eclipse.xtext.xbase.XForLoopExpression
import org.eclipse.xtext.xbase.XBasicForLoopExpression
import org.eclipse.xtext.xbase.XWhileExpression
import org.eclipse.xtext.xbase.XSwitchExpression
import java.util.HashMap
import com.google.inject.Inject
import org.eclipse.xtext.xbase.typesystem.IBatchTypeResolver
import org.eclipse.xtext.common.types.JvmVoid

class ReturnAnalysisResult{
	@Accessors Set<XExpression> implicitlyReturned
	@Accessors Set<XExpression> throwAwayReturnValue
	
	@Accessors Set<XtendFunction> implicitReturnNull 
	
	new(){
		implicitlyReturned = new HashSet
		throwAwayReturnValue = new HashSet
		implicitReturnNull = new HashSet
	}
}
 
class ReturnValueAnalyzer {
	private Map<XExpression, Set<XExpression>> nextExprs
	
	@Inject
	private IBatchTypeResolver typeResolver;
	
	def ReturnAnalysisResult analyze(XtendFunction func){
		nextExprs = new HashMap
		
		val startExprs = calculateNext(func.expression, #{null})
		
		println("start expressions are " + startExprs)
		
		for (e : nextExprs.keySet)
			println("next for " + e + " are " + nextExprs.get(e))
		
		val result = new ReturnAnalysisResult
		
		for (e : nextExprs.keySet){
			if (e.next.empty){
				throw new IllegalStateException
			}else if (e.next.contains(null)){
				if (e.next.size > 1){
					result.implicitReturnNull += func
				}else{
					if (!(e instanceof XReturnExpression) && !e.isInsideLoop){
						result.implicitlyReturned += e
					}
				}
			}
		}
		
		for (e : nextExprs.keySet){
			if (e.isNotVoid && !result.implicitlyReturned.contains(e))
				result.throwAwayReturnValue += e
		}
		result
	}
	
	def boolean isNotVoid(XExpression expr){
		val resolved = typeResolver.resolveTypes(expr)
		!(resolved.getActualType(expr).type instanceof JvmVoid)
	}
	
	def boolean isInsideLoop(XExpression expr){
		if (expr.eContainer instanceof XForLoopExpression || expr.eContainer instanceof XWhileExpression)
			return true
		else {
			if (expr.eContainer instanceof XtendFunction)
				return false
			else
				return (expr.eContainer as XExpression).isInsideLoop
		}
	}
	
	def Set<XExpression> getNext(XExpression e){
		if (nextExprs.containsKey(e)){
			nextExprs.get(e)
		}else{
			val result = new HashSet
			nextExprs.put(e, result)
			result
		}
	}
	
	def dispatch Set<? extends XExpression> calculateNext(XBlockExpression e, Set<? extends XExpression> next){
		var Set<? extends XExpression> currentNext = next
		for (var i = e.expressions.size - 1; i >= 0; i--){
			val currentExpr = e.expressions.get(i)
			currentNext = currentExpr.calculateNext(currentNext)
		}
		currentNext
	}
	
	def Set<? extends XExpression> calculateNextSkippableBlock(XExpression block, Set<? extends XExpression> next){
		val result = new HashSet(next)
		val blockNext = block.calculateNext(next)
		result.addAll(blockNext)
		result
	}
	
	def dispatch Set<? extends XExpression> calculateNext(XIfExpression e, Set<? extends XExpression> next){
		if (e.^else != null){
			val thenBranchNext = e.then.calculateNext(next)
			val elseBranchNext = e.^else.calculateNext(next)
			val result = new HashSet(thenBranchNext)
			result.addAll(elseBranchNext)
			result
		}else{
			e.then.calculateNextSkippableBlock(next)
		}
	}
	
	def dispatch Set<? extends XExpression> calculateNext(XForLoopExpression e, Set<? extends XExpression> next){
		e.eachExpression.calculateNextSkippableBlock(next)
	}
	
	def dispatch Set<? extends XExpression> calculateNext(XBasicForLoopExpression e, Set<? extends XExpression> next){
		e.eachExpression.calculateNextSkippableBlock(next)
	}
	
	def dispatch Set<? extends XExpression> calculateNext(XWhileExpression e, Set<? extends XExpression> next){
		e.body.calculateNextSkippableBlock(next)
	}
	
	def dispatch Set<? extends XExpression> calculateNext(XSwitchExpression e, Set<? extends XExpression> next){
		var Set<XExpression> result = null
		if (e.^default != null){
			result = new HashSet(e.^default.calculateNext(next))
		}else{
			result = new HashSet(next)
		}
		for (c : e.cases){
			result.addAll(c.then.calculateNext(next)) 
		}
		result
	}
	
	def dispatch Set<? extends XExpression> calculateNext(XReturnExpression e, Set<? extends XExpression> next){
		e.getNext.add(null)
		return #{e}
	}
	
	def dispatch Set<? extends XExpression> calculateNext(XExpression e, Set<? extends XExpression> next){
		e.getNext.addAll(next)
		return #{e}
	}
	
}