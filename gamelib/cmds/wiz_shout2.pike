/**
 * �����û�Ⱥ����Ϣ
 * @author oliver
 * @version $Revision: 1.2 $ $Date: 2003/10/13 07:58:08 $
 */

#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s="";
	if(!arg)
	{		
		s+="������ϵͳ��Ϣ:\n";
		s+="[string:wiz_shout2 ...]\n";
		s+="[����:game_deal]\n";
		write("%s",s);
		return 1;

	}
	if(search(arg," ")!=-1) {
		array(string) t=arg/" ";
		if(sizeof(t)==2&&t[0]==t[1]){
			arg=t[0];
		}
	} 
	string msg=arg;
	array(object) list;
	int j=0;
	//if( this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan" )	
	//	return 1;
	for (list = users(),j = 0; j < sizeof(list); j++) {
		tell_object(list[j],"ϵͳ�㲥��"+msg+"\n");
		write("send to "+list[j]->query_name_cn()+"("+list[j]->query_name()+")\n");
	}
	write("������ϡ�\n");
	s="[����:game_deal]\n";
	write("%s",s);
	return 1;
}
