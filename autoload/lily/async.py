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

    def _do_run(self):
        result = self.run()

        if type(result) == tuple:
            self.async_call(self.callbackFn, *result)
        else:
            self.async_call(self.callbackFn, result)

class BufAsyncCommand(AsyncCommand):
    def __init__(self, callbackFn, bufno):
        super(BufAsyncCommand, self).__init__(callbackFn)
        self.bufno = bufno

    def async_call(self, fun, *args):
        args = [self.bufno] + list(args)
        super(BufAsyncCommand, self).async_call(fun, *args)
