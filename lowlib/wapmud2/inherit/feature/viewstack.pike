#include <globals.h>
#include <wapmud2/include/wapmud2.h>
#define VIEW_PAGE_SNAPSHOT_TTL (30*60)
#define VIEW_PAGE_SNAPSHOT_LIMIT 16
#define VIEW_PAGE_SNAPSHOT_MAX_BYTES (512*1024)
#define VIEW_PAGE_SNAPSHOT_TOTAL_BYTES (2*1024*1024)
private function|zero init_view=0;
private mixed init_view_arg;
private array(mixed) viewstack=({});
private mapping spliter=([]);
private mapping(string:mapping(string:mixed)) view_page_snapshots=([]);
private int view_page_snapshot_serial;
private int combat_flag=1;
mapping query_spliter(){
	return spliter;
}

private int query_view_page_snapshot_bytes()
{
	int total=0;
	foreach(indices(view_page_snapshots),string snapshot_id){
		mapping snapshot=view_page_snapshots[snapshot_id];
		if(!snapshot)
			continue;
		total+=sizeof((string)(snapshot["header"] || ""));
		total+=sizeof((string)(snapshot["text"] || ""));
		total+=sizeof((string)(snapshot["footer"] || ""));
	}
	return total;
}

private void cleanup_view_page_snapshots()
{
	int now=time();
	array(string) snapshot_ids=indices(view_page_snapshots);
	for(int i=0;i<sizeof(snapshot_ids);i++){
		mapping snapshot=view_page_snapshots[snapshot_ids[i]];
		if(!snapshot || (int)snapshot["expires"]<now)
			m_delete(view_page_snapshots,snapshot_ids[i]);
	}
	while(sizeof(view_page_snapshots)>VIEW_PAGE_SNAPSHOT_LIMIT ||
	   query_view_page_snapshot_bytes()>VIEW_PAGE_SNAPSHOT_TOTAL_BYTES){
		string oldest_id="";
		int oldest_serial=0;
		snapshot_ids=indices(view_page_snapshots);
		for(int i=0;i<sizeof(snapshot_ids);i++){
			mapping snapshot=view_page_snapshots[snapshot_ids[i]];
			int serial=(int)snapshot["serial"];
			if(oldest_id=="" || serial<oldest_serial){
				oldest_id=snapshot_ids[i];
				oldest_serial=serial;
			}
		}
		if(oldest_id=="")
			break;
		m_delete(view_page_snapshots,oldest_id);
	}
}

// 分页内容必须独立于不断变化的 spliter。挂机每秒刷新视图时，旧页面
// 的“下一页”仍从这里读取生成链接时的完整快照。
string cache_view_page_snapshot()
{
	string header=(string)(spliter["header"] || "");
	string text=(string)spliter["text"];
	string footer=(string)(spliter["footer"] || "");
	string snapshot_id;
	if(!text || text=="" || sizeof(header)+sizeof(text)+sizeof(footer)>
	   VIEW_PAGE_SNAPSHOT_MAX_BYTES)
		return "";
	cleanup_view_page_snapshots();
	view_page_snapshot_serial++;
	if(view_page_snapshot_serial<=0)
		view_page_snapshot_serial=1;
	snapshot_id=sprintf("%d-%d",time(),view_page_snapshot_serial);
	view_page_snapshots[snapshot_id]=([
		"header":header,
		"text":text,
		"footer":footer,
		"expires":time()+VIEW_PAGE_SNAPSHOT_TTL,
		"serial":view_page_snapshot_serial,
	]);
	cleanup_view_page_snapshots();
	return view_page_snapshots[snapshot_id] ? snapshot_id : "";
}

mapping|zero query_view_page_snapshot(string snapshot_id)
{
	mapping snapshot;
	if(!snapshot_id || snapshot_id=="")
		return 0;
	snapshot=view_page_snapshots[snapshot_id];
	if(!snapshot || (int)snapshot["expires"]<time()){
		if(snapshot)
			m_delete(view_page_snapshots,snapshot_id);
		return 0;
	}
	return ([
		"header":(string)snapshot["header"],
		"text":(string)snapshot["text"],
		"footer":(string)snapshot["footer"],
	]);
}

mapping query_view_page_snapshot_status()
{
	cleanup_view_page_snapshots();
	return ([
		"entries":sizeof(view_page_snapshots),
		"limit":VIEW_PAGE_SNAPSHOT_LIMIT,
		"ttl_seconds":VIEW_PAGE_SNAPSHOT_TTL,
		"max_bytes":VIEW_PAGE_SNAPSHOT_MAX_BYTES,
		"total_bytes":query_view_page_snapshot_bytes(),
		"total_bytes_limit":VIEW_PAGE_SNAPSHOT_TOTAL_BYTES,
	]);
}
void push_view(function f,mixed...args){
	viewstack=({({f,args})})+viewstack;
}
void pop_view(){
	viewstack=a_delete(viewstack,0);
}
void write_view_tmp(void|object|function f,void|mixed...args){
	object env = environment(this_object());
	if(!combat_flag&&!this_object()->in_combat)
		combat_flag=1;
	if(this_object()->in_combat&&combat_flag){
		f=WAP_VIEWD["/fight"];
		reset_view(WAP_VIEWD["/fight"]);
		spliter["footer"]="";
		combat_flag=0;
	}
	spliter["header"]="";
	if(env&&env->is("room"))
		spliter["text"]=env->query_arrive_msg(this_object()->name)+f(@args);
	else
		spliter["text"]=f(@args);
	if(sizeof(viewstack)>1){
		spliter["footer"]="";
		if(viewstack[0][0]->cacheable)
			spliter["footer"]="[返回:flushview]\n[返回游戏:look]";
		else
			spliter["footer"]="[返回:flushview]\n[返回游戏:look]";
	}
	this_object()->command("_explorer _player/spliter", this_object());
}
void write_view(void|object|function f,void|mixed...args){
	object env = environment(this_object());
	if(init_view==0)
		init_view=WAP_VIEWD["/init"];
	if(!combat_flag&&!this_object()->in_combat)
		combat_flag=1;
	if(this_object()->in_combat&&combat_flag){
		reset_view(WAP_VIEWD["/fight"]);
		f=0;
		combat_flag=0;
	}
	//////////////////////触发随机奖励界面时，要强制通过输入验证码，才能解除该界面
	if(this_object()["/plus/random_rcd"]==1){
		reset_view(WAP_VIEWD["/modal_award"]);//随机奖励界面
		f=0;
	}
	//////////////////////触发随机奖励界面时，要强制通过输入验证码，才能解除该界面
	if(sizeof(viewstack)==0)
		push_view(init_view,init_view_arg);
	if(f)
		push_view(f,@args);
	if(!viewstack[0][0]->cacheable)
		this_object()->reset_hidden();
	spliter["header"]="";
	if(env&&env->is("room"))
		spliter["text"]=env->query_arrive_msg(this_object()->name)+viewstack[0][0](@(viewstack[0][1]));
	else
		spliter["text"]=viewstack[0][0](@(viewstack[0][1]));
	spliter["footer"]="";
	if(sizeof(viewstack)>1){
		if(viewstack[0][0]->cacheable)
			spliter["footer"]="[返回:popview]\n[返回游戏:look]";
		else
			spliter["footer"]="[返回:popview]\n[返回游戏:look]";
	}
	this_object()->command("_explorer _player/spliter", this_object());
}
void reset_view(void|object|function f,void|mixed...args){
	viewstack=({});
	if(f){
		init_view=f;
		init_view_arg=args;
		push_view(f,@args);
	}
}
