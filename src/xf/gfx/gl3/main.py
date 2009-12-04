import re

from parseEnums import parseEnums
from parseTypes import parseTypes
from parseFunctions import parseFunctions, ArrayType, PointerType, IdentMultArraySize
from utils import LineIter


enums = parseEnums(LineIter(open('enum.spec').read()))
types = parseTypes(LineIter(open('gl.tm').read()))
funcs = parseFunctions(LineIter(open('gl.spec').read()))
requiredTypes = {}


def formatType(t):
    if isinstance(t, type('')):
        if t in types:
            basic = types[t]
            if ("GLenum" == basic or "GLbitfield" == basic) and not ("GLenum" == t or "GLbitfield" == t):
                requiredTypes[t] = basic
                return t
            return basic
        return t
    elif isinstance(t, ArrayType):
        return formatType(t.basic) + "[]"
    elif isinstance(t, PointerType):
        return formatType(t.basic) + "*"
    else:
        assert False, `t`


def formatCType(t):
    if isinstance(t, type('')):
        if t in types:
            basic = types[t]
            if "GLenum" == basic or "GLbitfield" == basic:
                return t
            return basic
        return t
    elif isinstance(t, ArrayType):
        return formatCType(t.basic) + "*"
    elif isinstance(t, PointerType):
        return formatCType(t.basic) + "*"
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
    return n[0].lower() + n[1:]



funcsToEmit = [func for func in funcs if (not re.search(r"DEPRECATED", func.category)) and re.search(r"VERSION_", func.category)]
    

for func in funcsToEmit:
    formatType(func.returnType)
    for p in func.params:
        formatType(p.type_)

for td in requiredTypes.keys():
    print 'enum %s: %s {' % (td, requiredTypes[td])
    if td in enums:
        enum = enums[td]
    else:
        print 'NOT FOUND'
    print '}'


print
print


print 'extern (System) {'
for func in funcsToEmit:
    ret = formatCType(func.returnType)
    args = ', '.join((formatCType(p.type_) + ' ' + p.name for p in func.params))
    print '\t%s function(%s) pf_gl%s;' % (ret, func.name, args)
print '}'

print
print


for func in funcsToEmit:
    renamedFuncName = formatFuncName(func.name)
    
    ret = formatType(func.returnType)
    args = ', '.join((formatType(p.type_) + ' ' + p.name for p in func.params if not p.inferredFrom))
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
                formatType(param.type_),
                param.name,
                param.inferredFrom.name,
                '' if mult == 1 else ' / %s' % mult
            )
        
        sizeCheck = None
        
        if isinstance(param.type_, ArrayType):
            size = param.type_.size
            if isinstance(size, type(0)):
                sizeCheck = `size`
#                elif isinstance(size, IdentMultArraySize):
#                    sizeCheck = size.ident if 1 == size.mult else '%s * %s' % (size.ident, size.mult)

        if sizeCheck:
            print '\tassert (%s == %s.length)' % (sizeCheck, param.name)

    cargs = ', '.join((paramToCArg(p.type_, p.name)for p in func.params))

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
        
