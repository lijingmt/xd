#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEYAO_PATH ROOT "/gamelib/clone/item/teyao/"
//�г���ʯ�����ĳҩƷ�ľ�����Ϣ
//arg =   name       yushi_rareLevel    amount       type
//     ҩƷ�ļ���    ������ʯ��ϡ�ж�   ��ʯ�ĸ���  ҩƷ����

int main(string arg)
{
	object me = this_player();
	string teyao_name = "";
	int rarelevel = 0;
	int amount = 0;
	string type = "";
	int money = 0;//add by caijie 08/06/10
	int flag = 0;//add by caijie 08/06/10
	string s = "";
	sscanf(arg,"%s %d %d %s %d %d",teyao_name,rarelevel,amount,type,money,flag);//modify
	object teyao;
	mixed err = catch{
		teyao = clone(TEYAO_PATH+teyao_name);
	};
	if(!err && teyao){
		s += teyao->query_name_cn()+"��\n";
		s += teyao->query_picture_url()+"\n"+teyao->query_desc()+"\n";
		string need_namecn = YUSHID->get_yushi_namecn(rarelevel);
		int have_num = YUSHID->query_yushi_num(me,rarelevel);
		s += "--------\n";
		if(flag == 0){
			s += "��Ҫ��"+amount+"��"+need_namecn+"("+have_num+")\n";
			//s += "����Ŀǰӵ��"+need_namecn+"��"+have_num+"�飩\n";
			s += "�������(1-20)��\n[int no:...]\n";
			s += "[submit ȷ������:yushi_buy_teyao_confirm "+teyao_name+" "+rarelevel+" "+amount+" "+money+" 0 ...]\n";
		}
		else if(flag == 1){
			s += "��Ҫ��"+amount+"��"+need_namecn+","+money+"��("+have_num+")\n";
			s += "ÿ��ֻ����һ��,һ��ֻ�ܹ���"+teyao->query_short()+"\n";
			s += "[����:yushi_buy_teyao_confirm "+teyao_name+" "+rarelevel+" "+amount+" "+money+" 1 1]\n";
		}
	}
	else
		s += "�޷��鿴������ϵ���������ǽ�����Ϊ����\n";
	s += "[����:yushi_buy_teyao_list "+type+"]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
