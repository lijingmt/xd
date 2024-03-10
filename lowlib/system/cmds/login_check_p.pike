#include <globals.h>
int main(string arg)
{
	string user_name,user_area;
	if(arg&&(sscanf(arg,"%s %s",user_name,user_area)==2)){
		string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		if(!user){
			write("noaccount");
			return 1;
		}
		else{
			write("yes");
			return 1;
		}
	}
	return 1;
}
