"""Helper de edicao: conta as ocorrencias E grava a cada passo."""
import sys

class Patch:
    def __init__(self, path):
        self.path = path
        self.done = []
    def rep(self, old, new, count=1):
        s = open(self.path).read()
        n = s.count(old)
        if n != count:
            print("JA APLICADO/OK ATE AQUI: %s" % self.done)
            sys.exit("FALHOU em %s: esperava %d, achei %d de %r"
                     % (self.path, count, n, old[:90]))
        open(self.path, 'w').write(s.replace(old, new))
        label = old.strip().split('\n')[0][:52]
        self.done.append(label)
        print("ok  %s" % label)
