module FixDocs;

import tango.io.FilePath;
import tango.io.FileSystem;
import tango.text.Util;
import tango.stdc.stdio;
import tango.stdc.stdlib;



void process(char[] entry, char[] dir, char[] prefix) {
	printf("entry = %.*s\n", entry);
	printf("dir = %.*s\n", dir);
	
	char[] command = `sed ` ~ entry
	~ ` -e "s/candydoc/` ~ prefix ~ `candydoc/1"`
	~ ` -e "s/___source___/` ~ prefix ~ `source` ~ dir.substitute(`.`, `\.`) ~ `\/` ~ entry ~ `/" > ` ~ entry ~ `.new`;
	printf("%.*s\n\n", command);
	system((command ~ \0).ptr);
	FilePath(entry).remove;
	FilePath(entry ~ `.new`).rename(entry);
}


void recurse(char[] prefix, char[] dir) {
	foreach (entry; FilePath(".").toList) {
		char[] entryStr = entry.file;

		if (entry.isFolder && entryStr != `.` && entryStr != `..`) {
			FileSystem.setDirectory(entryStr);
			recurse(`..\/` ~ prefix, dir ~ `\/` ~ entryStr);
			FileSystem.setDirectory(`..`);
		} else if (entry.ext == `html`) {
			process(entryStr, dir, prefix);
		}
	}
}


void main() {
	recurse("", "");
}
