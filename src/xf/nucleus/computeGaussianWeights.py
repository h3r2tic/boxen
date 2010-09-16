from scipy.stats import norm
from math import *
from functools import reduce

numSamples = 5
sigma = 1
weights = []
offsets = []

distrib = norm(0, sigma)

for sample in range(numSamples):
    xl = float(sample) - 0.5*numSamples
    xc = (0.5 + sample) - 0.5*numSamples
    xr = (1.0 + sample) - 0.5*numSamples
    #weights.append(distrib.cdf(xr) - distrib.cdf(xl))
    offsets.append(xc)
    weights.append(distrib.pdf(xc))

norm = reduce(lambda x,y:x+y, weights, 0.0)
weights /= norm

#print zip(offsets, weights)

weights2 = []
offsets2 = []

while len(weights) > 1:
    w1, w2 = weights[0:2]
    o1, o2 = offsets[0:2]
    weights = weights[2:]
    offsets = offsets[2:]
    t = w1 / (w1+w2)
    weights2.append(w1+w2)
    offsets2.append(o1*t + o2*(1.0 - t))

if len(weights) > 0:
    weights2.append(weights[0])
    offsets2.append(offsets[0])

for w, o in zip(weights2, offsets2):
    print '\tres += img.sample(uv - offset * %s) * %s;' % (o, w)
    
