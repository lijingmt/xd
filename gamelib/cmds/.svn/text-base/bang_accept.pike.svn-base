#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = apply_name   flag    index
//      申请者id    1：通过  在入帮申请列表中的位置,为数组下标+1
//                  0：拒绝

int main(string arg)
{
	object me = this_player();
	int bangid = me->bangid;
	int rmflag = 0;
	string s = "";
	string content = "";
	string apply_name = "";
	int flag = 0;
	int index;
	sscanf(arg,"%s %d %d",apply_name,flag,index);
	object applyer = find_player(apply_name);
	if(!applyer){
		applyer = me->load_player(apply_name);
		rmflag = 1;
	}
	if(applyer->bangid != 0){
		s += "对方已有帮派\n";
		if(BANGD->if_in_apply(applyer,index-1,me->bangid))
			BANGD->rmove_bang_apply(me->bangid,index-1);
	}
	else{
		string bang_name = BANGD->query_bang_name(bangid);
		if(flag){
			if(BANGD->if_in_apply(applyer,index-1,me->bangid)){
				BANGD->rmove_bang_apply(me->bangid,index-1);
				int be = BANGD->add_new_member(apply_name,bangid);
				if(be){
					applyer->bangid=bangid;
					BANGD->bang_notice(bangid,applyer->query_name_cn()+"加入了帮派\n");
					s += "你通过了对方的申请\n";
					content = me->query_name_cn()+"通过了你的申请，你加入了<"+bang_name+">\n";
					applyer->recieve_mail(me->query_name(),me->query_name_cn(),applyer->query_name(),applyer->query_name_cn(),"入帮申请回复",content);
					tell_object(applyer,"你有新的信件，请即时查收\n");
				}
				else
					s += "通过申请失败\n";
			}
			else
				s += "此申请已被处理\n";
		}
		else{
			if(BANGD->if_in_apply(applyer,index-1,me->bangid)){
				BANGD->rmove_bang_apply(me->bangid,index-1);
				s += "你拒绝了对方的申请\n";
				content = me->query_name_cn()+"拒绝了你加入<"+bang_name+">的申请。\n";
				applyer->recieve_mail(me->query_name(),me->query_name_cn(),applyer->query_name(),applyer->query_name_cn(),"入帮申请回复",content);
				tell_object(applyer,"你有新的信件，请即时查收\n");
			}
			else
				s += "此申请已被处理\n";
		}
	}
	if(rmflag)
		applyer->remove();
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "[返回:bang_view_apply]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
