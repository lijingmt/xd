#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,this_player(),count);
	if(ob){
		if(ob->read_flag==1){
			this_player()->pop_view();
			int tmp = 0;
			tmp = ob->read();
			switch(tmp){
				case 0:
					this_player()->write_view(WAP_VIEWD["/read_fail"],ob);
				break;
				case 1:
					this_player()->write_view(WAP_VIEWD["/read_success"],ob);
				break;
				case 2:
					this_player()->write_view(WAP_VIEWD["/read_repeat"],ob);
				break;
				case 3:
					this_player()->write_view(WAP_VIEWD["/read_profeLimit"],ob);
				break;
				case 4:
					this_player()->write_view(WAP_VIEWD["/read_levelLimit"],ob);
				break;
				case 5:
					this_player()->write_view(WAP_VIEWD["/read_Limitone"],ob);
				break;
				case 6:
					this_player()->write_view(WAP_VIEWD["/read_Limitnext"],ob);
				break;
				case 7:
					this_player()->write_view(WAP_VIEWD["/read_Limitmore"],ob);
				break;
				
				//针对锻造和炼丹
				case 8:
					this_player()->write_view(WAP_VIEWD["/read_Noskill"],ob);//不会技能
				break;
				case 9:
					this_player()->write_view(WAP_VIEWD["/read_Csvwrong"],ob);//csv导表出错
				break;
				case 10:
					this_player()->write_view(WAP_VIEWD["/read_Levlimit"],ob);//熟练度不够
				break;
				case 11:
					this_player()->write_view(WAP_VIEWD["/read_Learned"],ob);//已学过
				break;
			}
		}
		else if(ob&&ob->read_flag==0)
			this_player()->write_view(WAP_VIEWD["/read_nobook"],ob);
	}
	else
		this_player()->write_view(WAP_VIEWD["/read_notfound"]);
	return 1;
}
