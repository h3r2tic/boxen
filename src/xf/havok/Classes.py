name2class = {}


class HkClass:
	def __init__(self, name, deriv):
		self.name = name
		self.hkname = name
		self.deriv = deriv
		self.funcs = []
		self.fields = []
		self.isPOD = 0
		self.verbatimD = []
		self.verbatimC = []
		self.abstract = 0
		self.newable = 0
		self._inheritanceResolved = False

	def ptrTypeName(self):
		return self.name + '_cptr'

	def hasFunction(self, name):
		for f in self.funcs:
			if f.name == name:
				return f, self
		for d in self.deriv:
			h = d.hasFunction(name)
			if h:
				return h
		return None

	def iterBases(self, direct = True):
		for i in range(len(self.deriv)):
#		for d in self.deriv:
			yield (self.deriv[i], i == 0 and direct)
			for it in self.deriv[i].iterBases(i == 0 and direct):
				yield it

class HkFunc:
	def __init__(self, name):
		self.name = name
		self.hkname = name
		self.params = []
		self.ret = 'void'
		self.static = 0
		self.cls = None

	def clone(self):
		res = HkFunc(self.name)
		res.hkname = self.hkname
		res.params = self.params
		res.ret = self.ret
		res.static = self.static
		res.cls = self.cls
		return res

	def bridgeName(self):
		if self.cls:
			return 'dhk_%s_%s' % (self.cls.name, self.name)
		else:
			return 'dhk_%s' % self.name

class HkFuncParam:
	def __init__(self, name, type_):
		self.name = name
		self.type_ = type_
		self.hktype = None
		self.passAs = name

	def passToC(self):
		return self.type_.passToC(self.name)

	def passToHavok(self):
		return self.type_.passToHavok(self.name)

class HkClassField:
	def __init__(self, name, type_):
		self.name = name
		self.type_ = type_
		self.hktype = None
		self.forceCast = 0
		self.cls = None

	def bridgeName(self):
		return 'dhk_%s_field_%s' % (self.cls.name, self.name)

