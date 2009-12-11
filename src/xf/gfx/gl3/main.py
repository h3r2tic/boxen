import re

from parseEnums import parseEnums, DirectName, SpecialNameAlias
from parseTypes import parseTypes
from parseFunctions import parseFunctions, ArrayType, PointerType, IdentMultArraySize
from utils import LineIter


enums = parseEnums(LineIter(open('enum.spec').read()))
types = parseTypes(LineIter(open('gl.tm').read()))
funcs = parseFunctions(LineIter(open('gl.spec').read()))
requiredTypes = {}
builtinEnumNames = []

hazEnumNames = set()
for en in enums.keys():
	e = enums[en]
	if (not re.search(r"DEPRECATED", en)) and re.search(r"VERSION_", en):
		for n in e.names:
			if not n.name in hazEnumNames:
				builtinEnumNames.append(n)
				hazEnumNames.add(n.name)
del hazEnumNames


def formatType(t, wantArray = False):
	if isinstance(t, type('')):
		if t in types:
			basic = types[t]
			if ("GLenum" == basic or "GLbitfield" == basic) and not ("GLenum" == t or "GLbitfield" == t):
				requiredTypes[t] = basic
#				return t
			return basic
		return t
	elif isinstance(t, ArrayType):
		if wantArray:
			return formatType(t.basic) + "[]"
		else:
			return formatType(t.basic) + "*"
	elif isinstance(t, PointerType):
		return formatType(t.basic) + "*"
	else:
		assert False, `t`


def formatCType(t):
	if isinstance(t, type('')):
		if t in types:
			basic = types[t]
			if "GLenum" == basic or "GLbitfield" == basic:
				return t
			return basic
		return t
	elif isinstance(t, ArrayType):
		return formatCType(t.basic) + "*"
	elif isinstance(t, PointerType):
		return formatCType(t.basic) + "*"
	else:
		assert False, `t`


def paramToCArg(t, n):
	if isinstance(t, type('')):
		return n
	elif isinstance(t, ArrayType):
		return n + ".ptr"
	elif isinstance(t, PointerType):
		return n
	else:
		assert False, `t`


def formatFuncName(n):
	return n[0].lower() + n[1:]


class Extension:
	def __init__(self, id):
		self.id = id
		self.funcs = []
		self.enums = []


extensions = []
for func in funcs:
	if (not re.search(r"DEPRECATED", func.category)) and (not re.search(r"VERSION_", func.category)) and not func.deprecated:
		if not ([func.category, None] in extensions):
			extensions.append([func.category, None])

for i in range(len(extensions)):
	e = extensions[i]
	e[1] = Extension(i)

ex = {}
for n, e in extensions:
	ex[n] = e;
extensions = ex
del ex

print extensions

print 'import GLTypes;'

if 1:
	funcsToEmit = [ \
		func for func in funcs \
			if (not re.search(r"DEPRECATED", func.category)) \
				and re.search(r"VERSION_", func.category) \
				and not func.deprecated
	]
		

	for func in funcsToEmit:
		formatType(func.returnType)
		for p in func.params:
			formatType(p.type_)

	definedEnumNames = set([])

	if len(builtinEnumNames) > 0:
#		print 'pragma (ctfe) GLenum'
		print 'enum : GLenum {'

		vals = []
		for n in builtinEnumNames:
			if not n in definedEnumNames:
				if isinstance(n, DirectName):
					vals.append((n.name, n.value))
					definedEnumNames.add(n.name)
				elif isinstance(n, SpecialNameAlias):
					vals.append((n.name, n.src.value))
					definedEnumNames.add(n.name)

		assert len(vals) > 0

		for e in vals[:-1]:
			print '\t%s = %s,' % e
		if 1:
			e = vals[-1]
			print '\t%s = %s' % e

		print '}'

	for td in requiredTypes.keys():
