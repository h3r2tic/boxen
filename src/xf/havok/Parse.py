from Classes import *
from Lex import findBlock, iterNonEmptyLines


class ParseError(Exception):
	def __init__(self, value):
		self.value = value

	def __str__(self):
		return `self.value`


def processFunc(args, body):
	res = HkFunc(args)
	
	def processFuncParam(args, body):
		par = apply(HkFuncParam, args.split(' ', 1))
		res.params.append(par)
		for item in body:
			if 'pass' == item[0]:
				par.passAs = item[1]
			elif 'hkType' == item[0]:
				par.hktype = item[1]
			else:
				raise ParseError('Unrecognized parameter attribute: "%s"' % `item`)


	for item in body:
		if 'hk' == item[0]:
			res.hkname = item[1]
		elif 'param' == item[0]:
			apply(processFuncParam, item[1:])
		elif 'static' == item[0]:
			res.static = 1
		elif 'return' == item[0]:
			assert type(item[1]) == type('')
			res.ret = item[1]
		else:
			raise ParseError('Unrecognized function attribute: "%s"' % `item`)

	return res


def processField(args, body):
	res = apply(HkClassField, args.split(' ', 1))
	for item in body:
		if 'hkType' == item[0]:
			res.hktype = item[1]
		elif 'forceCast' == item[0]:
			res.forceCast = 1
		else:
			raise ParseError('Unrecognized field attribute: "%s"' % `item`)
	return res


def processClass(args, body):
	name = args.split(' ', 1)
	deriv = ''
	if len(name) > 1:
		deriv = name[1]
	name = name[0]
	res = HkClass(name, deriv.split(' ') if len(deriv) > 0 else [])
	
	for item in body:
		if 'hk' == item[0]:
			res.hkname = item[1]
		elif 'func' == item[0]:
			res.funcs.append(processFunc(item[1], item[2]))
		elif 'field' == item[0]:
			res.fields.append(processField(item[1], item[2]))
		elif 'abstract' == item[0]:
			res.abstract = 1
		elif 'D' == item[0]:
			res.verbatimD += item[2]
		else:
			raise ParseError('Unrecognized class attribute: "%s"' % `item`)

	for fn in res.funcs:
		if fn.name == 'this':
			fn.ret = res.name + '*'
		
	return res


def processFile(name):
	block = findBlock([ l for l in iterNonEmptyLines(open(name).read().split('\n')) ], 0)[0]
	classes = []
	funcs = []
	dcode = []
	for item in block:
		if 'class' == item[0]:
			classes.append(apply(processClass, item[1:]))
		elif 'func' == item[0]:
			funcs.append(apply(processFunc, item[1:]))
		elif 'D' == item[0]:
			dcode.append(item[2])
		else:
			raise ParseError('Unrecognized module attribute: "%s"' % `item`)
	return classes, funcs, dcode

