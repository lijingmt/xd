#include <command.h>
#include <gamelib/include/gamelib.h>
// 公告中心：历史公告全部可反复查看。数据在 gamelib/etc/notices.json
// （新版在前）。入口：游戏右上角菜单、登录首页【全部公告】。

private array(mapping(string:mixed)) load_notices()
{
	string raw;
	mapping data;
	array list;
	raw="";
	mixed err=catch{ raw=Stdio.read_file(ROOT+"/gamelib/etc/notices.json") || ""; };
	if(err || raw=="")
		return ({});
	err=catch{ data=Standards.JSON.decode(raw); };
	if(err || !mappingp(data) || !arrayp(data["notices"]))
		return ({});
	list=({});
	foreach(data["notices"],mixed entry){
		if(mappingp(entry) && stringp(entry["date"]) &&
		   stringp(entry["title"]) && arrayp(entry["body"]))
			list+=({entry});
	}
	return list;
}

int main(string|zero arg)
{
	object me=this_player();
	array(mapping(string:mixed)) list;
	int idx=0;
	if(!me)
		return 1;
	list=load_notices();
	if(!sizeof(list)){
		write("暂时没有公告。\n[返回游戏:look]\n");
		return 1;
	}
	if(arg && sscanf(arg,"%d",idx)==1){
		if(idx<1 || idx>sizeof(list)){
			write("没有这条公告。\n[返回公告列表:notices]\n");
			return 1;
		}
		mapping n=list[idx-1];
		string s="§6【"+(string)n["date"]+"】"+(string)n["title"]+"§r\n";
		foreach(n["body"],string line)
			s+=line+"\n";
		s+="\n[返回公告列表:notices]|[返回游戏:look]\n";
		write(s);
		return 1;
	}
	string s="§6【公告中心】§r（共"+sizeof(list)+"期，新版在前）\n";
	for(int i=0;i<sizeof(list);i++)
		s+="["+(string)list[i]["date"]+" "+
			(string)list[i]["title"]+":notices "+(i+1)+"]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
