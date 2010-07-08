from utils import *
from re import sub


def parseTypes(lineIter):
	types = {}
	
	for line in lineIter.iterAllLines():
		if line.startswith('#') or len(line) == 0:
			continue

		m = re.match(r"(\w+),\*,\*, ?([^,]*),\*,\*,?$", line)
		if m:
			n = m.group(1)
			if n != "void":
				t = m.group(2)
				t = sub(r'\bconst\b', '', t)
				t = sub(r'\blong long\b', '$int64$', t)
				t = sub(r'\bunsigned long\b', 'size_t', t)
				t = sub(r'\blong\b', 'ptrdiff_t', t)
				t = sub(r'$int64$', 'long', t)
				t = sub(r'\bunsigned \b', 'u', t)
				types[n] = t
		else:
			assert False, 'Unrecognized type def: "%s"' % line

	return types


if __name__ == "__main__":
	types = parseTypes(LineIter(open('gl.tm').read()))
	print 'Parsed %d types.' % len(types)
