#include <command.h>
#include <gamelib/include/gamelib.h>

#define STORAGE_PAGE_SIZE 8

string account_storage_batch_token(string mode,int revision,
	array(string) item_ids)
{
	object hash = Crypto.SHA256();
	hash->update(mode+"|"+revision+"|"+(item_ids*"|"));
	return String.string2hex(hash->digest());
}

int main(string|zero arg)
{
	object me = this_player();
	string mode = "";
	string expected_token = "";
	string failure_reason = "";
	string s = "";
	int page = 0;
	int max_page = 0;
	int start_index = 0;
	int end_index = -1;
	int moved = 0;
	int failed = 0;
	int pending = 0;
	array source_items = ({});
	array(string) item_ids = ({});
	mapping snapshot;

	if(!arg || sscanf(arg,"%s %d %s",mode,page,expected_token)!=3 ||
	   sizeof(expected_token)!=64 ||
	   (mode!="put" && mode!="take") || page<0){
		s = "批量操作参数已过期，请刷新仓库页面后重试。\n";
	}
	else{
		snapshot = ACCOUNT_STORAGED->query_storage(me);
		if(!snapshot["ok"])
			s = (string)(snapshot["message"] ||
				"账号共享仓库暂不可用。")+"\n";
		else{
			source_items = mode=="put" ?
				(array)snapshot["personal_items"] :
				(array)snapshot["items"];
			if(sizeof(source_items))
				max_page = (sizeof(source_items)-1)/STORAGE_PAGE_SIZE;
			if(page>max_page)
				page = max_page;
			start_index = page*STORAGE_PAGE_SIZE;
			end_index = start_index+STORAGE_PAGE_SIZE-1;
			if(end_index>=sizeof(source_items))
				end_index = sizeof(source_items)-1;
			for(int i=start_index;i<=end_index;i++){
				if(mode=="put"){
					if(arrayp(source_items[i]) &&
					   sizeof(source_items[i])>=8)
						item_ids += ({(string)source_items[i][7]});
				}
				else if(mappingp(source_items[i]) &&
				        source_items[i]["id"])
					item_ids += ({(string)source_items[i]["id"]});
			}
			if(!sizeof(item_ids))
				s = "本页已经没有可批量转移的物品。\n";
			else if(expected_token!=account_storage_batch_token(mode,
			         (int)snapshot["revision"],item_ids))
				s = "仓库内容已经变化，本次重复或过期操作已拦截，请重新选择。\n";
			else{
				foreach(item_ids,string item_id){
					mapping result = mode=="put" ?
						ACCOUNT_STORAGED->transfer_to_shared(me,item_id) :
						ACCOUNT_STORAGED->transfer_to_personal(me,item_id);
					if(result["ok"])
						moved++;
					else if(result["pending"])
						pending++;
					else{
						failed++;
						if(failure_reason=="")
							failure_reason = (string)(result["message"] ||
								"物品转移失败。");
					}
				}
				s = "本页批量"+(mode=="put" ? "放入" : "取回")+
					"完成：成功"+moved+"件";
				if(pending)
					s += "，待系统确认"+pending+"件";
				if(failed)
					s += "，未转移"+failed+"件（"+failure_reason+"）";
				s += "。\n";
			}
		}
	}
	tell_object(me,s);
	me->command("account_storage "+
		(mode=="take" ? "take" : "put")+" "+page);
	return 1;
}