#		print 'typedef %s %s;' % (requiredTypes[td], td)
		vals = []
		if td in enums:
			enum = enums[td]
			for n in enum.names:
				if not n in definedEnumNames:
					if isinstance(n, DirectName):
						vals.append((n.name, n.value))
						definedEnumNames.add(n.name)
					elif isinstance(n, SpecialNameAlias):
						vals.append((n.name, n.src.value))
						definedEnumNames.add(n.name)

			if len(vals) > 0:
				print 'enum :  %s {' % requiredTypes[td]
				for e in vals[:-1]:
					print '\t%s = %s,' % e
				if 1:
					e = vals[-1]
					print '\t%s = %s' % e
				print '}'


	print
	print


	if 0:	
		print 'extern (System) {'
		for func in funcsToEmit:
			ret = formatCType(func.returnType)
			args = ', '.join((formatCType(p.type_) + ' ' + p.name for p in func.params))
			print '\t%s function(%s) pf_gl%s;' % (ret, args, func.name)
		print '}'

	print
	print



	for func in funcsToEmit:
		print 'char* fname_%s = "gl%s";' % (func.name, func.name)


	print

	print 'extern (System) {'

	funcId = -1;
	for func in funcsToEmit:
		funcId += 1
		renamedFuncName = "glwrap_%s" % func.name
#		renamedFuncName = formatFuncName(func.name)
		
		ret = formatType(func.returnType)
		args = ', '.join(['GL gl'] + [formatType(p.type_) + ' ' + p.name for p in func.params] + ['size_t _extraSpace = 0'])
		print '%s %s(%s) {' % (ret, renamedFuncName, args)

		print '\tconst int _frameSize = '
		print '\t\tupTo4(GL.sizeof)'
		for p in func.params:
			print '\t+\tupTo4(typeof(%s).sizeof)' % p.name
		print '\t;'

		print '''
	asm {
		naked;

		pop dword ptr [ESP + _frameSize];

		// obtain the function pointer
		pop EAX;
		mov EAX, [EAX];
		push dword ptr [fname_%(fname)s];
		push dword ptr %(fid)s;
		call gl_getCoreFuncPtr;
		call EAX;
	}
	version (ValidateFuncCalls) {
		asm {
			mov ECX, _frameSize - GL.sizeof;
			sub ESP, ECX;
			mov EDX, [fname_%(fname)s];
			jmp [validateFuncCallProc];
		}
	} else {
		asm {
			ret;
		}
	}
}''' % {'fname' : func.name, 'fid' : funcId}
		print 'alias %s %s;' % (renamedFuncName, formatFuncName(func.name))
		print

	print '}'


	if 0:
		for func in funcsToEmit:
			renamedFuncName = formatFuncName(func.name)
			
			ret = formatType(func.returnType)
			args = ', '.join((formatType(p.type_) + ' ' + p.name for p in func.params if not p.inferredFrom))
			print '%s %s(%s) {' % (ret, renamedFuncName, args)
			for param in func.params:
				if param.inferredFrom:
					mult = param.inferredFrom.type_.size.mult
					if mult != 1:
						print '\tassert (0 == %s.length %% %s);' % (
							param.inferredFrom.name,
							mult
						)
						
					print '\tfinal %s %s = %s.length%s;' % (
						formatType(param.type_),
						param.name,
						param.inferredFrom.name,
						'' if mult == 1 else ' / %s' % mult
					)
				
				sizeCheck = None
				
				if isinstance(param.type_, ArrayType):
					size = param.type_.size
					if isinstance(size, type(0)):
						sizeCheck = `size`
		#				elif isinstance(size, IdentMultArraySize):
		#					sizeCheck = size.ident if 1 == size.mult else '%s * %s' % (size.ident, size.mult)

				if sizeCheck:
					print '\tassert (%s == %s.length)' % (sizeCheck, param.name)

			cargs = ', '.join((paramToCArg(p.type_, p.name) for p in func.params))

			retValue = ''
			if ret != 'void':
				retValue = '%s _returnValue = ' % ret
			
			print '\t%sfp_gl%s(%s);' % (retValue, func.name, cargs)

			print '\tcheckErrors("%s", (Formatter _fmt) {' % renamedFuncName
			for param in func.params:
				if not param.inferredFrom:
					if isinstance(param.type_, ArrayType):
						print '\t\tif (%s.length <= 16) {' % param.name
						print '\t\t\t_fmt.format("%s: {}", %s);' % (param.name, param.name)
						print '\t\t} else {'
						print '\t\t\t_fmt.format("%s: {} ... ({} more)", %s[0..16], %s.length - 16);' % (param.name, param.name, param.name)
						print '\t\t}'
					else:
						print '\t\t_fmt.format("%s: {}", %s);' % (param.name, param.name)
			print '\t});'

			if ret != 'void':
				print 'return _returnValue;'
				
			print '}'
				
