#include <command.h>
#include <gamelib/include/gamelib.h>
//ȷ����ȡĳ�ֱ�ʯ

int main(string arg)
{
	object me = this_player();
	string goods_path= "";
	int lv = 0;
	string re = "";
	string s_log = "";
	sscanf(arg,"%s %d",goods_path,lv);
	array(string) tmp = ({});
	string type = "baoshi";                        //Ĭ�ϵ���Ʒ����
	tmp = goods_path/"/";                          //�õ��ļ�����Ŀ¼��Ҳ������Ʒ�ķ���
	if(tmp)                                  
	{
		type=tmp[0];
	}
	object goods = clone(ITEM_PATH+goods_path);
	string goods_name = goods->query_name();
	goods->set_toVip(1);	
	string goods_namecn = goods->query_name_cn();
	int result = VIPD->if_can_get_freely(me,goods,lv);//�жϸ�����Ƿ��ܻ�ø���Ʒ
	if(result ==4)//���Ի����Ʒ
	{
		goods->move_player(me->query_name());
		string s_log = me->query_name_cn()+"("+me->query_name()+")��������Ʒ"+goods_namecn+"("+goods_name+")\n";
		Stdio.append_file(ROOT+"/log/get_vip_free_item.log",MUD_TIMESD->get_mysql_timedesc()+":"+s_log);
	}
	re += VIPD->if_can_get_freely_desc(result,lv,goods_namecn);

	re += "[������ȡ:vip_myzone_free_list "+ type +" "+ lv +"]\n";
	re += "[������Ϸ:look]\n";
	write(re);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
