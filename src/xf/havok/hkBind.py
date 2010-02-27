from Classes import *
from Parse import processFile
from Semantic import resolveInheritance, analyzeTypes, classSemantic, TypeAnalysis


# ----------------------------------------------------------------

def generateDClass(cls, fmt):
	if cls.isPOD:
		assert 0 == len(cls.deriv)

#	if len(cls.deriv):
#		fmt('typedef %s %s;', cls.deriv[0].ptrTypeName(), cls.ptrTypeName())
#	else:
	if 1:
		fmt('typedef void* %s;', cls.ptrTypeName())

	fmt('struct %s', cls.name)
	fmt.push()

	if not cls.isPOD:
		# ---- _impl ----

		fmt('%s _impl;', cls.ptrTypeName())

		fmt('static typeof(*this) opCall(%s _impl)', cls.ptrTypeName())
		fmt.push()
		fmt('typeof(*this) res;')
		fmt('res._impl = _impl;')
		fmt('return res;')
		fmt.pop()

	# ---- verbatim ----

	if len(cls.verbatimD):
		fmt('// begin verbatim D code')
		fmt.nl()
		for d in cls.verbatimD:
			fmt.verbatim(d)
		fmt.nl()
		fmt('// end verbatim D code')

	# ---- fields ----

	for f in cls.fields:
		fmt('%s %s()', f.type_.forFacade(), f.name)
		fmt.push()
		fmt('return ' + f.type_.forDReturn('*%s(_impl)' % f.bridgeName()) + ';')
		fmt.pop()

		fmt('final void %s(%s _value)', f.name, f.type_.forFacade())
		fmt.push()
		fmt('*%s(_impl) = %s;', f.bridgeName(), HkFuncParam('_value', f.type_).passToC())
		fmt.pop()

	if not cls.isPOD:
		# ---- interface casting ----
		for base, direct in cls.iterBases():
			if direct:
				fmt('%s _as_%s()', base.name, base.name)
				fmt.push()
				fmt('return %s(cast(%s)_impl);', base.name, base.ptrTypeName())
				fmt.pop()
			else:
				fmt('%s _as_%s()', base.name, base.name)
				fmt.push()
				fmt('return %s(dhk_%s_as_%s(_impl));', base.name, cls.name, base.name)
				fmt.pop()

	# ---- end ----
		
	fmt.nl()
	for func in cls.funcs:
		generateDFunc(func, cls, fmt)

	fmt.pop()


def generateDFunc(func, scope, fmt):
	pstr = ', '.join('%s %s' % (p.type_.forFacade(), p.name) for p in func.params)
	if func.name == 'this':
		fmt('static typeof(*this) opCall(%s)', pstr)
		fmt.push()
		fmt('typeof(*this) _res;')
		args = [p.passToC() for p in func.params]
		fmt('_res._impl = %s(%s);', func.bridgeName(), ', '.join(args))
		fmt('return _res;')
		fmt.pop()
	else:
		functype = 'static ' if func.static else 'final'

#		if scope and not func.static and scope.abstract:
#			fmt('%s %s(%s);', func.ret.forFacade(), func.name, pstr)
#		else:
		if 1:
			fmt(functype + ' %s %s(%s)', func.ret.forFacade(), func.name, pstr)
			fmt.push()
			args = []
			
			if scope and not func.static:
				args.append('_impl')
			for p in func.params:
				args.append(p.passToC())
				
			fmt('return ' + func.ret.forDReturn('%s(%s)' % (func.bridgeName(), ', '.join(args))) + ';')

			fmt.pop()

# ----------------------------------------------------------------

def generateDDeclsClass(cls, fmt):
	for func in cls.funcs:
		generateDDeclsFunc(func, cls, fmt)

	for f in cls.fields:
		fmt('%s function(%s) %s;', TypeAnalysis(f.type_.c+'*').forDBridge(), cls.ptrTypeName(), f.bridgeName())

	for base, direct in cls.iterBases():
		if not direct:
			fmt('%s function(%s) dhk_%s_as_%s;', base.ptrTypeName(), cls.ptrTypeName(), cls.name, base.name)


def generateDDeclsFunc(func, scope, fmt):
	params = []
	if scope and func.name != 'this' and not func.static:
		params.append('%s _impl' % scope.ptrTypeName())
	
	params += ['%s %s' % (p.type_.forDBridge(), p.name) for p in func.params]
	
	pstr = ', '.join(params)
		
	fmt('%s function(%s) %s;', func.ret.forDBridge(), pstr, func.bridgeName())

# ----------------------------------------------------------------

def generateDLoadClass(cls, fmt):
	for func in cls.funcs:
		generateDLoadFunc(func, cls, fmt)

	for f in cls.fields:
		fname = f.bridgeName()
		fmt('%s = cast(typeof(%s))lib.getSymbol("%s");',
			fname, fname, fname)

	for base, direct in cls.iterBases():
		if not direct:
			fname = 'dhk_%s_as_%s' % (cls.name, base.name)
			fmt('%s = cast(typeof(%s))lib.getSymbol("%s");',
				fname, fname, fname)


def generateDLoadFunc(func, scope, fmt):
	fname = func.bridgeName()
	fmt('%s = cast(typeof(%s))lib.getSymbol("%s");',
		fname, fname, fname)

# ----------------------------------------------------------------

