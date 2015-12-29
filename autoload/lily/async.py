import threading
from subprocess import call
import json as JSON

LILY_FILTERS = {}

class AsyncCommand(object):
    
    def __init__(self, callbackFn):
        self.callbackFn = callbackFn

    def run(self):
        raise NotImplementedError('Subclasses must implement run()!')

    def start(self):
        threading.Thread(target=self._do_run).start()

    def error(self, message):
        self.async_call('lily#ui#Error', message)

    def async_call(self, fun, *args):
        """Call a vim callback function remotely"""
        instance = vim.eval('v:servername')
        exe = vim.eval('exepath(v:progpath)')
        
        expr = fun + '('
        expr += ','.join([ JSON.dumps(a, separators=(',',':')) for a in args ])
        expr += ') | redraw!'

        result = call([exe, '--servername', instance, \
            '--remote-expr', expr.replace("\\n", "")])
        if result != 0:
            self.error("Couldn't send request")

    def keys(self, item, keys, fn=lambda k,v:v):
        if item is None:
            return None

        return {k: fn(k, item[k]) \
                for k in keys \
                if item[k] is not None}

    def _do_run(self):
        try:
            result = self.run()
        except Exception, e:
            self.error(repr(e))
            return

        # let subclasses insert args
        args = self._expand_args(result)

        # clean up to avoid silent errors
        for i in xrange(0, len(args)):
            if args[i] is None:
                args[i] = 0

        # send it on over
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

def lily_filter(fn):
    # wraps the fn to save a closure
    #  so we can reuse a `self` instance.
    #  This may be a terrible idea.
    def wrapper(self, json):
        def closure(json):
            return fn(self, json)

        LILY_FILTERS[self.repo_path] = closure
        return closure(json)
    return wrapper
