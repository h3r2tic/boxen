from Classes import name2class
import re


class SemanticError(Exception):
	def __init__(self, value):
		self.value = value

	def __str__(self):
		return `self.value`


def _resolveSingleIneritance(cls):
	assert not cls._inheritanceResolved
	cls._inheritanceResolved = True

	alreadyGot = {}

	for base in cls.deriv:
		if not base._inheritanceResolved:
			_resolveSingleIneritance(base)
		for f in base.fields:
			if not f.name in alreadyGot:
				cls.fields.append(f)
				alreadyGot[f.name] = True
		for f in base.funcs:
			if not f.name in alreadyGot:
				f2 = f.clone()
				cls.funcs.append(f2)
				alreadyGot[f.name] = True


def resolveInheritance(classes):
	global name2class
	
	for cls in classes:
		assert not cls in name2class
		name2class[cls.name] = cls
		
	for cls in classes:
		for d in cls.deriv:
			if not d in name2class:
				raise SemanticError('Class %s which is inherited by %s is not defined' % (d, cls.name))

		deriv = [name2class[d] for d in cls.deriv]
		cls.deriv = deriv
		
	for cls in classes:
		if cls.abstract:
			for d in cls.deriv:
				assert d.abstract
		if len(cls.deriv) > 1:
			for d in cls.deriv[1:]:
				assert d.abstract, cls.name

	for cls in classes:
		if not cls._inheritanceResolved:
			_resolveSingleIneritance(cls)


def classSemantic(classes):
	for cls in classes:
		for func in cls.funcs:
			func.cls = cls
		for field in cls.fields:
			field.cls = cls


def analyzeTypes(classes, funcs):
	def anal(funcs):
		for f in funcs:
			assert type(f.ret) is type(''), `type(f.ret)`
			f.ret = TypeAnalysis(f.ret)
			for p in f.params:
				if isinstance(p.type_, TypeAnalysis):
					continue
				assert type(p.type_) is type(''), `type(p.type_)`
				p.type_ = TypeAnalysis(p.type_)
				if not p.hktype:
					p.hktype = p.type_.forCBridge()

	anal(funcs)

	for cls in classes:
		anal(cls.funcs)
		for f in cls.fields:
			assert type(f.type_) is type(''), `type(f.type_)`
			f.type_ = TypeAnalysis(f.type_)
			if not f.hktype:
				f.hktype = f.type_.forCBridge()


class TypeAnalysis:
	DebugOutput = False


	class FormatSettings:
		def __init__(self, preset = 'C++'):
			if 'D' == preset:
				self.wantConst = False
				self.refAsPtr = True
				self.DTempl = True
			elif 'C++' == preset:
				self.wantConst = True
				self.refAsPtr = False
				self.DTempl = False
			else:
				assert False, preset

	def d(self):
		return self._format(self.FormatSettings('D'))

	def _format(self, settings = FormatSettings()):
