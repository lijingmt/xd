#include <globals.h>
#define in_edit(x) 0
#define in_input(x) 0

int main(string arg)
{
	//if(this_object()->query_name()!="zhubin"||this_object()->query_name()!="wangyan")
	//	return 1;
	string n=0;
	//if(arg)
	//	sscanf(arg,"%d",n);
	array(object) list;
	int j;
	int shownum=0;
	printf("total online num:"+sizeof(users())+"\n");
	printf("%-25s idle\n", "name");
	printf("--------------------      ----\n");
	for (list = users(), j = 0; j < sizeof(list); j++) {
		mixed idle=list[j]["query_idle"]?
			(list[j]->query_idle() / 60)
			:"unknown";
		if(n==0||stringp(idle)||idle<n){
			shownum++;
			printf("%-25s %4d\n", (string)list[j]->query_name()+":"+(string)list[j]->query_name_cn(),idle);
		}
	}
	printf("list num:"+shownum+"\n");
	return 1;
}
