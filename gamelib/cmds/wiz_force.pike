/* wiz_force.pike
 * @author hps
 * ָ���ʽ wiz_force <ĳ��> to <ָ��>\n");
 * ǿ��ĳ��player����npcִ��ָ��
 */
#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object ob,me=this_player();
	string name,cmd,objname;
	int count=0;
	//if( this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan" )	
	//	return 1;
	if(!arg || sscanf(arg,"%s to %s",name,cmd)!=2){
		write("ָ���ʽ: force <ĳ��> to <ָ��>\n");
		return 1;
	}
	objname = name;
    sscanf(name,"%s %d",objname,count);
	ob = find_player(objname);
	if(!ob){
		write("�Ҳ���%s.\n",objname);
		return 1;
	}
	if(!living(ob)){
		write("����������ִ������.\n");
		return 1;
	}
	command(cmd,ob);
	return 1;
}