#		self.const = False
#		self.mutable = False
#		self.tuple = False
#		self.ref = False
#		self.ptr = False
#		self.plain = False
#		self.cls = None
#		self.template = False
#		self.base = None
#		self.param = None
#		self.c = t
		t = ''
		if self.plain:
			if self.const and settings.wantConst:
				t += 'const '
			t += self.base
		elif self.ptr:
			t += self.base._format(settings)
			t += '*'
			if self.const and settings.wantConst:
				t += 'const '
		elif self.ref:
			t += self.base._format(settings)
			t += ('*' if settings.refAsPtr else '&')
		elif self.template:
			t += self.base._format(settings)
			t += ('!(' if settings.DTempl else ' < ')
			t += self.param._format(settings)
			t += (')' if settings.DTempl else ' > ')
		elif self.tuple:
			t += ', '.join(item._format(settings) for item in self.tupleItems)
		else:
			assert False
		return t


	def forFacade(self, param = None):
		def worker(t):		# TODO
			if t.plain:
				return t.c
			if t.ptr and t.base.ptr:
				return self.base.forDBridge() + '*'
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return t.base.d()
			if t.ptr and ((t.base.plain and not t.base.cls) or t.base.ptr):
				return t.d()

			# const ref
			if t.ref and t.base.plain and not t.base.cls and t.base.const:
				return t.base.d()

			if t.ref and t.base.plain and not t.base.cls:
				return t.base.d()+'*'
			return ''
		return worker(self)

	def forDBridge(self, param = None):
		def worker(t):		# TODO
			if t.plain:
				return t.c
			if t.ptr and t.base.ptr:
				return self.base.forDBridge() + '*'
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return t.base.d() + '_cptr'

			# const ref
			if t.ref and t.base.plain and not t.base.cls and t.base.const:
				return t.base.d() + '*'

			if (t.ptr or t.ref) and ((t.base.plain and not t.base.cls) or t.base.ptr):
				return t.d()
			if t.ref and t.base.plain and not t.base.cls:
				return t.d()+'*'
			return ''
		return worker(self)

	def forCBridge(self, param = None):
		def worker(t):		# TODO
			if t.plain:
				return t.c
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return t.base.c + '*'

			# const ref
			if t.ref and t.base.plain and not t.base.cls and t.base.const:
				return t.base.c + '*'

			if t.ptr and ((t.base.plain and not t.base.cls) or t.base.ptr):
				return t.c
			if t.ref and t.base.plain and not t.base.cls:
				return t.base.c + '*'
			return ''
		return worker(self)

	def forDReturn(self, expr):
		def worker(t, expr):		# TODO
			if t.plain:
				return expr
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return '%s(%s)' % (t.base.base, expr)

			# const ref
			if t.ref and t.base.plain and not t.base.cls and t.base.const:
				return '*'+expr

			if t.ptr and ((t.base.plain and not t.base.cls) or t.base.ptr):
				return expr
			if t.ref and t.base.plain and not t.base.cls:
				return expr
			return ''
		return worker(self, expr)

	def forDPropGetter(self, expr):
		def worker(t, expr):		# TODO
			if t.plain:
				if t.cls:
					return '%s(%s)' % (t.base, expr)
				else:
					return '*'+expr
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return '%s(*%s)' % (t.base.base, expr)
			assert False, expr
		return worker(self, expr)

	def forDPropSetter(self, expr):
		def worker(t, expr):		# TODO
			if t.plain:
				if t.cls:
					return expr+'._impl'
				else:
					return expr
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return expr+'._impl'

			# const ref
			if t.ref and t.base.plain and not t.base.cls and t.base.const:
				return '&'+expr

			if t.ptr and ((t.base.plain and not t.base.cls) or t.base.ptr):
				return expr
			if t.ref and t.base.plain and not t.base.cls:
				return expr
			return ''
		return worker(self, expr)

	def passToC(self, expr):
		def worker(t, expr):		# TODO
			if t.plain:
				return expr
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return expr+'._impl'

			# const ref
			if t.ref and t.base.plain and not t.base.cls and t.base.const:
				return '&'+expr

			if t.ptr and ((t.base.plain and not t.base.cls) or t.base.ptr):
				return expr
			if t.ref and t.base.plain and not t.base.cls:
				return expr
			return ''
		return worker(self, expr)

	def passToHavok(self, expr):
		def worker(t, expr):		# TODO
			if t.plain:
				return expr
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return (expr if t.ptr else '*'+expr)

			# const ref
			if t.ref and t.base.plain and not t.base.cls and t.base.const:
				return '*'+expr

			if t.ptr and ((t.base.plain and not t.base.cls) or t.base.ptr):
				return expr
			if t.ref and t.base.plain and not t.base.cls:
				return '*'+expr
			return ''
		return worker(self, expr)

	def returnFromHavok(self, expr):
		def worker(t, expr):		# TODO
			if t.plain:
				return expr
			if (t.ptr or t.ref) and t.base.plain and t.base.cls:
				return (expr if t.ptr else '&'+expr)

			# const ref
			if t.ref and t.base.plain and not t.base.cls and t.base.const:
				return '&'+expr

			if t.ptr and ((t.base.plain and not t.base.cls) or t.base.ptr):
				return expr
			if t.ref and t.base.plain and not t.base.cls:
				return '&'+expr
			return ''
		return worker(self, expr)


	TOKptr = ('*', '*')
	TOKref = ('&', '&')
	TOKcomma = (',', ',')
	TOKconst = ('const', 'const')

	keywords = {
			'const' : TOKconst
	}

	def lexType(self, t, forTok = None):
		tokens = []
		def lexIdent(t):
			id = None
			if t[0].isalpha() or '_' == t[0]:
				id = t[0]
				t = t[1:]
				while len(t) and (t[0].isalnum() or '_' == t[0]):
					id += t[0]
					t = t[1:]
			return t, id

		while len(t.lstrip()):
			t = t.lstrip()

			t, ident = lexIdent(t)
			if ident:
				if ident in self.keywords:
					tokens.append(self.keywords[ident])
				else:
					tokens.append(('id', ident))
				continue

			if '*' == t[0]:
				tokens.append(self.TOKptr)
				t = t[1:]
				continue

			if '&' == t[0]:
				tokens.append(self.TOKref)
				t = t[1:]
				continue

			if ',' == t[0]:
				tokens.append(self.TOKcomma)
				t = t[1:]
				continue

			if '<' == t[0]:
				tt, t = self.lexType(t[1:], '<')
				tokens.append(('template', tt))
				continue

			if '>' == t[0]:
				assert '<' == forTok
				return tokens, t[1:]

			assert False, 'Unrecognized token: "%s"' % t
		return tokens


	def _stringizeTokens(self, tokens):
		def worker(tokens):
			res = []
			for t in tokens:
				if 'template' == t[0]:
					res += ['<'] + worker(t[1]) + ['>']
				else:
					res.append(t[1])
			return res
		return ' '.join(worker(tokens))

	def _parseType(self, tokens):
		if self.DebugOutput: print 'Recognizing type (%s) ...' % self._stringizeTokens(tokens)

		if tokens.count(self.TOKcomma):
			self.tuple = True
			tupleToks = []
			prev = 0
			for i in range(len(tokens)):
				if tokens[i] == self.TOKcomma:
					slice = tokens[prev:i]
					tupleToks.append(slice)
					assert len(slice) > 0
					prev = i+1
			slice = tokens[prev:]
			tupleToks.append(slice)
			assert len(slice) > 0
			self.tupleItems = [ TypeAnalysis(toks) for toks in tupleToks ]

		elif len(tokens) > 2 and self.TOKptr == tokens[-2] and self.TOKconst == tokens[-1]:
			if self.DebugOutput: print 'Type (%s) is a const pointer' % self._stringizeTokens(tokens)
			self.const = True
			self.ptr = True
			self.base = TypeAnalysis(tokens[:-2])

		elif len(tokens) > 1 and self.TOKptr == tokens[-1]:
			if self.DebugOutput: print 'Type (%s) is a mutable pointer' % self._stringizeTokens(tokens)
			self.ptr = True
			self.base = TypeAnalysis(tokens[:-1])

		elif len(tokens) > 1 and self.TOKref == tokens[-1]:
			if self.DebugOutput: print 'Type (%s) is a reference' % self._stringizeTokens(tokens)
			self.ref = True
			self.base = TypeAnalysis(tokens[:-1])

		else:
			if len(tokens) > 1 and 'template' == tokens[-1][0]:
				if self.DebugOutput: print 'Type (%s) is a template' % self._stringizeTokens(tokens)
				self.template = True
				self.param = TypeAnalysis(tokens[-1][1])
				self.base = TypeAnalysis(tokens[:-1])

			elif len(tokens) in [1, 2] and 'id' == tokens[-1][0]:
				if 2 == len(tokens):
					if self.TOKconst == tokens[0]:
						self.const = True
					else:
						assert False, 'Unknown modifier: "%s"' % tokens[0][1]

				id = tokens[-1][1]
				self.base = id

				global name2class

				if id in name2class:
					if self.DebugOutput: print 'Type (%s) is a class' % id
					self.cls = name2class[id]
				else:
					if self.DebugOutput: print 'Type (%s) is basic' % id

			else:
				assert False, self._stringizeTokens(tokens)

		self.mutable = not self.const
		self.plain = not (self.ptr or self.ref or self.template or self.tuple)


	def __init__(self, t):
		tokens = None

		if type(t) == type([]) and type(t[0]) == type(()):
			tokens = t

		if not tokens:
			tokens = self.lexType(t)

		# Yup, even if it was passed in, generate it from tokens anyway - stability test
		t = self._stringizeTokens(tokens)

		self.const = False
		self.mutable = False
		self.tuple = False
		self.ref = False
		self.ptr = False
		self.plain = False
		self.cls = None
		self.template = False
		self.base = None
		self.param = None
		self.c = t

		assert len(t) > 0

		self._parseType(tokens)


