from parseFunctions import ArrayType, PointerType, IdentMultArraySize
from parseEnums import DirectName, SpecialNameAlias
from utils import strfmt



def formatType(t, types, wantArray = False):
	if isinstance(t, type('')):
		if t in types:
			return types[t]
		return t
	elif isinstance(t, ArrayType):
		if wantArray:
			return formatType(t.basic, types) + "[]"
		else:
			return formatType(t.basic, types) + "*"
	elif isinstance(t, PointerType):
		return formatType(t.basic, types) + "*"
	else:
		assert False, `t`


def formatCType(t, types):
	if isinstance(t, type('')):
		if t in types:
			basic = types[t]
			if "GLenum" == basic or "GLbitfield" == basic:
				return t
			return basic
		return t
	elif isinstance(t, ArrayType):
		return formatCType(t.basic, types) + "*"
	elif isinstance(t, PointerType):
		return formatCType(t.basic, types) + "*"
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
	return n;
#	return n[0].lower() + n[1:]


modPrefix = 'xf.gfx.gl3.'


def emitModule(modName, enums, types, funcs, extId, extraImports = [], errorCheckFilter = lambda fname: True, funcNamePrefix = 'gl'):
	f = strfmt()

	definedEnumNames = set()

	f('module %s%s;', modPrefix, modName)
	f.nl()
	f('private {')
	f.push()
	f('import %sGLTypes;', modPrefix)
	for imp in extraImports:
		f('import %s;', imp)
	f.pop()
	f('}')
	f.nl()

	for ename, enum in enums:
		vals = []

		for n in enum.names:
			if n and not n.name in definedEnumNames:
				if isinstance(n, DirectName):
					vals.append((n.name, n.value))
					definedEnumNames.add(n.name)
				else:
					assert False, `n`

		if len(vals) > 0:
			f('enum {')
			f.push()
			for e in vals[:-1]:
				f('%s = %s,' % e)
			if 1:
				e = vals[-1]
				f('%s = %s' % e)
			f.pop()
			f('}')


	f.nl()
	f.nl()

	for func in funcs:
		f('char* fname_%s = "%s%s";', func.name, funcNamePrefix, func.name)


	f.nl()

	f('extern (System) {')
	f.push()

	funcId = -1;
	for func in funcs:
		funcId += 1
		renamedFuncName = "glwrap_%s" % func.name
#		renamedFuncName = formatFuncName(func.name)
		
		ret = formatType(func.returnType, types)
		args = ', '.join(['GL gl'] + [formatType(p.type_, types) + ' ' + p.name for p in func.params] + ['_GL3ExtraSpace _extraSpace = _GL3ExtraSpace.init'])
		f('%s %s(%s) {', ret, renamedFuncName, args)
		f.push()

		f('const int _frameSize = ')
		f.push()
		f('\tupTo4(GL.sizeof)')
		for p in func.params:
			f('+\tupTo4(typeof(%s).sizeof)', p.name)
		f(';')

		f.pop()
		f.pop()

		body = '''
	asm {
		naked;

		// get the return address into the _extraSpace slot
		pop dword ptr [ESP + _frameSize];

		// get the GL handle
		pop EAX;
		mov EAX, [EAX];

		// obtain the function pointer
		push dword ptr [fname_%(fname)s];
		push dword ptr 0x%(fid)4.4x%(extId)4.4x;
		call %(getProcFunc)s;

		// call the GL function
		call EAX;
		'''

		if errorCheckFilter(func.name):
			body += '''
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
}
	'''
		else:
			body += '''
		ret;
	}
}
		'''

		body = body % {
				'fname' : func.name,
				'fid' : funcId,
				'extId' : extId,
				'getProcFunc' : 'gl_getExtensionFuncPtr' if func.extension else 'gl_getCoreFuncPtr'}

		f(body)
		f('alias %s %s;' % (renamedFuncName, formatFuncName(func.name)))
		f.nl()

	f.pop()
	f('}')

	if 0:
		for func in funcsToEmit:
			renamedFuncName = formatFuncName(func.name)
			
			ret = formatType(func.returnType, types)
			args = ', '.join((formatType(p.type_, types) + ' ' + p.name for p in func.params if not p.inferredFrom))
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
						formatType(param.type_, types),
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
				

	open(modName.replace('.', '/')+'.d', 'w').write(f.data)

