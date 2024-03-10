#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	string item_name = "";
	string baoshi_name = "";
	int flag = 0;
	int count = 0;
	string s_log = "";
	sscanf(arg,"%s %d %d %s",item_name,count,flag,baoshi_name);
	object baoshi = present(baoshi_name,me,0);
	object item = present(item_name,me,count);
	//没有相对应的宝石
	if(!baoshi){
		s += "您没有这样的宝石，请返回\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	//没有装备
	if(!item){
		s += "您选择要镶嵌宝石的物品不存在，请返回\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	int xq_flag = 1;
	//有宝石也有装备,
	string color = baoshi->query_color();//获得宝石颜色
	string color_cn = baoshi->query_color_cn(color);//获得宝石颜色（中文描述）
	//werror("--------name="+baoshi->query_name()+"--color="+color+"--color_cn="+color_cn+"-\n");
	string baoshi_name_cn = baoshi->query_name_cn();
	string item_name_cn = item->query_name_cn();
	if(baoshi_name=="pshuangshuiyu"||baoshi_name=="slhuangshuiyu"||baoshi_name=="jinghuangshuiyu"){
		int shuiyu_num = me->query_baoshi_xiangqian_num("pshuangshuiyu",0)+me->query_baoshi_xiangqian_num("slhuangshuiyu",0)+me->query_baoshi_xiangqian_num("jinghuangshuiyu",0);
		if(shuiyu_num>=4){
			s += "每个玩家最多只能镶嵌4颗黄水玉（包括闪亮黄水玉、朴素黄水玉和【晶】黄水玉）\n";
			xq_flag = 0;
		}
	}
	if(!xq_flag){
		s += "[返回:equip_xiangqian_list]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(flag==0){
		//列出要镶嵌的宝石的相关信息
		
		s += baoshi_name_cn+"\n";
		s += baoshi->query_picture_url()+"\n";
		s += "对应"+color_cn+"插槽\n";
		s += baoshi->query_desc()+"\n";
		s += "\n";
		s += "[镶嵌:equip_xiangqian_confirm "+item_name+" "+count+" 1 "+baoshi_name+"]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else if(flag==1){
		//没有相对应的凹槽
		if(!item->query_if_aocao(color)){
			s += baoshi_name_cn+"为"+color_cn+"宝石,必须有"+color_cn+"凹槽才能镶嵌，请返回\n";
		}
		//有相对应的凹槽
		else{
			int num = item->query_aocao(color);//获得该物品含有空闲的color指定的颜色凹槽的数量
			//全部凹槽已经镶嵌了宝石
			if(!num||num<1){
				array(object) all_baoshi = item->query_baoshi(color);
				if(all_baoshi&&sizeof(all_baoshi)){
					for(int i=0;i<sizeof(all_baoshi);i++){
						s += all_baoshi[i]->query_name_cn()+"("+(all_baoshi[i]->query_desc()-"\n")+") [替换:equip_xiangqian_change "+item_name+" "+baoshi_name+" "+count+" "+i+" 0]\n";
					}
				}
				me->write_view(WAP_VIEWD["/emote"],0,0,s);
				return 1;
			}
			//有空闲的凹槽
			//string baoshi_path = file_name(baoshi)-ITEM_PATH;
			//baoshi_path = (baoshi_path/"#")[0];//获得宝石的文件路径，如baoshi/pshongchuoshi
			item->set_baoshi(color,baoshi);//在装备上添加宝石字段
			item->set_aocao(color,num-1);//改装备减少一个相对应颜色的凹槽
			me->remove_combine_item(baoshi->query_name(),1);//扣除宝石
			s += "您在"+item_name_cn+"上成功镶嵌了"+baoshi_name_cn+"\n";
		}
	}
	s += "[返回:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
