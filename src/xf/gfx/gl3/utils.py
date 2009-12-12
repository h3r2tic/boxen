import re

def rematch(pattern, inp):
	matcher = re.compile(pattern)
	matches = matcher.match(inp)
	if matches:
		yield matches


class LineIter:
	def __init__(self, data):
		self.enumSpecLines = data.split('\n')

	def iterAllLines(self):
		while len(self.enumSpecLines) > 0:
			res = self.enumSpecLines[0].strip()
			self.enumSpecLines = self.enumSpecLines[1:]
			res = re.sub(r"\s+", " ", res)
			yield res

	def iterBlock(self):
		while len(self.enumSpecLines) > 0:
			res = self.enumSpecLines[0].strip()
			self.enumSpecLines = self.enumSpecLines[1:]
			if 0 == len(res):
				break
			res = re.sub(r"\s+", " ", res)
			yield res

class fmt():
	def __init__(self):
		self.indent = 0
	
	def __call__(self, str, *args):
		data = str % args
		for l in data.splitlines():
			self.output('\t' * self.indent + l)
#		self.output('\n')

	def push(self):
#		self.output('\t' * self.indent + '{')
#		self.output('\n')
		self.indent += 1

	def pop(self):
		assert self.indent >=0
		self.indent -= 1
#		self.output('\t' * self.indent + '}')
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

