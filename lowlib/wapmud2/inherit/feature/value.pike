#include <globals.h>
#include <wapmud2/include/wapmud2.h>
string view_value(void|int n){
	if(n==0)
		return MUD_CHINESED->money[this_object()->value*this_object()->amount];
	else 
		return MUD_CHINESED->money[n];
}
