import re

from parseEnums import parseEnums, DirectName, NameAlias, SpecialNameAlias
from parseTypes import parseTypes
from parseFunctions import parseFunctions, ArrayType, PointerType, IdentMultArraySize
from utils import LineIter, strfmt
from codegen import emitModule
import os

def parseSpecs(func, *files):
	res = func(LineIter(open(files[0]).read()))
	if type(res) == type([]):
		for f in files[1:]:
			print 'parsing', f
			res += func(LineIter(open(f).read()))
	else:
		for f in files[1:]:
			print 'parsing', f
			res.update(func(LineIter(open(f).read())))
	return res

class Extension:
	def __init__(self, name):
		self.name = name
		self.funcs = []
		self.enums = []

def prepareForEmission(enumSpecs, typeSpecs, funcSpecs, extPrefix, coreCatRegex):
	enums = apply(parseSpecs, [parseEnums] + enumSpecs)
	types = apply(parseSpecs, [parseTypes] + typeSpecs)
	funcs = apply(parseSpecs, [parseFunctions] + funcSpecs)

	coreFuncs = [f for f in funcs if re.match(coreCatRegex, f.category) and not f.deprecated]
	coreEnums = []
	extensions = []

	name2ext = {}

	enumLookup = {}
	toResolve = []

	for ename in enums.keys():
		enum = enums[ename]
		foo = {}
		for i in range(len(enum.names)):
#			for n in enum.names:
			n = enum.names[i]
			if (isinstance(n, NameAlias)):
				n._owner = enum
				n._ownerIdx = i
				toResolve.append(n)
			elif (isinstance(n, SpecialNameAlias)):
				n._owner = enum
				n._ownerIdx = i
				n.enum = ename
				toResolve.append(n)
			foo[n.name] = n

	while len(toResolve) > 0:
		newToResolve = []
		resolvedAnything = False
		for n in toResolve:
			if n.enum in enums:
				srcEnum = enums[n.enum]
				found = False

				for src in srcEnum.names:
					if isinstance(n, NameAlias):
						if src.name != n.name: continue
					elif isinstance(n, SpecialNameAlias):
						if src.name != n.src: continue
					else: assert False

					if isinstance(src, DirectName):
#						print 'Resolved %s from %s' % (n.name, n.enum)
						e = DirectName(n.name, src.value, None)
						n._owner.names[n._ownerIdx] = e
						resolvedAnything = True
						found = True
						break

				if not found:
					newToResolve.append(n)
			else:
				assert False, "Could not resolve %s (the source '%s' was not found)" % (
						n.name, n.enum
				)

		if not resolvedAnything:
			print "Couldn't resolve enums: %s" % [e.name for e in newToResolve]
			for n in toResolve:
				n._owner.names[n._ownerIdx] = None
			break
		else:
			toResolve = newToResolve


	eid = 0
	for ename in enums.keys():
		e = enums[ename]
		for n in e.names:
			assert n is None or isinstance(n, DirectName), `n`

		if ename in types or re.match(coreCatRegex, ename) or (ename[0:len(extPrefix)] != extPrefix and len(extPrefix) != 0):
			coreEnums.append((ename, e))
		else:
			assert not (ename in name2ext)
			ext = Extension(ename)
			ext.enums.append((ename, e))
			extensions.append(ext)
			name2ext[ename] = ext

	for f in funcs:
		if f.deprecated:
			continue

		if re.search(r"DEPRECATED", f.category):
			continue

		assert len(extPrefix) == 0 or f.category[0:len(extPrefix)] != extPrefix
		if re.match(coreCatRegex, f.category):
			continue
		ename = extPrefix + f.category
		ext = None

		if not ename in name2ext:
			ext = Extension(ename)
			extensions.append(ext)
			name2ext[ename] = ext
		else:
			ext = name2ext[ename]

		ext.funcs.append(f)

	return (types, coreFuncs, coreEnums, extensions)


extFuncCounts = []
extId = 0


def emitWGL():
	global extFuncCounts, extId

	types, coreFuncs, coreEnums, extensions = prepareForEmission(
			['wglenum.spec', 'wglenumext.spec'],
			['gl.tm', 'wgl.tm'],
			['wglext.spec'],
			'WGL_',
			'^wgl$'
	)

	emitModule('WGL', coreEnums, types, coreFuncs, extId,
		extraImports=[
			'xf.gfx.gl3.WGLTypes'
		],
		errorCheckFilter = lambda fname: False,
		funcNamePrefix = 'wgl')
	extFuncCounts.append(len(coreFuncs))
	extId += 1

	try:
		os.makedirs('ext')
	except:
		pass

	for e in extensions:
		emitModule('ext.' + e.name, e.enums, types, e.funcs, extId,
				extraImports=[
					'xf.gfx.gl3.WGLTypes'
				],
				errorCheckFilter = lambda fname: False,
				funcNamePrefix = 'wgl')
		extFuncCounts.append(len(e.funcs))
		extId += 1


def emitCore():
	global extFuncCounts, extId

	types, coreFuncs, coreEnums, extensions = prepareForEmission(
			['enum.spec'],
			['gl.tm'],
			['gl.spec'],
			'',
			'^VERSION_[1-3]_[0-9]$'
	)
	emitModule('GL', coreEnums, types, coreFuncs, extId,
			errorCheckFilter = lambda fname: fname != "GetError")
	extFuncCounts.append(len(coreFuncs))
	extId += 1

	try:
		os.makedirs('ext')
	except:
		pass

	for e in extensions:
		emitModule('ext.' + e.name, e.enums, types, e.funcs, extId)
		extFuncCounts.append(len(e.funcs))
		extId += 1


emitCore()
emitWGL()
f = strfmt()
f('module xf.gfx.gl3.ExtensionGenConsts;')
f.nl()
f('const int[] extensionFuncCounts = [')
f.push()
for c in extFuncCounts[:-1]:
	f('%d,', c)
f('%d', extFuncCounts[-1])
f.pop()
f('];')
open('ExtensionGenConsts.d', 'w').write(f.data)
