# ulan-uncompile
反编译木兰编译器,并分析源码
---


> 涉及到的代码见: https://github.com/loopyme/ulan-uncompile

大家都在说木兰编译器是在水项目，但我感觉很多人啥也不知道跟着黑，你随机抽样几个网友出来很有可能都解释不清楚Parser和lexer．所以我找到时间，拆开木兰编译器看看源码,是好是坏拆开看.

（写在前面）结果是：我觉得：木兰编译器给python换了个前端，但至少不是我原来想的加了层贴纸(靠`eval`实现那种)，所以算是一个挺有趣的小项目，只是因为＇国产编译器＇名头太大了，再加上舆论，所以翻了车．但是要是我写出来这样一个项目(并且没有往项目里添加那些凑字数的文件的话)，我是会很自豪的，至少它比我脱裤子放屁的[`pymips`](https://github.com/CQU-AI/pymips)高到不知道哪里去了．

形象的说木兰编译器就是:有一群人找到个轮子,仔细读了读外胎的说明书,造了个外胎给轮子换上.内行觉得这外胎换了没啥意义,可能还没原来轮子好用,很多外行跟着起哄,以为木兰只是在原来的轮胎上贴了一层膜.






































































## 1. 反编译

易知，木兰编译器是用PyInstaller打包起来的python项目，于是反编译这个exe的思路就很清晰了

### 1.1 提取exe内容

用[pyinstxtractor](https://sourceforge.net/projects/pyinstallerextractor/)很容易就能提取PyInstaller生成的Windows可执行文件内容

```sh
python ./tools/pyinstxtractor.py ./ulang-0.2.2.exe
```

### 1.2 修补pyc文件

PyInstaller会把pyc文件的magic和时间戳吃掉，所以需要从struct文件里取前８个字节补回pyc文件前面.

```python
# ./tools/add_header.py
import os


with open("./ulang-0.2.2.exe_extracted/struct", "rb") as f:
    header = f.read()[:4]

for filename in os.listdir("./ulang-0.2.2.exe_extracted/PYZ-00.pyz_extracted"):
    if 'ulang' not in filename:
        continue
    
    with open("./ulang-0.2.2.exe_extracted/PYZ-00.pyz_extracted/" + filename, "rb") as f:
        data = f.read()

    with open("./pyc/" + filename, "wb") as f:
        f.write(header + data)
```

```sh
mkdir ./pyc/
python ./tools/add_header.py
```

### 1.3 反编译pyc文件

用[`uncompyle6`](https://github.com/rocky/python-uncompyle6)可以直接把pyc文件反编译了，至于下面的sh，我先`ls`一下，然后用熟练的列操作在`vs code`里粘出整齐的指令．

```　sh
mkdir ./ulang/
mkdir ./ulang/codegen/
mkdir ./ulang/parser/
mkdir ./ulang/runtime/

pip install uncompyle6

uncompyle6 ./pyc/ulang.codegen.blockly.pyc        > ./ulang/codegen/blockly.py
uncompyle6 ./pyc/ulang.codegen.pyc                > ./ulang/codegen/__init__.py
uncompyle6 ./pyc/ulang.codegen.python.pyc         > ./ulang/codegen/python.py
uncompyle6 ./pyc/ulang.codegen.ulgen.pyc          > ./ulang/codegen/ulgen.py
uncompyle6 ./pyc/ulang.parser.core.pyc            > ./ulang/parser/core.py
uncompyle6 ./pyc/ulang.parser.error.pyc           > ./ulang/parser/error.py
uncompyle6 ./pyc/ulang.parser.lexer.pyc           > ./ulang/parser/lexer.py
uncompyle6 ./pyc/ulang.parser.lrparser.pyc        > ./ulang/parser/lrparser.py
uncompyle6 ./pyc/ulang.parser.parsergenerator.pyc > ./ulang/parser/parsergenerator.py
uncompyle6 ./pyc/ulang.parser.pyc                 > ./ulang/parser/__init__.py
uncompyle6 ./pyc/ulang.pyc                        > ./ulang/__init__.py
uncompyle6 ./pyc/ulang.runtime.env.pyc            > ./ulang/runtime/env.py
uncompyle6 ./pyc/ulang.runtime.main.pyc           > ./ulang/runtime/main.py
uncompyle6 ./pyc/ulang.runtime.pyc                > ./ulang/runtime/__init__.py
uncompyle6 ./pyc/ulang.runtime.repl.pyc           > ./ulang/runtime/repl.py
```

然后再手动调整一下就大功告成了!

> 这样反编译出来代码实际是跑不起来的,debug发现是有些地方出了小问题,这并不影响我阅读源码的大致思路.

## 2. 源码分析
### 2.1 项目结构
```
.
├── __init__.py
├── main.py
├── CodeGen
│   ├── __init__.py
│   ├── blockly.py
│   ├── python.py*
│   └── ulgen.py
├── parser
│   ├── __init__.py
│   ├── core.py
│   ├── error.py
│   ├── lexer.py
│   ├── lrparser.py*
│   ├── parsergenerator.py*
└── runtime
    ├── __init__.py
    ├── env.py
    ├── main.py
    └── repl.py

*:是某个公开库的源文件副本
```

这个项目主要外部依赖于`ast`,`rply`,`codegen`.

### 2.2 ulang.parser

> `ulang.parser.core.Parser`注释: *A simple LR(1) parser to parse the source code of mu and yield the python ast for later using..*(
一个简单的LR(1)解析器，用于解析mu的源代码并生成python ast供后续使用。)

我查了查资料,猜测作者应该熟读了`rply`的文档,基于文档指导实现了Parser和Lexer,以下为具体分析:

#### 2.2.1 ulang.parser.lexer
`ulang.parser.lexer`选段:
``` python
lg.add('IDENTIFIER', '\\$?[_a-zA-Z][_a-zA-Z0-9]*')
lg.add('DOTDOTDOT', '\\.\\.\\.')
lg.add('DOTDOTLT', '\\.\\.<')
lg.add('DOTDOT', '\\.\\.')
lg.add('DOT', '\\.')
lg.add('DOLLAR', '\\$')
lg.add('[', '\\[')
lg.add(']', '\\]')
lg.add('(', '\\(')
```

**我猜测:** Lexer使用多次复制粘贴[`rply.LexerGenerator`](https://rply.readthedocs.io/en/latest/users-guide/lexers.html)教程示例代码的方式,加上了所有词法规则,实现了词法分析.

#### 2.2.2 ulang.parser.core
`ulang.parser.core`看起来比较硬核(毕竟是个`core`),充斥着大量函数,装饰器等,它基于`rply.parsergenerator`生成了一个Parser.

仔细读读rply文档,基本能够理解这个文件中的代码,整个文件思路很清晰,但是工作量比较大(和`ulang.parser.lexer`情况有点像).比如看似复杂冗长的装饰器,其实全部都是在用`rply.parsergenerator.production`来指定terminals (tokens) & non-terminals序列.

总的来说,我觉得作者在这一块应该付出了较大的精力.

#### 2.2.3 ulang.parser.lrparser 和 ulang.parser.parsergenerator
这俩就很微妙了.我读的时候感觉风格有点奇怪,专门去查了下,结果发现就是`rply.parser`和`rply.parsergenerator`的副本

我只能**猜测**为凑字数(也可能是作者环境配不对没办法import)

#### 2.2.4 ulang.parser.error
实现了一个`SyntaxError`,我认为中规中据.

### 2.3 ulang.CodeGen
> `ulang.CodeGen.blockly.CodeGen`注释: *A simple python ast to blockly xml converter.*(一个简单的python ast到blockly xml的转换器)

和`ulang.parser`代码风格感觉不一样.`ulang.CodeGen`下的文件分别实现了:
- `ulang.CodeGen.ulgen`: python ast -> ulang
- `ulang.CodeGen.blockly`: python ast -> blockly xml

而`ulang.CodeGen.python`则是[`codegen.codegen`](https://github.com/andreif/codegen/blob/master/codegen.py)的副本(换个人凑字数?)

总的来说,我觉得`ulang.CodeGen`比`ulang.parser`工作量差不多,但更有趣.

#### 2.3.1 ulang.CodeGen.ulgen
照着[`codegen.codegen`](https://github.com/andreif/codegen/blob/master/codegen.py)画瓢,再根据ulang的设想进行调整就能得到`ulang.CodeGen.ulgen`,其中工作量还是蛮大的.

#### 2.3.2 ulang.CodeGen.blockly
这个文件是要把python ast转换成blockly xml,大概就是visit树节点,并根据节点类型作相应的转化,挺有趣而且工作量也蛮大的.

### 2.4 ulang.runtime
这个模块里代码尤其糟糕,充分发扬了整个项目的大力出奇迹风格,不太好表述,直接节选代码了:

`ulang.runtime.repl`节选:
``` python
# 遍历检查括号匹配(说起来你可能不信,[(])是匹配的)
unclosed = []
unmatched = [0, 0, 0]
last = 2 * ['']
for tok in tokens:
    c = tok.gettokentype()
    last[0], last[1] = last[1], c
    if c in keywords:
        unclosed.append(c)
    if c == 'LBRACE':
        unmatched[0] += 1
    elif c == 'RBRACE':
        unmatched[0] -= 1
        if len(unclosed):
            unclosed.pop(-1)
    elif c == '(':
        unmatched[1] += 1
    elif c == ')':
        unmatched[1] -= 1
    elif c == '[':
        unmatched[2] += 1
    elif c == ']':
        unmatched[2] -= 1
unmatched_sum = sum(unmatched)
unclosed_sum = len(unclosed)
if unclosed_sum > 0:
    if unmatched_sum == 0:
        if last[1] == 'NEWLINE':
            if (last[0] == 'NEWLINE' or last[0]) == ';':
                pass
            return True
return unclosed_sum == 0 and unmatched_sum == 0
```

我感觉写成这样(对我来说)要快乐一些,还修了一个bug:
```python
SYMBOLS = {"}": "{", "]": "[", ")": "(", "RBRACE": "LBRACE"}

last = [""] * 2
unmatched = []
unclosed = []

for tok in tokens:
    c = tok.gettokentype()
    last[0], last[1] = last[1], c

    if c in keywords:
        unclosed.append(c)
    elif c == "RBRACE" and unclosed:
        unclosed.pop()
    
    if c in SYMBOLS.values(): # left/right symbol
        unmatched.append(c)
    elif c in SYMBOLS.keys() and unmatched.pop() != SYMBOLS[c]:
        return False

return (
    # NEWLINE
    unclosed
    and not unmatched
    and last[1] == "NEWLINE"
    and last[0] not in ["NEWLINE", ";"]
) or (
    # closed and matched
    not unclosed
    and not unmatched
)
```

`ulang.runtime.env`节选:
```python
# 自带的功能(我还把它排整齐了)
return {
    "print"             : local_print,
    "println"           : lambda *objs: local_print(*objs, **{"end":"\n"}),
    "assert"            : local_assert,
    "len"               : len,
    "enumerate"         : enumerate,
    "all"               : all,
    "any"               : any,
    "range"             : range,
    "round"             : round,
    "input"             : input,
    "reverse"           : reversed,
    "super"             : super,
    "locals"            : lambda: locals(),
    "bool"              : bool,
    "float"             : float,
    "int"               : int,
    "str"               : str,
    "list"              : list,
    "dict"              : dict,
    "set"               : set,
    "tuple"             : lambda *args: args,
    "char"              : chr,
    "ord"               : ord,
    "bytes"             : lambda s, encoding="ascii":bytes(s, encoding),
    "typeof"            : lambda x: x.__class__.__name__,
    "isa"               : lambda x, t: isinstance(x, t),
    "max"               : max,
    "min"               : min,
    "map"               : map,
    "filter"            : filter,
    "zip"               : zip,
    "staticmethod"      : staticmethod,
    "property"          : property,
    "ceil"              : math.ceil,
    "floor"             : math.floor,
    "fabs"              : math.fabs,
    "sqrt"              : math.sqrt,
    "log"               : math.log,
    "log10"             : math.log10,
    "exp"               : math.exp,
    "pow"               : math.pow,
    "sin"               : math.sin,
    "cos"               : math.cos,
    "tan"               : math.tan,
    "asin"              : math.asin,
    "acos"              : math.acos,
    "atan"              : math.atan,
    "spawn"             : builtin_spawn,
    "kill"              : builtin_kill,
    "self"              : builtin_self,
    "quit"              : sys.exit,
    "open"              : open,
    "install"           : pip_install,
    "time"              : time.time,
    "year"              : lambda: datetime.now().year,
    "month"             : lambda: datetime.now().month,
    "day"               : lambda: datetime.now().day,
    "hour"              : lambda: datetime.now().hour,
    "minute"            : lambda: datetime.now().minute,
    "second"            : lambda: datetime.now().second,
    "microsecond"       : lambda: datetime.now().microsecond,
    "sleep"             : time.sleep,
    "delay"             : lambda ms: time.sleep(ms / 1000),
    "delayMicroseconds" : lambda us: time.sleep(us / 1000000),
    "PI"                : math.pi,
    "ARGV"              : argv,
    "__builtins__"      : fix_builtins(
        {
            "__import__"      : local_import,
            "__build_class__" : __build_class__,
            "__name__"        : "__main__",
            "__file__"        : fname,
            "__print__"       : eval_print,
            "___"             : None,
            "__div__"         : __builtin_div,
            "__rem__"         : __builtin_rem,
        }
    ),
}
```

## 3.总结
**我觉得：**

木兰编译器按工作量可以算是一个'大型小项目',也有一定技术含量,很可能是几个同学(不超过三个)一起写的,并且具有浓厚的大力出奇迹的风格,这种风格在高校实验室代码里比较常见.代码质量和我小项目第一遍写出来差不多,应该是还没有整理重构过,全是查文档查资料跑通就行的那种.作者(团队)应该是熟读了`rply`和`codegen`的文档和教程,并修一修,补一补,写一写成了这个项目.

有一个比较大的问题是,打包了3个其他公开库的文件进去,强行改了名字没换内容.

总的来说,它是给python换了个前端，但至少不是我原来想的加了层贴纸(靠`eval`实现那种)，所以算是一个挺有趣的小项目，只是因为＇国产编译器＇名头太大了，再加上舆论，所以翻了车．但是要是我写出来这样一个项目(并且没有往项目里添加那些凑字数的文件的话)，我是会很自豪的，至少它比我脱裤子放屁的[`pymips`](https://github.com/CQU-AI/pymips)高到不知道哪里去了．

## 4.免责声明

本人不属于任何公司、集体。逆向工程时使用的所有参考信息均从网络公开资料中合法获得.逆向工程后的部分代码和逻辑完全靠猜想完成，具体代码与原木兰语言的实现没有任何关系，不代表原木兰项目功能和代码质量。本文的所有观点和分析都是个人的猜测,可能与真实状况有较大差异.
