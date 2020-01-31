
source ../venv/bin/activate

rm -rf ./ulang

###############################################################################
echo '1. Extract exe'

python ./tools/pyinstxtractor.py ./ulang-0.2.2.exe


###############################################################################
echo '2. Add pyc magic-time header'

mkdir ./pyc/
python ./tools/add_header.py


###############################################################################
echo '3. Uncompyle'
mkdir ./ulang/
mkdir ./ulang/codegen/
mkdir ./ulang/parser/
mkdir ./ulang/runtime/

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


###############################################################################
echo '4. Clean'
rm -rf ./pyc
rm -rf ./ulang-0.2.2.exe_extracted
black ./py/ulang

echo 'Done'