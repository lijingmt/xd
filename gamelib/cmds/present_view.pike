//�û��鿴�Լ��Ļ��ֺ����Ƽ��˵���Ϣ
#include <command.h>
#include <gamelib/include/gamelib.h>
#define log_file ROOT "/log/presenter.log"
int main(string arg)
{
	object me = this_player();
	string s = "�ҵ�ǰ�Ļ��֣�"+me->cur_mark+"\n";
	if(!arg){
		//s = "�ҵ�ǰ�Ļ��֣�"+me->cur_mark+"\n";
		s += "�����Ƽ��ĺ��ѣ�\n"+MUD_PRESENTD->query_my_men(me)+"\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		int load_flg = 0;
		object man = find_player(arg);
		if(!man){
			mixed err = catch{
				man = me->load_player(arg);
				load_flg = 1;
			};
			if(err || !man){
				s += "û�������ң���ȷ�Ϻ���������\n";
				s += "[����:look]\n";
				write(s);
				return 1;
			}
		}
		s += man->query_name_cn()+"\n�ȼ���"+man->query_level()+"\n��ǰ���֣�"+man->cur_mark+"\n";
		if(load_flg)
			man->remove();
		s += "[����:present_view]\n";
		write(s);
		return 1;
	}

}
