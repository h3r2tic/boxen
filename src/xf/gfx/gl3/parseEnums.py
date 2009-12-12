from utils import *


class Enum:
	def __init__(self):
		self.names = []

	def addItem(self, item):
		self.names.append(item)

class DirectName:
	def __init__(self, name, value, annot):
		self.name = name
		self.value = value
		self.annot = annot

class NameAlias:
	def __init__(self, enum, name):
		self.enum = enum
		self.name = name

class SpecialNameAlias:
	def __init__(self, name, src):
		self.name = name
		self.src = src


class AliasAnnotation:
	def __init__(self, name):
		self.name = name

class TypeAnnotation:
	def __init__(self, typename, count):
		assert typename == 'F' or typename == 'I'
		self.typename = typename
		self.count = count


# ----------------------------------------------------------------

extensionNames = {}
enums = {}

# ----------------------------------------------------------------

def parseEntity(line, lineIter):
	global extensionNames
	if re.match(r"Extensions define:$", line):
		for versionDef in lineIter.iterBlock():
			name = re.search(r"(\w+)", versionDef).group(1)
			extensionNames[name] = 1
		return

	for enumMatch in rematch(r"(\w+(?:, \w+)*) enum:(.*)$", line):
		parseEnum(enumMatch, lineIter)
		return

	if re.match(r"passthru:", line):
		return

	if len(line) > 0:
		print 'Unrecognized entity: ', line


def parseEnum(enumMatch, lineIter):
	global enums
	
	groups = enumMatch.groups()
	names = groups[0].split(' ')
	annot = groups[1]

	def getEnum(n):
		if n in enums: return enums[n]
		en = Enum()
		enums[n] = en
		return en
		
	localEnums = [getEnum(n) for n in names]

	def addItem(item):
		for en in localEnums:
			en.addItem(item)

	for enumDef in lineIter.iterAllLines():
		for m in rematch(r"(\w[0-9a-zA-Z_]*(?:, \w[0-9a-zA-Z_]*)*) enum:(.*)$", enumDef):
#			print 'DUPA: %s' % enumDef
			parseEnum(m, lineIter)
			return

		parseEnumEntity(enumDef, lambda item:addItem(item))

def sanitizeEnumName(n):
	if n[0:3] == "GL_":
		n = n[3:]
	if n[0] in '0123456789':
		return '_' + n
	else:
		return n

def sanitizeEnumNumericValue(n):
	n = n.replace('ll', 'L')
	n = n.replace('l', 'L')
	n = n.replace('u', 'U')
	return n

def parseEnumEntity(enumDef, addItem):
	if 0 == len(enumDef): return

	for m in rematch(r"(\w+): \(OpenGL ES only\)$", enumDef):
		return

	for m in rematch(r"use (\w+) (\w+)$", enumDef):
		assert 2 == len(m.groups())
		addItem(NameAlias(m.group(1), sanitizeEnumName(m.group(2))))
		return

	for m in rematch(r"(\w+) = ((?:0x[0-9A-F]+|[0-9]+)[ulUL]*)( #.*)?$", enumDef):
		assert 3 == len(m.groups())
		annot = m.group(3)

		aliases = []
		
		if annot:
			annot = parseEnumItemAnnotation(annot)
			newAnnot = []
			for a in annot:
				if isinstance(a, AliasAnnotation):
					aliases.append(a.name)
				else:
					newAnnot.append(a)
			annot = newAnnot

		aliases.append(sanitizeEnumName(m.group(1)))

		for alias in aliases:
			addItem(DirectName(alias, sanitizeEnumNumericValue(m.group(2)), annot))
		
		return
		
	for m in rematch(r"(\w+) = (\w+)$", enumDef):
		assert 2 == len(m.groups())
		addItem(SpecialNameAlias(sanitizeEnumName(m.group(1)), sanitizeEnumName(m.group(2))))
		return

	for m in rematch(r"#", enumDef):
		return

	print 'Unrecognized enum field def: ', enumDef
	assert False


def parseEnumItemAnnotation(annot):
	annots = [an.strip() for an in annot.split('#')][1:]
	res = []
	for a in annots:
		parsed = parseAnnotItem(a)
		if parsed:
			res.append(parsed)
	return res

def parseAnnotItem(annot):
	for m in rematch(r"([0-9]+) ([IF])$", annot):
		return TypeAnnotation(m.group(2), int(m.group(1)))

	for m in rematch(r"alias (\w+)$", annot):
		return AliasAnnotation(sanitizeEnumName(m.group(1)))

	for m in rematch(r"Different from .* value$", annot):
		return

	for m in rematch(r"\w+ \(renamed\)$", annot):
		return

	for m in rematch(r"(\w+(?: / \w+)*)$", annot):
		return

	for m in rematch(r"(\w+(?: \+ \w+)*)$", annot):
		return

	for m in rematch(r"(\w+(?:, \w+)*)$", annot):
		return

	for m in rematch(r"Not promoted", annot):
		return

	for m in rematch(r"Equivalent to \w+$", annot):
		return

	print "unrecognized annotation: ", annot

# ----------------------------------------------------------------


def parseEnums(lineIter):
	global extensionNames, enums

	extensionNames = {}
	enums = {}

	for line in lineIter.iterAllLines():
		if re.match(r"#", line):
			continue
		parseEntity(line, lineIter)
	return enums


if __name__ == "__main__":
	enums = parseEnums(LineIter(open('enum.spec').read()))
	print 'Parsed %d enums.' % len(enums)
	
