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