if __name__ == '__main__':
	global name2class

	# these are to be HkClass instances, the True is just a placeholder for a value
	name2class = {
		'Foo' : True,
		'Bar' : True,
		'Baz' : True
	}

	TypeAnalysis.DebugOutput = True

	def cmp(a, b):
		if a.replace(' ', '') != b.replace(' ', ''):
			assert False, '"%s" (result) != "%s" (expected)' % (a, b)
	
	if 1:
		a = TypeAnalysis('float')
		assert a.plain
		assert not a.ptr
		assert not a.ref
		cmp(a.c, 'float')
		cmp(a.forFacade(), 'float')
		cmp(a.forDBridge(), 'float')
		cmp(a.forCBridge(), 'float')
		cmp(a.forDReturn('x'), 'x')
		cmp(a.passToHavok('x'), 'x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('float*')
		assert a.ptr
		cmp(a.c, 'float *')
		assert a.base.plain
		cmp(a.base.c, 'float')
		cmp(a.forFacade(), 'float*')
		cmp(a.forDBridge(), 'float*')
		cmp(a.forCBridge(), 'float*')
		cmp(a.forDReturn('x'), 'x')
		cmp(a.passToHavok('x'), 'x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('float&')
		assert a.ref
		cmp(a.c, 'float &')
		assert a.base.plain
		cmp(a.base.c, 'float')
		cmp(a.forFacade(), 'float*')
		cmp(a.forDBridge(), 'float*')
		cmp(a.forCBridge(), 'float*')
		cmp(a.forDReturn('x'), 'x')
		cmp(a.passToHavok('x'), '*x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('float**')
		assert a.ptr
		cmp(a.c, 'float * *')
		assert a.base.ptr
		cmp(a.base.c, 'float *')
		assert a.base.base.plain
		cmp(a.base.base.c, 'float')
		cmp(a.forFacade(), 'float**')
		cmp(a.forDBridge(), 'float**')
		cmp(a.forCBridge(), 'float**')
		cmp(a.forDReturn('x'), 'x')
		cmp(a.passToHavok('x'), 'x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('const int *')
		assert a.ptr
		assert a.mutable
		assert a.base.plain
		assert a.base.const
		assert a.base.c == "const int", a.base.c
		cmp(a.forFacade(), 'int*')
		cmp(a.forDBridge(), 'int*')
		cmp(a.forCBridge(), 'const int*')
		cmp(a.forDReturn('x'), 'x')
		cmp(a.passToHavok('x'), 'x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('const float&')
		assert a.ref
		cmp(a.c, 'const float &')
		assert a.base.plain
		assert a.base.const
		cmp(a.base.c, 'const float')
		cmp(a.forFacade(), 'float')
		cmp(a.forDBridge(), 'float*')
		cmp(a.forCBridge(), 'const float*')
		cmp(a.forDReturn('x'), '*x')
		cmp(a.passToHavok('x'), '*x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('const int * const')
		assert a.ptr
		assert a.const
		assert a.base.plain
		assert a.base.const
		assert a.base.c == "const int", a.base.c
		cmp(a.forFacade(), 'int*')
		cmp(a.forDBridge(), 'int*')
		cmp(a.forCBridge(), 'const int* const')
		cmp(a.forDReturn('x'), 'x')
		cmp(a.passToHavok('x'), 'x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('Foo')
		assert a.plain
		assert a.c == "Foo", a.c
		assert a.cls
		cmp(a.forFacade(), 'Foo')
		cmp(a.forDBridge(), 'Foo')
		cmp(a.forCBridge(), 'Foo')
		cmp(a.forDReturn('x'), 'x')
		cmp(a.passToHavok('x'), 'x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('Foo*')
		assert a.ptr
		assert a.base.plain
		assert a.base.c == "Foo", a.base.c
		assert a.base.cls
		cmp(a.forFacade(), 'Foo')
		cmp(a.forDBridge(), 'Foo_cptr')
		cmp(a.forCBridge(), 'Foo*')
		cmp(a.forDReturn('x'), 'Foo(x)')
		cmp(a.passToHavok('x'), 'x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('Foo&')
		assert a.ref
		assert a.base.plain
		assert a.base.c == "Foo", a.base.c
		assert a.base.cls
		cmp(a.forFacade(), 'Foo')
		cmp(a.forDBridge(), 'Foo_cptr')
		cmp(a.forCBridge(), 'Foo*')
		cmp(a.forDReturn('x'), 'Foo(x)')
		cmp(a.passToHavok('x'), '*x')
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('Foo <int>')
		assert a.template
		assert a.base.plain
		assert a.base.c == "Foo", a.base.c
		assert a.base.cls
		cmp(a.c, a._format())

	if 1:
		a = TypeAnalysis('Foo <int, float>')
		assert a.template
		assert a.base.plain
		assert a.base.c == "Foo", a.base.c
		cmp(a.c, 'Foo < int , float >')
		cmp(a.c, a._format())


