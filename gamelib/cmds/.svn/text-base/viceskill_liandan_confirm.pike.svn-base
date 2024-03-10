#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = p_id 和炼丹的数量 
//此指令完成炼丹的最后阶段，即炼制出成品
int main(string arg)
{
	string s = "";
	object me=this_player();
	//int p_id = (int)arg;
	int p_id = 0;
	int num = 0;
	string s_num = "";
	sscanf(arg,"%d %s",p_id,s_num);
	sscanf(s_num,"no=%d",num);
	int can_make_num = LIANDAND->can_make_num(me,p_id);
	//删除身上复数物品的接口为remove_combine_item(string name,int count),在gamelib/clone/user.pike中
	if(num <= 0 || num > 20){
		s += "您输入的数量不正确，炼制数量必须大于0小于20\n";
		s += "\n[继续炼制:viceskill_liandan_pf normal]\n";       
        	s += "[返回游戏:look]\n";
	        write(s);
		 return 1;
	}
	if(sizeof(me->material_m) == 0)
		s += "你不能进行这样的操作！\n";
	else if(can_make_num == 0 || num > can_make_num)
		s += "你没有足够的材料！\n";
	else{
		//先获得炼丹物品的文件名
		string get_name = LIANDAND->query_liandan_item(p_id);
		object get_item = clone(ITEM_PATH+get_name);
		get_item->amount = num;
		if(get_item){
			if(me->if_over_load(get_item))
				s += "你随身物品已满，无法再存放更多的东西\n\n";
			else{
				//然后获得材料个数，从玩家身上删除所需要的材料
				mapping(string:array) tmp_m = LIANDAND->query_get_m(p_id);
				foreach(indices(tmp_m),string material_name){
					array tmp_arr = tmp_m[material_name];
					int m_num = tmp_arr[1]*num;//炼num个丹所需要的材料数量
					me->remove_combine_item(material_name,m_num);
				}
				string now=ctime(time());
				array(int) skill = me->vice_skills["liandan"];
				s += "炼制成功!\n";
				string s_file = file_name(get_item);
				s += "你获得了"+num+"颗["+get_item->query_name_cn()+":inv_other "+s_file+"]\n";
				//检查熟练度是否升级
				int flag = 0;//标志炼丹熟练度是否提高
				int now_lev = skill[0];
		    	    for(int i=0;i<num;i++){
				if(skill[0]<skill[2]){
					int update_need = (int)(skill[0]/5);
					skill[1]++;
					if(skill[1]>=update_need){
						skill[0] ++;
						skill[1] = 0;
						flag = 1;
					}
				}
			    }	
			    if(flag){
				s += "你的炼丹熟练度提高到了"+(skill[0])+"级\n";
			    }
				me->material_m = ([]);
				Stdio.append_file(ROOT+"/log/liandan.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+")：炼丹获得 "+num+"颗"+get_item->query_name_cn()+"\n");
				get_item->move_player(me->query_name());	
			}
		}
		else
			s += "炼制失败\n";
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[继续炼制:viceskill_liandan_pf normal]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
