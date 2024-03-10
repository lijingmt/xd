#include <globals.h>

int main(string file)
{
	if(file&&sizeof(file)>1&&file[0]=='~'&&file[1]=='/'){
		file=ROOT+file[1..];
	}
    object obj;

    if (!file) {
#ifndef __NO_ADD_ACTION__
	return notify_fail("update what?\n");
#else
	write("update what?\n");
	return 1;
#endif
    }
    if (obj = find_object(file)) {
	    destruct(obj);
    }
    if(file_stat(file)&&compile_file(file))
	    update(file);
    else if(file_stat(file+".pike")&&compile_file(file+".pike"))
	    update(file);

    load_object(file);
    return 1;
}
