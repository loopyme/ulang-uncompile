# uncompyle6 version 3.6.3
# Python bytecode 3.7 (3394)
# Decompiled from: Python 3.7.5 (default, Nov  7 2019, 10:50:52)
# [GCC 8.3.0]
# Embedded file name: ulang\parser\error.py


class SyntaxError(ValueError):
    __module__ = __name__
    __qualname__ = "SyntaxError"

    def __init__(self, message, filename, lineno, colno, source=None):
        self.message_ = message
        self.filename_ = filename
        self.lineno_ = lineno if lineno > 0 else 1
        self.colno_ = colno if colno > 0 else 1
        self.source_ = source

    def __str__(self):
        msg = 'File "%s", line %d:%d, %s' % (
            self.filename_,
            self.lineno_,
            self.colno_,
            self.message_,
        )
        if self.source_:
            line = self.source_[(self.lineno_ - 1)]
            col = " " * (self.colno_ - 1) + "^"
            msg = "%s\n%s\n%s" % (msg, line, col)
        return msg

# okay decompiling ./pyc/ulang.parser.error.pyc
