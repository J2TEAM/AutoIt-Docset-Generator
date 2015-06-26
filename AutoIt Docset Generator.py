#!/usr/bin/env python
# Developed by Juno_okyo
# Website: http://junookyo.blogspot.com/
import os, sqlite3, distutils.file_util
from subprocess import call

BASE = os.getcwd()
CHM = '%s\AutoIt.chm' % BASE
dir_docset = '%s\AutoIt.docset\\' % BASE
dir_contents = '%sContents\\' % dir_docset
dir_resources = '%sResources\\' % dir_contents
dir_documents = '%sDocuments\\' % dir_resources
queries = 0

def main():
    if decompile_CHM():
        generate_database()
        add_require_files()
        print('\n> Done! Total queries: %s' % queries)

def decompile_CHM():
    if os.path.exists('%sindex.htm' % dir_documents):
        return True
    
    if not os.path.exists(CHM):
        print('Error: AutoIt.chm is not exists!')
        return False

    # Decompile CHM to HTML resources
    call('hh.exe -decompile %s %s' % (dir_resources, CHM), shell=True)

    # Remove junk files
    os.remove('%sAutoIt3 Index.hhk' % dir_resources)
    os.remove('%sAutoIt3 TOC.hhc' % dir_resources)

    # Rename "html" folder to "Documents"
    os.rename('%s\html\\' % dir_resources, dir_documents)
    return True

def generate_database():
    conn = sqlite3.connect('%sdocSet.dsidx' % dir_resources)
    c = conn.cursor()
    global queries

    # Prepare database
    c.execute("DROP TABLE IF EXISTS searchIndex;")
    c.execute("CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);")
    c.execute("CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);")
    queries += 3

    insert_index(c, 'guiref', 'Interface')
    insert_index(c, 'keywords', 'Keyword', 9)
    insert_index(c, 'macros', 'Macro', 19)
    insert_index(c, 'functions', 'Function', 10, True)
    insert_index(c, 'libfunctions', 'User Defined Function', 10, True)
    insert_index(c, 'intro', 'Instruction')
    insert_index(c, 'appendix', 'Section')

    # Manual queries
    c.execute("INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('My First Script (Hello World)', 'Guide', 'tutorials/helloworld/helloworld.htm');")
    c.execute("INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('Simple Notepad Automation', 'Guide', 'tutorials/notepad/notepad.htm');")
    c.execute("INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('WinZip Installation', 'Guide', 'tutorials/winzip/winzip.htm');")
    c.execute("INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('String Regular expression', 'Guide', 'tutorials/regexp/regexp.htm');")
    c.execute("INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('Simple Calculator GUI', 'Guide', 'tutorials/simplecalc-josbe/simplecalc.htm');")
    c.execute("INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('#pragma compile', 'Directive', 'directives/pragma-compile.htm');")
    queries += 6

    conn.commit()
    c.close()

def insert_index(db_cursor, folder, type, remove=0, skip=False):
    files = os.listdir('%s%s\\' % (dir_documents, folder))
    global queries

    for file in files:
        if skip and ' ' in file:
            continue
        
        path = '%s%s\%s' % (dir_documents, folder, file)
        name = get_title(path)
        if remove > 0:
            name = _strip(name, remove)
        
        db_cursor.execute("INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('%s', '%s', '%s/%s');" % (name, type, folder, file))
        queries += 1
        print('[%s] %s (%s/%s)' % (type, name, folder, file))

def add_require_files():
    distutils.file_util.copy_file('%s\icon.png' % BASE, '%sicon.png' % dir_docset)
    distutils.file_util.copy_file('%s\icon@2x.png' % BASE, '%sicon@2x.png' % dir_docset)
    print('\n> Added icon files.')

    distutils.file_util.copy_file('%s\Info.plist' % BASE, '%sInfo.plist' % dir_contents)
    print('\n> Added Info.plist files.')

def get_title(file):
    with open(file, 'r') as f:
        data = f.read(200) # 200 char (included <head>...</head>)
        f.close()
        return str_between(data, '<title>', '</title>')

def str_between(string, prefix, suffix):
    temp = string.split(prefix)
    temp = temp[1].split(suffix)
    temp = temp[0]
    return temp

def _strip(str, length):
    tmp = ''
    for i in range(int(length - 1), len(str)):
        tmp += str[i]
    return tmp.strip()

if __name__ == '__main__':
    main()
