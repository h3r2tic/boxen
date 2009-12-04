import re


def countIndent(str):
    indent = 0
    while len(str) > 0 and str[0] == '\t':
        indent += 1
        str = str[1:]
    assert len(str) > 0 and str[0] != ' '
    return indent


def iterNonEmptyLines(lines):
    for line in lines:
        sline = line.strip()
        if 0 == len(sline) or sline[0] == '#':
            continue
        yield line

def findBlock(lines, minIndent):
    res = []

    while len(lines) > 0:
        line = lines[0]
        indent = countIndent(line)
        if indent < minIndent:
            return res, lines

        lines = lines[1:]
        sline = line.strip()

        if sline == '<D':
            code = []
            while len(lines) > 0:
                ln = lines[0]
                lines = lines[1:]
                if ln.strip() == 'D>':
                    break
                code.append(ln)
            res.append(('D', None, code))
            continue

        directive, args = (sline+' ').split(' ', 1)
        args = args.strip()
        args = re.sub(r'\s+', ' ', args)

        body, lines = findBlock(lines, indent+1)
        res.append((directive, args, body))
        
    return res, lines

