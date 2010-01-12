from utils import *


attribTypes = {}
functions = []


class Function:
	def __init__(self, name):
		self.name = name
		self.params = []
		self.returnType = None
		self.extension = False
		self.category= None
		self.attribs = {}
		self.deprecated = None

	def addParam(self, param):
		self.params.append(param)

	def addAttrib(self, name, value):
		self.attribs[name] = value

class Param:
	'The type can be a string, ArrayType or IdentMultArraySize'
	def __init__(self, type_, name):
		self.name = name
		self.type_ = type_
		self.inferredFrom = None

class ArrayType:
	'The "basic" param is a string'
	def __init__(self, basic, size):
		self.basic = basic
		self.size = size

class PointerType:
	'The "basic" param is a string'
	def __init__(self, basic):
		self.basic = basic

class IdentMultArraySize:
	'The "ident" param is a string and refers to a param of the same function'
	def __init__(self, ident, mult):
		self.ident = ident
		self.mult = mult

# ----------------------------------------------------------------

def parseEntity(line, lineIter):
	global attribTypes

	for prop in rematch(r"([a-zA-Z_][a-zA-Z0-9_-]*):(.*)", line):
		name = prop.group(1)
		if name in ('passthru', 'newcategory'):
			return
		else:
			if not (name in attribTypes):
				print 'adding entity "%s"' % name
				
				vals = prop.group(2).strip()
				if vals != '*':
					attribTypes[name] = vals.split(' ')
				else:
					attribTypes[name] = None
			return

	for funcMatch in rematch(r"(\w+)\(\s*(\w+(?:\s*, \w+)*)?\s*\)$", line):
		parseFunc(funcMatch, lineIter)
		return

	if len(line) > 0:
		print 'Unrecognized entity: "%s"' % line


def parseFunc(funcMatch, lineIter):
	func = Function(funcMatch.group(1))
	for line in lineIter.iterBlock():
		parseFuncAttrib(line, func)
	verifyFunc(func)
	functions.append(func)

def verifyFunc(func):
	assert not (func.category is None)
	assert not (func.returnType is None)
	
	params = dict( (p.name, p) for p in func.params )
	for param in func.params:
		if isinstance(param.type_, ArrayType):
			size = param.type_.size
			if isinstance(size, IdentMultArraySize):
				if not (size.ident in params):
					assert False, 'array length for param %s references unknown param %s' % (param.name, size.ident)
				else:
					params[size.ident].inferredFrom = param


def parseFuncAttrib(line, func):
	for m in rematch(r"return (\w+)$", line):
		func.returnType = m.group(1)
		return

	for m in rematch(r"category (\w+)( # old: [^ ]+)?$", line):
		func.category = m.group(1)
		return

	for m in rematch(r"deprecated (.*)", line):
		func.deprecated = m.group(1)
		return

	for m in rematch(r"param (\w+) (.*)", line):
		pname = m.group(1)
		if 'ref' == pname:
			pname = '_ref'
		ptype = parseParamType(m.group(2).strip())
		func.addParam(Param(ptype, pname))
		return

	for m in rematch(r"extension\b", line):
		func.extension = True
		return

	for m in rematch(r"(\w+) ([^#]*)( #.*)?$", line):
		attrName = m.group(1)
		assert attrName != "return", line
		assert attrName != "category", line
		assert attrName != "param", line
		if attrName in attribTypes:
			possibleValues = attribTypes[attrName]
			values = [s for s in m.group(2).split(' ') if len(s) > 0]
			if possibleValues:
				for v in values:
					if not (v in possibleValues):
						print "Invalid function attrib value: '%s' (type is '%s')" % (v, attrName)
			func.addAttrib(attrName, values)
			return

	print "Unrecognized function attrib: '%s'" % line

def parseParamType(tstr):
	m = re.match(r"(\w+) (in|out) value", tstr)
	if m:
		return m.group(1)
	
	m = re.match(r"(\w+) (in|out) reference", tstr)
	if m:
		return PointerType(m.group(1))

	m = re.match(r"(\w+) (in|out) array \[([^\]]*)\]", tstr)
	if m:
		asize = parseArraySize(m.group(3).strip())
		if isinstance(asize, type(0)):
			return PointerType(m.group(1))
		else:
			return ArrayType(m.group(1), asize)

	m = re.match(r"(\w+) (in|out) array", tstr)
	if m:
		return PointerType(m.group(1))

	print "Unrecognized function param attrib: '%s'" % tstr

def parseArraySize(tstr):
	if 0 == len(tstr):
		return None
	
	for m in rematch(r"([0-9])+$", tstr):
		return int(m.group(1))

	for m in rematch(r"(\w+)$", tstr):
		return IdentMultArraySize(m.group(1), 1)

	for m in rematch(r"(\w+)\*([0-9]+)$", tstr):
		return IdentMultArraySize(m.group(1), int(m.group(2)))

	for m in rematch(r"COMPSIZE\((\w+(?:[/,]\w+)*)*\)+$", tstr):
		# TODO
		return None

	print "Couldn't parse array size: '%s'" % tstr
	return None

# ----------------------------------------------------------------

def parseFunctions(lineIter):
	global attribTypes, functions

	attribTypes = {}
	functions = []
	
	for line in lineIter.iterAllLines():
		if line.startswith('#'):
			continue
		parseEntity(line, lineIter)
	return functions


if __name__ == "__main__":
	funcs = parseFunctions(LineIter(open('gl.spec').read()))
	print 'Parsed %d functions.' % len(funcs)