def generateCClass(cls, fmt):
	if len(cls.verbatimC):
		fmt('// begin verbatim C code')
		fmt.nl()
		for c in cls.verbatimC:
			fmt.verbatim(c)
		fmt.nl()
		fmt('// end verbatim C code')
		fmt.nl()
		
	for func in cls.funcs:
		generateCFunc(func, cls, fmt)

	for f in cls.fields:
		fmt('HKCAPI %s* %s(void* const impl_)', f.hktype, f.bridgeName())
		fmt.push()
		fmt('assert (impl_ != NULL);')
		fmt('return')
		if f.forceCast:
			fmt('(%s*)', f.hktype)
		fmt('&reinterpret_cast<%s*>(impl_)->%s;', cls.hkname, f.name)
		fmt.pop()

	for base, direct in cls.iterBases():
		if not direct:
			fmt('HKCAPI void* dhk_%s_as_%s(void* const impl_)', cls.name, base.name)
			fmt.push()
			fmt('assert (impl_ != NULL);')
			fmt('return dynamic_cast<%s*>(reinterpret_cast<%s*>(impl_));', base.hkname, cls.hkname)
			fmt.pop()

def generateCFunc(func, scope, fmt):
	params = ['%s %s' % (p.hktype, p.name) for p in func.params]
	argPass = []
	
	for p in func.params:
		if p.passAs != p.name:
			argPass.append(p.passAs)
		else:
			argPass.append(p.passToHavok())

	if func.name == 'this':
		pstr = ', '.join(params)
		fmt('HKCAPI %s* %s(%s)', scope.hkname, func.bridgeName(), pstr)
		fmt.push()
		fmt('return new %s(%s);', scope.hkname, ', '.join(argPass))
	else:
		callstr = ''

		if scope is None or func.static:
			pstr = ', '.join(params)
			fmt('HKCAPI %s %s(%s)', func.ret.forCBridge(), func.bridgeName(), pstr)
			fmt.push()

			callstr = ''
			if func.static:
				callstr += '%s::' % scope.hkname

			callstr += '%s(%s)' % (func.hkname, ', '.join(argPass))
		else:
			pstr = ', '.join(['void* const impl_'] + params)
			fmt('HKCAPI %s %s(%s)', func.ret.forCBridge(), func.bridgeName(), pstr)
			fmt.push()
			fmt('assert (impl_ != NULL);')

			callstr = \
				('reinterpret_cast<%s*>(impl_)->' % scope.hkname) + \
				('%s(%s)' % (func.hkname, ', '.join(argPass)))

		if func.ret != 'void':
			fmt('return %s;', func.ret.returnFromHavok(callstr))
		else:
			fmt(callstr+';')
	fmt.pop()

# ----------------------------------------------------------------

class fmt():
	def __init__(self):
		self.indent = 0
	
	def __call__(self, str, *args):
		self.output('\t' * self.indent + str % args)
#		self.output('\n')

	def push(self):
		self.output('\t' * self.indent + '{')
#		self.output('\n')
		self.indent += 1

	def pop(self):
		assert self.indent >=0
		self.indent -= 1
		self.output('\t' * self.indent + '}')
#		self.output('\n')

	def verbatim(self, str, *args):
		self.output(str % args)
#		self.output('\n')

	def nl(self):
		self.output('')


class printfmt(fmt):
	def output(self, str):
		print str


class strfmt(fmt):
	def __init__(self):
		fmt.__init__(self)
		self.data = ''
	
	def output(self, str):
		self.data += str + '\n'


def generateCode(classes, funcs, dcode):
	dout = strfmt()
	cout = strfmt()

	dout('module xf.havok.Havok;')
	dout('import tango.sys.SharedLib;')
	dout('public import xf.havok.HavokDefs;')

	dout.nl()
	dout('// ----------------------------------------------------------------')
	dout.nl()

	for cls in classes:
		generateDClass(cls, dout)
		dout.nl()
	for func in funcs:
		generateDFunc(func, None, dout)
		dout.nl()

	dout.nl()
	dout('// ----------------------------------------------------------------')
	dout.nl()

	dout('extern (C)')
	dout.push()
	for cls in classes:
		generateDDeclsClass(cls, dout)
		dout.nl()
	for func in funcs:
		generateDDeclsFunc(func, None, dout)
		dout.nl()
	dout.pop()

	dout.nl()
	dout('// ----------------------------------------------------------------')
	dout.nl()

	dout('void loadHavok(SharedLib lib)')
	dout.push()
	for cls in classes:
		generateDLoadClass(cls, dout)
		dout.nl()
	for func in funcs:
		generateDLoadFunc(func, None, dout)
		dout.nl()
	dout.pop()

	for cls in classes:
		generateCClass(cls, cout)
		cout.nl()
	for func in funcs:
		generateCFunc(func, None, cout)
		cout.nl()

	for d in dcode:
		dout.nl()
		for l in d:
			dout.verbatim(l)
		dout.nl()

	open('Havok.d', 'w').write(dout.data)
	open('HavokC.cpp.i', 'w').write(cout.data)

# ----------------------------------------------------------------


classes, funcs, dcode = processFile('dupa.txt')
resolveInheritance(classes)
analyzeTypes(classes, funcs)
classSemantic(classes)
generateCode(classes, funcs, dcode)
