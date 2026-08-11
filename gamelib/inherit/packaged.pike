#include <globals.h>
#include <gamelib/include/gamelib.h>
#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))
//一开始免费10个位置
//每增加10个位置100g,总共能买9次，放置100个物品
mapping packaged_goods =([]);
array packaged_items =({});
string state_packaged(int user_p_level)
{
	string result = "";
	int a;
	if(packaged_items==0)
		packaged_items = ({});
	if(sizeof(packaged_items))
		a = sizeof(packaged_items);
	else
		a = 0;
	result += "("+a+"/"+user_p_level+")";
	return result;
}
int packaged(object ob, int user_p_level){
	if(packaged_items==0)
		packaged_items = ({});
	if(sizeof(packaged_items)>=user_p_level)
		return 1;
	//复数物品的判断
	string filename_all = (file_name(ob)/"#")[0];
	string tmp = "";
	string filename = "";
	sscanf(filename_all,"%s/item/%s",tmp,filename);
	if(ob->is("combine_item")){
		if(sizeof(packaged_items)==0)
			//packaged_items=({({ob->query_name(),ob->query_name_cn(),ob->query_short(),(file_name(ob)/"#")[0],0,0,ob->amount})});
			packaged_items=({({ob->query_name(),ob->query_name_cn(),ob->query_short(),filename,0,0,ob->amount})});
		else
			packaged_items+=({({ob->query_name(),ob->query_name_cn(),ob->query_short(),filename,0,0,ob->amount})});
	}
	else{
		int convert_count = 0;
		if(ob->is("equip"))
			convert_count = ob->query_convert_count();
		if(ob->item_dura){
			if(sizeof(packaged_items)==0)
				packaged_items=({({ob->query_name(),ob->query_name_cn(),ob->query_short(),filename,ob->item_cur_dura,ob->item_dura,convert_count})});
			else
				packaged_items+=({({ob->query_name(),ob->query_name_cn(),ob->query_short(),filename,ob->item_cur_dura,ob->item_dura,convert_count})});
		}
		else{
			if(sizeof(packaged_items)==0)
				packaged_items=({({ob->query_name(),ob->query_name_cn(),ob->query_short(),filename,0,0,convert_count})});
			else
				packaged_items+=({({ob->query_name(),ob->query_name_cn(),ob->query_short(),filename,0,0,convert_count})});
		}
	}
	//加入存入仓库的Log
	string now=ctime(time());
	ASYNC_IOD->append_log(ROOT+"/log/package.log",
		now[0..sizeof(now)-2]+":"+this_object()->query_name_cn()+
		"("+this_object()->query_name()+"):"+ob->name_cn+
		"("+ob->name+")被存入\n");
	return 0;
}
string view_packaged_list(){
	string out="";
	if(packaged_items==0)
		packaged_items = ({});
	if(packaged_items&&sizeof(packaged_items)){
		foreach(packaged_items,array s){
			if(!s) continue;
			out+="["+s[2];
			out+=":user_repackage "+s[0]+"]\n";
		}
		if(out=="")
			out="当前没有存储任何物品。";
	}
	else
		out="当前没有存储任何物品。";
	return out;
}
object repackaged(string name){
	if(packaged_items==0)
		packaged_items = ({});
	for(int i=0;i<sizeof(packaged_items);i++){
		if(!packaged_items[i]) continue;
		if(packaged_items[i][0]==name){//有该物品
			string returnString = packaged_items[i][3];
			array(string) tmp = returnString/"item/";
			if(tmp && sizeof(tmp)==2){
				returnString = tmp[1];
			}
			object ob;
			mixed err=catch{
				ob=new (ITEM_PATH+returnString);
			};
			if(!err && ob){
				//取出复数物品
				if(ob->is("combine_item"))
					ob->amount = (int)packaged_items[i][6];
				else{
					if(ob->item_dura){
						ob->item_cur_dura = (int)packaged_items[i][4];	
						ob->item_dura = (int)packaged_items[i][5];
					}
					if(ob->is("equip")){
						int convert_count = 0;
						// 账号共享仓库会在第8列追加永久物品ID；旧取出流程
						// 仍必须保留第7列的装备转换次数。
						if(sizeof(packaged_items[i])>=7)
							convert_count = (int)packaged_items[i][6];
						ob->set_convert_count(convert_count);
					}
				}
				packaged_items[i]=packaged_items[0];
				packaged_items = packaged_items[1..sizeof(packaged_items)-1];
				//加入取出仓库的Log
				string now=ctime(time());
				ASYNC_IOD->append_log(ROOT+"/log/package.log",
					now[0..sizeof(now)-2]+":"+
					this_object()->query_name_cn()+"("+
					this_object()->query_name()+"):"+ob->name_cn+
					"("+ob->name+")被取出\n");
				return ob;
			}
			else{
				string s_tmp = "";
				tell_object(this_object(),s_tmp);
				return 0;
			}
		}
	}
	return 0;
}

object repackaged_by_storage_id(string item_id)
{
	if(!item_id || sizeof(item_id)!=64 || !arrayp(packaged_items))
		return 0;
	for(int i=0;i<sizeof(packaged_items);i++){
		if(!arrayp(packaged_items[i]) || sizeof(packaged_items[i])<8 ||
		   (string)packaged_items[i][7]!=item_id)
			continue;
		string item_name = (string)packaged_items[i][0];
		if(i>0){
			array selected = packaged_items[i];
			packaged_items[i] = packaged_items[0];
			packaged_items[0] = selected;
		}
		return repackaged(item_name);
	}
	return 0;
}
