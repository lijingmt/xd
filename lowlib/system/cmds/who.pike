#include <globals.h>
#define in_edit(x) 0
#define in_input(x) 0

int main(string arg)
{
	werror("===== who command called =====\n");
	//if(this_object()->query_name()!="zhubin"||this_object()->query_name()!="wangyan")
	//	return 1;
	string|zero n=0;
	//if(arg)
	//	sscanf(arg,"%d",n);
	array(object) list;
	array(object) visible_list = ({});
	object viewer = this_player();
	object logical_zoned = (object)(ROOT+
		"/gamelib/single/daemons/logical_zoned.pike");
	int j;
	int shownum=0;
	list = users();
	for(j=0;j<sizeof(list);j++)
		if(!viewer || !logical_zoned ||
		   logical_zoned->can_interact(viewer,list[j]))
			visible_list += ({list[j]});
	list = visible_list;
	printf("total online num:"+sizeof(list)+"\n");
	printf("%-25s idle\n", "name");
	printf("--------------------      ----\n");
	for (j = 0; j < sizeof(list); j++) {
		mixed idle=list[j]["query_idle"]?
			(list[j]->query_idle() / 60)
			:"unknown";
		if(!n||stringp(idle)||idle<n){
			shownum++;
			printf("%-25s %4d\n", (string)list[j]->query_name()+":"+(string)list[j]->query_name_cn(),idle);
		}
	}
	printf("list num:"+shownum+"\n");
	return 1;
}
