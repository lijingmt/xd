#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令列出玩家身上可供属性转换的装备列表
int main(string arg)
{
	object me = this_player();
	string s = "";
	string s_log = "";
	string item_name = "";
	string baoshi_name = "";
	int id = 0;//原来宝石镶嵌的位置
	int flag = 0;
	int count = 0;
	sscanf(arg,"%s %s %d %d %d",item_name,baoshi_name,count,id,flag);
	if(flag==0){
		s += "您的操作将会摧毁原来凹槽的宝石, 并镶嵌新的宝石,您确定要镶嵌么?\n";
		s += "[注意]2009年2月24日前黄水玉系列宝石不会被摧毁\n";
		s += "[确定:equip_xiangqian_change "+item_name+" "+baoshi_name+" "+count+" "+id+" 1]\n";
		s += "[我再想想:look]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(flag==1){
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
		//有宝石也有装备,
		string color = baoshi->query_color();//获得宝石颜色
		string color_cn = baoshi->query_color_cn();//获得宝石颜色（中文描述）
		string baoshi_name_cn = baoshi->query_name_cn();
		string item_name_cn = item->query_name_cn();
		//werror("----id="+id+"----\n");
		string old_bsh_nm = item->query_baoshi_by_id(color,id);//要替换的宝石的名字
		if(old_bsh_nm!=""){
			object old_baoshi;
			string s_log;
			mixed err=catch{
				old_baoshi=clone(ITEM_PATH+old_bsh_nm);
			};
			if(!err&&old_baoshi){
				string old_baoshi_name = old_baoshi->query_short();
				if(old_baoshi->query_name()=="pshuangshuiyu"||old_baoshi->query_name()=="slhuangshuiyu"||old_baoshi->query_name()=="jinghuangshuiyu"||old_baoshi->query_name()=="nianshoulingshi"||old_baoshi->query_name()=="nianshoulingshi2"||old_baoshi->query_name()=="nianshoulingshi3"){
					s += old_baoshi->query_short()+"已放到您的背包中\n";
					old_baoshi->move_player(me->query_name());
				}
				item->set_baoshi(color,baoshi,id+1);//在装备上添加宝石字段,替换宝石的位置从1开始，因为id=0或空时表示直接镶嵌宝石而不是替换
				me->remove_combine_item(baoshi->query_name(),1);//扣除宝石
				s += "您在"+item_name_cn+"上成功镶嵌了"+baoshi_name_cn+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+")用"+baoshi_name_cn+"替换"+old_baoshi_name+"\n";
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/xiangqian_change.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
		}
		else{
			s += "系统累了，请与客服联系\n";
			string s_log = me->query_name_cn()+"("+me->query_name()+")用"+baoshi_name_cn+"替换错误\n";
			string now=ctime(time());
			Stdio.append_file(ROOT+"/log/xiangqian_change_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		}
	}
	s += "[返回:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
