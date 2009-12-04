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
