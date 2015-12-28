import threading
from subprocess import call
import json as JSON

class AsyncCommand(object):
    
    def __init__(self, callbackFn):
        self.callbackFn = callbackFn

    def run(self):
        raise NotImplementedError('Subclasses must implement run()!')

    def start(self):
        threading.Thread(target=self._do_run).start()

    def async_call(self, fun, *args):
        """Call a vim callback function remotely"""
        instance = vim.eval('v:servername')
        exe = vim.eval('exepath(v:progpath)')
        
        expr = fun + '('
        expr += ','.join([ JSON.dumps(a, separators=(',',':')) for a in args ])
        expr += ') | redraw!'

        call([exe, '--servername', instance, \
            '--remote-expr', expr])

    def keys(self, item, keys, fn=lambda k,v:v):
        if item is None:
            return None

        return {k: fn(k, item[k]) \
                for k in keys \
                if item[k] is not None}

    def _do_run(self):
        result = self.run()

        args = self._expand_args(result)
        self.async_call(self.callbackFn, *args)

    def _expand_args(self, args):
        if type(args) == tuple:
            return list(args)
        else:
            return [args]

class BufAsyncCommand(AsyncCommand):
    def __init__(self, callbackFn, bufno):
        super(BufAsyncCommand, self).__init__(callbackFn)
        self.bufno = bufno

    def _expand_args(self, args):
        parent = super(BufAsyncCommand, self)._expand_args(args)
        return [self.bufno] + parent

class HubrAsyncCommand(BufAsyncCommand):
    def __init__(self, callbackFn, bufno, repo_path):
        super(HubrAsyncCommand, self).__init__(callbackFn, bufno)
        self.repo_path = repo_path

    def hubr(self):
        return Hubr.from_config(self.repo_path + '.hubrrc')

    def _expand_args(self, args):
        parent = super(HubrAsyncCommand, self)._expand_args(args)
        parent.insert(1, self.repo_path)
        return parent

