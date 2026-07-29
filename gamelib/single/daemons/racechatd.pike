#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

// 仙、妖仍使用各自频道；中立方士同时连接两边频道。
array(object) query_chat_daemons(string race_id)
{
	if(race_id=="human")
		return ({CHATROOMD});
	if(race_id=="monst")
		return ({CHATROOM2D});
	if(race_id=="third")
		return ({CHATROOMD,CHATROOM2D});
	return ({});
}

string query_chatroom_list(string race_id)
{
	if(!sizeof(query_chat_daemons(race_id)))
		return "暂无聊天频道开放。\n";
	// 两个阵营读取同一份频道配置，列表只显示一次。
	return CHATROOMD->query_chatroom_list();
}

string query_chat_msg(string race_id,string chat_id,string look_id)
{
	array(object) daemons = query_chat_daemons(race_id);
	string result = "";

	for(int i=0;i<sizeof(daemons);i++){
		if(race_id=="third")
			result += i==0 ? "【仙界消息】\n" : "【妖界消息】\n";
		result += daemons[i]->query_chat_msg(chat_id,look_id);
	}
	return result;
}

string query_chatroom_msg(string race_id,string chat_id,string look_id)
{
	array(object) daemons = query_chat_daemons(race_id);
	string result = "";

	for(int i=0;i<sizeof(daemons);i++)
		result += daemons[i]->query_chatroom_msg(chat_id,look_id);
	return result;
}

int add_chat_msg(string race_id,string chat_id,string message)
{
	array(object) daemons = query_chat_daemons(race_id);
	int success = sizeof(daemons)>0;

	foreach(daemons,object daemon){
		if(!daemon->add_chat_msg(chat_id,message))
			success = 0;
	}
	return success;
}

protected void create()
{
}
