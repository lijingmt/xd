#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name flag 
//      name 为目标玩家id
//      flag=0 只是察看；=1时要显示提升的信息；=2时要显示降级的信息；=3时要显示开除的信息
int main(string arg)
{
	object me = this_player();
	string s = "";
	string target_name = "";
	int flag = 0;
	int level = 0;
	sscanf(arg,"%s %d",target_name,flag);
	if(!me->bangid){
		s = "你未加入任何帮派\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">:";
		s += BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		level = BANGD->query_level(me->query_name(),me->bangid);
		s += BANGD->query_nums(me->bangid,"online")+"在线/"+BANGD->query_nums(me->bangid,"all")+"人\n";
		//提升
		if(flag == 1){
			int rmflag = 0;
			string target_namecn = "";
			object target = find_player(target_name);
			if(target)
				target_namecn = target->query_name_cn();
			else{
				target = me->load_player(target_name);
				if(target){
					target_namecn = target->query_name_cn();
					rmflag = 1;
				}
			}
			int update = BANGD->update_level(me,target_name,me->bangid);
			//update_level()的返回值=0:不能再提升对方等级
			//                      =1:提升成功
			//                      =2:没有被提升的成员
			//                      =3:帮派有些问题
			if(update == 0)
				tell_object(me,"你已不能再提升对方等级\n");
			else if(update == 1){
				string tell_s = me->query_name_cn()+"将"+target_namecn+"提升为了"+BANGD->query_level_cn(target_name,me->bangid)+"\n";
				BANGD->bang_notice(me->bangid,tell_s);
			}
			else if(update == 2){
				tell_object(me,"对方已经不在帮派里了\n");
				if(target->bangid == me->bangid)
					target->bangid = 0;
			}
			else if(update == 3){
				tell_object(me,"请确保你所在的帮派还存在\n");
				me->bangid=0;	
				target->bangid=0;
			}
			if(rmflag)
				target->remove();
		}
		//降级
		else if(flag == 2){
			int rmflag = 0;
			string target_namecn = "";
			object target = find_player(target_name);
			if(target)
				target_namecn = target->query_name_cn();
			else{
				target = me->load_player(target_name);
				if(target){
					target_namecn = target->query_name_cn();
					rmflag = 1;
				}
			}
			int down = BANGD->down_level(me,target_name,me->bangid);
			//down_level()的返回值  =0:已不能再降低对方等级
			//                      =1:降级成功
			//                      =2:没有被降级的成员
			//                      =3:帮派有些问题
			if(down == 0)
				tell_object(me,"权限不够，你不能降低对方等级\n");
			else if(down == 1){
				string tell_s = me->query_name_cn()+"将"+target_namecn+"降级为了"+BANGD->query_level_cn(target_name,me->bangid)+"\n";
				BANGD->bang_notice(me->bangid,tell_s);
			}
			else if(down == 2){
				tell_object(me,"对方已经不在帮派里了\n");
				if(target->bangid == me->bangid)
					target->bangid = 0;
			}
			else if(down == 3){
				tell_object(me,"请确保你所在的帮派还存在\n");
				me->bangid=0;	
				target->bangid=0;
			}
			if(rmflag)
				target->remove();
		}
		//开除
		else if(flag == 3){
			string target_namecn = "";
			object target = find_player(target_name);
			int removeflag = 0;
			if(target)
				target_namecn = target->query_name_cn();
			else{
				target = me->load_player(target_name);
				if(target){
					target_namecn = target->query_name_cn();
					removeflag = 1;
				}
			}
			int fire = BANGD->fire_member(me,target_name,me->bangid);
			//fire_member()的返回值 =0:权限不够，无法开除
			//                      =1:成功开除
			//                      =2:没有这个成员
			//                      =3:帮派有些问题
			if(fire == 0)
				tell_object(me,"权限不够，你不能开除对方\n");
			else if(fire == 1){
				string tell_s = me->query_name_cn()+"将"+target_namecn+"开除出了帮派\n";
				tell_object(target,"你被开除出了帮派\n");
				target->bangid = 0;
				BANGD->bang_notice(me->bangid,tell_s);
			}
			else if(fire == 2){
				tell_object(me,"对方已经不在帮派里了\n");
				if(target->bangid == me->bangid)
					target->bangid = 0;
			}
			else if(fire == 3){
				tell_object(me,"请确保你所在的帮派还存在\n");
				me->bangid=0;	
				target->bangid=0;
			}
			if(removeflag)
				target->remove();
		}
		s += BANGD->query_bang_members(me,me->bangid,level)+"\n"; 
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "[返回:my_bang]\n";
	//s += "[返回游戏:look]\n";
	//write(s);
	return 1;
}
