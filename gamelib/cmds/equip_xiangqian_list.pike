#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	string s_tmp = "";
	array(object) all_ob = all_inventory(me);
	array(object) temp = ({});
	mapping(string:int) name_count = ([]);
	//int i = 0;
	foreach(all_ob,object ob_tmp){
		//werror("-----------name="+ob_tmp->query_name()+"--aocao="+ob_tmp->query_if_aocao("all")+"\n");
		if(!ob_tmp["equiped"]&&ob_tmp->query_if_aocao("all")){
			s_tmp += "["+ob_tmp->query_name_cn()+":equip_xiangqian_detail "+ob_tmp->query_name()+" "+name_count[ob_tmp->query_name()]+" 0]\n";
			name_count[ob_tmp->query_name()]++;
		}
	}
	if(s_tmp!=""){
		s += "��ѡ����Ҫ��Ƕ��ʯ��װ��:\n";
		s += "--------\n";
		s += s_tmp;
	}
	else{
		s += "ֻҪ�а��۵�װ��������Ƕ��ʯ����������û��������װ��\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
